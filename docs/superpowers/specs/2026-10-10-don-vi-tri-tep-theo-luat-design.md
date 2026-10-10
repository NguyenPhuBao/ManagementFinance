# Dọn vị trí tệp theo luật mục 8 + test quét 25 — thiết kế

**Ngày:** 2026-10-10 · **Trạng thái:** thiết kế duyệt trong chat (bốn câu hỏi, mục 0) — bản viết chờ người dùng đọc ·
**Trả nợ:** G88 gạch 7 (`docs/CLIENT_APP_KNOWN_GAPS.md`) · **Luật:** mục 8 `docs/KIEN_TRUC_CLIENT_APP.md` ·
**Tiền nhiệm:** spec bịt điểm rò `2026-10-10-bit-diem-ro-kien-truc-client-design.md` (đợt ấy cố ý không dời tệp).

Đợt này **không đổi hành vi**: không đổi schema, payload đồng bộ, `pubspec`, màn hình. Chỉ đổi chỗ tệp, dòng import, và
thêm một test quét canh để cây không trôi lại. Mọi số đếm trong tệp này đo bằng lệnh ngày 2026-10-10 trên `HEAD` = `cc040342`.

## 0. Bốn quyết định của người dùng (2026-10-10)

1. **Phạm vi** = danh sách G88 gạch 7 **cộng** ba chỗ cùng luật lộ ra khi rà cả cây để viết test: `core/auth/dem_nguoc_xoa`,
   năm tệp repository nằm thẳng dưới `data/` (analytics 4, premium 1), hai tệp `core/category` không tệp `core` nào dùng.
2. **`core/auth/buoc_dang_xuat.dart` ở lại `core/auth`** — kiểu Dart thuần mà **bốn** tệp hạ tầng dùng (`AuthInterceptor`,
   `RealtimeChannel`, `PhienDieuPhoi`, `PhienDieuPhoiThat`); dời là bốn tệp `core` import `features` và câu *"PhienDieuPhoiThat
   không import features"* phải bỏ. Thành hàng luật mới (mục 7), G88 sửa chữ.
3. **Spike:** xoá `spike_sql` (đo xong 2026-09-27, mục 9.30 `AI_EDGE_FEATURE.md`, người dùng đã chốt không cho mô hình đọc
   SQL); **giữ `spike_c4`** dưới miễn trừ đích danh của quét 25, ghi *"gỡ khi C4 chốt lối"* — C4 là việc ngay sau đợt này và
   phần 20 câu nói chưa đo.
4. **`core/bill/bill_recurrence.dart` dời về `features/bill/domain/`** theo tiền lệ `bill_pay_status`: trong `core` chỉ
   `sync_engine` dùng (một hằng `kBillCycleMonth`), mà `SyncEngine` là bộ dịch payload của mọi mảng nên vốn import 6 tệp
   miền. Hệ quả nói rõ: hạ tầng `core → features` **36 → 37** dòng, điểm ghép **136 → 135** (`current_account` rời `core`),
   tổng 172 không đổi; 63 tệp đổi import; `other_tables.dart` có chú thích trỏ đường cũ nên phải chạy `build_runner`.

## 1. Mục tiêu / không mục tiêu

**Mục tiêu.** Sau đợt: (a) không tệp nào trong `lib/`, `test/` lệch bảng mục 8 — trừ `ai_chat/spike/` được miễn trừ có tên;
(b) test quét **25** canh cây bằng máy, danh sách *còn chờ* rỗng; (c) `flutter analyze` **20 / 0 lỗi**, `flutter test` xanh
toàn phần; (d) `git log --follow` còn lịch sử của tệp dời (dùng `git mv`, mỗi nhóm một commit).

**Không mục tiêu.** 52 tệp rời khác dưới `data/` (`*_nguon`, `*_store`, tool AI, `luu_tep_platform`…) — bảng mục 8 chưa có
hàng cho chúng, **không dời, không canh**. Gạch 1–6 của G88 không đụng, chỉ gạch 4 nhận một **ratchet** (mục 4, luật 5).
Không đổi tên lớp, hàm, khoá widget. Không sửa đơn `DA-XONG/` (ảnh chụp).

## 2. Bảng dời (nguồn → đích, số tệp phải đổi import `lib` + `test`)

