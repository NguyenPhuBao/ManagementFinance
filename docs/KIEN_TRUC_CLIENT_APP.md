# Kiến trúc Client-app (FlowMoney, Flutter)

> Viết 2026-10-10, sau đợt **bịt điểm rò kiến trúc** (spec `docs/superpowers/specs/2026-10-10-bit-diem-ro-kien-truc-client-design.md`);
> cập nhật cùng ngày (khuya) sau đợt **dọn vị trí tệp** (spec `docs/superpowers/specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`)
> — mục 3, 4, 6, 7, 8, 9, 10; cập nhật lần nữa **2026-10-15** sau đợt **Entity Thông báo + gạch 5 + gạch 6** (spec `docs/superpowers/specs/2026-10-15-entity-thong-bao-application-design.md`) — mục 1, 3, 4, 5, 6, 8, 9;
> và **2026-10-17** sau **trợ lý online hỗn hợp** (spec `docs/superpowers/specs/2026-10-11-tro-ly-online-backend-fallback-tren-may-design.md`) — mục 2, 3, 5, 7, 9, 10.
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
| Hai máy cùng tài khoản ghi khi offline; server không có khái niệm "bản nháp" | **Đồng bộ tự viết, hai chiều, LWW theo `update_at`**, đẩy lô thao tác + kéo theo mốc giờ-server | `core/sync/sync_engine.dart` (506 dòng — vòng đời, giãn cách, `_runSync`) + ba lớp cộng tác `ap_du_lieu_keo_ve.dart` (743) · `thu_gom_day.dart` (455) · `gui_lo_dong_bo.dart` (410), `sync_payload_normalizer.dart`, `moc_keo_ve.dart` (đo 2026-10-19 sau tách SyncEngine; quét 34 canh mỗi tệp ≤ 800) |
| Người dùng chọn AI **trên máy** để chạy không mạng và không gửi dữ liệu tài chính đi — rồi ngày 2026-10-11 chốt thêm **trợ lý online hỗn hợp** cho màn Trợ lý AI (có mạng hỏi backend, hỏng / mất mạng thì AI trên máy) | **Hai tầng AI**: luật + hàm thuần (`ai_edge/domain`) cho mọi màn; mô hình Gemma 4 E2B trên máy chỉ cho hỏi đáp / đọc câu / đọc ảnh, mọi con số đi qua lớp chắn. Màn Trợ lý AI thử chatbot backend (SSE) trước khi công tắc bật ∧ có mạng ∧ câu không thuộc nhóm dữ liệu sống; hỏng thì cùng câu đi đường trên máy | `features/ai_edge/`, `features/ai_chat/`, `core/api/khung_sse.dart` |
| Tự trả hoá đơn, tự trích mục tiêu phải xảy ra đúng lúc kể cả khi app đóng | **Chạy nền bằng WorkManager** đánh thức một engine Flutter không giao diện, dùng lại đúng bộ quét của app | `android/.../TuChuyenTien*.kt`, `core/nen/` |

## 3. Cây thư mục

`lib/` có **658** tệp `.dart` (HEAD `a6c6fc7d`, 2026-10-19; **652** ở lần đo trước), **127.697** dòng (đo 2026-10-19 @`ce8dfcd8`, `git ls-files lib | grep '\.dart$' | xargs cat | wc -l`; 127.530 ở lần đo trước; kể 16 tệp `.g.dart` do Drift sinh) — `git ls-files lib | grep '\.dart$'`
và `… | xargs cat | wc -l`. `test/` có **662** tệp `*_test.dart` (675 tệp `.dart` kể cả helper), **132.532** dòng (đếm lại **2026-10-19** sau tách SyncEngine và ca canh G14 — HEAD `8889bb72`, `git ls-files`; `lib/` 658 tệp). (Trước đó, sau phần còn lại của báo cáo soát — `DateFormatter`, `chuPhanTram`, tách `other_daos.dart`, giao dịch có `application/` — HEAD `925e38a9`: `test/` 661 `_test` (673 `.dart`), 132.420 dòng.) (Trước phần còn lại của báo cáo soát, sau bốn lát sửa lệch kiến trúc và gỡ `CategoryIconRegistry`: `lib/` 647 tệp, 127.534 dòng; `test/` 657 `_test` (669 `.dart`), 132.258 dòng. Trước khi gỡ registry, HEAD `9712fc80`: `lib/` 648 tệp, 127.595 dòng; `test/` 658 `_test` (670 `.dart`), 132.276 dòng. Trước đó 2026-10-18 tối sau G94 lát 2, HEAD `ddd35e1a`: `lib/` 644 tệp, 127.539 dòng; `test/` 652 `_test` (664 `.dart`), 131.848 dòng. Trước đó 2026-10-18 sau G94 lát 1, HEAD `cc300f61`: `lib/` 634 tệp, 126.253 dòng; `test/` 647 `_test` (659 `.dart`), 130.633 dòng. Trước đó 2026-10-17 sau trợ lý online, HEAD `fb92c16d`: `lib/` 629 tệp, 125.809 dòng; `test/` 644 `_test` (656 `.dart`), 129.998 dòng. Trước đó 2026-10-16 sau gỡ cụm, HEAD `f702a884`: `lib/` 618 tệp, 124.393 dòng; `test/` 629 `_test` (640 `.dart`), 126.455 dòng. 2026-10-15: 626 tệp `.dart` (617 `_test`), 124.875 dòng; 2026-10-13, sau tách bốn trang lớn: 596 / 616 tệp, 122.667 / 123.486 dòng.)

