# Kiến trúc Client-app (FlowMoney, Flutter)

> Viết 2026-10-10, sau đợt **bịt điểm rò kiến trúc** (spec `docs/superpowers/specs/2026-10-10-bit-diem-ro-kien-truc-client-design.md`);
> cập nhật cùng ngày (khuya) sau đợt **dọn vị trí tệp** (spec `docs/superpowers/specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`)
> — mục 3, 4, 6, 7, 8, 9, 10.
> Tệp do **client** sở hữu — được sửa, và phải khớp mã. Mọi con số ở đây đếm bằng lệnh ngày **2026-10-10** trên
> `src/Client-app` (lệnh ghi cạnh số); **đừng cộng dồn, hãy đếm lại** khi cập nhật.

Mục lục

1. [Một câu](#1-một-câu)
2. [Bốn ràng buộc → bốn quyết định](#2-bốn-ràng-buộc--bốn-quyết-định)
3. [Cây thư mục](#3-cây-thư-mục)
4. [Ba tầng và vai trò của `core`](#4-ba-tầng-và-vai-trò-của-core)
5. [Tám luồng chính](#5-tám-luồng-chính)
6. [Ba chữ ký thật](#6-ba-chữ-ký-thật)
7. [Mối quan tâm xuyên suốt](#7-mối-quan-tâm-xuyên-suốt)
8. [Luật vị trí tệp](#8-luật-vị-trí-tệp)
9. [Ưu điểm, nhược điểm, nợ có tên](#9-ưu-điểm-nhược-điểm-nợ-có-tên)
10. [Cách nói khi trình bày](#10-cách-nói-khi-trình-bày)

---

## 1. Một câu

Client-app là **feature-first, ba tầng `data · domain · presentation`, offline-first** — SQLite (Drift) là nguồn sự thật
cục bộ, server chỉ là nơi hội tụ giữa các máy. Nó **không** phải Clean Architecture đúng sách, và đó là lựa chọn có lý
do: interface repository nằm ở tầng `data` chứ không ở `domain`, không có lớp use case, và Entity chỉ có ở 4/14 mảng
(ví, giao dịch, mục tiêu, ngân sách). Tầng `domain` ở đây là **hàm thuần** — luật nghiệp vụ không biết Flutter, không
biết CSDL — chứ không phải nơi sở hữu interface. Bài toán (một người, một máy, dữ liệu nhỏ, phải chạy không mạng) không
trả nổi giá của bốn tầng và một lớp ánh xạ cho mỗi kiểu; thứ nó cần là luật đúng và đúng **một chỗ**, và thứ ấy được
canh bằng test quét mã nguồn (mục 6).

## 2. Bốn ràng buộc → bốn quyết định

| Ràng buộc của bài toán | Quyết định | Ở đâu trong mã |
|---|---|---|
| Ghi chép phải chạy khi không có mạng (đi chợ, đi tàu) — một khoản bị mất vì rớt sóng là app hết đáng tin | **Offline-first**: mọi lệnh ghi vào SQLite trước, giao diện đọc từ SQLite; mạng chỉ là chuyện đồng bộ | `core/database/` (Drift, schema v30), mọi repository |
| Hai máy cùng tài khoản ghi khi offline; server không có khái niệm "bản nháp" | **Đồng bộ tự viết, hai chiều, LWW theo `update_at`**, đẩy lô thao tác + kéo theo mốc giờ-server | `core/sync/sync_engine.dart` (2.166 dòng), `sync_payload_normalizer.dart`, `moc_keo_ve.dart` |
| Người dùng chọn AI **trên máy** để chạy không mạng và không gửi dữ liệu tài chính đi | **Hai tầng AI**: luật + hàm thuần (`ai_edge/domain`) cho mọi màn; mô hình Gemma 4 E2B trên máy chỉ cho hỏi đáp / đọc câu / đọc ảnh, mọi con số đi qua lớp chắn | `features/ai_edge/`, `features/ai_chat/` |
| Tự trả hoá đơn, tự trích mục tiêu phải xảy ra đúng lúc kể cả khi app đóng | **Chạy nền bằng WorkManager** đánh thức một engine Flutter không giao diện, dùng lại đúng bộ quét của app | `android/.../TuChuyenTien*.kt`, `core/nen/` |

## 3. Cây thư mục

`lib/` có **546** tệp `.dart`, **120.022** dòng (kể 13 tệp `.g.dart` do Drift sinh) — `find lib -name '*.dart' | wc -l`
và `… | xargs cat | wc -l`. `test/` có **595** tệp, **119.347** dòng. (Đếm lại sau đợt dọn vị trí tệp; trước đợt 545 / 596.)

```
lib/
├── main.dart                 điểm vào app + điểm vào engine nền (`chayNenTuChuyenTien`, @pragma)
├── core/            124 tệp  hạ tầng + điểm ghép — KHÔNG chứa màn hình (16 chủ đề — test quét 25)
│   ├── api/           3      DioClient, AuthInterceptor (gắn token, làm mới, dịch 401 + code)
│   ├── auth/          3      buoc_dang_xuat (kiểu thuần 4 tệp hạ tầng dùng), PhienDieuPhoi(+That) ← điều phối phiên
│   ├── category/      1      category_name (normalizeCategoryName — DAO + util dùng)
│   ├── constants/     2      app_constants, app_localization
│   ├── database/     39      AppDatabase, 10 tệp DAO, bảng, kết nối (native / web)
│   ├── di/            1      injection_container (943 dòng) ← điểm ghép duy nhất của DI
│   ├── errors/        1      app_exceptions
│   ├── nen/           6      chạy nền: chay_nen, luot_nen, lich_nen, kênh `flowmoney/tu_chuyen_tien`
│   ├── network/       1      connection_monitor
│   ├── notification/ 35      bộ quét + 20 luật + OsNotifier (cổng) + nhắc + D1/biên lai/nhắc ghi + ThongBaoNguon
│   ├── ocr/           7      DocChuAnh (cổng) + bản ML Kit, kho ảnh quét
│   ├── realtime/      5      RealtimeChannel; chỉ realtime_socket.dart import socket_io_client
│   ├── router/        1      app_router (GoRouter) ← điểm ghép
│   ├── sync/          8      SyncEngine, normalizer, checkpoint, noiBoNgheKetQuaDay
│   ├── ui/            4      thong_bao_nhanh (toast), bieu_do_cham, do_chu, bao_che_day_toast
│   └── utils/         7      CurrencyFormatter, gioi_han_do_dai, so_bang_chu, ngay_trong_cau, khop_ten…
├── features/        408 tệp  14 mảng nghiệp vụ, mỗi mảng data / domain / presentation
│   ├── ai_edge/      81      data 22 · domain 54 · presentation 5 — luật, gói số, tool, SLM runtime, lớp chắn
│   ├── transaction/  55      data 9 · domain 22 · presentation 24 (widgets/them_giao_dich/ 7 tệp)
│   ├── analytics/    51      data 8 · domain 19 · presentation 24 (widgets/phan_tich/ 14 tệp)
│   ├── bill/         33      data 5 · domain 14 · presentation 14
│   ├── goal/         33      data 4 · domain 17 · presentation 12
│   ├── wallet/       32      data 11 · domain 9 · presentation 12 (state/ 1)
│   ├── budget/       28      data 8 · domain 7 · presentation 13
│   ├── premium/      27      data 8 · domain 8 · presentation 11 (bloc/ thay cubit/; state/ 1)
│   ├── auth/         21      data 5 · domain 1 · presentation 15 (bloc/ 4 kể AuthBloc + current_account · pages/ 6 · state/ 1 · widgets/ 4)
│   ├── category/     21      data 9 · domain 6 · presentation 6
│   ├── profile/       8      presentation 8
│   ├── home/          7      domain 1 · presentation 6
│   ├── notification/  6      presentation 6 (luật nằm ở core/notification — nợ G88)
│   └── ai_chat/       5      data 2 · presentation 1 · spike/ 2 (mã đo C4 sau cờ dart-define — miễn trừ quét 25)
└── shared/           13 tệp  theme/ 3 (AppTheme, AppColors) · widgets/ 10 (MainShell, chuông, toast…)
```

Đếm mảng: `for d in features/*/; do find $d -name '*.dart' | wc -l; done` (và `$d/data`, `$d/domain`, `$d/presentation`).
Số trên đếm lại 2026-10-10 sau đợt dọn vị trí tệp (HEAD `e2ab224c`).
`core/notification` nay **35** tệp (34 + `thong_bao_nguon.dart` của đợt này).

## 4. Ba tầng và vai trò của `core`

| Tầng | Trách nhiệm | Được phép import | Không được |
|---|---|---|---|
| `presentation/` | Trang, widget, Bloc/Cubit; giữ trạng thái màn, gọi repository | `domain/`, `data/` của chính mảng và mảng khác (repository, nguồn), `core/` — kể `core/database` để dùng **kiểu** hàng Drift (`Wallet`, `Transaction`…), `core/di` để lấy repository qua service locator, `core/ui`, `core/utils`, `core/constants` — và `shared/` | cầm `AppDatabase` / gọi DAO (**test quét 22** — kiểu hàng thì được, lối truy cập thì không); tệp quá 1.200 dòng ngoài danh sách miễn trừ (**quét 23**) |
| `domain/` | Hàm thuần: luật nghiệp vụ, phép tính, định dạng câu | Dart thuần, `domain/` khác | Flutter, Drift, `sl` |
| `data/` | Repository (interface + bản thi hành), datasource, Entity, `services/` điều phối nhiều bước | `core/database`, `core/api`, `domain/` | widget |

Ba tầng **không** đối xứng như sách: interface repository khai ở `data/repositories/<x>_repository.dart` cạnh bản thi
hành; `domain/` không biết interface nào. Một số repository trả **Entity** (ví, giao dịch, mục tiêu, ngân sách), số khác
trả **hàng Drift** (hoá đơn, danh mục) — và từ 2026-10-10 có **11 lối chuyển tiếp** cho trang (`getActiveRows`,
`getAllRows`, `watchAllRows`, `getRowById`, `loadBangTraTen`, `BillRepository.getById`,
`TaiPhanBoNguon.ghiPhanHoi`…) trả đúng kiểu hàng Drift mà trang đang cầm, vì Entity cho 14 mảng là việc ngoài phạm vi
(quyết định 10 của spec, nợ G88).

**`core` có hai vai, cố ý tách bạch:**

- **Hạ tầng** dùng chung, không biết mảng nào: CSDL, HTTP, socket, OCR, định dạng tiền, toast. Đây là phần lớn của 124 tệp.
- **Điểm ghép** — nơi duy nhất được biết mọi mảng: `core/di/injection_container.dart` (đăng ký mọi thứ, nối hook),
  `core/router/app_router.dart` (mọi route), `core/nen/chay_nen.dart` (dựng DI ở chế độ nền), và
  `core/auth/phien_dieu_phoi_that.dart` — bộ điều phối phiên nhận **hook hàm** cho mọi việc của mảng khác, nên chính nó
  **không** import `features/`. Đo `grep -rnE "^import .*features/" lib/core` (2026-10-10 sau đợt dọn vị trí tệp):
  **175** dòng — điểm ghép **138** (DI 82 · router 54 · `chay_nen` 2), hạ tầng **37** (`notification_rules` 10 ·
  `sync_engine` 7 · `notification_scanner` 5 · `lich_nen` 3 · …). 37 dòng hạ tầng là nợ có tên (G88 gạch 4). *(Trước
  đợt: 172 = 136 + 36. DI +2 vì `TransactionRepositoryImpl` / `CategoryManagementRepositoryImpl` tách tệp `_impl`; router
  +1 và `current_account` −1 vì tệp ấy rời `core` về `features/auth/presentation/bloc/`; `sync_engine` 6 → 7 vì
  `bill_recurrence` về `features/bill/domain/`.)* Từ 2026-10-10 **test quét 25** (`vi_tri_tep_theo_luat_test`) canh:
  ngoài ba điểm ghép, tệp `core` import `features/` phải nằm trong danh sách chỉ-được-giảm (`conChoCoreImport`).

## 5. Tám luồng chính

**Ghi.** Trang gọi Bloc/Cubit (hoặc gọi thẳng repository với màn đơn giản) → repository ở `features/<x>/data/repositories/`
ghi SQLite với `syncStatus = pending` và `updatedAt` mới. Mọi thay đổi số dư đi qua `wallet/data/services/so_du_vi_service.dart`
— chỗ **duy nhất** được ghi `wallets.balance`, vì số dư là cache của tổng sổ giao dịch (G37). Repository xong thì gọi
`SyncEngine.scheduleSync()` (giãn cách), nên người dùng không bao giờ chờ mạng.

**Đọc.** Màn đọc dùng **stream Drift** (`watch…`) qua repository — `StreamBuilder` ở trang hoặc Cubit nghe stream (ví dụ
`AnalyticsRepository.watchKy` gộp tám nguồn). Ghi ở bất kỳ đâu, kể cả Pull của đồng bộ, đều tự đẩy màn vẽ lại; không có
cache tầng giữa nào phải làm mới tay. Từ đợt 2026-10-10 trang **không** cầm DAO: lối đọc là repository hoặc một nguồn đăng
ký DI (`ThongBaoNguon`, `TaiPhanBoNguon`, `GanDanhMucNguon`).

**Đồng bộ.** `core/sync/sync_engine.dart` gom thao tác chờ theo thứ tự khoá ngoại (`_collectPendingOps`: hoá đơn **trước**
giao dịch), dựng payload tay rồi qua `SyncPayloadNormalizer`, `POST /sync/push`; kết quả phát ở `pushResultStream`
**trước** bước Pull (người nghe `BillPaymentConflictResolver`, `ViTrungTenResolver` nối ở `noiBoNgheKetQuaDay`). Rồi
`GET /sync/pull` với mốc giờ-server `mocTuMaxSince`, ghi bằng `insertAllOnConflictUpdate` (quy tắc 3), tính lại số dư,
tạo bản sao danh mục mặc định. Hợp đồng tên trường nằm ở `test/core/sync/sync_payload_contract_test.dart`.

**Thời gian thực.** `core/realtime/RealtimeChannel` giữ Socket.IO (chỉ `realtime_socket.dart` import thư viện), nối lại
theo `onConnectivityChanged`. Payload là **hộp đen** — client chỉ đọc tên sự kiện: `sync.completed` → `syncNow()` im lặng;
`account.upgraded` → gói làm mới; `account.force_logout` (ngoại lệ duy nhất đọc payload) → luồng `buocDangXuat` →
`PhienDieuPhoi` → `AuthBloc`.

**Nền.** Android `TuChuyenTien.kt` hẹn WorkManager theo mốc kế tiếp; worker thấy app đang mở thì gọi vào engine của app,
app đóng thì dựng `FlutterEngine` headless chạy `chayNenTuChuyenTien` (`main.dart`) → `core/nen/chay_nen.dart` dựng DI
`cheDoNen: true` → `LuotNen` (gói → đồng bộ → quét → đồng bộ). Cùng họ: `BienDongListenerService.kt` (đọc thông báo ngân
hàng, D1), `NhanBienLaiActivity.kt` (chia sẻ biên lai), `PhienNganHang.kt` (nhắc ghi) — cả ba ghi hàng chờ `.jsonl`,
Dart nhập khi bộ quét chạy.

**Thông báo.** `core/notification/notification_scanner.dart` chạy các luật thuần ở `notification_rules.dart`, ghi bảng
**cục bộ** `AppNotifications` bằng `insertIfAbsent` theo `dedupeKey` (không đi đồng bộ — quy tắc 9), đặt lịch hệ điều hành
qua `ReminderScheduler` + cổng `OsNotifier` (native / web / stub), đếm chuông qua `BadgeUpdater`. Trang đọc qua cổng
`ThongBaoNguon`; chạm thông báo đi `NotificationTapRouter` → deeplink, `go` hay `push` theo `nhanhThanhTab`.

**AI.** Tầng tất định: `ai_edge/domain` dựng **gói số** từ hàm domain sẵn có (lớp AI không tự tính — test quét 14) cho
khối Nhận xét ở sáu màn và kế hoạch tái phân bổ. Tầng mô hình: `ai_edge/data/slm_runtime.dart` (chỗ duy nhất import
`flutter_gemma`) chạy Gemma 4 E2B trên máy; màn Trợ lý AI đi `vong_lap_cong_cu.dart` — định tuyến `dinhTuyenCauHoi`, tool
**chỉ đọc** qua repository, mọi câu qua `kiemCauTraLoi` (sáu lớp chắn) trước khi hiện. Ô Nhập nhanh, lệnh tạo, đọc ảnh
quét dùng phiên một lời gọi; AI chỉ **điền sẵn**, người dùng bấm Lưu (bất biến ④).

**Xác thực.** `core/api/dio_client.dart` + `AuthInterceptor` gắn token từ `FlutterSecureStorage`, làm mới khi 401, dịch
401 mang `code` thành lời từ chối có lý do. `AuthBloc` giữ trạng thái và thứ tự emit; vòng đời phiên ở
`PhienDieuPhoi` hai pha: `moPhienCucBo` **trước** `AuthSuccess` (dọn tài khoản khác, bộ quét — để mở app không chờ mạng,
G86) rồi `batThoiGianThuc` · kiểm `_vanLaPhien` · `batDongBo`; `dongPhien` / `xoaDuLieu` khi đăng xuất hay bị buộc đăng xuất.

## 6. Ba chữ ký thật

**(1) Một định nghĩa duy nhất.** Mỗi luật hỏng-im-lặng có đúng một hàm, mọi nơi gọi lại nó: `khoanVaoThongKe` (khoản nào
vào thống kê), `viTinhVaoTong` (ví nào cộng vào tổng), `normalizeCategoryName` (trùng tên danh mục),
`CurrencyFormatter` (hiển thị tiền), `kyKeTiepCua` (kỳ hoá đơn kế), `BudgetEntity.mocKy` (lưới kỳ ngân sách),
`cuaSoNhinLai` (trung bình mỗi tháng), `duocDung` (quyền theo gói), `SoDuViService` (ghi số dư). Chép tay lần thứ hai là
lỗi đã xảy ra thật ở mỗi chỗ — ví dụ G41/G47 (bảng tra tên danh mục chép ba lần).

**(2) Test quét mã nguồn.** Luật nào bộ test hành vi không thấy được (một import lọt, một handler rỗng, một `?? 1`) thì
thành một test **đọc `lib/`** và đỏ khi luật bị phá. Bảng dưới khoá theo **tên tệp**: dãy số tự xưng 1–25 phủ **26
tệp** — số **14** được hai tệp cùng nhận (cả hai docstring đều ghi *"thứ mười bốn"*, va chạm có từ 2026-09-21) — cộng
**3** tệp cùng khuôn không đánh số, tổng **29**. Đếm: `grep -rlE "Directory\(['\"]lib" test` (25 tệp quét cây, đo
2026-10-10) cộng các tệp đọc danh sách tệp cố định. Test quét mới lấy số **26**.

| Số | Tệp (dưới `test/`) | Luật | Phạm vi | Từ |
|---|---|---|---|---|
| 1 | `core/utils/currency_formatter_test.dart` | chỉ `CurrencyFormatter` dựng `NumberFormat` | cây `lib/` | 2026-09-09 |
| 2 | `features/wallet/wallet_picker_sources_test.dart` | mỗi chỗ đọc danh sách ví được phân loại tay: bộ chọn hay bảng tra | cây | 2026-09-10 |
| 3 | `core/auth/khong_du_phong_admin_test.dart` | mã tài khoản không rơi về `?? 1` / mặc định `= 1` (tài khoản admin) | cây | 2026-09-11 |
| 4 | `core/sync/sync_engine_start_owner_test.dart` | chỉ `PhienDieuPhoiThat` gọi `start` của SyncEngine / RealtimeChannel / NotificationScanner (chủ cũ: AuthBloc) | cây | 2026-09-12 |
| 5 | `features/bill/bill_conflict_resolver_wiring_test.dart` | `BillPaymentConflictResolver` được bắt đầu nghe | cây | 2026-09-13 |
| 6 | `features/wallet/so_du_mot_noi_ghi_test.dart` | chỉ `SoDuViService` gọi `updateBalance` | cây | 2026-09-13 |
| 7 | `features/wallet/wallet_cho_phep_am_test.dart` | cờ `allowNegative` không lọt vào đường đồng bộ | danh sách tệp | 2026-09-17 |
| 8 | `core/utils/o_nhap_tien_co_tran_test.dart` | mọi ô nhập tiền có trần 13 chữ số | cây | 2026-09-18 |
| 9 | `features/wallet/lien_ket_ngan_hang_da_bo_test.dart` | không còn tham chiếu đường `bank-link` | cây | 2026-09-18 |
| 10 | `core/ui/khong_co_nut_chet_test.dart` | không handler rỗng (danh sách giữ có số đếm) | cây | 2026-09-19 |
| 11 | `core/utils/ky_hieu_tien_mot_noi_test.dart` | không nối `đ` tay | cây | 2026-09-19 |
| 12 | `core/ui/icon_button_co_tooltip_test.dart` | mọi `IconButton` có `tooltip` | cây | 2026-09-19 |
| 13 | `features/profile/avatar_chu_khac_mau_nen_test.dart` | avatar không viết chữ `primary` trên nền `primaryContainer` | cây | 2026-09-19 |
| 14 | `features/ai_edge/ai_edge_khong_tinh_test.dart` | `ai_edge/` không so chiều tiền / tự tính | cây `ai_edge/` | 2026-09-19 |
| 14 | `core/utils/dau_tien_mot_noi_test.dart` | `formatIncome` / `formatExpense` chỉ trong `currency_formatter.dart` | cây | 2026-09-21 |
| 15 | `features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart` | thứ cục bộ của schema v24 không vào đồng bộ | danh sách tệp | 2026-09-19 |
| 16 | `features/ai_edge/chi_mot_noi_import_gemma_test.dart` | chỉ `slm_runtime.dart` import `flutter_gemma` | cây | 2026-09-22 |
| 17 | `core/ocr/chi_mot_noi_import_mlkit_test.dart` | chỉ `doc_chu_anh_mlkit.dart` (+ spike) import ML Kit | cây | 2026-10-02 |
| 18 | `features/premium/chi_mot_noi_import_url_launcher_test.dart` | chỉ `mo_lien_ket.dart` import `url_launcher` | cây | 2026-10-06 |
| 19 | `core/ui/khong_snackbar_test.dart` | không `SnackBar` / `ScaffoldMessenger` | cây | 2026-10-06 |
| 20 | `features/transaction/chi_mot_noi_import_image_picker_test.dart` | chỉ `quet_anh_page.dart` import `image_picker` | cây | 2026-10-08 |
| 21 | `features/premium/quyen_tinh_nang_mot_noi_test.dart` | quyền theo gói chỉ đọc qua `duocDung` | cây | 2026-10-08 |
| **22** | `core/ui/presentation_khong_cham_csdl_test.dart` | `presentation/` và `shared/` không cầm `AppDatabase` / DAO; `conCho` rỗng | cây | **2026-10-10** |
| **23** | `core/ui/tep_presentation_khong_qua_dai_test.dart` | tệp `presentation` ≤ 1.200 dòng; 5 tệp miễn trừ, trần riêng chỉ giảm | cây `features/` | **2026-10-10** |
| **24** | `features/auth/auth_bloc_khong_sl_test.dart` | `auth_bloc.dart` không gọi service locator, không import `core/di` | một tệp | **2026-10-10** |
| **25** | `core/ui/vi_tri_tep_theo_luat_test.dart` | cây `lib/` / `test/` khớp luật vị trí tệp mục 8 (sáu luật; ratchet `core` → `features` ngoài ba điểm ghép); `conCho` rỗng, miễn trừ duy nhất `ai_chat/spike/` | cây `lib/` + `test/` | **2026-10-10** |
| — | `features/wallet/vi_trung_ten_resolver_wiring_test.dart` | `ViTrungTenResolver` dựng một chỗ và được nối | cây | 2026-10-05 |
| — | `features/wallet/vi_trung_ten_cuc_bo_test.dart` | cờ `bi_tu_choi_trung_ten` không lọt vào đồng bộ | danh sách tệp | 2026-10-05 |
| — | `core/nen/noi_bo_nghe_hai_noi_test.dart` | hai engine (app + nền) mỗi engine nối bộ nghe kết quả đẩy đúng một lần | cây | 2026-10-10 |

Ngoài 29 tệp trên còn chừng chục test đọc **một** tệp `lib/` cụ thể (manifest, router, một hằng) — không vào dãy số.
⚠️ Các test quét của đợt 2026-10-10 có **ca tiền đề** (phép quét phải thấy ít nhất một tệp) để không xanh giả khi chạy sai thư mục; một số test quét cũ chưa có; chạy từ
`src/Client-app`.

**(3) Cổng + bộ chuyển.** Mọi ranh giới với nền tảng hay gói bên ngoài là một interface Dart thuần có một bản thi hành
thật và bản giả trong test: `OsNotifier` (thông báo hệ điều hành), `DocChuAnh` (OCR), `SlmRuntime` / `PhienCongCu` (mô
hình), `RealtimeSocket`, `NguonTaiNen` (tải mô hình), `MoLienKet` (khe hàm bọc `url_launcher`), `KenhTuChuyenTien` /
`KenhBienDong` / `KenhPhienNganHang` / `NguonLyDoThoat` / `LuuTepPlatform` (sáu kênh `flowmoney/*` sang Kotlin, mỗi
kênh đứng sau một lớp Dart riêng; `tu_chuyen_tien_nen` dùng chung tệp với `KenhTuChuyenTien`). Đợt 2026-10-10 thêm hai cổng **bên trong** app theo cùng khuôn:
`ThongBaoNguon` (giao diện ↔ bảng thông báo) và `PhienDieuPhoi` (Bloc ↔ vòng đời phiên).

## 7. Mối quan tâm xuyên suốt

| Mối quan tâm | Cách làm | Ở đâu |
|---|---|---|
| DI | get_it, một tệp đăng ký, `setupDependencies(cheDoNen:)` cho cả app lẫn engine nền; lazy singleton cho dịch vụ, factory cho Bloc | `core/di/injection_container.dart` |
| Điều hướng | GoRouter, `StatefulShellRoute` bốn nhánh (Trang chủ · Phân tích · Giao dịch · Cá nhân), drawer cho phần còn lại; chặn theo gói ở `redirect` | `core/router/app_router.dart`, `shared/widgets/main_shell.dart` |
| Lỗi | Lỗi đồng bộ chia vĩnh viễn / tạm thời (`_permanentCodes`), lỗi người dùng thấy đi toast; lỗi ở phần phụ (nhịp chi, gợi ý) rơi về "không có" chứ không chặn màn | `core/sync/`, `core/ui/thong_bao_nhanh.dart` |
| Thời gian | Đồng hồ tiêm được (`now:` / `clock`) ở mọi hàm thuần; múi giờ ghim ở test và CI (`TZ=Asia/Ho_Chi_Minh`) | `core/nen/mui_gio.dart`, `.github/workflows/client-app.yml` |
| Log | `debugPrint` / `print` có tiền tố (`[SLM]`, `[C4]`, `[RealtimeChannel]`); không thư viện logger — nợ | rải rác |
| i18n | Một ngôn ngữ (tiếng Việt), `flutter_localizations` cho widget hệ thống | `core/constants/app_localization.dart` |
| Theme | `AppTheme` + `AppColors`; widget test màn có nút phải dựng bằng `AppTheme.lightTheme` | `shared/theme/` |
| Bảo mật | Token ở `FlutterSecureStorage`; `idaccount` chỉ từ phiên; không mã hoá SQLite — nợ; dữ liệu AI không rời máy | `core/api/`, `features/auth/presentation/bloc/current_account.dart` |
| Nền tảng | Android là đích chính (chạy nền, D1, OCR, mô hình); web chạy được với cổng stub; iOS chưa có các tính năng Android-only | `core/notification/os/`, `core/nen/co_chay_nen.dart` |
| CI | GitHub Actions: `flutter analyze` + đếm cảnh báo ≤ `MUC_NEN` (20), `flutter test` toàn phần trên Ubuntu, test đỏ in thành annotation | `.github/workflows/client-app.yml` |

## 8. Luật vị trí tệp

Bảng này là luật cho mọi tệp; **test quét 25** (`test/core/ui/vi_tri_tep_theo_luat_test.dart`) canh phần máy canh được
(sáu luật, spec dọn vị trí tệp 2026-10-10 mục 4). Đợt dọn 2026-10-10 (`docs/superpowers/specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`)
đưa cây về khớp bảng — G88 gạch 7 đóng; miễn trừ duy nhất `ai_chat/spike/` tới khi C4 chốt lối. Máy **có** canh việc mọi tệp dưới
`presentation/` nằm trong một trong bốn thư mục `bloc/` · `pages/` · `widgets/` · `state/` (không tệp rời); còn **thư mục nào**
trong số `bloc/` · `widgets/` · `state/` là đúng, và hàng *"hạ tầng core cần"*, là luật **đọc** — máy không canh.

| Loại tệp | Thư mục |
|---|---|
| Interface repository + bản thi hành | `features/<x>/data/repositories/<x>_repository.dart` + `<x>_repository_impl.dart` |
| Datasource (bọc DAO / API) | `features/<x>/data/datasources/` |
| Entity, model | `features/<x>/data/models/` |
| Bộ điều phối nhiều bước (dịch vụ ghi qua nhiều repository) | `features/<x>/data/services/` — tầng application chưa đổi tên; không thêm tầng mới |
| Hàm thuần (luật, phép tính, câu chữ) | `features/<x>/domain/` |
| Bloc / Cubit | `features/<x>/presentation/bloc/` |
| Hàm đọc / dịch trạng thái Bloc–Cubit (accessor, extension `BuildContext` đọc cubit) | `features/<x>/presentation/bloc/` — cạnh Bloc nó đọc |
| Trang (route) | `features/<x>/presentation/pages/` |
| Widget của **một** trang | `features/<x>/presentation/widgets/<tên trang>/` (ví dụ `widgets/phan_tich/`, `widgets/them_giao_dich/`) |
| Widget dùng chung trong mảng | `features/<x>/presentation/widgets/` |
| Hộp thoại, hành động giao diện dùng chung trong mảng (hàm nhận `BuildContext`: `showDialog`, gọi repository rồi gửi event, báo toast) | `features/<x>/presentation/widgets/` |
| Tệp trạng thái giao diện (cờ ẩn, `ValueNotifier` sống theo phiên) | `features/<x>/presentation/state/` |
| Hạ tầng không biết mảng | `core/<chủ đề>/` |
| Kiểu / hàm Dart thuần mà **hạ tầng `core` cần để chạy** (interceptor, socket, DAO, util) — `buoc_dang_xuat`, `category_name` | `core/<chủ đề>/`; thứ chỉ `SyncEngine` cần đi theo tiền lệ `bill_pay_status`: `features/<x>/domain/` |
| Widget dùng chung toàn app, theme | `shared/widgets/`, `shared/theme/` |
| Test | soi gương `lib/` dưới `test/` theo **thư mục** (quét 25); không `*_test.dart` ở gốc `test/`; test quét ở `test/core/ui/` hoặc cạnh mảng nó canh; helper ở `test/helpers/` |
| Script đo, ảnh so sánh | scratchpad của phiên, không vào repo |

## 9. Ưu điểm, nhược điểm, nợ có tên

**Ưu điểm.** Chạy trọn không mạng, kể cả AI. Luật hỏng-im-lặng có một chỗ và có máy canh (29 tệp test quét, CI). Ranh
giới nền tảng thay được bằng bản giả, nên **6.617** ca test (đo 2026-10-10 sau đợt dọn vị trí tệp, +9 skip) chạy trên Windows và Ubuntu không cần thiết bị. Tách mảng theo
nghiệp vụ nên một việc thường chạm một thư mục.

**Nhược điểm còn lại.** Giao diện vẫn cầm kiểu hàng Drift; Entity mới ở 4/14 mảng. `SyncEngine` 2.166 dòng một tệp.
Trang Thêm giao dịch còn **2.007** dòng — trạng thái 61 trường ở lại trang. Luật thông báo nằm trong `core`. Không logger,
không mã hoá SQLite. `setState` vẫn là cách giữ trạng thái chủ đạo (289 chỗ; 3 Bloc, 7 Cubit cho màn có luồng ghi).

**Nợ có tên:** **G88** ở `docs/CLIENT_APP_KNOWN_GAPS.md` — bảy gạch có số đo và hướng xử lý (gạch 7 *vị trí tệp* đóng
2026-10-10 — đợt dọn vị trí tệp, quét 25; còn gạch 1–6). Bảng dưới là trước/sau của đợt **bịt điểm rò**.

| Thước đo (cùng cách đếm, 2026-10-10) | Trước đợt | Sau đợt |
|---|---|---|
| `sl<AppDatabase>` trong `presentation/` | 29 chỗ / 17 tệp | **0** |
| `auth_bloc.dart` | 560 dòng · 23 `sl<` | **377** dòng (370 + 7 dòng docstring đầu lớp) · **0** |
| `analytics_page.dart` | 4.208 dòng | **339** + 14 tệp `widgets/phan_tich/` |
| `add_transaction_page.dart` | 3.107 dòng | **2.007** + 7 tệp `widgets/them_giao_dich/` |
| Tệp `presentation` > 1.200 dòng | 6 | **5** (danh sách miễn trừ quét 23) |
| `flutter test` · `flutter analyze` | 6.587 (+9 skip) · 20 | **6.614** (+9 skip) · **20** |
| Workflow CI | 0 | **1** |

## 10. Cách nói khi trình bày

1. **Mở bằng ràng buộc, không bằng tên mẫu.** "App phải ghi được khi không có mạng và AI không được gửi dữ liệu đi" — rồi
   mới tới "nên SQLite là nguồn sự thật và đồng bộ tự viết".
2. **Gọi đúng tên.** Feature-first ba tầng, offline-first. Không nhận là Clean Architecture; nói vì sao không (mục 1).
3. **Ba chữ ký.** Một định nghĩa duy nhất · test quét mã nguồn · cổng + bộ chuyển — mỗi cái kèm một ví dụ lỗi thật nó
   đã chặn (G41 bảng tra tên chép ba lần; G38 rơi về tài khoản admin; mô hình sập native thì canary bắt).
4. **Con số.** 14 mảng, 546 tệp, 29 test quét, 6.617 ca test, CI xanh trên Ubuntu; trước/sau của đợt 2026-10-10 (mục 9).
5. **Tự nêu nhược điểm trước khi bị hỏi.** Entity 4/14, `SyncEngine` một tệp, trang Thêm giao dịch 2.007 dòng — và nói nó
   nằm ở G88 với hướng xử lý, tức là đã biết và có kế hoạch, không phải chưa nhìn thấy.