| Nhóm | Nguồn | Đích | Import | Ghi chú |
|---|---|---|---|---|
| **A** | `transaction/data/repositories/transaction_repository.dart` (175 dòng, interface + Impl) | tách `TransactionRepositoryImpl` ra `transaction_repository_impl.dart` | 25 (Impl: DI + 3 test) | bốn mảng kia đã tách |
| A | `category/data/repositories/category_management_repository.dart` (532 dòng) | `CategoryValidationException` + interface ở lại; Impl → `category_management_repository_impl.dart` | 31 (Impl: DI + 8 test) | |
| A | `analytics/data/{analytics,bao_cao}_repository(_impl).dart` (4 tệp) | `analytics/data/repositories/` | 28 · 2 · 10 · 3 | `wallet_picker_sources_test` ghi cứng `bao_cao_repository_impl` (mục 6) |
| A | `premium/data/goi_repository.dart` (lớp cụ thể, không interface) | `premium/data/repositories/` | 23 | test `premium/data/goi_repository_test` dời theo |
| **B** | `auth/presentation/an_the_cho_xoa` · `premium/presentation/an_nhac_het_han` · `wallet/presentation/an_nhac_vi_trung_ten` (ba `ValueNotifier`) | `<mảng>/presentation/state/` | 6 · 4 · 6 | hàng *tệp trạng thái* |
| B | `core/auth/current_account.dart` (đọc `AuthState`, import `AuthBloc`) | `auth/presentation/bloc/current_account.dart` | 30 | hàng mới *hàm đọc Bloc* (mục 7); điểm ghép −1 |
| B | `premium/presentation/co_quyen.dart` (extension `BuildContext` đọc `GoiCubit`) · `phien_goi_tu_auth.dart` (`AuthState → PhienGoi`) | `premium/presentation/bloc/` | 10 · 3 | hàng mới *hàm đọc Bloc* |
| B | `auth/presentation/xac_nhan_dang_xuat.dart` (`showDialog`) · `huy_yeu_cau_xoa.dart` (gọi repo + gửi event + toast) | `auth/presentation/widgets/` | 2 · 2 | hàng mới *hộp thoại / hành động dùng chung* |
| B | `premium/presentation/cubit/goi_cubit.dart` | `premium/presentation/bloc/goi_cubit.dart` | 18 | bảy mảng kia đều `bloc/` |
| **C** | `core/auth/dem_nguoc_xoa.dart` (hàm thuần, 0 tệp `core` dùng) | `auth/domain/dem_nguoc_xoa.dart` (thư mục **mới**) | 4 | |
| C | `core/category/category_classify.dart` · `category_visuals.dart` (0 tệp `core` dùng) | `category/domain/` | 15 · 16 | `category_name.dart` **ở lại** — DAO + 3 util dùng |
| C | `core/bill/bill_recurrence.dart` | `bill/domain/bill_recurrence.dart` | 16 `lib` + 47 `test` | quyết định 4; `core/bill/` biến mất |
| **D** | `core/constants/app_router.dart` | `core/router/app_router.dart` | 3 `lib` + 7 `test` | hai test đọc `File('lib/core/constants/app_router.dart')` (mục 6) |
| **E** | `test/e2e_sqlite_to_backend_sync_test.dart` | `test/core/sync/` | — | |
| E | `test/transaction_repository_test.dart` (import Impl) | `test/features/transaction/data/repositories/` | — | **sau** nhóm A |
| E | `test/features/layout/no_overflow_test.dart` | `test/shared/no_overflow_test.dart` | — | không có `lib/features/layout` |
| E | 8 test đi theo tệp dời — `test/core/auth/current_account_test` → `test/features/auth/` (phẳng, như 13 test sẵn có) · `test/core/auth/dem_nguoc_xoa_test` → `test/features/auth/domain/` · `test/core/bill/bill_recurrence_test` → `test/features/bill/domain/` · `test/core/category/{category_classify,category_visuals}_test` → `test/features/category/domain/` · `test/core/constants/{router_chan_theo_goi,xuat_bao_cao_co_cua_quyen}_test` → `test/core/router/` · `test/features/premium/data/goi_repository_test` → `test/features/premium/data/repositories/` | soi gương **thư mục** chỗ mới | — | `test/core/auth/khong_du_phong_admin_test` + `phien_dieu_phoi_that_test` + `buoc_dang_xuat_test` ở lại; `test/core/category/category_name_test` ở lại |