```
lib/
├── main.dart                 điểm vào app + điểm vào engine nền (`chayNenTuChuyenTien`, @pragma)
├── core/            109 tệp (đếm 2026-10-20, sau G89; 107 sau chẻ `pullFromBackend`)  hạ tầng + điểm ghép — KHÔNG chứa màn hình (15 chủ đề — test quét 25; `core/notification` đã dời 2026-10-15)
│   ├── api/           5      DioClient (DI dùng `sl<DioClient>().dio`; tự dựng `MayChuInterceptor` từ tham số `trangThaiMayChu` + `khiBiTatQuyen` — quét 36), `interceptors/` (`may_chu_interceptor` — ghi `TrangThaiMayChu` từ 503 `MAINTENANCE_MODE` / 403 `AIOPS_QUARANTINED` của request mang phiên, hook 403 `FEATURE_DISABLED`; đứng SAU AuthInterceptor, G89 2026-10-20; `ket_qua_lam_moi`), AuthInterceptor (gắn token, làm mới, dịch 401 + code; phát lại sau 401 giữ `responseType` · `receiveTimeout` · `cancelToken`), `khung_sse` (bộ tách khung SSE thuần, 2026-10-17)
│   ├── auth/          3      buoc_dang_xuat (kiểu thuần 4 tệp hạ tầng dùng), PhienDieuPhoi(+That) ← điều phối phiên
│   ├── category/      1      category_name (normalizeCategoryName — DAO + util dùng)
│   ├── constants/     2      app_constants, app_localization
│   ├── database/     46      AppDatabase, 14 tệp DAO (đếm 2026-10-19; `other_daos.dart` đã tách thành `budget_dao` · `bill_dao` · `goal_dao`), bảng, kết nối (native / web)
│   ├── di/            1      injection_container (1.039 dòng) ← điểm ghép duy nhất của DI
│   ├── errors/        1      app_exceptions
│   ├── nen/           7      chạy nền: chay_nen, luot_nen, lich_nen, kênh `flowmoney/tu_chuyen_tien`, `app_lifecycle_watcher`
│   ├── network/       2      connection_monitor, `trang_thai_may_chu` (mô hình bảo trì / phong toả, Dart thuần, không gắn tài khoản, không lưu đĩa — G89 2026-10-20)
│   ├── ocr/           7      DocChuAnh (cổng) + bản ML Kit, `ten_tep_bien_lai` (kho ảnh quét dời về `transaction/data/datasources/` 2026-10-16)
│   ├── realtime/      5      RealtimeChannel; chỉ realtime_socket.dart import socket_io_client
│   ├── router/        1      app_router (GoRouter) ← điểm ghép
│   ├── sync/          15     `SyncEngine` + ba lớp cộng tác (`ApDuLieuKeoVe` · `ThuGomThaoTacDay` · `GuiLoDongBo`), năm tệp hàm thuần (`uuid_dong_bo` · `moc_keo_ve` · `bieu_tuong_danh_muc_mac_dinh` · `gieo_tu_khoa` · `anh_xa_keo_ve` — sáu hàm dựng companion kéo về, 2026-10-20), normalizer, model; ngoài `core/sync` chỉ dùng sáu tệp cửa công khai (quét 35)s, checkpoint, `backend_bool`, hai cổng `CongSoDuVi` · `CongViBiGiu` (2026-10-19 tách SyncEngine; `noiBoNgheKetQuaDay` đã về DI từ 2026-10-16)
│   ├── ui/            3      thong_bao_nhanh (toast), bieu_do_cham, do_chu (`bao_che_day_toast` dời về `shared/widgets/` 2026-10-19)
│   └── utils/        10      CurrencyFormatter, `DateFormatter` (tám hàm, mỗi mẫu ngày một hàm — quét 32), `chuPhanTram` (quét 33), gioi_han_do_dai, so_bang_chu, ngay_trong_cau, khop_ten, `tuan_iso`, `dung_sai_tien` (hàm thuần dùng chung — tiền lệ cho `domain/` mục 4)…
├── features/        537 tệp (đếm 2026-10-19)  14 mảng nghiệp vụ, mỗi mảng data / domain / presentation (+ `application/` ở sáu mảng: ví · danh mục · hoá đơn · mục tiêu · thông báo · giao dịch)
│   ├── ai_edge/      83      data 23 (datasources/ 5) · domain 55 · presentation 5 (đếm 2026-10-19) — luật, gói số, tool, SLM runtime, lớp chắn
│   ├── transaction/  77      data 18 · domain 29 · application 1 · presentation 29 (đếm 2026-10-19; bloc/ 5 kể `ThemGiaoDichCubit` + state · widgets/them_giao_dich/ 7 tệp)
│   ├── analytics/    61      data 9 · domain 18 · presentation 34 (widgets/phan_tich/ 14 tệp · widgets/xem_truoc_bao_cao/ 10 tệp)
│   ├── bill/         39      data 7 · domain 16 · application 2 · presentation 14
│   ├── goal/         49      data 4 · domain 18 · application 1 · presentation 26 (widgets/them_muc_tieu/ 7 tệp · widgets/chi_tiet_muc_tieu/ 7 tệp)
│   ├── wallet/       33      data 8 · domain 9 · application 4 · presentation 12 (state/ 1)
│   ├── budget/       30      data 7 · domain 10 · presentation 13
│   ├── premium/      43      data 14 (models/ 4 · datasources/ 4 · repositories/ 3) · domain 8 · presentation 21 (bloc/ 5 · state/ 2 · pages/ 4 · widgets/ 10) — đếm 2026-10-19 (G94 lát 2, 2026-10-18 tối: 42; lát 1: 32 — data 12 · domain 7 · presentation 13; trước lát 1: 27)
│   ├── auth/         21      data 5 · domain 1 · presentation 15 (bloc/ 4 kể AuthBloc + current_account · pages/ 6 · state/ 1 · widgets/ 4)
│   ├── category/     22      data 8 · domain 6 · application 2 · presentation 6
│   ├── profile/       8      presentation 8
│   ├── home/          8      domain 1 · presentation 7
│   ├── notification/ 48      data 17 · domain 11 · application 8 · presentation 12 (widgets/cai_dat_thong_bao/ 6 tệp; luật, bộ quét, bộ nhập dời từ core/notification 2026-10-15)
│   └── ai_chat/      15      data 7 (datasources/ 1 — SSE trợ lý online · repositories/ 2 · models/ 1 · `cong_tac_online` · `doc_lenh_bang_ai` · `nguon_lenh_tao`; đếm 2026-10-19) · domain 2 (`duong_hoi`, `su_kien_online`) · presentation 6 (pages/ 1 · widgets/tro_ly_ai/ 5) — màn Trợ lý AI + trợ lý online (2026-10-17; spike C4 đã gỡ 2026-10-12)
└── shared/           14 tệp (đếm 2026-10-19)  theme/ 3 (AppTheme, AppColors) · widgets/ 11 (MainShell, chuông, toast…)
```

