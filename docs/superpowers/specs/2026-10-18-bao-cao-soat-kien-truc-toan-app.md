# Báo cáo soát kiến trúc toàn client-app — chỉ đọc (2026-10-18)

**Bối cảnh:** người dùng chốt 2026-10-18 *"từ đây về sau tất cả các phần mới hay cũ đều phải tuân thủ kiến trúc mà
client-app đang hướng đến"* và *"sau khi hoàn thành phần này, tôi muốn kiểm tra lại toàn bộ"* (spec G94 mục 13). Báo cáo
này là **phép đo chỉ đọc**, không sửa tệp nào; việc sửa làm **sau lượt G94**, người dùng chọn lát. Đối chiếu
`docs/KIEN_TRUC_CLIENT_APP.md` mục 4 · 5 · 6 · 8. HEAD lúc đo `af7351fe`. Bỏ qua `features/premium` (đã dọn ở G94 lát 1).

Nguồn: một lượt quét máy (grep) + một agent đọc từng mảng. Ký hiệu: **A** = lệch rõ, trích được hai đầu · **B** = chưa
chắc, có lý do · **C** = để biết / không lệch theo luật đã viết.

**Tổng: 14 A · 7 B · 11 C.** Nặng nhất: luật *"mục tiêu đã xong"* (`daHoanThanh`) viết lại 6 chỗ / 5 tệp với hai công
thức. Chỉ **một** datasource API backend bị trang gọi thẳng (`TroLyOnlineRemoteDataSource` ở trang Trợ lý AI — trang còn
cầm `CancelToken` của Dio). Không tệp nào ở gốc `data/` bọc API backend. Repository (10 cặp) và import `domain/` · `core/`
sạch.

## 1. Model / hàm thuần sai chỗ

| Mảng | Tệp:dòng | Loại | Lệch | Cách sửa tối thiểu | Tệp phải đổi |
|---|---|---|---|---|---|
| transaction | `transaction/data/models/transaction_type_label.dart:6` `transactionTypeLabel` | A | Hàm thuần (câu chữ) nằm ở `data/models/` (chiều ngược mục 8) | Dời sang `transaction/domain/`, sửa 2 import + test | 3 lib + 1 test |
| budget | `budget/data/models/budget_period.dart:22,33` (7 hàm lịch, tự ghi "logic thuần") | A | Hàm thuần ở `data/models/` | Dời sang `budget/domain/budget_period.dart` | 3 lib + 1 test |
| notification | `notification/domain/notification_prefs.dart:441,471` `toJson` / `fromJson` | B | Bộ đọc / ghi JSON (bản lưu secure storage, không phải payload server) ở `domain/`; lớp mang luật | Giữ lớp ở `domain/`, chuyển `toJson` / `fromJson` vào `notification_prefs_store.dart` | 2 lib + 1 test |
| transaction | `transaction/domain/doc_mon_hang.dart:41,43` `MonHang.toJson` / `fromJson` | B | Đọc / ghi tệp cục bộ `.mon.json` ở `domain/` | Chuyển hai hàm thành private trong `kho_anh_quet.dart` | 2 lib + 1 test |
| transaction · ai_edge · notification | `KetQuaAi.tuThamSo`, `KetQuaLenhAi.tuLoiGoi`, `KetQuaChinhThamSo`, `docJsonGemmaAnh`, `docSuKien`, `HangSoLieu.json` | C | Đọc đầu ra mô hình / tham số tool / kênh Kotlin — hàm thuần hợp lệ | — | 0 |

## 2. Tệp ở gốc `features/<x>/data/` (54 tệp)

Không tệp nào bọc API backend (`grep dio|core/api|DioClient` chỉ trúng chữ `supportAudio`). Mọi tệp là nguồn / store /
cổng / dịch vụ bị gọi theo tiền lệ, trừ:

| Mảng | Tệp:dòng | Loại | Lệch | Cách sửa | Tệp |
|---|---|---|---|---|---|
| ai_chat | `ai_chat/data/nguon_lenh_tao.dart:17` | A | Đọc ví bằng `sl<AppDatabase>().walletDao.getActive` trong khi có `WalletRepository.getActive` (mục 5 Đọc; quét 2 chấp nhận dạng `walletDao.getActive(` nên không bắt) | `sl<WalletRepository>().getActive(idaccount)` | 1 |
| transaction | `transaction/data/dong_hang_bien_dong.dart:15,33` | B | Hai hàm nhiều bước (nhớ ví → xoá hàng → xoá ảnh) — dáng bộ điều phối | Nếu chốt: dời sang `transaction/application/` | 2 + 1 test |

