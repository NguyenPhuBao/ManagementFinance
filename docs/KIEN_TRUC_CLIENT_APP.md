# Kiến trúc Client-app (FlowMoney, Flutter)

> Viết 2026-10-10, sau đợt **bịt điểm rò kiến trúc** (spec `docs/superpowers/specs/2026-10-10-bit-diem-ro-kien-truc-client-design.md`);
> cập nhật cùng ngày (khuya) sau đợt **dọn vị trí tệp** (spec `docs/superpowers/specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`)
> — mục 3, 4, 6, 7, 8, 9, 10; cập nhật lần nữa **2026-10-15** sau đợt **Entity Thông báo + gạch 5 + gạch 6** (spec `docs/superpowers/specs/2026-10-15-entity-thong-bao-application-design.md`) — mục 1, 3, 4, 5, 6, 8, 9.
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

Client-app là **feature-first, ba tầng `data · domain · presentation` + `application/` (bộ điều phối, 2026-10-15), offline-first** — SQLite (Drift) là nguồn sự thật
cục bộ, server chỉ là nơi hội tụ giữa các máy. Nó **không** phải Clean Architecture đúng sách, và đó là lựa chọn có lý
do: interface repository nằm ở tầng `data` chứ không ở `domain`, không có lớp use case, và Entity chỉ có ở 7/14 mảng
(ví, giao dịch, mục tiêu, ngân sách, hoá đơn, danh mục, thông báo — hai mảng cuối từ 2026-10-15). Lộ trình G88 gạch 3 **xong**: Hoá đơn, Ví, Giao dịch xong 2026-10-14, Danh mục và Thông báo xong 2026-10-15 (quét 27: `conChoKieu`, `conChoDomain` và `conChoDynamic` đều rỗng; bốn luật). Cùng đợt Thông báo đóng gạch 5 (`core/notification` dời hẳn về `features/notification/`) và gạch 6 (tầng `application/` có tên, bốn mảng). **G88 gạch 4 + quét 28 đóng 2026-10-16** (đợt cuối, G88 đóng): `core` → `features` ngoài bốn điểm ghép chỉ còn năm tệp domain thuần (danh sách cố định, mục 4), `SyncEngine` nhận hai cổng, `domain/` không import `presentation/` hay `data/` ngoài `data/models/` (quét 28). Mục tiêu, Ngân sách đã có Entity và nằm ngoài lộ trình chỉ theo nghĩa giao diện gần như không cầm hàng Drift của chúng từ đầu (đo 2026-10-15 bằng quét 27: giao diện cầm `Goal` 0 tệp, `Budget` 0); ba nợ còn lại của chúng đã trả 2026-10-15: `goal_auto_deposit_runner` dời về `goal/data/services/` (rồi 2026-10-15 sang `goal/application/`), `GoalRepository.watchGoalTransactions` trả `Stream<List<TransactionEntity>>`, `TaiPhanBoNguon.ghiPhanHoi` nhận lớp thuần `PhanHoiTaiPhanBo`. Tầng `domain` ở đây là **hàm thuần** — luật nghiệp vụ không biết Flutter, không
biết CSDL — chứ không phải nơi sở hữu interface. Bài toán (một người, một máy, dữ liệu nhỏ, phải chạy không mạng) không
trả nổi giá của bốn tầng và một lớp ánh xạ cho mỗi kiểu; thứ nó cần là luật đúng và đúng **một chỗ**, và thứ ấy được
canh bằng test quét mã nguồn (mục 6).

## 2. Bốn ràng buộc → bốn quyết định

| Ràng buộc của bài toán | Quyết định | Ở đâu trong mã |
|---|---|---|
| Ghi chép phải chạy khi không có mạng (đi chợ, đi tàu) — một khoản bị mất vì rớt sóng là app hết đáng tin | **Offline-first**: mọi lệnh ghi vào SQLite trước, giao diện đọc từ SQLite; mạng chỉ là chuyện đồng bộ | `core/database/` (Drift, schema v31), mọi repository |
| Hai máy cùng tài khoản ghi khi offline; server không có khái niệm "bản nháp" | **Đồng bộ tự viết, hai chiều, LWW theo `update_at`**, đẩy lô thao tác + kéo theo mốc giờ-server | `core/sync/sync_engine.dart` (2.166 dòng), `sync_payload_normalizer.dart`, `moc_keo_ve.dart` |
| Người dùng chọn AI **trên máy** để chạy không mạng và không gửi dữ liệu tài chính đi | **Hai tầng AI**: luật + hàm thuần (`ai_edge/domain`) cho mọi màn; mô hình Gemma 4 E2B trên máy chỉ cho hỏi đáp / đọc câu / đọc ảnh, mọi con số đi qua lớp chắn | `features/ai_edge/`, `features/ai_chat/` |
| Tự trả hoá đơn, tự trích mục tiêu phải xảy ra đúng lúc kể cả khi app đóng | **Chạy nền bằng WorkManager** đánh thức một engine Flutter không giao diện, dùng lại đúng bộ quét của app | `android/.../TuChuyenTien*.kt`, `core/nen/` |

## 3. Cây thư mục

`lib/` có **618** tệp `.dart`, **124.393** dòng (kể 14 tệp `.g.dart` do Drift sinh) — `git ls-files lib | grep '\.dart$'`
và `… | xargs cat | wc -l`. `test/` có **629** tệp `*_test.dart` (640 tệp `.dart` kể cả helper), **126.455** dòng (đếm lại **2026-10-16 sau gỡ cụm**, HEAD `f702a884`). (Trước đó 2026-10-15: 626 tệp `.dart` (617 `_test`), 124.875 dòng; 2026-10-13, sau tách bốn trang lớn: 596 / 616 tệp, 122.667 / 123.486 dòng.)