Sau chẻ `pullFromBackend`, đếm lại bằng máy **2026-10-20** (`find … -name '*.dart' | wc -l`): `core` 107 · `core/sync` 15 · `lib/` 659 · `test/` 664 `_test`; sau G89 (đếm lại 2026-10-20, `find … | wc -l`): `core` 109 · `lib/` 662 · `test/` 669 `_test`; các hàng còn lại ngay dưới là của lần đếm trước (2026-10-19 sau tách SyncEngine: `core` 106 · `core/sync` 14 · `lib/` 658 · `test/` 662). Các hàng của khối cây trước đó đếm lại bằng máy **2026-10-19** trên HEAD `925e38a9` (`git ls-files`, sau phần còn lại của báo cáo soát): `core` 100 · `core/database` 46 (14 tệp DAO) · `core/utils` 10 · `lib/` 652 · `test/` 661 `_test` · `transaction` data 18 · domain 29 · application 1 · presentation 29 · `application/` toàn `features/` 18. Trước đó, hàng `core` (95) và `shared` (14 · `widgets/` 11) đếm lại bằng máy **2026-10-19** (`find lib/core -name '*.dart' | wc -l`, `find lib/shared -name '*.dart' | wc -l`) sau khi `bao_che_day_toast` dời `core/ui/` → `shared/widgets/` (core 97 → 96) và gỡ `core/sync/category_icon_registry.dart` (96 → 95; `sync/` 9 → 8 — người dùng chốt: không còn ai ghi vào nó, chỉ đọc di sản). Hàng `core/api` · `core/di` đếm lại bằng máy **2026-10-17 sau trợ lý online** (HEAD `fb92c16d`, `git ls-files … | grep -c '\.dart$'`; `injection_container` bằng `wc -l`; `core` lúc ấy 97 tệp, nay 96 sau khi `bao_che_day_toast` dời). Các hàng `lib/` · `test/` · `features/` · `transaction` · `budget` · `premium` · `ai_edge` · `ai_chat` đếm lại **2026-10-19** (HEAD `9712fc80`, `git ls-files lib/features/<mảng>/<tầng> | grep -c '\.dart$'`). Các số dưới là của lần đếm trước.
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
| `application/` (từ 2026-10-15, G88 gạch 6) | Bộ điều phối nhiều bước — ghi qua nhiều repository, quét, nhập, đặt lịch (`features/<x>/application/`: ví 4 · danh mục 2 · hoá đơn 2 · mục tiêu 1 · thông báo 8 · giao dịch 1 = **18** tệp, đếm 2026-10-19) | `data/`, `domain/`, `core/` | widget; được điểm ghép (`core/di` · `core/nen/chay_nen` · `phien_dieu_phoi_that`), `main.dart` và `presentation/` gọi; (`core/sync/noi_bo_nghe_ket_qua_day` — nợ gạch 4 — đã về DI 2026-10-16, không còn ngoại lệ); còn `data/` và `domain/` **không** import nó |

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
  ngoài bốn điểm ghép (DI · router · `chay_nen` · `phien_dieu_phoi_that`), tệp `core` import `features/` chỉ được trỏ vào **năm tệp domain thuần** trong danh sách CỐ ĐỊNH `domainThuanChoCore` (luật 5, từ 2026-10-16; **thay** ratchet `conChoCoreImport` 18 dòng / 7 tệp): `wallet/domain/wallet_status` · `wallet_type`, `bill/domain/bill_pay_status` · `bill_recurrence`, `goal/domain/uu_tien_hop_le` — hằng và hàm thuần mà DAO, `SyncEngine`, bộ chuẩn hoá payload cần đọc. Luật 5b canh năm tệp ấy còn thuần (chỉ import `dart:` hoặc `data/models/` của chính mảng nó). Thêm tệp thứ sáu là sửa danh sách — có lý do và ngày, không phải nới trần. *(Đo 2026-10-16 bằng vòng `for` + `grep -cE "^(import|export) .*features/"` từng tệp, HEAD `4b7740a3`: **178** = điểm ghép **170** (DI 111 · router 54 · `chay_nen` 4 · `phien_dieu_phoi_that` 1) + hạ tầng **8** (`sync_engine` 4 · `sync_payload_normalizer` 2 · `wallet_dao` 1 · `other_daos` 1) — cả tám đều trỏ vào năm tệp trên; trước đợt 184 = 166 + 18.)* *(Đo lại 2026-10-19 sau tách SyncEngine, HEAD `a6c6fc7d`, cùng vòng `for`: **194** tổng = điểm ghép **185** + hạ tầng **9** — `ap_du_lieu_keo_ve` 4 · `sync_payload_normalizer` 2 · `thu_gom_day` 1 · `wallet_dao` 1 · `bill_dao` 1; bốn dòng của `sync_engine` cũ nay ở `ap_du_lieu_keo_ve` (4) cộng một ở `thu_gom_day`, `sync_engine.dart` mới không import `features/` nào; `bill_dao` là dòng của `other_daos` cũ sau khi tách ba DAO; cả chín đều trỏ vào năm tệp domain thuần.)* **Thứ có trạng thái thì không đi bằng import mà bằng cổng:** `core/sync/cong_so_du_vi.dart` (`CongSoDuVi`) và `cong_vi_bi_giu.dart` (`CongViBiGiu`, `BanGhiGiuKhoiDay`) là interface Dart thuần; `SyncEngine` nhận hai cổng **bắt buộc**, bản thật `SoDuViService` · `ViBiGiuDongBo` (`features/wallet/data/`) do DI nối — khuôn cho mọi thứ `core` cần từ một mảng mà không phải hằng thuần. Lịch nền theo cùng khuôn: `core/nen/lich_nen.dart` chỉ **gộp** (`gopLichNen`), mỗi mảng tự tính mốc của mình (`mocTuTraNen` ở `bill/domain`, `mocTrichNen` ở `goal/domain`).

## 5. Tám luồng chính

**Ghi.** Trang gọi Bloc/Cubit (hoặc gọi thẳng repository với màn đơn giản) → repository ở `features/<x>/data/repositories/`
ghi SQLite với `syncStatus = pending` và `updatedAt` mới. Mọi thay đổi số dư đi qua `wallet/data/so_du_vi_service.dart`
— chỗ **duy nhất** được ghi `wallets.balance`, vì số dư là cache của tổng sổ giao dịch (G37). Repository xong thì gọi
`SyncEngine.scheduleSync()` (giãn cách), nên người dùng không bao giờ chờ mạng.

**Đọc.** Màn đọc dùng **stream Drift** (`watch…`) qua repository — `StreamBuilder` ở trang hoặc Cubit nghe stream (ví dụ
`AnalyticsRepository.watchKy` gộp tám nguồn). Ghi ở bất kỳ đâu, kể cả Pull của đồng bộ, đều tự đẩy màn vẽ lại; không có
cache tầng giữa nào phải làm mới tay. Từ đợt 2026-10-10 trang **không** cầm DAO: lối đọc là repository hoặc một nguồn đăng
ký DI (`TaiPhanBoNguon`, `GanDanhMucNguon`; bảng thông báo qua `ThongBaoRepository`).