## 3. Tầng giao diện / application import sai tầng

| Mảng | Tệp:dòng | Loại | Lệch | Cách sửa | Tệp |
|---|---|---|---|---|---|
| ai_chat | `ai_chat/presentation/pages/ai_chat_page.dart:63,336,659` (+ `:32` `import 'package:dio/dio.dart' show CancelToken`) | A | Trang gọi thẳng **datasource API backend** `TroLyOnlineRemoteDataSource` và cầm kiểu Dio | Repository / nguồn DI `ai_chat/data/…` bọc `hoi(…)`, giấu `CancelToken` sau kiểu huỷ thuần | 4–5 |
| notification | `notification/presentation/pages/notification_center_page.dart:10,136,172,252,547,563` | A | Trang **ghi** thẳng qua datasource `NhatKyThongBao` (bọc DAO cục bộ) | Thêm `ghiNhatKy` / `ghiNhatKyNhieu` vào `ThongBaoRepository` | 4 lib + 1 test |
| notification (application) | `notification/application/mo_tu_tom_tat_bien_dong.dart:13` `import 'package:flutter/widgets.dart'` | A | `application/` import widgets chỉ để lấy `AppLifecycleState` | `import 'dart:ui' show AppLifecycleState;` | 1 |
| notification | `notification/presentation/pages/notification_settings_page.dart:7,8,10` (`OsNotifier`, `KenhBienDong`, `KenhPhienNganHang`) | B | Cổng nền tảng nằm dưới `datasources/` được trang gọi như nguồn — chỉ lệch vị trí chữ (tiền lệ cổng ở gốc `data/`) | Ghi ngoại lệ vào KIEN_TRUC mục 8 (0 mã) **hoặc** dời 2 kênh lên gốc `data/` (~9 lib + 9 test); `os_notifier*` nên giữ (mục 7 đã chốt chỗ) | 0 hoặc ~18 |
| transaction | `transaction/presentation/pages/add_transaction_page.dart:13,14,135,139` (`KhoBienLai`, `KhoAnhQuet`) | B | Trang import kiểu datasource chỉ để làm khe tiêm test, chuyển vào nguồn | Thay hai khe bằng một khe `ThemGiaoDichNguon? nguon` | 1 lib + 4 test |
| transaction | `transaction/presentation/pages/quet_anh_page.dart:27,138,216,222,226,243` (`KhoAnhQuet`) | B | Trang ghi / xoá thẳng qua cổng hệ tệp cục bộ | Nguồn DI ở gốc `transaction/data/` (vd. `AnhQuetNguon`) | 4 |

## 4. Repository — 0 lệch

20 tệp = 10 cặp interface + `_impl`; interface không import Drift; không lớp `*Repository` cụ thể thiếu interface (ngoài
`GoiRepository` của Premium). (C) Bốn impl gọi DAO thẳng không qua datasource — mục 8 không bắt.

## 5. Import `domain/` · `core/`

`domain/` → `data/` ngoài `data/models/`: 0; → `presentation/` / `application/`: 0; → Flutter / Drift / `core/di`: 0.
`core` → `features` ngoài bốn điểm ghép: 8 dòng, đều trỏ vào năm tệp được phép.

| Mảng | Tệp | Loại | Lệch | Cách sửa | Tệp |
|---|---|---|---|---|---|
| core | `core/ui/bao_che_day_toast.dart` | A (đã biết) | Widget dùng chung toàn app nằm ở `core/` (mục 8 → `shared/widgets/`) | Dời sang `shared/widgets/`, sửa 2 import, dời test | 3 lib + 2 test |

## 6. Chữ ký 1 — "một định nghĩa duy nhất"