```
lib/
├── main.dart                 điểm vào app + điểm vào engine nền (`chayNenTuChuyenTien`, @pragma)
├── core/             96 tệp  hạ tầng + điểm ghép — KHÔNG chứa màn hình (15 chủ đề — test quét 25; `core/notification` đã dời 2026-10-15)
│   ├── api/           3      DioClient, AuthInterceptor (gắn token, làm mới, dịch 401 + code)
│   ├── auth/          3      buoc_dang_xuat (kiểu thuần 4 tệp hạ tầng dùng), PhienDieuPhoi(+That) ← điều phối phiên
│   ├── category/      1      category_name (normalizeCategoryName — DAO + util dùng)
│   ├── constants/     2      app_constants, app_localization
│   ├── database/     42      AppDatabase, 10 tệp DAO, bảng, kết nối (native / web)
│   ├── di/            1      injection_container (943 dòng) ← điểm ghép duy nhất của DI
│   ├── errors/        1      app_exceptions
│   ├── nen/           7      chạy nền: chay_nen, luot_nen, lich_nen, kênh `flowmoney/tu_chuyen_tien`, `app_lifecycle_watcher`
│   ├── network/       1      connection_monitor
│   ├── ocr/           7      DocChuAnh (cổng) + bản ML Kit, `ten_tep_bien_lai` (kho ảnh quét dời về `transaction/data/datasources/` 2026-10-16)
│   ├── realtime/      5      RealtimeChannel; chỉ realtime_socket.dart import socket_io_client
│   ├── router/        1      app_router (GoRouter) ← điểm ghép
│   ├── sync/          9      SyncEngine, normalizer, checkpoint, hai cổng `CongSoDuVi` · `CongViBiGiu` (2026-10-16; `noiBoNgheKetQuaDay` đã về DI)
│   ├── ui/            4      thong_bao_nhanh (toast), bieu_do_cham, do_chu, bao_che_day_toast
│   └── utils/         9      CurrencyFormatter, gioi_han_do_dai, so_bang_chu, ngay_trong_cau, khop_ten, `tuan_iso`, `dung_sai_tien` (hàm thuần dùng chung — tiền lệ cho `domain/` mục 4)…
├── features/        508 tệp  14 mảng nghiệp vụ, mỗi mảng data / domain / presentation (+ `application/` ở năm mảng: ví · danh mục · hoá đơn · mục tiêu · thông báo)
│   ├── ai_edge/      83      data 23 · domain 55 · presentation 5 — luật, gói số, tool, SLM runtime, lớp chắn
│   ├── transaction/  76      data 19 · domain 28 · presentation 29 (bloc/ 5 kể `ThemGiaoDichCubit` + state · widgets/them_giao_dich/ 7 tệp)
│   ├── analytics/    61      data 9 · domain 18 · presentation 34 (widgets/phan_tich/ 14 tệp · widgets/xem_truoc_bao_cao/ 10 tệp)
│   ├── bill/         39      data 7 · domain 16 · application 2 · presentation 14
│   ├── goal/         49      data 4 · domain 18 · application 1 · presentation 26 (widgets/them_muc_tieu/ 7 tệp · widgets/chi_tiet_muc_tieu/ 7 tệp)
│   ├── wallet/       33      data 8 · domain 9 · application 4 · presentation 12 (state/ 1)
│   ├── budget/       30      data 8 · domain 9 · presentation 13
│   ├── premium/      27      data 8 · domain 8 · presentation 11 (bloc/ thay cubit/; state/ 1)
│   ├── auth/         21      data 5 · domain 1 · presentation 15 (bloc/ 4 kể AuthBloc + current_account · pages/ 6 · state/ 1 · widgets/ 4)
│   ├── category/     22      data 8 · domain 6 · application 2 · presentation 6
│   ├── profile/       8      presentation 8
│   ├── home/          8      domain 1 · presentation 7
│   ├── notification/ 48      data 17 · domain 11 · application 8 · presentation 12 (widgets/cai_dat_thong_bao/ 6 tệp; luật, bộ quét, bộ nhập dời từ core/notification 2026-10-15)
│   └── ai_chat/       3      data 2 · presentation 1 (spike C4 đã gỡ 2026-10-12)
└── shared/           13 tệp  theme/ 3 (AppTheme, AppColors) · widgets/ 10 (MainShell, chuông, toast…)
```