**Đồng bộ.** `core/sync/sync_engine.dart` giữ vòng đời, giãn cách và `_runSync` (mọi cam kết thứ tự) và gọi ba lớp cộng tác dựng trong constructor của nó: `ThuGomThaoTacDay` (`thu_gom_day.dart`) gom thao tác chờ theo thứ tự khoá ngoại (`collectPendingOps`: hoá đơn **trước**
giao dịch), dựng payload tay; `GuiLoDongBo` (`gui_lo_dong_bo.dart`) qua `SyncPayloadNormalizer` rồi `POST /sync/push` và phân loại lỗi (`_permanentCodes`); kết quả phát ở `pushResultStream`
**trước** bước Pull (người nghe `BillPaymentConflictResolver`, `ViTrungTenResolver` nối ở `noiBoNgheKetQuaDay()` — nay ở cuối `core/di/injection_container.dart`, từ 2026-10-16). Rồi
`ApDuLieuKeoVe` (`ap_du_lieu_keo_ve.dart`) `GET /sync/pull` với mốc giờ-server `mocTuMaxSince`, dựng companion từng hàng bằng sáu hàm thuần ở `anh_xa_keo_ve.dart` (từ 2026-10-20 — mọi chốt *server im lặng = `Value.absent()`* nằm ở đó), ghi bằng `insertAllOnConflictUpdate` (quy tắc 3), tính lại số dư;
sau **mỗi** lượt kéo về thành công (gác theo `soLanKeoVeXong`), `_runSync` gọi cổng tuỳ chọn `sauKeoVe` ngay sau Pull, trước lần thử đẩy lại — DI nối `DefaultCategorySeeder` (ngoài `core/sync`), quy tắc 8; cổng chạy trong cờ `syncing` nên không gieo chồng, lỗi chỉ ghi log (từ 2026-10-20; trước đó `PhienDieuPhoiThat.batDongBo` gọi móc `taoBanSaoDanhMuc` một lần mỗi phiên, sau `start()` — ca canh `test/core/sync/sync_gieo_sau_keo_ve_test.dart`). Hợp đồng tên trường nằm ở `test/core/sync/sync_payload_contract_test.dart`.

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
khối Nhận xét ở sáu màn và kế hoạch tái phân bổ. Tầng mô hình: `ai_edge/data/datasources/slm_runtime.dart` (chỗ duy nhất import
`flutter_gemma`) chạy Gemma 4 E2B trên máy; màn Trợ lý AI đi `vong_lap_cong_cu.dart` — định tuyến `dinhTuyenCauHoi`, tool
**chỉ đọc** qua repository, mọi câu qua `kiemCauTraLoi` (sáu lớp chắn) trước khi hiện. Ô Nhập nhanh, lệnh tạo, đọc ảnh
quét dùng phiên một lời gọi; AI chỉ **điền sẵn**, người dùng bấm Lưu (bất biến ④). **Trợ lý online** (2026-10-17, nghiệm thu OnePlus 13R 2026-10-18
trên backend dev): trước đường trên máy, `ai_chat_page.dart` hỏi `nenHoiOnline` (`ai_chat/domain/duong_hoi.dart` — công tắc
`CongTacOnline` bật ∧ `ConnectionMonitor.coMangNgay()` ∧ `!chuDeBiChanOnline`) → tờ thông tin một lần → `TroLyOnlineRepository.hoi` (`ai_chat/data/repositories/`, từ 2026-10-19) trả `LuotHoiOnline`
(`ai_chat/data/models/` — luồng sự kiện + `huy` thuần; datasource giữ `CancelToken`) → datasource SSE
`ai_chat/data/datasources/tro_ly_online_remote_data_source.dart` (`POST /ai/chatbot/chat/stream` qua `sl<DioClient>().dio`, khung tách
ở `core/api/khung_sse.dart`) → luật rơi thuần `quyetDinhSauOnline`: hỏng trước chữ đầu thì **cùng câu** đi đường trên máy; câu
online không qua lớp chắn ở client, chỉ mang nhãn nguồn.

**Xác thực.** `core/api/dio_client.dart` + `AuthInterceptor` gắn token từ `FlutterSecureStorage`, làm mới khi 401, dịch
401 mang `code` thành lời từ chối có lý do. `AuthBloc` giữ trạng thái và thứ tự emit; vòng đời phiên ở
`PhienDieuPhoi` hai pha: `moPhienCucBo` **trước** `AuthSuccess` (dọn tài khoản khác, bộ quét — để mở app không chờ mạng,
G86) rồi `batThoiGianThuc` · kiểm `_vanLaPhien` · `batDongBo`; `dongPhien` khi đăng xuất hay bị buộc đăng xuất (`xoaDuLieu` và `purgeDataForAccount` gỡ 2026-10-20, G89 — `ACCOUNT_DELETED` không xoá SQLite ở mọi nguồn).

## 6. Ba chữ ký thật

**(1) Một định nghĩa duy nhất.** Mỗi luật hỏng-im-lặng có đúng một hàm, mọi nơi gọi lại nó: `khoanVaoThongKe` (khoản nào
vào thống kê), `viTinhVaoTong` (ví nào cộng vào tổng), `normalizeCategoryName` (trùng tên danh mục),
`CurrencyFormatter` (hiển thị tiền), `kyKeTiepCua` (kỳ hoá đơn kế), `BudgetEntity.mocKy` (lưới kỳ ngân sách),
`cuaSoNhinLai` (trung bình mỗi tháng), `trangThaiQuyen` / `duocDung` (quyền theo gói), `SoDuViService` (ghi số dư). Chép tay lần thứ hai là
lỗi đã xảy ra thật ở mỗi chỗ — ví dụ G41/G47 (bảng tra tên danh mục chép ba lần).

**(2) Test quét mã nguồn.** Luật nào bộ test hành vi không thấy được (một import lọt, một handler rỗng, một `?? 1`) thì
thành một test **đọc `lib/`** và đỏ khi luật bị phá. Bảng dưới khoá theo **tên tệp**: dãy số tự xưng 1–36 phủ **37
tệp** — số **14** được hai tệp cùng nhận (cả hai docstring đều ghi *"thứ mười bốn"*, va chạm có từ 2026-09-21) — cộng
**3** tệp cùng khuôn không đánh số, tổng **40** (đếm bằng bảng 2026-10-20, sau quét 36; helper `test/helpers/duong_dong_bo.dart` — `tepDuongDongBo()` trả mọi tệp `lib/core/sync/` cho ba quét cột cục bộ — không đếm, như `chi_thi_dart.dart`). Đếm (2026-10-20, từ `src/Client-app`, bằng awk — `grep` qua rtk bóp méo mẫu): tệp `test/` (trừ `helpers/`) chứa `Directory('lib` ra **35** tệp quét cây (gồm quét 34, 35 và 36; quét 31 duyệt cây qua biến `goc` nên khuôn ấy không thấy nó — cộng 1 là 36); chứa `tepDuongDongBo` ra **3** tệp (ba quét cột cục bộ); 36 + 3 = 39, **1** tệp còn lại đọc danh sách tệp cố định — tổng 40 khớp bảng (đếm lại 2026-10-20 sau G89). Từ 2026-10-24 thêm quét **38** (soát bảo mật: log không lộ dữ liệu người
dùng ở bản release) — số **37** dành cho quét gia đình (spec `2026-10-23-gia-dinh-nen-mong-design.md` mục 7.2, chưa thi
công) — tổng **41** tệp. Từ 2026-10-26 thêm quét **39** (đo bề rộng chữ lúc dựng phải qua `BoCucTheoFont`) — tổng **42**
tệp; 2026-10-27 quét **40** (danh sách chọn danh mục qua một cửa) — **43**; 2026-10-28 quét **41** (công tắc khoá theo quyền qua
`CongTacTheoQuyen`, G111) — tổng **44** tệp (đếm bằng bảng 2026-10-28). Test quét mới lấy số **42**.