Tổng: **21** tệp `lib` (19 dời + 2 tách: A 5 + 2 · B 9 · C 4 · D 1), **11** tệp test dời, ≈ **250** dòng import đổi
(đếm lại bằng script lúc làm — đừng cộng dồn).

## 3. Xoá

- `lib/features/ai_chat/spike/spike_sql.dart` + `test/features/ai_chat/spike_sql_test.dart` (6 ca). Trong `ai_chat_page.dart`:
  bỏ import, khối `if (kSpikeSql && …)`, hàm `_spikeSql`. Các import còn lại của trang (`currentAccountIdOrNull`,
  `MoHinhTaiVe`, `SlmRuntime`, `sl`, `kChuaSanSangPhien`) đều có chỗ dùng khác — không thành `unused_import`.
- `test/widget_test.dart` — placeholder của `flutter create` (`expect(1, 1)`), 1 ca.

Số test đổi: **−7** cộng số ca của quét 25; **đo lại**, không cộng dồn.

## 4. Test quét 25 — `test/core/ui/vi_tri_tep_theo_luat_test.dart`

Khuôn quét 22/23: mỗi vi phạm còn chờ nằm trong danh sách `conCho` kèm số, **chỉ được giảm**; sạch rồi quên rút → đỏ.
Viết **trước** nhóm A: chạy với `conCho` rỗng phải đỏ **đúng** danh sách mục 2 và không đỏ chỗ khác (chép danh sách đỏ ra
so với bảng); rồi điền `conCho` cho xanh, commit; mỗi nhóm dời rút bớt; cuối đợt `conCho` rỗng.

Sáu luật máy canh được:

1. `lib/` chỉ gồm `main.dart` + `core/` · `features/` · `shared/`. `features/<x>/` chỉ gồm `data` · `domain` · `presentation`,
   không tệp rời. **Miễn trừ đích danh** `features/ai_chat/spike/` kèm ghi chú *"mã đo C4 — gỡ khi C4 chốt lối"*; thư mục
   miễn trừ không còn tồn tại → đỏ để rút (khuôn quét 23).
2. `features/<x>/presentation/` chỉ gồm `bloc` · `pages` · `widgets` · `state`; **không tệp rời** ngay dưới `presentation/`.
3. Tệp tên `*_repository.dart` / `*_repository_impl.dart` phải ở `data/repositories/`. Tệp `*_repository.dart` không được
   chứa `class \w+Impl` (interface + bản thi hành gộp).
4. `core/` chỉ gồm 16 chủ đề: `api` · `auth` · `category` · `constants` · `database` · `di` · `errors` · `nen` · `network`
   · `notification` · `ocr` · `realtime` · `router` · `sync` · `ui` · `utils`. Thêm chủ đề là phải ghi vào danh sách.
5. **Ratchet `core → features`** (gạch 4 G88): dòng `import` trỏ `features/` trong `lib/core` chỉ được ở điểm ghép
   `core/di/injection_container.dart` · `core/router/app_router.dart` · `core/nen/chay_nen.dart` (không trần), hoặc ở tệp
   trong `conCho` kèm số dòng chỉ được giảm — sau đợt: `notification_rules` 10 · `sync_engine` 7 · `notification_scanner` 5
   · `lich_nen` 3 · `sync_payload_normalizer` 2 · `noi_bo_nghe_ket_qua_day` 2 · `reminder_scheduler` 2 · `nhap_bien_lai` 2
   · `kho_anh_quet` 1 · `nhap_bien_dong` 1 · `wallet_dao` 1 · `other_daos` 1 = **37**.
6. `test/`: không `*_test.dart` ở gốc; thư mục cấp 1 ∈ `core` · `features` · `shared` · `helpers` · `tool`; mọi thư mục
   `test/core/<y>…` và `test/features/<x>…` phải tồn tại ở `lib/` — soi gương **theo thư mục**, không theo tệp (hàng trăm
   test nằm phẳng ở gốc mảng là cố ý).