| Mảng | Hai đầu | Loại | Lệch | Cách sửa | Tệp |
|---|---|---|---|---|---|
| goal (+ notification) | `goal_entity.dart:243` `daHoanThanh` (docstring nói rõ đừng chép) ↔ `goal_entity.dart:283`, `goal/application/goal_auto_deposit_runner.dart:47`, `goal/domain/moc_trich_nen.dart:23`, `notification/application/reminder_scheduler.dart:230`, `goal/presentation/widgets/chi_tiet_muc_tieu/khoi_nhan_dinh_muc_tieu.dart:30,48` | **A — nặng nhất** | Viết lại 6 lần, 2 công thức (`progress >= 1.0` ↔ `remainingAmount <= 0`) — khác nhau ở biên NaN | Thay cả 6 bằng `.daHoanThanh` | 5 |
| category | `category/presentation/pages/gan_danh_muc_page.dart:120` ↔ `transactionTypeLabel` | A | Hai nhánh thu / chi viết tay — đúng mẫu `transactionTypeLabel` sinh ra để thay | Gọi `transactionTypeLabel(t.type)` | 1 |
| goal | `goal/presentation/pages/goal_add_page.dart:251-260` `_cycleDays` ↔ `goal/domain/goal_forecast.dart:26-33` `soNgayChuKy`; ánh xạ chu kỳ viết 2 lần (:113–117, :376–381); `:273` trừ `DateTime` thô (trái luật tính theo NGÀY) | A | | Dùng `soNgayChuKy`, `_chuKyHienTai`, cắt về ngày | 1–2 |
| goal | `goal/presentation/widgets/goal_config_card.dart:36-42` ↔ `chi_tiet_muc_tieu/khoi_nhan_dinh_muc_tieu.dart:39-45` | A (nhẹ) | Cùng bảng nhãn nhịp `'Day'→'mỗi ngày'…` chép 2 lần | `nhanNhipChuKy` ở `goal_forecast.dart` | 3 |
| bill | `bill/domain/bill_recurrence.dart:139-145` `tenChuKyHoaDon` ↔ `bill_add_page.dart:791-796`, `bill_edit_page.dart:339-342` | A | Nhãn chu kỳ viết lại ở hai form | Dựng option từ hằng chu kỳ + `tenChuKyHoaDon` | 2 |
| core | `core/sync/category_icon_registry.dart:31,42` `trim().toLowerCase()` ↔ `core/category/category_name.dart` `normalizeCategoryName` | A | Tên khác NFC / khoảng trắng đôi tra icon trượt, im lặng | Gọi `normalizeCategoryName` | 1 |
| ai_chat | `ai_chat/data/nguon_lenh_tao.dart:20-23` lọc tay ↔ `CategoryManagementRepository.selectableChildren` | A (nhẹ) | | `selectableChildren(accountId:, classify: 'chi')` | 1 (chung tệp mục 2) |
| budget | `budget/data/datasources/budget_local_data_source.dart:156-160` `getExpenses` không qua `khoanVaoThongKe` | **B — cần người dùng chốt** | Ngân sách **tổng** cộng cả khoản điều chỉnh số dư giảm và nửa chi của cặp nạp mục tiêu kiểu cũ, trong khi Phân tích / Trang chủ / Sổ đều loại | Nếu chốt: thêm `khoanVaoThongKe` vào `getExpenses` | 1 + test |
| transaction / analytics | `summarizeTransactions` ↔ `tongThuChi` | C | Vòng cộng chép 2 lần, luật vẫn một chỗ | (tuỳ chọn) | 2 |
| bill / budget / goal / ai_edge | 6 bản `DateTime(y, m+1, 0).day` / cộng tháng kẹp ngày | C | Phép nền chép 6 lần | (tuỳ chọn) `ngayKepTrongThang` ở `core/utils` | 6 + 1 |
| budget | `budget_repository_impl.dart:353` ↔ `budget_form.dart:169` | C | Ngày bắt đầu mặc định viết 2 chỗ | (tuỳ chọn) | 3 |
| nhiều mảng | `DateFormat('dd/MM/yyyy')` dựng tay ở ~14 tệp ↔ `DateFormatter.formatDate` | C | Hai đường song song, không test quét | (tuỳ chọn) | ~14 |
| nhiều mảng | `(x * 100).round()}%` tự viết > 10 chỗ | C | Chưa có định nghĩa chung | — | — |

## Tổng theo mảng

| Mảng | A | B | C |
|---|---|---|---|
| ai_chat | 3 | 0 | 0 |
| ai_edge | 0 | 0 | 2 |
| bill | 1 | 0 | 0 |
| budget | 1 | 1 | 1 |
| category | 1 | 0 | 0 |
| goal | 3 | 0 | 0 |
| notification | 2 | 2 | 1 |
| transaction | 1 | 4 | 2 |
| core | 2 | 0 | 0 |
| nhiều mảng | 0 | 0 | 5 |
| analytics · auth · home · profile · wallet | 0 | 0 | 0 |
| **Tổng** | **14** | **7** | **11** |

**Rẻ và rõ, nên sửa trước:** `daHoanThanh` (5 tệp) · `mo_tu_tom_tat_bien_dong` → `dart:ui` (1) · `gan_danh_muc_page:120`
(1) · `nguon_lenh_tao` (1, sửa cả hai lệch) · `tenChuKyHoaDon` (2) · `category_icon_registry` (1) · `goal_add_page` (1).