| Số | Tệp (dưới `test/`) | Luật | Phạm vi | Từ |
|---|---|---|---|---|
| 1 | `core/utils/currency_formatter_test.dart` | chỉ `CurrencyFormatter` dựng `NumberFormat` | cây `lib/` | 2026-09-09 |
| 2 | `features/wallet/wallet_picker_sources_test.dart` | mỗi chỗ đọc danh sách ví được phân loại tay: bộ chọn hay bảng tra | cây | 2026-09-10 |
| 3 | `core/auth/khong_du_phong_admin_test.dart` | mã tài khoản không rơi về `?? 1` / mặc định `= 1` (tài khoản admin) | cây | 2026-09-11 |
| 4 | `core/sync/sync_engine_start_owner_test.dart` | chỉ `PhienDieuPhoiThat` gọi `start` của SyncEngine / RealtimeChannel / NotificationScanner (chủ cũ: AuthBloc) | cây | 2026-09-12 |
| 5 | `features/bill/bill_conflict_resolver_wiring_test.dart` | `BillPaymentConflictResolver` được bắt đầu nghe | cây | 2026-09-13 |
| 6 | `features/wallet/so_du_mot_noi_ghi_test.dart` | chỉ `SoDuViService` gọi `updateBalance` | cây | 2026-09-13 |
| 7 | `features/wallet/wallet_cho_phep_am_test.dart` | cờ `allowNegative` không lọt vào đường đồng bộ | mọi tệp `core/sync` (`tepDuongDongBo()`, từ 2026-10-19; trước: danh sách tệp) | 2026-09-17 |
| 8 | `core/utils/o_nhap_tien_co_tran_test.dart` | mọi ô nhập tiền có trần 13 chữ số | cây | 2026-09-18 |
| 9 | `features/wallet/lien_ket_ngan_hang_da_bo_test.dart` | không còn tham chiếu đường `bank-link` | cây | 2026-09-18 |
| 10 | `core/ui/khong_co_nut_chet_test.dart` | không handler rỗng (danh sách giữ có số đếm) | cây | 2026-09-19 |
| 11 | `core/utils/ky_hieu_tien_mot_noi_test.dart` | không nối `đ` tay | cây | 2026-09-19 |
| 12 | `core/ui/icon_button_co_tooltip_test.dart` | mọi `IconButton` có `tooltip` | cây | 2026-09-19 |
| 13 | `features/profile/avatar_chu_khac_mau_nen_test.dart` | avatar không viết chữ `primary` trên nền `primaryContainer` | cây | 2026-09-19 |
| 14 | `features/ai_edge/ai_edge_khong_tinh_test.dart` | `ai_edge/` không so chiều tiền / tự tính | cây `ai_edge/` | 2026-09-19 |
| 14 | `core/utils/dau_tien_mot_noi_test.dart` | `formatIncome` / `formatExpense` chỉ trong `currency_formatter.dart` | cây | 2026-09-21 |
| 15 | `features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart` | thứ cục bộ của schema v24 không vào đồng bộ | mọi tệp `core/sync` (`tepDuongDongBo()`, từ 2026-10-19; trước: danh sách tệp) | 2026-09-19 |
| 16 | `features/ai_edge/chi_mot_noi_import_gemma_test.dart` | chỉ `datasources/slm_runtime.dart` import `flutter_gemma` | cây | 2026-09-22 |
| 17 | `core/ocr/chi_mot_noi_import_mlkit_test.dart` | chỉ `doc_chu_anh_mlkit.dart` import ML Kit | cây | 2026-10-02 |
| 18 | `features/premium/chi_mot_noi_import_url_launcher_test.dart` | chỉ `datasources/mo_lien_ket.dart` import `url_launcher` | cây | 2026-10-06 |
| 19 | `core/ui/khong_snackbar_test.dart` | không `SnackBar` / `ScaffoldMessenger` | cây | 2026-10-06 |
| 20 | `features/transaction/chi_mot_noi_import_image_picker_test.dart` | chỉ `quet_anh_page.dart` import `image_picker` | cây | 2026-10-08 |
| 21 | `features/premium/quyen_tinh_nang_mot_noi_test.dart` | quyền theo gói chỉ đọc qua `trangThaiQuyen` (`duocDung` là vế bool; B1 2026-10-27) | cây | 2026-10-08 |
| **22** | `core/ui/presentation_khong_cham_csdl_test.dart` | `presentation/` và `shared/` không cầm `AppDatabase` / DAO; `conCho` rỗng | cây | **2026-10-10** |
| **23** | `core/ui/tep_presentation_khong_qua_dai_test.dart` | tệp `presentation` ≤ 1.200 dòng; `mienTru` **rỗng** từ 2026-10-13 (G88 gạch 2; từng 4 tệp, rút `add_transaction_page` 2026-10-11) | cây `features/` | **2026-10-10** |
| **24** | `features/auth/auth_bloc_khong_sl_test.dart` | `auth_bloc.dart` không gọi service locator, không import `core/di` | một tệp | **2026-10-10** |
| **25** | `core/ui/vi_tri_tep_theo_luat_test.dart` | cây `lib/` / `test/` khớp luật vị trí tệp mục 8 (**tám** luật — luật 7 `data/` và `domain/` không import `application/` (2026-10-15); `tangMang` có `application`; `diemGhep` có `phien_dieu_phoi_that.dart`; luật 5 `core` → `features` ngoài bốn điểm ghép chỉ được đọc năm tệp trong danh sách CỐ ĐỊNH `domainThuanChoCore` (2026-10-16, thay ratchet `conChoCoreImport` 18 dòng / 7 tệp), luật 5b canh năm tệp ấy còn thuần; luật 5, 5b, 7 đọc chỉ thị qua `test/helpers/chi_thi_dart.dart` từ 2026-10-16 — thấy `part`, từng vế import có điều kiện, chỉ thị xuống dòng); `conCho` rỗng (miễn trừ `ai_chat/spike/` đã gỡ 2026-10-12) | cây `lib/` + `test/` | **2026-10-10** |
| **26** | `features/transaction/chi_mot_noi_import_giong_noi_test.dart` | `speech_to_text` chỉ ở `nghe_android.dart`, `record` chỉ ở `ghi_am.dart` (có ca tiền đề) | cây `lib/` | **2026-10-12** |
| **27** | `core/ui/presentation_domain_khong_kieu_drift_test.dart` | **bốn** luật — (1) `presentation/` + `shared/` + `lib/core` (trừ `database`, `sync`) và, từ 2026-10-15, cả `features/*/domain/` không nhắc kiểu hàng Drift theo tên kiểu (danh sách chờ theo kiểu `conChoKieu` **rỗng** từ 2026-10-15, đợt Entity Thông báo); (2) `domain/` không import `core/database` / `package:drift` (danh sách chờ rỗng từ 2026-10-15); (3) `features/*/data` và `features/*/application` không khai `<dynamic>` trần cho `Stream` / `Future` / `List` / `Iterable` (danh sách chờ rỗng); (4) interface repository (`features/*/data/repositories/*_repository.dart`, 13 tệp không kể `_impl` — `git ls-files 'lib/features/*/data/repositories/*_repository.dart' | wc -l`, đếm 2026-10-19) không import `core/database` / `package:drift`; từ 2026-10-16 luật 2 và 4 đọc chỉ thị qua `chi_thi_dart.dart` nên thấy cả `export`, còn mẫu tên kiểu của luật 1 bắt thêm `is X ?` và `X(` (hai dạng tách bạch: mẫu `case X(…)` của Dart 3, và dựng hàng `X(…)` trực tiếp — đo 0 chỗ trúng mới) | cây `lib/` | **2026-10-14** |
| **28** | `core/ui/domain_khong_import_tang_tren_test.dart` | **hai** luật — `features/*/domain/` không import đường chứa `/presentation/`; đường chứa `/data/` phải chứa `/data/models/` (Entity, `BudgetView`, `ThongKeKy` hợp lệ; repository / datasource / nguồn thì không); `conCho` **rỗng** từ khi có (đo gốc năm tệp, rút cùng đợt; đọc chỉ thị qua `chi_thi_dart.dart`) | cây `lib/` | **2026-10-16** |
| **29** | `core/ui/domain_khong_vong_mang_test.dart` | đồ thị cấp mảng — cạnh `A->B` khi tệp dưới `features/A/domain/` có `import` / `export` / `part` tới bất kỳ tầng nào của mảng B; cạnh nằm trên một vòng (hai đầu cùng một thành phần liên thông mạnh > 1) phải ở `conCho` (**rỗng** từ 2026-10-16 — ba lát gỡ cụm theo chiều `analytics → bill → transaction → category`; cạnh trong danh sách mà hết nằm trên vòng thì đỏ "rút"); có ca tiền đề số tệp | `features/*/domain/` → mọi tầng mảng khác | **2026-10-16** |
| **30** | `features/goal/da_hoan_thanh_mot_noi_test.dart` | luật "mục tiêu đã xong" chỉ ở getter `daHoanThanh` (`isCompleted \|\|` ngoài `goal_entity.dart` là đỏ) | cây | **2026-10-19** |
| **31** | `core/ui/trang_khong_import_datasource_csdl_api_test.dart` | trang (`presentation/`, `shared/`) import datasource bọc CSDL / API backend hoặc gói Dio — `conCho` rỗng từ 2026-10-19 (Trung tâm thông báo và Trợ lý AI gỡ cùng ngày) | `presentation/` + `shared/` | **2026-10-19** |
| **32** | `core/utils/dinh_dang_ngay_mot_noi_test.dart` | nhắc `DateFormat` ngoài `core/utils/date_formatter.dart` — mỗi mẫu ngày một hàm `DateFormatter` | cây | **2026-10-19** |
| **33** | `core/utils/phan_tram_mot_noi_test.dart` | tự viết `(x * 100).round()}%` ngoài `chuPhanTram` (`core/utils/phan_tram.dart`) | cây | **2026-10-19** |
| **34** | `core/sync/sync_tep_khong_qua_dai_test.dart` | tệp dưới `lib/core/sync/` > 800 dòng ngoài `mienTru` (trần riêng chỉ giảm; rỗng từ 2026-10-19) | cây | **2026-10-19** |
| **35** | `core/sync/chi_core_sync_import_tep_noi_bo_test.dart` | ngoài `lib/core/sync/` chỉ thị vào `core/sync` không qua `cuaCongKhai` (sáu tệp); tệp mới trong `core/sync` mặc định nội bộ; `conCho` rỗng | cây | **2026-10-20** |
| **36** | `core/api/may_chu_interceptor_chi_trong_dio_client_test.dart` | `MayChuInterceptor` (interceptor trạng thái máy chủ) dựng ngoài `core/api/dio_client.dart` | cây `lib/` | **2026-10-20** |
| **38** | `core/utils/log_khong_lo_du_lieu_nguoi_dung_test.dart` | lệnh `debugPrint` / `print` / `log` in `.balance` · `.amount` · `.note` · `.args` · `.noiDung` · `.ghiChu` (thêm 2026-10-24) mà không qua `kDebugMode` (trong câu lệnh, hoặc khối bao quanh mở bằng dòng có `kDebugMode` / `assert(`) — `debugPrint` không bị lược ở bản release; có sáu ca mẫu viết tay cho bộ đọc | cây `lib/` | **2026-10-24** |
| **39** | `core/ui/do_chu_qua_bo_cuc_theo_font_test.dart` | tệp có `doRongChu(` / `TextPainter(` (dòng mã, bỏ phần sau `//`) không có `LayoutBuilder(` — phải qua `BoCucTheoFont` (`core/ui/do_chu.dart`, miễn trừ): font Inter (`google_fonts`, không đóng gói) nạp sau khung đầu, `Text` tự đo lại còn `builder` của `LayoutBuilder` thì không; ca tiền đề ≥ 10 tệp đo chữ; đỏ đúng 9 chỗ lúc thêm | cây `lib/` | **2026-10-26** |
| **40** | `features/category/danh_sach_chon_danh_muc_mot_cua_test.dart` | gọi `getCategoryRows` / `watchCategoryRows` ngoài DAO và cửa `features/category/data/danh_sach_chon_danh_muc.dart` — mọi danh sách CHỌN bỏ bản sao đang ẩn theo khuôn qua cửa ấy (spec 2026-10-27 mục 4) | cây `lib/` | **2026-10-27** |
| **41** | `features/premium/cong_tac_khoa_mot_noi_test.dart` | `Switch(` / `HangCongTac(` khoá theo quyền bằng `onChanged` (đối số hỏi `coQuyen(` / `coQuyenDoc(` / `coQuyenNen(` mà không qua `biKhoa:`) — công tắc khoá đi qua `CongTacTheoQuyen` (mờ 50 % + ổ khoá trong núm; màu đặt cứng thắng màu khoá mặc định của Material 3, G111); có ca tiền đề | cây `lib/` | **2026-10-28** |
| — | `features/wallet/vi_trung_ten_resolver_wiring_test.dart` | `ViTrungTenResolver` dựng một chỗ và được nối | cây | 2026-10-05 |
| — | `features/wallet/vi_trung_ten_cuc_bo_test.dart` | cờ `bi_tu_choi_trung_ten` không lọt vào đồng bộ | mọi tệp `core/sync` (`tepDuongDongBo()`, từ 2026-10-19; trước: danh sách tệp) | 2026-10-05 |
| — | `core/nen/noi_bo_nghe_hai_noi_test.dart` | hai engine (app + nền) mỗi engine nối bộ nghe kết quả đẩy đúng một lần | cây | 2026-10-10 |