Kèm **ca tiền đề** (phép quét thấy ≥ 14 mảng, ≥ 1 tệp dưới mỗi `presentation/`) để không xanh giả khi chạy sai thư mục, và
**một bản sai** lúc viết (thả một tệp rời về `presentation/`, thêm một dòng import `features/` vào `core/utils`) phải làm
test đỏ — ca xanh ngay từ đầu là ca chưa chứng minh.

**Không canh được, chỉ là luật đọc:** hàng *"hạ tầng `core` cần → `core/<chủ đề>`"* (`buoc_dang_xuat`, `category_name`);
chỗ xếp giữa `bloc/` · `widgets/` · `state/` của một tệp mới (luật 2 chỉ cấm tệp rời).

## 5. Cơ chế dời

- `lib` dùng **100 % import tương đối** (364 tệp), `test` dùng `package:flowmoney/`. Dời một tệp đổi cả đường của mọi
  tệp import nó **và** mọi import tương đối bên trong chính nó → **script Python** ở scratchpad: đọc bản đồ `cũ → mới`,
  với từng tệp `.dart` trong `lib`/`test` phân giải `import`/`export`/`part` tương đối → tuyệt đối → áp bản đồ → ghi lại
  tương đối (`lib`) hoặc `package:` (`test`). Không `sed` tay. Script là mã đo, không vào repo.
- `git mv` cho mọi tệp dời (tách Impl: `git mv` không dùng được — tạo tệp mới, giữ nguyên văn thân lớp).
- **Thứ tự, mỗi nhóm một commit**, sau mỗi nhóm `flutter analyze` về **20 / 0 lỗi** và chạy test của mảng chạm + quét 25:
  0 quét 25 (xanh với `conCho` đầy) → A → B → C (tách C2 = `bill_recurrence` vì cần `build_runner`) → D → E + xoá → tài liệu
  tổng (mục 8). Nhóm E sau A vì `transaction_repository_test` import Impl.
- Sau C2: sửa chú thích `other_tables.dart:217` rồi `dart run build_runner build --delete-conflicting-outputs` để
  `app_database.g.dart:5391` khớp (diff chỉ chú thích — kiểm bằng `git diff --stat`).

## 6. Đường dẫn ghi cứng ngoài tầm `flutter analyze` (sửa trong **cùng commit** với nhóm dời)

| Tệp | Dòng | Nhóm |
|---|---|---|
| `test/features/wallet/wallet_picker_sources_test.dart` | 44, 171: `features/analytics/data/bao_cao_repository_impl.dart` — test **đỏ to** khi đường dẫn chết (dòng 142) | A |
| `test/core/constants/xuat_bao_cao_co_cua_quyen_test.dart` | 15: `File('lib/core/constants/app_router.dart')` (+ chính nó dời sang `test/core/router/`) | D |
| `test/shared/widgets/main_shell_tab_so_giao_dich_test.dart` | 49, 64: `doc('lib/core/constants/app_router.dart')` | D |
| `test/features/home/drawer_trang_chu_test.dart` | 17: import `package:flowmoney/core/constants/app_router.dart` | D |
| `test/core/auth/khong_du_phong_admin_test.dart` | 55: câu `reason` nêu `core/auth/current_account.dart` | B |
| `lib/core/database/tables/other_tables.dart` + `app_database.g.dart` | 217 / 5391: chú thích `core/bill/bill_recurrence.dart` | C2 |
| Hai scan mlkit / image_picker | miễn trừ `spike_c4_page.dart` — **không đổi** | — |

Sau nhóm B chạy riêng quét 21 (`quyen_tinh_nang_mot_noi_test`) và quét 24 (`auth_bloc_khong_sl_test`); sau nhóm D chạy
`sync_engine_start_owner_test` (quét 4) và hai test đọc router.

## 7. Ba hàng luật mới cho bảng mục 8 `KIEN_TRUC_CLIENT_APP.md`

| Loại tệp | Thư mục |
|---|---|
| Hàm đọc / dịch trạng thái Bloc–Cubit (accessor, extension `BuildContext` đọc cubit) | `features/<x>/presentation/bloc/` — cạnh Bloc nó đọc |
| Hộp thoại, hành động giao diện dùng chung trong mảng (hàm nhận `BuildContext`: `showDialog`, gọi repository rồi gửi event, báo toast) | `features/<x>/presentation/widgets/` |
| Kiểu / hàm Dart thuần mà **hạ tầng `core` cần để chạy** (interceptor, socket, DAO, util) — `buoc_dang_xuat`, `category_name` | `core/<chủ đề>/`; thứ chỉ `SyncEngine` cần đi theo tiền lệ `bill_pay_status`: `features/<x>/domain/` |