Số tệp `lib/`/`test/`/`features/` và ba mảng `ai_edge`, `transaction`, `home` đếm lại bằng máy **2026-10-12** (sau C4); tổng `lib/` (**596** tệp, **122.667** dòng), `test/` và các hàng `analytics` · `goal` · `notification` đếm lại **2026-10-13** sau tách bốn trang lớn (G88 gạch 2). Đếm mảng: `for d in features/*/; do find $d -name '*.dart' | wc -l; done` (và `$d/data`, `$d/domain`, `$d/presentation`).
Tổng `lib/` · `core` · `features/` và bốn mảng `analytics` · `transaction` · `bill` · `category` (kèm tách data / domain) đếm lại bằng máy **2026-10-16 sau gỡ cụm** (HEAD `f702a884`, `git ls-files`): `lib/` 618 · `core` 96 · `features/` 508 · `analytics` 61 · `transaction` 76 · `bill` 39 · `category` 22; câu *"`core` vẫn 92 tệp, `features/` 504, `lib/` 610"* ở dưới là số của HEAD `4b7740a3` trước đợt này.
Số trên đếm lại 2026-10-10 sau đợt dọn vị trí tệp (HEAD `e2ab224c`); riêng tổng `lib/` · `test/` · `features/` và mảng `transaction` đếm lại 2026-10-11 sau tách trang Thêm giao dịch (HEAD `18ae5749`).
Các hàng `core/sync` · `core/ocr` và `features/` (tổng + `transaction` · `analytics` · `bill` · `goal` · `wallet` · `budget`) đếm lại bằng máy **2026-10-16** (HEAD `4b7740a3`, sau đợt G88 gạch 4 + quét 28; `core` vẫn 92 tệp, `features/` 504, `lib/` 610). Phần còn lại của khối cây đếm lại bằng máy **2026-10-15** (HEAD `08effea7`, sau đợt Entity Thông báo + gạch 5 + gạch 6) bằng `find … -name "*.dart" | wc -l` từng thư mục; `core/notification` (35 tệp) **không còn** — 34 tệp dời: 31 về `features/notification/` (domain · data · data/datasources · application), 3 về `core/nen` · `core/ocr` · `core/utils` (số tệp hiện có của thư mục: domain 11 · data 17 gồm repository và entity mới · application 8 — không phải số tệp dời).

## 4. Ba tầng và vai trò của `core`

| Tầng | Trách nhiệm | Được phép import | Không được |
|---|---|---|---|
| `presentation/` | Trang, widget, Bloc/Cubit; giữ trạng thái màn, gọi repository | `domain/`, `data/` của chính mảng và mảng khác (repository, nguồn), `application/` (bộ điều phối), `core/` — kể `core/database` để dùng **kiểu** hàng Drift — chỉ cho mảng chưa có Entity (danh sách chờ của quét 27); Hoá đơn, Ví, Giao dịch, Danh mục, Thông báo: Entity (danh sách chờ rỗng từ 2026-10-15) — `core/di` để lấy repository qua service locator, `core/ui`, `core/utils`, `core/constants` — và `shared/` | cầm `AppDatabase` / gọi DAO (**test quét 22** — kiểu hàng thì được, lối truy cập thì không); tệp quá 1.200 dòng ngoài danh sách miễn trừ (**quét 23**) |
| `domain/` | Hàm thuần: luật nghiệp vụ, phép tính, định dạng câu — kể cả hàm thuần dùng chung nhiều mảng, đặt ở `core/utils` · `core/category` (tiền lệ `tuan_iso`, `normalizeCategoryName`) | Dart thuần, `domain/` khác, Entity ở `data/models/` (kéo Drift bắc cầu qua `fromDrift` — cái giá đã nhận) | Flutter, Drift, `sl`, `application/` (quét 25 luật 7) |
| `data/` | Repository (interface + bản thi hành), datasource, Entity, các dịch vụ **bị datasource / repository gọi** (`so_du_vi_service`, `tha_vi_bi_giu`) | `core/database`, `core/api`, `domain/` | widget, `application/` (quét 25 luật 7), Drift trong interface repository (quét 27 luật 4) |
| `application/` (từ 2026-10-15, G88 gạch 6) | Bộ điều phối nhiều bước — ghi qua nhiều repository, quét, nhập, đặt lịch (`features/<x>/application/`: ví 4 · danh mục 2 · hoá đơn 2 · mục tiêu 1 · thông báo 8 = **17** tệp) | `data/`, `domain/`, `core/` | widget; được điểm ghép (`core/di` · `core/nen/chay_nen` · `phien_dieu_phoi_that`), `main.dart` và `presentation/` gọi; (`core/sync/noi_bo_nghe_ket_qua_day` — nợ gạch 4 — đã về DI 2026-10-16, không còn ngoại lệ); còn `data/` và `domain/` **không** import nó |

Chiều import một hướng **presentation → application → data / domain** (spec mục 8; luật 7 quét 25 canh vế data / domain).

Ba tầng (cộng `application/` — bộ điều phối, đổi tên chứ không thêm tầng) **không** đối xứng như sách: interface repository khai ở `data/repositories/<x>_repository.dart` cạnh bản thi
hành; `domain/` không biết interface nào. Từ repository trở lên, các mảng ví, giao dịch, mục tiêu, ngân sách, hoá đơn, danh mục và thông báo trả **Entity**
(`CategoryEntity`, `NotificationEntity` từ 2026-10-15) — **không còn mảng nào** trả hàng Drift từ repository trở lên. Từ 2026-10-10 từng có **lối chuyển tiếp** cho trang trả đúng kiểu
hàng Drift trang đang cầm (11 lúc đầu; 10 sau đợt Hoá đơn; 4 sau đợt Giao dịch + Ví; **0 từ 2026-10-15**, đợt Entity Danh mục, đếm bằng máy:
`watchAllRows` · `getRowById` đã bỏ; `CategoryManagementRepository.watchAll` / `getById` / `loadBangTraTen` trả `CategoryEntity`;
`TaiPhanBoNguon.ghiPhanHoi` nhận `PhanHoiTaiPhanBo`; `ThongBaoNguon` thành `ThongBaoRepository` 2026-10-15)

**`core` có hai vai, cố ý tách bạch:**