(Bảng có 44 hàng sau khi thêm quét 40 và 41 ngày 2026-10-28; 42 hàng sau quét 39 ngày 2026-10-26 — đếm bằng `awk` hàng bắt đầu `| <số>`, `| **<số>**` hoặc `| —` có `_test.dart` (awk `/^\| (\*\*)?[0-9—]/`) = 42; 41 sau quét 38, 38 sau quét 34, 37 sau quét 32 / 33, 35 trước đó. Bộ đọc chỉ thị dùng chung `test/helpers/chi_thi_dart.dart` và test của nó là test helper, không vào bảng.) Ngoài các tệp trên còn chừng chục test đọc **một** tệp `lib/` cụ thể (manifest, router, một hằng) — không vào dãy số.
⚠️ Các test quét của đợt 2026-10-10 có **ca tiền đề** (phép quét phải thấy ít nhất một tệp) để không xanh giả khi chạy sai thư mục; một số test quét cũ chưa có; chạy từ
`src/Client-app`.

**(3) Cổng + bộ chuyển.** Mọi ranh giới với nền tảng hay gói bên ngoài là một interface Dart thuần có một bản thi hành
thật và bản giả trong test: `OsNotifier` (thông báo hệ điều hành), `DocChuAnh` (OCR), `SlmRuntime` / `PhienCongCu` (mô
hình), `RealtimeSocket`, `NguonTaiNen` (tải mô hình), `MoLienKet` (khe hàm bọc `url_launcher`), `KenhTuChuyenTien` /
`KenhBienDong` / `KenhPhienNganHang` / `NguonLyDoThoat` / `LuuTepPlatform` / `LuuAnhQr` (bảy kênh `flowmoney/*` sang Kotlin — `flowmoney/luu_anh` thêm 2026-10-18, G94 —, mỗi
kênh đứng sau một lớp Dart riêng; `tu_chuyen_tien_nen` dùng chung tệp với `KenhTuChuyenTien`). Đợt 2026-10-10 thêm hai cổng **bên trong** app theo cùng khuôn:
`ThongBaoNguon` (giao diện ↔ bảng thông báo; từ 2026-10-15 là `ThongBaoRepository`) và `PhienDieuPhoi` (Bloc ↔ vòng đời phiên).