Và sửa câu mở đầu mục 8 (*"tệp cũ lệch luật… để dành đợt dọn riêng"*) thành quá khứ, trỏ quét 25.

## 8. Tài liệu phải sửa (liệt kê theo khái niệm, mở từng tệp)

- `docs/KIEN_TRUC_CLIENT_APP.md`: mục 3 cây (`core/auth` 5 → 3, `core/bill` mất, `core/category` 3 → 1, `core/constants`
  3 → 2, `core/router` 1, `features/auth` thêm `domain/` 1 + `state/`, `premium` `cubit` → `bloc`, `ai_chat` `spike/` 3 → 2),
  mục 4 (điểm ghép 135 · hạ tầng 37, bỏ `current_account` khỏi điểm ghép), mục 8 (ba hàng mới), mục 9 (số test quét 28 → 29).
- `docs/CLIENT_APP_KNOWN_GAPS.md`: G88 gạch 7 ✅ (chữ *"7 tệp trạng thái"* → ba trạng thái + bốn hàm), gạch 4 có ratchet;
  dòng cập nhật đầu tệp; bảng tóm tắt.
- `CLAUDE.md`: hàng *Đụng vào presentation* (quét 25 là gì, *"test quét mới lấy số 26"*, 29 tệp quét), mốc test/analyze,
  `test/transaction_repository_test` → đường mới, `spike_sql` ở hàng AI, `ai_chat` 77/1309 đo lại.
- `docs/PROJECT_CONTEXT.md`: khối mới mục 14; mục 9 cấu trúc nếu nêu đường cũ.
- `docs/PREMIUM_FEATURE.md` (co_quyen, phien_goi_tu_auth, an_nhac_het_han, goi_cubit, goi_repository), `docs/bill/BILL_DOCUMENTATION.md`
  (`core/bill/`, `core/constants/app_router`), `docs/AI_EDGE_FEATURE.md` 9.30 (mã gỡ, giữ bảng đo + mã commit).
- Hai spec cũ nhắc đường cũ (`2026-09-10-cuong-che…` → `dem_nguoc_xoa`; `2026-09-14-thong-ke-phan-loai…` → `category_classify`):
  thêm **một dòng** con trỏ *"đường dẫn đã dời 2026-10-10"*; đơn `DA-XONG/` không sửa.
- Chú thích trong mã nhắc đường cũ (`grep -rn "core/auth/current_account\|core/bill/\|core/constants/app_router\|presentation/cubit" lib test`).

## 9. Tiêu chí nghiệm thu

1. Quét 25 xanh với `conCho` **rỗng** (trừ miễn trừ `spike/`), và từng bị đỏ đúng danh sách khi `conCho` rỗng ở bước 0.
2. `flutter analyze`: **20** issue, **0** error (hằng `MUC_NEN` CI không đổi). `flutter test` toàn phần xanh; số ca ghi lại.
3. `git log --follow -- <tệp mới>` của ít nhất một tệp mỗi nhóm hiện lịch sử trước khi dời.
4. `grep -rn` các đường cũ (mục 8, gạch cuối) ra **0** dòng trong `lib`, `test`, tài liệu sống.
5. Không nghiệm thu máy thật riêng — không đổi hành vi; lượt nghiệm thu OnePlus kế tiếp (việc 2 của thứ tự đã chốt) sẽ chạy
   bản sau đợt này.

## 10. Rủi ro còn lại

- Script tính lại import sai một trường hợp hiếm (`export … show`, `part of`) → `flutter analyze` báo **lỗi** ngay, không im lặng.
- Một test quét nào đó liệt kê đường dẫn bằng cách tôi chưa quét được (`grep` theo tên tệp trên 42 test đọc cây `lib` đã ra
  đủ bảng mục 6) → lộ ở lần `flutter test` toàn phần của nhóm ấy.
- `build_runner` sinh lại `.g.dart` khác ngoài chú thích (phiên bản Drift khác) → `git diff --stat` phải chỉ thấy đổi chú thích; khác thì dừng hỏi.