- **Hạ tầng** dùng chung, không biết mảng nào: CSDL, HTTP, socket, OCR, định dạng tiền, toast. Đây là phần lớn của 92 tệp (đếm 2026-10-15).
- **Điểm ghép** (`core/di`, `core/router`, `core/nen/chay_nen.dart`, `core/auth/phien_dieu_phoi_that.dart`; `core/nen/lich_nen.dart` là hạ tầng, từ 2026-10-16 không còn import `features/`) — nơi duy nhất được biết mọi mảng, nhưng **không** được nêu tên kiểu hàng Drift (quét 27 luật 1, từ 2026-10-14): biết mảng qua repository / Entity. Gồm: `core/di/injection_container.dart` (đăng ký mọi thứ, nối hook),
  `core/router/app_router.dart` (mọi route), `core/nen/chay_nen.dart` (dựng DI ở chế độ nền), và
  `core/auth/phien_dieu_phoi_that.dart` — bộ điều phối phiên nhận **hook hàm** cho mọi việc của mảng khác; chỉ import bộ quét thông báo
  (`notification_scanner`, điểm ghép thứ tư — quét 25), không import mảng nào khác. Đo `grep -rnE "^import .*features/" lib/core` (2026-10-10 sau đợt dọn vị trí tệp):
  **175** dòng — điểm ghép **138** (DI 82 · router 54 · `chay_nen` 2), hạ tầng **37** (`notification_rules` 10 ·
  `sync_engine` 7 · `notification_scanner` 5 · `lich_nen` 3 · …). *(Đo lại 2026-10-14 bằng `grep -rcE "^(import|export) .*features/" lib/core`: 182 = điểm ghép 142 (DI 87 · router 53 · `chay_nen` 2) + hạ tầng **40** — `notification_rules` 11 · `notification_scanner` 6 · `lich_nen` 4 do đợt Entity Hoá đơn, ratchet +1 ở ba tệp.)* *(Đo lại 2026-10-14 sau đợt Entity Giao dịch + Ví: 185 = điểm ghép 142 + hạ tầng **43** — `notification_rules` 12 · `notification_scanner` 7 · `de_xuat_thong_bao_nguon` 1, ratchet +3 vì luật ví và nguồn B5b nhận `WalletEntity` / `TransactionEntity`.)* (Khi ấy) 43 dòng hạ tầng là nợ có tên (G88 gạch 4); khi ấy 18 dòng / 7 tệp (2026-10-15). *(Đo lại 2026-10-15 sau đợt Entity Thông báo bằng vòng `for` + `grep -cE "^(import|export) .*features/"` từng tệp: **184** = điểm ghép **166** (DI 107 · router 54 · `chay_nen` 4 · `phien_dieu_phoi_that` 1) + hạ tầng **18** — `sync_engine` 7 · `lich_nen` 4 · `noi_bo_nghe_ket_qua_day` 2 · `sync_payload_normalizer` 2 · `other_daos` 1 · `wallet_dao` 1 · `kho_anh_quet` 1; ratchet `conChoCoreImport` đo 43 → 47 (Task 4, Luật tăng) → 45 → **18** (Task 6, bảy mục thông báo rút hết); từ nay điểm ghép là **bốn** tệp.)* *(Trước
  đợt: 172 = 136 + 36. DI +2 vì `TransactionRepositoryImpl` / `CategoryManagementRepositoryImpl` tách tệp `_impl`; router
  +1 và `current_account` −1 vì tệp ấy rời `core` về `features/auth/presentation/bloc/`; `sync_engine` 6 → 7 vì
  `bill_recurrence` về `features/bill/domain/`.)* Từ 2026-10-10 **test quét 25** (`vi_tri_tep_theo_luat_test`) canh:
  ngoài bốn điểm ghép (DI · router · `chay_nen` · `phien_dieu_phoi_that`), tệp `core` import `features/` chỉ được trỏ vào **năm tệp domain thuần** trong danh sách CỐ ĐỊNH `domainThuanChoCore` (luật 5, từ 2026-10-16; **thay** ratchet `conChoCoreImport` 18 dòng / 7 tệp): `wallet/domain/wallet_status` · `wallet_type`, `bill/domain/bill_pay_status` · `bill_recurrence`, `goal/domain/uu_tien_hop_le` — hằng và hàm thuần mà DAO, `SyncEngine`, bộ chuẩn hoá payload cần đọc. Luật 5b canh năm tệp ấy còn thuần (chỉ import `dart:` hoặc `data/models/` của chính mảng nó). Thêm tệp thứ sáu là sửa danh sách — có lý do và ngày, không phải nới trần. *(Đo 2026-10-16 bằng vòng `for` + `grep -cE "^(import|export) .*features/"` từng tệp, HEAD `4b7740a3`: **178** = điểm ghép **170** (DI 111 · router 54 · `chay_nen` 4 · `phien_dieu_phoi_that` 1) + hạ tầng **8** (`sync_engine` 4 · `sync_payload_normalizer` 2 · `wallet_dao` 1 · `other_daos` 1) — cả tám đều trỏ vào năm tệp trên; trước đợt 184 = 166 + 18.)* **Thứ có trạng thái thì không đi bằng import mà bằng cổng:** `core/sync/cong_so_du_vi.dart` (`CongSoDuVi`) và `cong_vi_bi_giu.dart` (`CongViBiGiu`, `BanGhiGiuKhoiDay`) là interface Dart thuần; `SyncEngine` nhận hai cổng **bắt buộc**, bản thật `SoDuViService` · `ViBiGiuDongBo` (`features/wallet/data/`) do DI nối — khuôn cho mọi thứ `core` cần từ một mảng mà không phải hằng thuần. Lịch nền theo cùng khuôn: `core/nen/lich_nen.dart` chỉ **gộp** (`gopLichNen`), mỗi mảng tự tính mốc của mình (`mocTuTraNen` ở `bill/domain`, `mocTrichNen` ở `goal/domain`).