## 7. Mối quan tâm xuyên suốt

| Mối quan tâm | Cách làm | Ở đâu |
|---|---|---|
| DI | get_it, một tệp đăng ký, `setupDependencies(cheDoNen:)` cho cả app lẫn engine nền; lazy singleton cho dịch vụ, factory cho Bloc | `core/di/injection_container.dart` |
| Điều hướng | GoRouter, `StatefulShellRoute` bốn nhánh (Trang chủ · Phân tích · Giao dịch · Cá nhân), drawer cho phần còn lại; chặn theo gói ở `redirect` | `core/router/app_router.dart`, `shared/widgets/main_shell.dart` |
| Lỗi | Lỗi đồng bộ chia vĩnh viễn / tạm thời (`_permanentCodes` của `GuiLoDongBo`), lỗi người dùng thấy đi toast; lỗi ở phần phụ (nhịp chi, gợi ý) rơi về "không có" chứ không chặn màn | `core/sync/`, `core/ui/thong_bao_nhanh.dart` |
| Thời gian | Đồng hồ tiêm được (`now:` / `clock`) ở mọi hàm thuần; múi giờ ghim ở test và CI (`TZ=Asia/Ho_Chi_Minh`) | `core/nen/mui_gio.dart`, `.github/workflows/client-app.yml` |
| Log | `debugPrint` / `print` có tiền tố (`[SLM]`, `[C4]`, `[RealtimeChannel]`, `[Online]` — chỉ loại sự kiện, mã HTTP, thời gian; không in câu hỏi / câu trả lời); không thư viện logger — nợ | rải rác |
| i18n | Một ngôn ngữ (tiếng Việt), `flutter_localizations` cho widget hệ thống | `core/constants/app_localization.dart` |
| Theme | `AppTheme` + `AppColors`; widget test màn có nút phải dựng bằng `AppTheme.lightTheme` | `shared/theme/` |
| Bảo mật | Token ở `FlutterSecureStorage`; `idaccount` chỉ từ phiên; không mã hoá SQLite — nợ. **AI trên máy không gửi gì**; **trợ lý online** (khi bật và có mạng — người dùng chốt 2026-10-11) gửi câu hỏi + bản tóm tắt tài chính + kết quả tool (số tiền giao dịch, ghi chú đã che PII) tới máy chủ FlowMoney và Google Gemini; báo trước bằng tờ thông tin một lần, mỗi bong bóng ghi nguồn, tắt được ở Cài đặt AI (cờ gắn máy); câu dữ liệu sống và lệnh tạo không đi online | `core/api/`, `features/auth/presentation/bloc/current_account.dart`, `features/ai_chat/` |
| Nền tảng | Android là đích chính (chạy nền, D1, OCR, mô hình); web chạy được với cổng stub; iOS chưa có các tính năng Android-only | `features/notification/data/datasources/os_notifier*.dart`, `core/nen/co_chay_nen.dart` |
| CI | GitHub Actions: `flutter analyze` + đếm cảnh báo ≤ `MUC_NEN` (20), `flutter test` toàn phần trên Ubuntu, test đỏ in thành annotation | `.github/workflows/client-app.yml` |

## 8. Luật vị trí tệp