**Cần người dùng chốt trước khi sửa:** ngân sách tổng có áp `khoanVaoThongKe` không; cổng nền tảng / cổng hệ tệp dưới
`datasources/` — ghi ngoại lệ vào KIEN_TRUC mục 8 hay dời tệp.

Đã biết thêm (spec G94 mục 13): `core/database/daos/other_daos.dart` chứa ba DAO → tách; `SyncEngine` 2.164 dòng →
lượt riêng.

## Quyết định người dùng 2026-10-19

Trình báo cáo đầu phiên 2026-10-19 (HEAD `868551b6`; đối chiếu lại mọi điểm A trên mã hiện tại — ngoài Premium chỉ
`app_router.dart` đổi từ `af7351fe`, số dòng trích còn đúng). G94 tạm gác (chưa nghiệm thu máy).

1. **Ngân sách tổng đi qua `khoanVaoThongKe`** (hàng B mục 6): *đã chi* của ngân sách tổng bỏ khoản *Điều chỉnh số dư*, *Số dư ban
   đầu*, nửa chi cặp nạp mục tiêu kiểu cũ — khớp *chi tháng này* ở Trang chủ / Phân tích / Sổ. Ba loại ấy không danh mục nên
   ngân sách theo danh mục không đổi; dòng điều chỉnh vẫn ở Sổ, không còn trong danh sách ngân sách tổng.
2. **Cổng nền tảng / gói ngoài / hệ tệp → `data/datasources/`** (hàng B mục 3): mục 8 `KIEN_TRUC` thêm hàng; trang được gọi thẳng
   cổng nền tảng, không được import datasource bọc CSDL / API backend (test quét mới). Đo 2026-10-19: hai chỗ ấy ngang nhau (~10
   tệp ở gốc `data/`, ~12 dưới `datasources/`); xếp loại lại thì **8** tệp ở gốc là cổng (`slm_runtime`, `phien_cong_cu`,
   `nguon_ly_do_thoat`, `nguon_tai_nen`, `tai_nen_background_downloader`, `luu_tep_platform`, `luu_anh_qr`, `mo_lien_ket`) → dời;
   nguồn / store / dịch vụ (`nguon_giong_noi`, `slm_cache`, `mo_hinh_tai_ve`, `bo_nap_mo_hinh`, `xuat_tep_service_impl`) ở lại.
   Ba hàng B của mục 3 (Cài đặt thông báo, Thêm giao dịch, Quét ảnh gọi thẳng cổng) đóng theo luật này, 0 mã.
   Preflight 2026-10-19 làm rõ hai vế: **cổng** = interface + bản thật cho MỘT ranh giới (kênh `flowmoney/*`, gói nền tảng, thư mục
   tệp riêng) → `datasources/`; **store** (kho khoá–giá trị / bảng cục bộ mang luật của mảng — `*_store`, `cong_tac_*`, kể cả bọc
   `flutter_secure_storage`) và nguồn / dịch vụ → gốc `data/`; `auth_local_data_source` (đã ở `datasources/` từ trước) giữ chỗ.
   `luu_anh_qr` lẫn bộ tải ảnh Dio trần → tách bộ tải ra tệp riêng để cổng kênh không import Dio (trang Chờ thanh toán gọi thẳng nó).
3. **Làm cả bốn lát** — Mục tiêu · Giao dịch + Danh mục · Thông báo + Trợ lý AI · Hoá đơn + core + Premium — **bằng agent con**.
   Thêm vào lát 4 (đo 2026-10-19, ngoài 14 A cũ vì báo cáo bỏ qua Premium): `premium/presentation/widgets/the_khoa_quyen.dart` 12
   giá trị `Color(0x…)` trên 10 dòng. Thêm vào lát 1 (C): `analytics/domain/du_bao_dong_tien.dart:338` viết
   `daHoanThanh || remainingAmount <= 0` — vế sau thừa. Đã kiểm hai điểm *rẻ*: `progress` trả 1.0 khi `targetAmount <= 0` nên hai
   công thức *đã xong* chỉ khác ở NaN / âm; `transactionTypeLabel` trả đúng chữ màn Gắn danh mục đang in.

Chưa làm trong đợt này: hàng B `notification_prefs` / `MonHang` toJson, `dong_hang_bien_dong`; mọi hàng C; `other_daos.dart`,
`SyncEngine`.