## 5. Tám luồng chính

**Ghi.** Trang gọi Bloc/Cubit (hoặc gọi thẳng repository với màn đơn giản) → repository ở `features/<x>/data/repositories/`
ghi SQLite với `syncStatus = pending` và `updatedAt` mới. Mọi thay đổi số dư đi qua `wallet/data/so_du_vi_service.dart`
— chỗ **duy nhất** được ghi `wallets.balance`, vì số dư là cache của tổng sổ giao dịch (G37). Repository xong thì gọi
`SyncEngine.scheduleSync()` (giãn cách), nên người dùng không bao giờ chờ mạng.

**Đọc.** Màn đọc dùng **stream Drift** (`watch…`) qua repository — `StreamBuilder` ở trang hoặc Cubit nghe stream (ví dụ
`AnalyticsRepository.watchKy` gộp tám nguồn). Ghi ở bất kỳ đâu, kể cả Pull của đồng bộ, đều tự đẩy màn vẽ lại; không có
cache tầng giữa nào phải làm mới tay. Từ đợt 2026-10-10 trang **không** cầm DAO: lối đọc là repository hoặc một nguồn đăng
ký DI (`TaiPhanBoNguon`, `GanDanhMucNguon`; bảng thông báo qua `ThongBaoRepository`).

**Đồng bộ.** `core/sync/sync_engine.dart` gom thao tác chờ theo thứ tự khoá ngoại (`_collectPendingOps`: hoá đơn **trước**
giao dịch), dựng payload tay rồi qua `SyncPayloadNormalizer`, `POST /sync/push`; kết quả phát ở `pushResultStream`
**trước** bước Pull (người nghe `BillPaymentConflictResolver`, `ViTrungTenResolver` nối ở `noiBoNgheKetQuaDay()` — nay ở cuối `core/di/injection_container.dart`, từ 2026-10-16). Rồi
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