Bảng này là luật cho mọi tệp; **test quét 25** (`test/core/ui/vi_tri_tep_theo_luat_test.dart`) canh phần máy canh được
(tám luật — sáu của spec dọn vị trí tệp 2026-10-10 mục 4, thêm luật 7 *data / domain không import application/* ở đợt 2026-10-15, luật 5b *năm tệp domain thuần của `core` còn thuần* ở đợt 2026-10-16; luật 5 từ ratchet thành danh sách cố định). Đợt dọn 2026-10-10 (`docs/superpowers/specs/2026-10-10-don-vi-tri-tep-theo-luat-design.md`)
đưa cây về khớp bảng — G88 gạch 7 đóng; miễn trừ `ai_chat/spike/` đã gỡ khi C4 chốt lối (2026-10-12). Máy **có** canh việc mọi tệp dưới
`presentation/` nằm trong một trong bốn thư mục `bloc/` · `pages/` · `widgets/` · `state/` (không tệp rời); còn **thư mục nào**
trong số `bloc/` · `widgets/` · `state/` là đúng, và hàng *"hạ tầng core cần"*, là luật **đọc** — máy không canh. **Test quét 31** (`test/core/ui/trang_khong_import_datasource_csdl_api_test.dart`) canh vế *trang không cầm datasource bọc CSDL / API*.

| Loại tệp | Thư mục |
|---|---|
| Interface repository + bản thi hành | `features/<x>/data/repositories/<x>_repository.dart` + `<x>_repository_impl.dart` |
| Datasource (bọc DAO / API) | `features/<x>/data/datasources/` |
| **Cổng** nền tảng / gói ngoài / hệ tệp — interface Dart thuần + bản thật cho MỘT ranh giới: một kênh `flowmoney/*`, một gói nền tảng (thông báo hệ điều hành, tải nền, mở liên kết, mô hình trên máy, ghi âm / nhận giọng) hoặc thư mục tệp riêng của app (`os_notifier*`, `kenh_bien_dong`, `kho_anh_quet`, `slm_runtime`, `mo_lien_ket`, `luu_anh_qr`…) | `features/<x>/data/datasources/` (người dùng chốt 2026-10-19). Trang **được** gọi thẳng cổng; datasource bọc CSDL (`core/database/`) hoặc mạng / API (Dio, `core/api/`) thì **không** — trang đi qua repository / nguồn (quét 31). **Store** — kho khoá–giá trị / bảng cục bộ mang luật đọc–ghi của mảng (`*_store`, `cong_tac_*`, kể cả bọc `flutter_secure_storage`) — và **nguồn / dịch vụ** gom nhiều cổng hoặc mang luật (`nguon_giong_noi`, `slm_cache`, `mo_hinh_tai_ve`, `bo_nap_mo_hinh`) ở gốc `data/`. Tiền lệ cũ giữ chỗ: `auth/data/datasources/auth_local_data_source.dart` (store token, có từ trước luật) |
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

**Ưu điểm.** Chạy trọn không mạng, kể cả AI. Luật hỏng-im-lặng có một chỗ và có máy canh (44 tệp test quét, CI — đếm bằng bảng 2026-10-28 sau quét 41). Ranh
giới nền tảng thay được bằng bản giả, nên **7.597** ca test (đo 2026-10-20, +10 skip) chạy trên Windows và Ubuntu không cần thiết bị. Tách mảng theo
nghiệp vụ nên một việc thường chạm một thư mục.

**Nhược điểm còn lại.** Entity 7/14 mảng; giao diện không còn cầm kiểu hàng Drift ở mảng nào (G88 gạch 3 xong: Hoá đơn, Ví, Giao dịch 2026-10-14, Danh mục + Thông báo 2026-10-15; gạch 5 và 6 đóng cùng đợt). Gạch 4 đóng 2026-10-16 (`core` → `features` chỉ còn năm tệp domain thuần, quét 25 luật 5 / 5b), G88 đóng. Ba lệch `domain` → `data/repositories` và hai chỗ `ai_edge/domain` → `presentation` (`pickHomeBudget`) từng nằm ở đây đã trả cùng đợt, nay canh bằng quét 28. Vòng `bill/domain/bill_status.dart` ↔ `notification/domain/notification_rules.dart` **đã gỡ 2026-10-16** (`billLeadDays` + `mocNhacMacDinh` về `bill/domain/bill_nhac_truoc.dart`); cạnh `bill/application/bill_payment_conflict_resolver.dart` → `notification_rules.dart` còn, cố ý (bộ điều phối phát thông báo; quét 29 chỉ đọc nguồn `domain/`). Bốn cặp hai chiều của cụm {analytics, bill, category, transaction} **đã gỡ 2026-10-16** (ba lát, spec `2026-10-16-go-vong-mang-domain-design.md`; chiều chuẩn `analytics → bill → transaction → category`), `conCho` của quét 29 rỗng. *(Câu "`SyncEngine` 2.163 dòng một tệp" của lần đo 2026-10-16 đã trả 2026-10-19 — tách thành engine 506 dòng + ba lớp cộng tác + bốn tệp hàm thuần, quét 34 canh ≤ 800 dòng.)*
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

1. **Mở bằng ràng buộc, không bằng tên mẫu.** "App phải ghi được khi không có mạng và AI trên máy không được gửi dữ liệu đi" — rồi
   mới tới "nên SQLite là nguồn sự thật và đồng bộ tự viết". (Trợ lý online từ 2026-10-17 là lựa chọn có báo trước của người
   dùng, rơi về AI trên máy khi mất mạng — mục 7 *Bảo mật*.)
2. **Gọi đúng tên.** Feature-first ba tầng + `application/` (bộ điều phối), offline-first. Không nhận là Clean Architecture; nói vì sao không (mục 1).
3. **Ba chữ ký.** Một định nghĩa duy nhất · test quét mã nguồn · cổng + bộ chuyển — mỗi cái kèm một ví dụ lỗi thật nó
   đã chặn (G41 bảng tra tên chép ba lần; G38 rơi về tài khoản admin; mô hình sập native thì canary bắt).
4. **Con số.** 14 mảng, 662 tệp `lib/` (đếm 2026-10-20, mục 3), 40 tệp test quét (đếm bằng bảng 2026-10-20), 7.597 ca test (đo 2026-10-20, +10 skip), CI xanh trên Ubuntu; trước/sau của đợt 2026-10-10 (mục 9).
5. **Tự nêu nhược điểm trước khi bị hỏi.** Còn mở: Entity mới 7/14 mảng (xong Hoá đơn, Ví, Giao dịch 2026-10-14, Danh mục, Thông báo 2026-10-15); không logger, không mã hoá SQLite; `setState` vẫn là cách giữ trạng thái chủ đạo; và cạnh `bill/application/bill_payment_conflict_resolver.dart` → `notification_rules.dart` giữ cố ý (bộ điều phối phát thông báo, quét 29 chỉ đọc nguồn `domain/`). Đã trả, có ngày: `SyncEngine` một tệp 2.153 dòng (lúc tách; 2.163 là số đo 2026-10-16) tách thành engine + ba lớp cộng tác + bốn tệp hàm thuần 2026-10-19 (quét 34: mọi tệp `core/sync` ≤ 800 dòng, `mienTru` rỗng); G88 đóng 2026-10-16 (gạch 4: `core` → `features` chỉ còn năm tệp domain thuần; bốn trang trên 1.200 dòng tách xong 2026-10-13), vòng `bill_status` ↔ `notification_rules` và bốn cặp hai chiều của cụm {analytics, bill, category, transaction} gỡ 2026-10-16 — quét 29 canh vòng mới, `conCho` rỗng. Nói cả hai nhóm, tức là đã biết, không phải chưa nhìn thấy.