**Thông báo.** `features/notification/application/notification_scanner.dart` chạy các luật thuần ở `domain/notification_rules.dart`, ghi bảng
**cục bộ** `AppNotifications` bằng `insertIfAbsent` theo `dedupeKey` (không đi đồng bộ — quy tắc 9), đặt lịch hệ điều hành
qua `ReminderScheduler` + cổng `OsNotifier` (native / web / stub), đếm chuông qua `BadgeUpdater`. Trang đọc qua cổng
`ThongBaoRepository` (trả `NotificationEntity`); chạm thông báo đi `NotificationTapRouter` → deeplink, `go` hay `push` theo `nhanhThanhTab`.

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
thành một test **đọc `lib/`** và đỏ khi luật bị phá. Bảng dưới khoá theo **tên tệp**: dãy số tự xưng 1–29 phủ **30
tệp** — số **14** được hai tệp cùng nhận (cả hai docstring đều ghi *"thứ mười bốn"*, va chạm có từ 2026-09-21) — cộng
**3** tệp cùng khuôn không đánh số, tổng **33** (đếm bằng máy 2026-10-16, sau quét 27, 28 và 29). Đếm: `grep -rlE "Directory\(['\"]lib" test` (29 tệp quét cây, đo
2026-10-16) cộng các tệp đọc danh sách tệp cố định. Test quét mới lấy số **30**.

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
| 17 | `core/ocr/chi_mot_noi_import_mlkit_test.dart` | chỉ `doc_chu_anh_mlkit.dart` import ML Kit | cây | 2026-10-02 |
| 18 | `features/premium/chi_mot_noi_import_url_launcher_test.dart` | chỉ `mo_lien_ket.dart` import `url_launcher` | cây | 2026-10-06 |
| 19 | `core/ui/khong_snackbar_test.dart` | không `SnackBar` / `ScaffoldMessenger` | cây | 2026-10-06 |
| 20 | `features/transaction/chi_mot_noi_import_image_picker_test.dart` | chỉ `quet_anh_page.dart` import `image_picker` | cây | 2026-10-08 |
| 21 | `features/premium/quyen_tinh_nang_mot_noi_test.dart` | quyền theo gói chỉ đọc qua `duocDung` | cây | 2026-10-08 |
| **22** | `core/ui/presentation_khong_cham_csdl_test.dart` | `presentation/` và `shared/` không cầm `AppDatabase` / DAO; `conCho` rỗng | cây | **2026-10-10** |
| **23** | `core/ui/tep_presentation_khong_qua_dai_test.dart` | tệp `presentation` ≤ 1.200 dòng; `mienTru` **rỗng** từ 2026-10-13 (G88 gạch 2; từng 4 tệp, rút `add_transaction_page` 2026-10-11) | cây `features/` | **2026-10-10** |
| **24** | `features/auth/auth_bloc_khong_sl_test.dart` | `auth_bloc.dart` không gọi service locator, không import `core/di` | một tệp | **2026-10-10** |
| **25** | `core/ui/vi_tri_tep_theo_luat_test.dart` | cây `lib/` / `test/` khớp luật vị trí tệp mục 8 (**tám** luật — luật 7 `data/` và `domain/` không import `application/` (2026-10-15); `tangMang` có `application`; `diemGhep` có `phien_dieu_phoi_that.dart`; luật 5 `core` → `features` ngoài bốn điểm ghép chỉ được đọc năm tệp trong danh sách CỐ ĐỊNH `domainThuanChoCore` (2026-10-16, thay ratchet `conChoCoreImport` 18 dòng / 7 tệp), luật 5b canh năm tệp ấy còn thuần; luật 5, 5b, 7 đọc chỉ thị qua `test/helpers/chi_thi_dart.dart` từ 2026-10-16 — thấy `part`, từng vế import có điều kiện, chỉ thị xuống dòng); `conCho` rỗng (miễn trừ `ai_chat/spike/` đã gỡ 2026-10-12) | cây `lib/` + `test/` | **2026-10-10** |
| **26** | `features/transaction/chi_mot_noi_import_giong_noi_test.dart` | `speech_to_text` chỉ ở `nghe_android.dart`, `record` chỉ ở `ghi_am.dart` (có ca tiền đề) | cây `lib/` | **2026-10-12** |
| **27** | `core/ui/presentation_domain_khong_kieu_drift_test.dart` | **bốn** luật — (1) `presentation/` + `shared/` + `lib/core` (trừ `database`, `sync`) và, từ 2026-10-15, cả `features/*/domain/` không nhắc kiểu hàng Drift theo tên kiểu (danh sách chờ theo kiểu `conChoKieu` **rỗng** từ 2026-10-15, đợt Entity Thông báo); (2) `domain/` không import `core/database` / `package:drift` (danh sách chờ rỗng từ 2026-10-15); (3) `features/*/data` và `features/*/application` không khai `<dynamic>` trần cho `Stream` / `Future` / `List` / `Iterable` (danh sách chờ rỗng); (4) interface repository (`features/*/data/repositories/*_repository.dart`, 11 tệp đếm 2026-10-15) không import `core/database` / `package:drift`; từ 2026-10-16 luật 2 và 4 đọc chỉ thị qua `chi_thi_dart.dart` nên thấy cả `export`, còn mẫu tên kiểu của luật 1 bắt thêm `is X ?` và `X(` (hai dạng tách bạch: mẫu `case X(…)` của Dart 3, và dựng hàng `X(…)` trực tiếp — đo 0 chỗ trúng mới) | cây `lib/` | **2026-10-14** |
| **28** | `core/ui/domain_khong_import_tang_tren_test.dart` | **hai** luật — `features/*/domain/` không import đường chứa `/presentation/`; đường chứa `/data/` phải chứa `/data/models/` (Entity, `BudgetView`, `ThongKeKy` hợp lệ; repository / datasource / nguồn thì không); `conCho` **rỗng** từ khi có (đo gốc năm tệp, rút cùng đợt; đọc chỉ thị qua `chi_thi_dart.dart`) | cây `lib/` | **2026-10-16** |
| **29** | `core/ui/domain_khong_vong_mang_test.dart` | đồ thị cấp mảng — cạnh `A->B` khi tệp dưới `features/A/domain/` có `import` / `export` / `part` tới bất kỳ tầng nào của mảng B; cạnh nằm trên một vòng (hai đầu cùng một thành phần liên thông mạnh > 1) phải ở `conCho` (**rỗng** từ 2026-10-16 — ba lát gỡ cụm theo chiều `analytics → bill → transaction → category`; cạnh trong danh sách mà hết nằm trên vòng thì đỏ "rút"); có ca tiền đề số tệp | `features/*/domain/` → mọi tầng mảng khác | **2026-10-16** |
| — | `features/wallet/vi_trung_ten_resolver_wiring_test.dart` | `ViTrungTenResolver` dựng một chỗ và được nối | cây | 2026-10-05 |
| — | `features/wallet/vi_trung_ten_cuc_bo_test.dart` | cờ `bi_tu_choi_trung_ten` không lọt vào đồng bộ | danh sách tệp | 2026-10-05 |
| — | `core/nen/noi_bo_nghe_hai_noi_test.dart` | hai engine (app + nền) mỗi engine nối bộ nghe kết quả đẩy đúng một lần | cây | 2026-10-10 |

(Bảng có 33 hàng sau khi thêm quét 29 ngày 2026-10-16; 32 trước đó. Bộ đọc chỉ thị dùng chung `test/helpers/chi_thi_dart.dart` và test của nó là test helper, không vào bảng.) Ngoài các tệp trên còn chừng chục test đọc **một** tệp `lib/` cụ thể (manifest, router, một hằng) — không vào dãy số.
⚠️ Các test quét của đợt 2026-10-10 có **ca tiền đề** (phép quét phải thấy ít nhất một tệp) để không xanh giả khi chạy sai thư mục; một số test quét cũ chưa có; chạy từ
`src/Client-app`.

**(3) Cổng + bộ chuyển.** Mọi ranh giới với nền tảng hay gói bên ngoài là một interface Dart thuần có một bản thi hành
thật và bản giả trong test: `OsNotifier` (thông báo hệ điều hành), `DocChuAnh` (OCR), `SlmRuntime` / `PhienCongCu` (mô
hình), `RealtimeSocket`, `NguonTaiNen` (tải mô hình), `MoLienKet` (khe hàm bọc `url_launcher`), `KenhTuChuyenTien` /
`KenhBienDong` / `KenhPhienNganHang` / `NguonLyDoThoat` / `LuuTepPlatform` (sáu kênh `flowmoney/*` sang Kotlin, mỗi
kênh đứng sau một lớp Dart riêng; `tu_chuyen_tien_nen` dùng chung tệp với `KenhTuChuyenTien`). Đợt 2026-10-10 thêm hai cổng **bên trong** app theo cùng khuôn:
`ThongBaoNguon` (giao diện ↔ bảng thông báo; từ 2026-10-15 là `ThongBaoRepository`) và `PhienDieuPhoi` (Bloc ↔ vòng đời phiên).

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
| Nền tảng | Android là đích chính (chạy nền, D1, OCR, mô hình); web chạy được với cổng stub; iOS chưa có các tính năng Android-only | `features/notification/data/datasources/os_notifier*.dart`, `core/nen/co_chay_nen.dart` |
| CI | GitHub Actions: `flutter analyze` + đếm cảnh báo ≤ `MUC_NEN` (20), `flutter test` toàn phần trên Ubuntu, test đỏ in thành annotation | `.github/workflows/client-app.yml` |

## 8. Luật vị trí tệp

Bảng này là luật cho mọi tệp; **test quét 25** (`test/core/ui/vi_tri_tep_theo_luat_test.dart`) canh phần máy canh được
(tám luật — sáu của spec dọn vị trí tệp 2026-10-10 mục 4, thêm luật 7 *data / domain không import application/* ở đợt 2026-10-15, luật 5b *năm tệp domain thuần của `core` còn thuần* ở đợt 2026-10-16; luật 5 từ ratchet thành danh sách cố định). Đợt dọn 2026-10-10 (`docs/superpowers/specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`)
đưa cây về khớp bảng — G88 gạch 7 đóng; miễn trừ `ai_chat/spike/` đã gỡ khi C4 chốt lối (2026-10-12). Máy **có** canh việc mọi tệp dưới
`presentation/` nằm trong một trong bốn thư mục `bloc/` · `pages/` · `widgets/` · `state/` (không tệp rời); còn **thư mục nào**
trong số `bloc/` · `widgets/` · `state/` là đúng, và hàng *"hạ tầng core cần"*, là luật **đọc** — máy không canh.

| Loại tệp | Thư mục |
|---|---|
| Interface repository + bản thi hành | `features/<x>/data/repositories/<x>_repository.dart` + `<x>_repository_impl.dart` |
| Datasource (bọc DAO / API) | `features/<x>/data/datasources/` |
| Entity, model | `features/<x>/data/models/` |
| Bộ điều phối nhiều bước (dịch vụ ghi qua nhiều repository, bộ quét, bộ nhập) | `features/<x>/application/` (từ 2026-10-15; trước là `data/services/`). Dịch vụ mà datasource / repository **gọi** (`so_du_vi_service`, `tha_vi_bi_giu`) ở lại `data/` — `data/` không import `application/` (quét 25 luật 7) |
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
| Test | soi gương `lib/` dưới `test/` theo **thư mục** kể cả `application/` (quét 25); không `*_test.dart` ở gốc `test/`; test quét ở `test/core/ui/` hoặc cạnh mảng nó canh; helper ở `test/helpers/` |
| Script đo, ảnh so sánh | scratchpad của phiên, không vào repo |

## 9. Ưu điểm, nhược điểm, nợ có tên

**Ưu điểm.** Chạy trọn không mạng, kể cả AI. Luật hỏng-im-lặng có một chỗ và có máy canh (33 tệp test quét, CI — đếm 2026-10-16). Ranh
giới nền tảng thay được bằng bản giả, nên **7.178** ca test (đo 2026-10-17 sau màn xác nhận xoá hoá đơn + "Nhắc trước" là mặc định cho hoá đơn mới, +10 skip) chạy trên Windows và Ubuntu không cần thiết bị. Tách mảng theo
nghiệp vụ nên một việc thường chạm một thư mục.

**Nhược điểm còn lại.** Entity 7/14 mảng; giao diện không còn cầm kiểu hàng Drift ở mảng nào (G88 gạch 3 xong: Hoá đơn, Ví, Giao dịch 2026-10-14, Danh mục + Thông báo 2026-10-15; gạch 5 và 6 đóng cùng đợt). Gạch 4 đóng 2026-10-16 (`core` → `features` chỉ còn năm tệp domain thuần, quét 25 luật 5 / 5b), G88 đóng. Ba lệch `domain` → `data/repositories` và hai chỗ `ai_edge/domain` → `presentation` (`pickHomeBudget`) từng nằm ở đây đã trả cùng đợt, nay canh bằng quét 28. Vòng `bill/domain/bill_status.dart` ↔ `notification/domain/notification_rules.dart` **đã gỡ 2026-10-16** (`billLeadDays` + `mocNhacMacDinh` về `bill/domain/bill_nhac_truoc.dart`); cạnh `bill/application/bill_payment_conflict_resolver.dart` → `notification_rules.dart` còn, cố ý (bộ điều phối phát thông báo; quét 29 chỉ đọc nguồn `domain/`). Bốn cặp hai chiều của cụm {analytics, bill, category, transaction} **đã gỡ 2026-10-16** (ba lát, spec `2026-10-16-go-vong-mang-domain-design.md`; chiều chuẩn `analytics → bill → transaction → category`), `conCho` của quét 29 rỗng. `SyncEngine` 2.163 dòng một tệp (đo 2026-10-16).
Không còn tệp `presentation` nào trên 1.200 dòng (bốn trang cuối — cài đặt thông báo, thêm mục tiêu, chi tiết mục tiêu, xem trước báo cáo — tách xong 2026-10-13, G88 gạch 2; trang lớn nhất trong bốn trang đó nay 866 dòng). Không logger,
không mã hoá SQLite. `setState` vẫn là cách giữ trạng thái chủ đạo (250 chỗ — `git grep -c "setState(" HEAD -- lib` cộng các tệp, 2026-10-11; trước tách trang Thêm giao dịch 289; 3 Bloc, 8 Cubit cho màn có luồng ghi).

**Nợ có tên:** **G88** ở `docs/CLIENT_APP_KNOWN_GAPS.md` — bảy gạch có số đo và hướng xử lý (gạch 7 *vị trí tệp* đóng
2026-10-10 — đợt dọn vị trí tệp, quét 25; gạch 1 *trang Thêm giao dịch* đóng 2026-10-11; gạch 1–3, 5, 6 đã đóng — 2026-10-15; gạch 4 đóng 2026-10-16 — **G88 đóng**). Một nợ có từ trước (vòng chéo mảng `bill/domain/bill_status.dart` → `notification/domain/notification_rules.dart` → `bill/domain/…`) đã gỡ 2026-10-16 và từ đó quét 29 cấm vòng mới giữa các mảng ở `domain/`; bốn cặp hai chiều của cụm {analytics, bill, category, transaction} cũng đã gỡ cùng ngày (ba lát, chiều chuẩn `analytics → bill → transaction → category`), `conCho` của quét 29 rỗng. Bảng dưới là trước/sau của đợt **bịt điểm rò** (2026-10-10), kèm một đoạn cập nhật sau bảng.

| Thước đo (cùng cách đếm, 2026-10-10) | Trước đợt | Sau đợt |
|---|---|---|
| `sl<AppDatabase>` trong `presentation/` | 29 chỗ / 17 tệp | **0** |
| `auth_bloc.dart` | 560 dòng · 23 `sl<` | **377** dòng (370 + 7 dòng docstring đầu lớp) · **0** |
| `analytics_page.dart` | 4.208 dòng | **339** + 14 tệp `widgets/phan_tich/` |
| `add_transaction_page.dart` | 3.107 dòng | **2.007** + 7 tệp `widgets/them_giao_dich/` |
| Tệp `presentation` > 1.200 dòng | 6 | **5** (danh sách miễn trừ quét 23) |
| `flutter test` · `flutter analyze` | 6.587 (+9 skip) · 20 | **6.614** (+9 skip) · **20** |
| Workflow CI | 0 | **1** |

Sau đợt trên, **tách trang Thêm giao dịch** (2026-10-11, G88 gạch 1): `add_transaction_page.dart` 2.007 → **779** dòng, thêm `ThemGiaoDichCubit` **1.097** · `ThemGiaoDichState` **184** · `ThemGiaoDichNguon` **352** (đo `wc -l`); tệp `presentation` > 1.200 dòng 5 → **4** (rồi → **0** ngày 2026-10-13, G88 gạch 2: 30 tệp widget mới + 2 tệp `domain/`, `flutter test` → **7.039**); `flutter test` 6.617 → **6.681** (+9 skip), `flutter analyze` vẫn **20**.

## 10. Cách nói khi trình bày

1. **Mở bằng ràng buộc, không bằng tên mẫu.** "App phải ghi được khi không có mạng và AI không được gửi dữ liệu đi" — rồi
   mới tới "nên SQLite là nguồn sự thật và đồng bộ tự viết".
2. **Gọi đúng tên.** Feature-first ba tầng + `application/` (bộ điều phối), offline-first. Không nhận là Clean Architecture; nói vì sao không (mục 1).
3. **Ba chữ ký.** Một định nghĩa duy nhất · test quét mã nguồn · cổng + bộ chuyển — mỗi cái kèm một ví dụ lỗi thật nó
   đã chặn (G41 bảng tra tên chép ba lần; G38 rơi về tài khoản admin; mô hình sập native thì canary bắt).
4. **Con số.** 14 mảng, 618 tệp `lib/` (đếm 2026-10-16 sau gỡ cụm), 33 tệp test quét, 7.178 ca test (đo 2026-10-17), CI xanh trên Ubuntu; trước/sau của đợt 2026-10-10 (mục 9).
5. **Tự nêu nhược điểm trước khi bị hỏi.** Còn mở: Entity mới 7/14 mảng (xong Hoá đơn, Ví, Giao dịch 2026-10-14, Danh mục, Thông báo 2026-10-15); `SyncEngine` một tệp 2.163 dòng; không logger, không mã hoá SQLite; `setState` vẫn là cách giữ trạng thái chủ đạo; và cạnh `bill/application/bill_payment_conflict_resolver.dart` → `notification_rules.dart` giữ cố ý (bộ điều phối phát thông báo, quét 29 chỉ đọc nguồn `domain/`). Đã trả, có ngày: G88 đóng 2026-10-16 (gạch 4: `core` → `features` chỉ còn năm tệp domain thuần; bốn trang trên 1.200 dòng tách xong 2026-10-13), vòng `bill_status` ↔ `notification_rules` và bốn cặp hai chiều của cụm {analytics, bill, category, transaction} gỡ 2026-10-16 — quét 29 canh vòng mới, `conCho` rỗng. Nói cả hai nhóm, tức là đã biết, không phải chưa nhìn thấy.
