# Thống nhất Entity cho mảng Danh mục (+ hai nợ Mục tiêu, cụm phản hồi tái phân bổ) — G88 gạch 3, đợt 3/4

**Ngày:** 2026-10-15 · **Nhánh:** `TranQuangDat` · **HEAD lúc viết:** `6971dfab` · **Trạng thái:** người dùng duyệt ba chốt và
bốn phần (A–D) trong chat, rồi **duyệt bản viết** (`ec3e6e0a`, cùng ngày — kể cả lượt soát lật chốt 3: không ghi dữ liệu thử, nhận lỗ C1).
Kế hoạch: `docs/superpowers/plans/2026-10-15-entity-danh-muc.md` (gitignore).

Đợt **thứ ba** của G88 gạch 3 (`docs/CLIENT_APP_KNOWN_GAPS.md`; lộ trình người dùng chốt 2026-10-11: Hoá đơn → Giao dịch + Ví →
**Danh mục** → Thông báo). Tiền lệ trực tiếp: `specs/2026-10-14-entity-hoa-don-design.md` (đợt 1/4) và
`specs/2026-10-14-entity-giao-dich-vi-design.md` (đợt 2/4), cả hai thi công xong 2026-10-14. Người dùng app **không thấy gì đổi**
trên bất kỳ màn nào; cái đổi là từ repository trở lên, Danh mục chỉ còn **một** kiểu dữ liệu (`CategoryEntity`, **mới** — Danh mục là
mảng đầu tiên trong lộ trình chưa có Entity sẵn), bốn lối chuyển tiếp trả hàng Drift biến mất, danh sách chờ của luật 2 quét 27 về
rỗng, và quét 27 học thêm hai điều từ bài học bàn giao đợt 2 (quét domain theo tên kiểu; `dynamic` ở chữ ký là lỗ).

> ✅ **Số đo sau thi công (2026-10-15, HEAD `811e1ea8`; đếm bằng máy, đừng cộng dồn).** Thi công xong bằng agent con mỗi task, mọi task qua soát
> (không lỗi Quan trọng): Task 1 `f443a647` (quét 27: luật 1 quét `domain/` theo tên kiểu + ba sàn đếm, luật 3 cấm `<dynamic>` trần) · Task 2 `34f54ec9`
> (`CategoryEntity`, 83 dòng) · Task 3 `2e04954d` (đổi kiểu trục Danh mục, **một commit** 87 tệp: 41 `lib` + 46 `test`) · Task 4 `3cfaed55`
> (`PhanHoiTaiPhanBo`, `ghiPhanHoi`) · Task 5 `406c20c6` (`watchGoalTransactions`, bỏ 9 phép ép + 2 `?? ''`) · Task 6 `811e1ea8` (runner dời
> `goal/data/services/`). Lối chuyển tiếp trả hàng Drift: **4 → 0**. `conChoDomain` **rỗng**; `conChoDynamic` **rỗng**; `conChoKieu` chỉ còn
> `AppNotification` (9 tệp). Entity **6/14** mảng. Ratchet quét 25 **43 giữ**, TOTAL import `features/` trong `core` **185**. `flutter test` 7.065 → **7.069**
> pass / **10** skip (entity +2 · quét 27 +1 [luật 3] · test rows 2 → 3 [+1] · Companion 0 ca mới — ca cũ thay bằng ca đếm 11 cột), `flutter analyze` **20**.
> Quét 27: `test/core/ui/presentation_domain_khong_kieu_drift_test.dart` 242 dòng. Kiểm grep: `watchAllRows|getRowById` trong `lib` = 0; `core/database|package:drift`
> trong `features/*/domain` = 0; `<dynamic>` trong `features/*/data` = 0 chỗ mã (1 dòng là docstring lịch sử `goal_repository.dart:215`); `AiRebalancingFeedbacksCompanion`
> trong `lib/features`: chỗ dựng duy nhất `budget/data/tai_phan_bo_nguon.dart`, tên còn trong một docstring `ai_edge/domain/ap_dung_ke_hoach.dart`; grep thô `Category`
> trên `lib/core` ra đúng 1 dòng là chú thích DI `injection_container.dart:343` (không phải vi phạm — thước đo thẩm quyền là quét 27, có `boChuThich`, xanh).
> `them_giao_dich_nguon.dart` thôi import `app_database` (vẫn import hằng `kKindBienDongSoDu` từ `notification_dao.dart` — không phải kiểu Drift). Test rows
> `category_repository_rows_test.dart` được **thay bằng** `category_repository_doc_danh_muc_test.dart` (git ghi xoá + tệp mới).
>
> ✅ **Nghiệm thu máy ảo (2026-10-15, `FlowMoney_16G`, 1080×2400, `-gpu host`, demo mode 12:00).** APK trước `94394e4c88b237b2010a04b7c4a82a51cc73c7d9`
> (`lastUpdateTime` 2026-10-14 21:29:25) ↔ sau `d3b7b9083a981c80110e8228eba5f200d4354562` (`lastUpdateTime` 2026-10-15 12:09:02, đổi). **29 cặp ảnh**, cắt 100 px thanh
> trạng thái: **27/29 cặp cùng SHA-1 (0 px)**; hai cặp lệch — `17_hoa_don_them_cuon` 165.749 px và `18_hoa_don_dropdown` 80.738 px — do cuộn giữ-rồi-thả dừng lệch **1 px** theo chiều
> dọc, nội dung giống hệt (dropdown 10 mục: Di chuyển · Giáo dục · Giải trí · Hóa đơn · Mua sắm · Nhà cửa · Y tế · test · test1 · Ăn uống, chọn sẵn Di chuyển). Vàng thuần
> `#FFFF00` **0**. Kiểm chức năng bổ sung bản sau, không ghi dữ liệu: chip lọc danh mục ở Sổ giao dịch (*Giải trí* → 3 giao dịch, chip *Xoá lọc*) ✅; thẻ *Gợi ý danh mục*
> ở Thêm giao dịch (78.000 đ + ghi chú `food` → *Ăn uống*, nút *Chọn danh mục này*) ✅; `pop<CategoryEntity>` của form Chọn danh mục ✅; logcat 0 dòng `FATAL` / `is not a subtype`.
> ⚠️ **Lỗ:** (1) *Đề xuất cân đối ngân sách* (5g) không hiện — dữ liệu không đủ điều kiện, cấm ghi để tạo; (2) C1 / thẻ *"Có N giao dịch chưa có danh mục"* và màn Gắn danh mục
> — `demChuaGan` = 0; chốt *ghi khoản thử* đã lật (`chuanBiLuu` :631 chặn lưu thiếu danh mục), nhận lỗ như đợt 2, phủ bằng `gan_danh_muc_page_test` (11 ca),
> `gan_danh_muc_nguon_test` (5), `gan_danh_muc_nguon_lop_test` (2). Ảnh ở scratchpad, không vào repo.

Đợt này **gộp thêm hai cụm ngoài mảng Danh mục** (người dùng chốt 2026-10-15, cả hai là nợ có tên ở G88 gạch 3): cụm phản hồi tái
phân bổ (`TaiPhanBoNguon.ghiPhanHoi` — lối chuyển tiếp thứ tư, mảng Ngân sách / ai_edge) và hai nợ Mục tiêu (`watchGoalTransactions`
`Stream<dynamic>`, `goal_auto_deposit_runner` cầm Drift ở domain). Sau đợt: lối chuyển tiếp **0**, `conChoDomain` **rỗng**, chỉ còn
đợt Thông báo (`AppNotification`, 9 tệp) trong gạch 3.

## 1. Quyết định đã chốt (trong chat, 2026-10-15)

| # | Câu hỏi | Chốt | Lý do ngắn |
|---|---|---|---|
| 1 | Gộp cụm phản hồi tái phân bổ (bảng *Đề xuất cân đối*, trang Ngân sách) vào đợt Danh mục? | **Gộp** — một task cuối đợt | Đây là lối chuyển tiếp thứ tư và tệp domain `ap_dung_ke_hoach` còn import `drift`; làm cùng thì lối chuyển tiếp về 0 chứ không 1. Không phải Danh mục — ghi rõ ở tên spec |
| 2 | Hai nợ Mục tiêu (`watchGoalTransactions` · `goal_auto_deposit_runner`) xếp đâu? | **Gộp cả hai** — hai task cuối đợt | Sau đợt `conChoDomain` rỗng, luật 2 không còn danh sách chờ; runner chỉ dời tệp, không sửa thân |
| 3 | Ghi dữ liệu thử trên máy nghiệm thu để chụp màn Gắn danh mục (C1)? | Chốt đầu *"ghi một khoản thử qua giao diện"* **bị lật khi soát**: `ThemGiaoDichCubit.chuanBiLuu` :631 từ chối lưu thu / chi thiếu danh mục, form Sửa đi cùng cubit — app không có lối tay nào sinh khoản không danh mục. **Chốt lại: nhận lỗ như đợt 2** — C1 do widget test phủ, không ghi dữ liệu | Hai lối còn lại (INSERT thẳng SQLite máy ảo — hàng sẽ đẩy lên backend dev; hoãn tới máy thật) người dùng không chọn; ghi lỗ vào biên bản nghiệm thu |
| A1 | `loadBangTraTen` đổi tên theo chốt *gộp tên* đợt 2? | **Giữ tên**; chỉ `watchAllRows → watchAll`, `getRowById → getById` | Tên mang nghĩa G41 (bảng tra gồm hàng xoá mềm + mặc định) — khác `getAll` của ví / giao dịch |
| A2 | `CategoryEntity` chép đủ 18 cột hay chỉ cột có chỗ đọc? | **13 trường** = 18 − 5 (mục 4.1) | Cùng khuôn `WalletEntity` / `BillEntity`: bỏ cột lỗi đồng bộ; mở rộng khi có chỗ đọc thật (tiền lệ 4.0 đợt 2) |
| B1 | Kiểu trả của `phanHoiTu` (ai_edge/domain) | **Lớp Dart thuần `PhanHoiTaiPhanBo` 11 trường** cùng tệp; nguồn dựng Companion | Record 11 trường quá dài để đọc; đợt 2 dùng record vì chỉ 3 trường |
| B2 | Runner Mục tiêu | **Dời nguyên văn** `goal/domain/` → `goal/data/services/` (tiền lệ `BillAutoPayRunner`) | Tệp cầm DAO + Companion là đúng vai ở `data/services` (bảng mục 8 `KIEN_TRUC`) |
| C1 | Luật 3 mới của quét 27 (cấm `<dynamic>` trần ở `features/*/data`) | **Thêm vào quét 27**, không mở số 28 | Cùng câu hỏi *"giao diện / domain có cầm hàng Drift không"*; `dynamic` là cách hàng Drift đi qua mà luật 1 mù |
| D1 | Bước đổi kiểu trục Danh mục | **Một commit** (~45 tệp `lib` + ~45 tệp test, đếm ở kế hoạch) | Năm hàm giữ tên đổi kiểu trả tại chỗ — Dart không cho hai hàm cùng tên khác kiểu trả; chèn map tạm ở ~30 chỗ gọi rồi gỡ là bắt người soát đọc hai lần |
| D2 | Lối thi công (inline · agent con) | **Hỏi sau khi có kế hoạch** | Bộ nhớ *thực thi kế hoạch* |

Tiền lệ giữ nguyên từ hai đợt trước, không hỏi lại: domain + giao diện + **mọi** tệp ngoài mảng cùng đổi; repository là cửa duy nhất;
đổi kiểu không đổi thân (ngoại lệ có tên ở mục 3); dời nguyên văn; `dart format` chỉ tệp mới; mỗi bước TDD, mỗi bước một commit,
toàn bộ test xanh ở mỗi commit; mọi số đếm bằng máy, ghi kèm ngày.

## 2. Hiện trạng đo được (2026-10-15, HEAD `6971dfab`)

Mọi số đếm bằng `grep` / `find` / công cụ Grep, chạy từ `src/Client-app`. Mẫu *"nhắc kiểu"* là `mauKieu` của quét 27.

| Thứ | Số | Ghi chú |
|---|---|---|
| Tệp `presentation/` + `shared/` nhắc `Category` Drift | **20** | = `conChoKieu['Category']` hiện tại: Danh mục 5 · Giao dịch 8 · Hoá đơn 4 · Ngân sách 2 · Trang chủ 1 (phụ lục A) |
| Tệp `domain/` nhắc `Category` Drift | **6** | `category/domain/`: `ban_sao_mac_dinh` · `gan_hang_loat`; `transaction/domain/`: `dien_san_bien_dong` · `doc_cau_giao_dich` · `transaction_lookup`; `ai_edge/domain/`: `hang_danh_muc` |
| Tệp `domain/` nhắc kiểu Drift **khác** `Category` | **1** | `goal/domain/goal_auto_deposit_runner.dart` (`Goal`, `GoalsCompanion`) — dời đi (mục 8) |
| `conChoDomain` (tệp `domain/` import `core/database` / `package:drift`) | **8 → 0** | 6 trên + `ai_edge/domain/ap_dung_ke_hoach` + `goal/domain/goal_auto_deposit_runner` |
| Lối chuyển tiếp trả hàng Drift (`KIEN_TRUC` mục 4) | **4 → 0** | `CategoryManagementRepository.loadBangTraTen` · `watchAllRows` · `getRowById` + `TaiPhanBoNguon.ghiPhanHoi` |
| Chỗ gọi ba lối của Danh mục ở giao diện | **5** | `bill_detail_page` :90 · `bill_page` :92 → `loadBangTraTen` (giữ); `bill_actions` :29 → `getRowById`; `home_page` :161 · `transaction_page` :139 → `watchAllRows` |
| Lối tay sinh khoản thu / chi **không** danh mục | **0** | `them_giao_dich_cubit.dart` :631 `if (!s.laChuyen && danhMuc == null) return const LoiLuu('Vui lòng chọn danh mục')` — Thêm và Sửa cùng cubit; màn C1 chỉ có hàng khi dữ liệu cũ / kéo về (G18). Lật chốt 3 |
| Bảng `Categories` | **18** cột (`grep -cE "Column\s+get"` trên khối bảng) | Entity **13** trường = 18 − 5: `isLocalOnly` · `deletedAt` · `syncRetryCount` · `syncError` · `syncBlockedUntil` — không tệp nào ngoài `core/database`, `core/sync`, impl đọc chúng |
| Trường giao diện / domain đang đọc trên `Category` | **11** | `id · idaccount · name · classify · icon · colour · isDefault · isDeleted · parentId · isGroup · aiCoDinh` — đo bằng `grep -nE "\.(isLocalOnly\|syncRetryCount\|…)"` từng tệp rồi lọc theo biến kiểu `Category` (lượt đo thô lẫn `t.` / `w.` / `budget.`) |
| Interface / nguồn phải đổi chữ ký | **7** | mục 4.2 (`CategoryManagementRepository`), 4.3 (`CategorySuggestionEngine` qua model), 4.4 (`BudgetRepository.getExpenseCategories` · `BudgetLocalDataSource.getExpenseCategories` / `getAllCategories` · `ThemGiaoDichNguon` 2 hàm · `GanDanhMucNguon` · `DeXuatHoaDonNguon.bangDanhMuc`) |
| `lib/core` (trừ `database`, `sync`) nhắc `Category` Drift | **0** | → `core` không import `category_entity.dart`; ratchet quét 25 **43 không đổi** (dự kiến, đo lại khi xong) |
| Tệp `lib/features/*/data/**` khai `(Stream\|Future\|List\|Iterable)<dynamic>` | **2** | `goal_repository.dart:214` · `goal_repository_impl.dart:665` — cả hai là `watchGoalTransactions`; `core/sync` 8 dòng và `core/router` 1 dòng **ngoài phạm vi** luật 3 (đọc payload JSON, `GoRouterRefreshStream`) |
| Tệp `.dart`: `presentation/` + `shared/` · `core` trừ `database` / `sync` · `features/*/domain/` | **206 · 77 · 164** | sàn ba bộ đếm tiền đề của quét 27 (mục 9) |
| Fake `implements` trong `test/` | `CategoryManagementRepository` **5** · `TaiPhanBoNguon` **4** · `DeXuatHoaDonNguon` **2** · `BudgetLocalDataSource` **1** · `ThemGiaoDichNguon` **1** (+ helper `them_giao_dich_nguon_gia`) · `GoalRepository` **12** (chỉ **2** khai `watchGoalTransactions`, 10 còn lại `noSuchMethod`) · `BudgetRepository` 15 (**6** tệp nhắc `getExpenseCategories`) | phụ lục B |
| Tệp test dựng `Category(` bằng tay | **11** | 10 đi qua `makeCategory` của `test/features/category/presentation/category_test_fakes.dart` (phụ lục C); **34** tệp test cầm `List<Category>` / `Map<String, Category>` / `Category?` |
| Tệp test nhắc `AiRebalancingFeedbacksCompanion` / `phanHoiTu` / `GhiPhanHoi` | **7** | `schema_v24_test` (kiểm bảng — **giữ** Companion) + 6 đổi (phụ lục B) |
| `goal_auto_deposit_runner` được import | **3** `lib` + **4** test | DI · `notification_rules` · `notification_scanner`; `notification_deeplink_test` · `notification_rules_goal_wallet_test` · `notification_scanner_khoa_test` · `goal_auto_deposit_runner_test` (+ mục `conChoDomain`) |
| `conChoKieu['AppNotification']` | **9** tệp | không đụng — đợt Thông báo |
| `flutter test` · `flutter analyze` | **7.065** (10 skip, 0 fail) · **20** | đo 2026-10-14 sau đợt 2 (bàn giao) |

Tiền lệ: `CategoryChildDraft` / `CategoryGroupDraft` (`category_tree.dart`) đã là Dart thuần; `GanDanhMucNguon`, `ThemGiaoDichNguon`,
`DeXuatHoaDonNguon` đã là cổng tiêm được; đợt này không dựng cửa mới, chỉ đổi kiểu đi qua cửa có sẵn.

## 3. Quy tắc đổi mã

1. **Đổi kiểu, không đổi thân.** `CategoryEntity` mang đúng tên 11 trường mọi tệp sắp đổi đang đọc (đo mục 2), nên thân hàm,
   widget, luật giữ từng dòng; chỉ chữ ký, import, generic, fixture và **tên hai hàm** (`watchAll`, `getById`) đổi. **Ngoại lệ có
   tên (mục 8.1):** tám phép ép kiểu `as String?` / `as DateTime` / `as double` / `as String` ở `goal_detail_page._doiSangKhoan` và
   `khoi_lich_su_muc_tieu._DanhSachLichSu` (4 + 4, đếm bằng máy 2026-10-15) cộng `snapshot.data as List<dynamic>?` ở
   `goal_detail_page` :603 phải **bỏ** — để lại là lint `unnecessary_cast`, `flutter analyze` vượt mức nền 20.
2. **Ánh xạ Drift chỉ ở tầng data, mỗi kiểu MỘT định nghĩa:** `CategoryEntity.fromDrift` (mới); `PhanHoiTaiPhanBo → AiRebalancingFeedbacksCompanion`
   ở `TaiPhanBoNguonImpl.ghiPhanHoi` (mới); `TransactionEntity.fromDrift` (có sẵn) cho `watchGoalTransactions`.
3. **Không có "thêm trước, rút sau"** (khác đợt 2 — chốt D1): năm hàm giữ tên của `CategoryManagementRepository` đổi kiểu trả tại chỗ,
   hai hàm đổi tên có 3 chỗ gọi; mọi chỗ gọi đi cùng **một** commit (bước 3 mục 11). Người soát đọc bằng `git diff --word-diff=plain -U0`
   và luật *"chỉ chữ ký, import, generic, tên hai hàm; không dòng thân nào đổi"*.
4. **Map tại chỗ** ở `data/` đọc DAO thẳng (tiền lệ `dem_dang_hoat_dong` đợt 1): `default_category_seeder` và `dem_dang_hoat_dong`
   gọi `laBanSaoMacDinh` thì `.map(CategoryEntity.fromDrift)` **một lần ngoài vòng lặp**, không mở repository, không đổi constructor.
   Tệp `data/` chỉ đọc hàng cho chính mình (`analytics_repository_impl` · `bao_cao_repository_impl` · `tai_phan_bo_nguon.nap` ·
   `personal_default_categories`) **không đổi** — luật 1 không quét `data/`.
5. `dart format` **chỉ** trên tệp mới (`category_entity.dart`, `category_entity_test.dart`, test đổi tên); quét 27 là tệp cũ — không format.
6. Mỗi bước TDD, mỗi bước một commit, toàn bộ test xanh ở mỗi commit.
7. Không đụng `core/sync/*`, `core/database/*` (trừ chú thích), `category_dao.dart`, `sync_payload_normalizer`, `categoryForPush`,
   `DefaultCategorySeeder` ngoài chỗ gọi `laBanSaoMacDinh` (quy tắc 8 `CLAUDE.md` — luật bản sao đếm cả xoá mềm **giữ nguyên**),
   `_hasDuplicateName` / `getNamesInUse` (quy tắc 7), `getBangTraTen` (G41).

## 4. `CategoryEntity`, repository, nguồn

### 4.1 Tệp mới `features/category/data/models/category_entity.dart`

Khuôn `WalletEntity`: `class CategoryEntity extends Equatable` — **bắt buộc có đẳng thức theo giá trị**: `DropdownButton<Category>` ở
Thêm / Sửa hoá đơn (`bill_add_page` :672, `bill_edit_page` :453) so `value` với từng `item` bằng `==`; hàng Drift so theo giá trị,
Entity không có `==` thì dropdown **mất lựa chọn** mà không lỗi nào báo. 13 trường `final`: `id · idaccount · name · classify ·
icon · colour · isDefault · isDeleted · parentId (String?) · isGroup · aiCoDinh · syncStatus · updatedAt`. Constructor `const`, mặc định
như cột bảng (`icon = 'category'`, `colour = '#4CAF50'`, bốn cờ `false`, `syncStatus = 'pending'`). `factory CategoryEntity.fromDrift(Category c)`
chép 13 trường; `props` liệt kê đủ 13. **Không có `toCompanion`** — mọi đường ghi danh mục đã đi qua `CategoryChildDraft` /
`CategoryGroupDraft` → Companion trong impl; Entity là ảnh **chỉ đọc** (khác Ví, cùng tinh thần `BillDraft` đợt 1). Docstring nêu năm
cột cố ý không chép và vì sao (`isLocalOnly`, `deletedAt` chỉ `core/sync` / DAO / impl đọc; ba cột lỗi đồng bộ là của hàng đợi đẩy).

Test mới `test/features/category/data/models/category_entity_test.dart` (thư mục chưa có): `fromDrift` chép đủ — **đếm cột bằng máy**
(`db.categories.$columns.length − 5` so `props.length`), fixture **khác mặc định ở mọi trường** (bài học review đợt 1); hai Entity cùng
giá trị thì `==` (ca canh đẳng thức — bản sai bỏ `Equatable` phải đỏ).

### 4.2 `CategoryManagementRepository`

| Trước | Sau |
|---|---|
| `watchTree` / `loadTree → CategoryTree` (chứa `Category`) | giữ tên; `CategoryTree` chứa `CategoryEntity` (4.3) |
| `selectableChildren` / `selectableChildrenAll → List<Category>` | giữ tên → `List<CategoryEntity>` |
| `loadBangTraTen → List<Category>` | **giữ tên** (A1) → `List<CategoryEntity>` |
| `watchAllRows → Stream<List<Category>>` | **`watchAll`** → `Stream<List<CategoryEntity>>` |
| `getRowById → Category?` | **`getById`** → `CategoryEntity?` (vẫn `categoryDao.getById` — trả cả hàng xoá mềm, ca canh chuyển từ test rows) |

Interface **thôi import `core/database`**. Impl **giữ Drift bên trong**: `_validParent`, `_rejectDefault`, `_requireOwnership`,
`_hasDuplicateName`, `_hasDuplicateAssignedChildName`, mọi `write(CategoriesCompanion(…))` không đổi; `_treeFromRows(List<Category>)`
nhận hàng rồi dựng cây bằng `CategoryEntity.fromDrift`; `selectableChildren*` map ở biên trả về. Chú thích docstring của ba lối cũ
(*"`categoryDao.getBangTraTen`"*, *"bộ lọc Sổ giao dịch, Trang chủ"*, *"tên danh mục trên bảng thanh toán hoá đơn"*) giữ nguyên nội dung.

Test `test/features/category/category_repository_rows_test.dart` (ngay dưới thư mục mảng, không có `data/`) **chuyển** (không xoá) sang `category_repository_doc_danh_muc_test.dart` cùng chỗ,
giữ ba khẳng định: `loadBangTraTen` gồm hàng xoá mềm + mặc định toàn cục · `watchAll` phát lại khi bảng đổi · `getById` trả hàng xoá mềm.
Helper `test/helpers/nguon_doc_gia.dart`: `DanhMucRowsGia → DanhMucGia`, bốn override đổi kiểu (map từ DAO).

### 4.3 `CategoryTree` · `CategorySuggestion` · `CategorySuggestionEngine`

`category_tree.dart`: `CategoryTree.ungroupedChildren` / `defaultChildren`, `CategoryGroupNode.group` / `children` → `CategoryEntity`;
thôi import `core/database` (hai draft đã thuần). `category_suggestion.dart`: `CategorySuggestion.category`, `CategoryKeywordCandidate.category`
→ `CategoryEntity`; thôi import `core/database`. `category_suggestion_engine.dart`: `_CandidateMatch.category` → Entity, thôi import
`core/database` (thân so khớp đọc `isDeleted` · `isGroup` · `id` — đều trên Entity). Chỗ dựng `CategoryKeywordCandidate(` trong `lib`
có **2**: `doc_cau_giao_dich` :577 (domain) và `them_giao_dich_cubit` :468 — đổi theo nguồn danh mục (đã là Entity sau 4.4).

### 4.4 Bảy interface / nguồn ngoài mảng — đổi chữ ký vì trả cho domain / giao diện

| Tệp | Đổi |
|---|---|
| `budget/data/datasources/budget_local_data_source.dart` | `getExpenseCategories` · `getAllCategories → Future<List<CategoryEntity>>`; impl `.map(CategoryEntity.fromDrift)` tại chỗ — `getAllCategories` **vẫn qua `getBangTraTen`** (bảng tra, E8 / G41, chú thích giữ) |
| `budget/data/repositories/budget_repository.dart` + impl | `getExpenseCategories → Future<List<CategoryEntity>>` (chuyền từ datasource); `lookupFor` dựng `TransactionLookup(categories: Entity)` |
| `transaction/data/them_giao_dich_nguon.dart` | `danhMucChonDuoc`, `napDanhMucVaTuKhoa` → Entity (tự theo repository); tệp **thôi import `core/database`** — hoàn tất câu hẹn mục 4.4 spec đợt 2 (đo: không còn kiểu Drift nào khác). Docstring ⚠️ về chuỗi một dòng `sl<WalletRepository>().getActive(` / `sl<TransactionRepository>().getAll(` **giữ** |
| `category/data/gan_danh_muc_nguon.dart` | `DuLieuGanDanhMuc.chonDuoc → List<CategoryEntity>`; `ghiPhanHoiGan(duDoan: CategoryEntity)`; tệp **vẫn** import `core/database` (đọc `db.transactionDao`, `db.walletDao` — data, đúng vai) |
| `bill/data/de_xuat_hoa_don_nguon.dart` | `bangDanhMuc → Future<Map<String, CategoryEntity>>`: map hàng `getBangTraTen` tại chỗ (thẻ *Có vẻ là khoản lặp* đọc biểu tượng / màu) |
| `ai_edge/data/cong_cu_goi_y_han_muc.dart` | `khopTheoTen<Category>` → `<CategoryEntity>` (nhận từ `BudgetRepository.getExpenseCategories`) |
| `ai_edge/data/cong_cu_danh_muc.dart` | không đổi dòng — `selectableChildrenAll` trả Entity, `hangDanhMuc` nhận Entity (mục 5) |

### 4.5 Map tại chỗ, giữ Drift nội bộ (quy tắc 4)

`category/data/services/default_category_seeder.dart` (`_daCoBanSao`: map `daCo` và `mau` sang Entity trước vòng `any`) và
`premium/data/dem_dang_hoat_dong.dart` (nhánh `danhMucRieng`: map `khuon` một lần, map từng `r` khi gọi `laBanSaoMacDinh` — hàng đã lọc
`deletedAt`, chú thích *"13 bản sao"* giữ). Không đổi: `analytics_repository_impl` (`dungKhoan(List<Transaction>, List<Category>)`
`@visibleForTesting` — test dựng hàng Drift, giữ), `bao_cao_repository_impl`, `tai_phan_bo_nguon.nap` (đọc `c.aiCoDinh && !c.isDeleted`
trên hàng DAO), `personal_default_categories`.

## 5. Domain (6 tệp, đổi kiểu không đổi thân)

| Tệp | Đổi |
|---|---|
| `category/domain/ban_sao_mac_dinh.dart` | `laBanSaoMacDinh(CategoryEntity c, List<CategoryEntity> khuon)`; test `ban_sao_mac_dinh_test` fixture → Entity |
| `category/domain/gan_hang_loat.dart` | `hopLeTheoChieu(String, List<CategoryEntity>)`, `dungDanhSachGan(chonDuoc: List<CategoryEntity>, …)`; thôi import `core/database` (hàng giao dịch đã là `TransactionEntity` từ đợt 2) |
| `transaction/domain/dien_san_bien_dong.dart` | tham số `chonDuoc` → Entity; thôi import `core/database` |
| `transaction/domain/doc_cau_giao_dich.dart` | `chonDuoc` (2 chỗ) → Entity; `KhopMot<CategoryEntity>` :488; `CategoryKeywordCandidate(category: c …)` :577; thôi import `core/database` |
| `transaction/domain/transaction_lookup.dart` | `TransactionLookup({categories: Iterable<CategoryEntity>})`, `_categories: Map<String, CategoryEntity>`, `category(String?) → CategoryEntity?`; thôi import `core/database`. Chỗ dựng trong `lib`: `bill_detail_page` :91 · `bill_page` :94 · `home_page` :195 · `transaction_page` :263 (giao diện, nguồn `loadBangTraTen` / `watchAll`) · `budget_repository_impl` :191 (`getAllCategories`) |
| `ai_edge/domain/hang_danh_muc.dart` | `hangDanhMuc(List<CategoryEntity> danhMuc, …)`; thôi import `core/database`; quét 14 không đổi (không phép tính mới) |

Sau bước này `conChoDomain` rút 6 tệp; `ap_dung_ke_hoach` rút ở mục 7, `goal_auto_deposit_runner` ở mục 8.

## 6. Giao diện (20 tệp — đổi kiểu, giữ `Key` và chữ; phụ lục A)

Đổi kiểu tham số / trường / generic: `push<CategoryEntity>` (`transaction_page` :276, `add_transaction_page` :862), `pop<CategoryEntity>`
(`choose_category_page` :307), `DropdownButton<CategoryEntity>` / `DropdownMenuItem<…>` / `DropdownButtonFormField<…>` (`bill_add_page`,
`bill_edit_page` — `_firstWhereOrNull<T>` đọc `(item as dynamic).id`, không đổi), `StreamBuilder<List<CategoryEntity>>` (`home_page`,
`transaction_page`), `showModalBottomSheet<CategoryEntity>` (`chon_danh_muc_gan_sheet`), `Map<String, CategoryEntity>` (`the_khoan_lap`,
`gan_danh_muc_page`, `khoi_tach`, `ThemGiaoDichState.dmTheoId`), sentinel `danhMuc as CategoryEntity?` (`them_giao_dich_state` :179),
`pickCategory: Future<CategoryEntity?> Function()` (`transaction_filter_bar`), `BudgetFormReady.categories` / `BudgetForm.categories`.

Đổi tên hai hàm ở **3** chỗ gọi: `home_page` :161 · `transaction_page` :139 → `.watchAll(`; `bill_actions` :29 → `.getById(`.
`bill_detail_page` :90 · `bill_page` :92 giữ `.loadBangTraTen(`. Router `app_router.dart`: `ChooseCategoryPage(classify: state.extra as String?)`
— không có `extra as Category`, **không đụng**. `category_visuals.dart` nhận chuỗi `icon` / `colour`, không đụng. ⚠️ Hai lời gọi
`sl<CategoryManagementRepository>().watchAll(` phải **nằm trên một dòng**: quét 2 (`tepDocViQuaTruong`, đọc 2026-10-15) đếm mọi dòng
`.getAll(` / `.watchAll(` trong tệp có nhắc `WalletRepository` là đọc ví, trừ khi **chính dòng ấy** chứa `CategoryManagementRepository>()`
— tách dòng là dương tính giả ở `home_page` / `transaction_page`.

`conChoKieu` **xoá khoá `Category`**. Trang lớn nhất bị chạm: `them_giao_dich_cubit` 1.132 dòng (trần 1.200, quét 23) — đổi kiểu không
thêm dòng. Test giao diện: `makeCategory` của `category_test_fakes.dart` trả `CategoryEntity` (bỏ `isLocalOnly`, `syncRetryCount`,
tham số không có trên Entity) — 34 tệp cầm `List<Category>` theo nó; fixture tự dựng `Category(` ở 10 tệp còn lại (phụ lục C) đổi sang
`CategoryEntity(` hoặc `makeCategory`. **Không đổi kỳ vọng ca nào.**

## 7. Cụm phản hồi tái phân bổ (bảng *Đề xuất cân đối*, trang Ngân sách — mảng Ngân sách / ai_edge)

Đường hôm nay: `budget_page` :82 `moKeHoachTaiPhanBoSheet(ghiPhanHoi: sl<TaiPhanBoNguon>().ghiPhanHoi)` → sheet gọi
`phanHoiTu(_kh, chon, …)` (ai_edge/domain, trả `List<AiRebalancingFeedbacksCompanion>`) rồi `widget.ghiPhanHoi(c)` từng hàng →
`TaiPhanBoNguonImpl.ghiPhanHoi(Companion) → db.aiFeedbackDao.ghi`. Domain dựng Companion là lỗ (import `drift` + `core/database`), và
`TaiPhanBoNguon.ghiPhanHoi` là lối chuyển tiếp thứ tư.

**Sau đợt:**
- `ai_edge/domain/ap_dung_ke_hoach.dart`: lớp Dart thuần **`PhanHoiTaiPhanBo`** cùng tệp — 11 trường `final` khớp 11 cột bảng
  `AiRebalancingFeedbacks` theo tên (`id · idaccount · createdAt · deficitBudgetId · donorBudgetId · donorCategoryId · suggestedAmount ·
  actualAmount · action · periodFrom · periodTo`), constructor `const`, không `Equatable` (không chỗ nào so bằng); `phanHoiTu` trả
  `List<PhanHoiTaiPhanBo>` — thân giữ từng dòng, chỉ đổi `AiRebalancingFeedbacksCompanion(id: Value(…))` thành `PhanHoiTaiPhanBo(id: …)`;
  `Uuid` ở lại (gói thuần). Tệp thôi import `package:drift` và `core/database` → rút khỏi `conChoDomain`.
- `budget/data/tai_phan_bo_nguon.dart`: `TaiPhanBoNguon.ghiPhanHoi(PhanHoiTaiPhanBo p)`; impl dựng `AiRebalancingFeedbacksCompanion`
  từ `p` — **chỗ duy nhất** phép ánh xạ sống; docstring *"`aiFeedbackDao.ghi`"* giữ.
- `ai_edge/presentation/pages/ke_hoach_tai_phan_bo_sheet.dart`: `typedef GhiPhanHoi = Future<void> Function(PhanHoiTaiPhanBo)`; hai vòng
  `for (final c in phanHoiTu(…)) await widget.ghiPhanHoi(c)` không đổi dòng. `budget_page` không đổi.
- Test: `ap_dung_ke_hoach_test` (19 chỗ đọc `.value` → đọc trường thẳng, kỳ vọng giữ); 4 fake `TaiPhanBoNguon` (`bo_cong_cu_test`,
  `cong_cu_ngan_sach_test`, `budget_cubit_ke_hoach_test`, `tai_phan_bo_nguon_test`); `ke_hoach_sheet_test` (fixture `ghiPhanHoi`);
  `tai_phan_bo_nguon_ghi_test` **thêm** ca *Companion dựng đủ cột từ lớp thuần* — đếm `db.aiRebalancingFeedbacks.$columns.length`
  (11) so số `Value` present, fixture khác mặc định; `schema_v24_test` kiểm bảng, **giữ** Companion.

## 8. Mục tiêu — hai nợ

### 8.1 `GoalRepository.watchGoalTransactions`

`Stream<dynamic>` → **`Stream<List<TransactionEntity>>`** (`goal_repository.dart` :214); impl :665
`db!.transactionDao.watchByGoal(…).map((rows) => rows.map(TransactionEntity.fromDrift).toList())`, nhánh không `db` →
`Stream.value(const <TransactionEntity>[])`. Hai widget nhận kiểu rõ: `goal_detail_page` (`StreamBuilder<List<TransactionEntity>>` :588,
`snapshot.data ?? const []` :603, `_doiSangKhoan(List<TransactionEntity>)` :150) và `khoi_lich_su_muc_tieu` (`List<TransactionEntity> txs`
:38, :123). **Ngoại lệ đổi thân có tên** (quy tắc 1): **tám** phép ép `tx.note as String?` (×2) · `tx.date as DateTime` (×2) ·
`tx.amount as double` (×2) · `tx.walletId as String` (×2) — `goal_detail_page` :152 · :154 · :155 · :158 và bốn dòng ở
`_DanhSachLichSu` (đếm bằng `grep -nE "\bas (String\??|DateTime|double)\b"` 2026-10-15) — cộng `snapshot.data as List<dynamic>?` :603,
đều **bỏ**; `(tx.note as String?) ?? ''` thành `tx.note` (`TransactionEntity.note` là `String` không null). Đếm lại ở kế hoạch. Test: 2 fake (`goal_detail_live_test`
:91 `Stream<List<dynamic>>` → `Stream<List<TransactionEntity>>`, `khoanLichSu` kiểu rõ; `goal_detail_phieu_tran_test` :59);
`goal_repository_impl_test` 3 ca (:988, :1014, :1043) bỏ `as List` / `as Transaction`, kỳ vọng giữ.

### 8.2 `goal_auto_deposit_runner.dart` dời

`lib/features/goal/domain/goal_auto_deposit_runner.dart` → **`lib/features/goal/data/services/goal_auto_deposit_runner.dart`**, dời
nguyên văn (`git mv`), chỉ sửa đường import tương đối trong tệp. Tiền lệ `bill/data/services/bill_auto_pay_runner.dart` (đợt 1); bảng
mục 8 `KIEN_TRUC` hàng *Bộ điều phối nhiều bước*. Sửa **3** import `lib` (`core/di/injection_container.dart` :35,
`core/notification/notification_rules.dart` :5, `core/notification/notification_scanner.dart` :21 — mỗi tệp vẫn **một** dòng import
→ ratchet quét 25 **không đổi**) và **4** import test; test `test/features/goal/goal_auto_deposit_runner_test.dart` dời về
`test/features/goal/data/services/` (soi gương như `bill_auto_pay_runner_test`). Docstring `goal_auto_deposit.dart` :23 nhắc tên test —
giữ. Rút tệp khỏi `conChoDomain` → **rỗng**; khoá tạm `Goal` của luật 1 (mục 9) rút cùng commit.

## 9. Test quét 27 sau đợt (vẫn số 27 — mở rộng, không mở số 28)

Tệp `test/core/ui/presentation_domain_khong_kieu_drift_test.dart` (226 dòng hôm nay).

**Luật 1 — mở sang `features/*/domain/` theo tên kiểu** (việc mang sang 0.2a của bàn giao đợt 2). Vòng quét thêm `Directory('lib/features')`
nhánh `/domain/` (hôm nay nhánh ấy bị `continue`). Ba bộ đếm tiền đề tách riêng thay `soTep > 100` gộp (0.2b): `soTepTrang > 100`
(presentation + shared, đo 206) · `soTepCore > 20` (đo 77) · `soTepDomain > 80` (đo 164) — sàn ≈ nửa số đo, cùng khuôn hai sàn cũ.
Danh sách chờ **trong lúc thi công** (bước 1 mục 11): `'Category'` thêm 6 tệp domain (mục 5); khoá tạm `'Goal': {'features/goal/domain/goal_auto_deposit_runner.dart'}`.
**Sau đợt**: `conChoKieu` chỉ còn `'AppNotification'` (9 tệp). Bản sai thử đỏ: thêm `Category c` vào một tệp domain.

**Luật 2 — giữ cơ chế, danh sách rỗng**: `conChoDomain = <String>{}` (như `mienTru` quét 23 sau gạch 2); vòng *"đã sạch — rút"* vẫn chạy
trên tập rỗng. Bản sai thử đỏ: thêm `import 'package:drift/drift.dart';` vào một tệp domain.

**Luật 3 — mới**: mọi tệp `lib/features/*/data/**/*.dart`, trên dòng đã bỏ chú thích, không khớp
`RegExp(r'\b(Stream|Future|List|Iterable)<dynamic>')` — đây là lớp lỗ đã giấu `watchGoalTransactions` hai tháng (bài học bàn giao: *"câu
'X là kiểu duy nhất' phải đo cả `dynamic` / `Object` ở chữ ký repository"*). Danh sách chờ `conChoDynamic` **trong lúc thi công**:
`{goal_repository.dart, goal_repository_impl.dart}`; **sau đợt rỗng**. Phạm vi **cố ý hẹp**: không quét `core/sync` (8 dòng đọc payload
JSON `as List<dynamic>?`), `core/router` (`GoRouterRefreshStream(Stream<dynamic>)` của go_router), không bắt `Map<String, dynamic>`
(JSON của `auth`, `ai_edge`). Ca tiền đề: mẫu bắt `Stream<dynamic> watchX(` và `as List<dynamic>?`, **không** bắt `Map<String, dynamic>`.

**Chữ** (0.2c): docstring :7 *"Kiểu KHÔNG có khoá trong [conChoKieu] là kiểu đã thống nhất Entity"* và thông điệp :193 *"kiểu này đã
thống nhất Entity"* → *"kiểu này không có chỗ chờ trong phạm vi quét — nhắc tới là đỏ"*. Lý do: `Goal` / `Budget` cũng không có khoá mà
hai mảng ấy chưa đạt trọn định nghĩa thống nhất (`KIEN_TRUC` mục 1); test không được nói hơn tài liệu. Docstring đầu tệp thêm dòng
*"Mở rộng 2026-10-15 (spec Entity Danh mục mục 9): luật 1 quét domain; luật 3"*; docstring `kieuDrift` :15 *"Kiểu hàng Drift mà giao
diện từng cầm"* → *"… mà giao diện, domain hay `core` từng cầm"*.

## 10. Đối chiếu luật kiến trúc và lộ trình G88

- **`KIEN_TRUC` mục 4 (ba tầng):** `data/` được import `core/database` → `category_entity.dart`, `tai_phan_bo_nguon.dart`, runner ở
  `data/services`, `budget_local_data_source`, `de_xuat_hoa_don_nguon`, `gan_danh_muc_nguon` giữ import là đúng vai; `domain/` là Dart
  thuần → 8 tệp hết import Drift; `presentation/` đọc qua repository / nguồn → không đổi cửa, chỉ đổi kiểu qua cửa. Repository
  interface **vẫn ở `data/repositories/`** (quyết định có lý do của tài liệu, không đụng).
- **Mục 8 (vị trí tệp):** Entity ở `data/models/` ✓; runner ở `data/services/` ✓ (hàng *Bộ điều phối*); test soi gương theo thư mục ✓
  (`test/features/goal/data/services/`, `test/features/category/data/models/`); `PhanHoiTaiPhanBo` ở `ai_edge/domain/` cạnh hàm sinh nó
  (hàng *Hàm thuần*).
- **Quét 22** (presentation không cầm `sl<AppDatabase>` / `.xxxDao`): không đụng — không trang nào mở DAO. **Quét 23**: không tệp nào
  thêm dòng. **Quét 25**: ratchet `conChoCoreImport` **43 không đổi** (dự kiến — `core` không import `category_entity`; runner dời
  giữ số dòng); vị trí tệp khớp bảng. **Quét 2** (đọc `tepDocViQuaTruong` 2026-10-15): tệp nhắc `WalletRepository` có dòng `.getAll(` /
  `.watchAll(` bị đếm là đọc ví trừ khi dòng ấy chứa `CategoryManagementRepository>()` — hai lời gọi đổi tên ở `home_page` /
  `transaction_page` giữ trên một dòng (mục 6) thì quét 2 không đổi; đo lại khi xong.
  **Quét 14 / 15**: `PhanHoiTaiPhanBo` không thêm phép tính; `aiCoDinh` lên Entity không chạm `SyncEntityType` / `categoryForPush`.
  **Quét 21**: không đụng quyền. **Quét 27**: mục 9.
- **Quy tắc 7 / 8 `CLAUDE.md`:** `_hasDuplicateName` / `getNamesInUse` / `normalizeCategoryName` không đụng; seeder vẫn đọc
  `getOwnedIncludingDeleted` (đếm cả xoá mềm — G16) rồi map; `laBanSaoMacDinh` chỉ đổi kiểu tham số; `getBangTraTen` là định nghĩa duy
  nhất của bảng tra (G41) — `loadBangTraTen`, `getAllCategories`, `bangDanhMuc`, `tai_phan_bo_nguon.nap` đều vẫn gọi nó.
- **Lộ trình G88 gạch 3:** đợt 3/4 đóng → còn Thông báo (`AppNotification` 9 tệp — 2 giao diện + 7 `core/notification`, gắn với gạch 5
  dời `core/notification` sang `features/notification/`). Hai nợ Mục tiêu và lối `ghiPhanHoi` **đã trả** ở đợt này — câu *"Mục tiêu /
  Ngân sách ngoài lộ trình, chưa đạt định nghĩa thống nhất"* ở `KIEN_TRUC` mục 1 / 9 / 10 và `KNOWN_GAPS` G88.3 viết lại (mục 13).
  Entity: **6/14** mảng (ví, giao dịch, mục tiêu, ngân sách, hoá đơn, **danh mục**).

## 11. Kiểm thử và nghiệm thu

**Thứ tự thi công** (mỗi bước một commit, toàn bộ test xanh ở mỗi commit):

1. Quét 27 mở rộng (mục 9) với danh sách chờ **hiện trạng**: luật 1 quét domain + `Category` thêm 6 tệp + khoá tạm `Goal`; ba sàn đếm;
   luật 3 + `conChoDynamic` tạm 2; chữ :7 / :193. Bản sai thử đỏ cho cả ba luật.
2. `category_entity.dart` + `category_entity_test` (đếm cột, đẳng thức).
3. **Một commit đổi kiểu "trục Danh mục"** (chốt D1): repository interface + impl (4.2) · `CategoryTree` / `CategorySuggestion` / engine
   (4.3) · 7 interface / nguồn ngoài mảng (4.4) · map tại chỗ 2 tệp (4.5) · 6 domain (mục 5) · 20 giao diện (mục 6) · `makeCategory` +
   5 fake `CategoryManagementRepository` + 1 `BudgetLocalDataSource` + 2 `DeXuatHoaDonNguon` + 1 `ThemGiaoDichNguon` + helper + 6 tệp
   nhắc `getExpenseCategories` + fixture 10 tệp (phụ lục B, C) · test rows chuyển + đổi tên · `nguon_doc_gia`. Rút 6 domain khỏi
   `conChoDomain`, **xoá khoá `Category`** khỏi `conChoKieu`. Ước ~45 tệp `lib` + ~45 tệp test — **đếm ở kế hoạch**.
   **Phép đo của người soát (bắt buộc; kế hoạch viết script ở scratchpad):** lấy `git diff -U0` của commit, chuẩn hoá các thay thế
   được phép trên dòng `-` (`\bCategory\b` không theo sau bởi `Entity|Tree|Group|Suggestion|Keyword|Management|Validation` →
   `CategoryEntity`; `watchAllRows → watchAll`; `getRowById → getById`; dòng `import … core/database/app_database.dart` ↔
   `… category_entity.dart`), rồi so tập dòng `-` đã chuẩn hoá với tập dòng `+` — **phải rỗng** ngoài fixture test và docstring.
   Lệch một dòng là một chỗ "tiện tay sửa" cần giải thích.
4. Cụm phản hồi tái phân bổ (mục 7) + 6 tệp test; rút `ap_dung_ke_hoach` khỏi `conChoDomain`.
5. `watchGoalTransactions` (8.1) + 2 fake + 3 ca; rút hai tệp khỏi `conChoDynamic` → rỗng.
6. Runner dời (8.2) + test dời + 7 import; rút khoá tạm `Goal` và tệp cuối của `conChoDomain` → rỗng.
7. Tài liệu (mục 13) + số đo + nghiệm thu máy ảo.

**Không đổi kỳ vọng ca nào**; `flutter test` tăng đúng số ca mới (entity 2–3, companion 1, quét 27 +1 luật 3 và ca tiền đề — đếm khi
xong); `flutter analyze` **20** (tám phép ép + một `as List<dynamic>?` ở Mục tiêu bỏ đúng vì lý do ấy). `test/tool/kiem_csdl_that_test.dart` :58 và
`do_goi_y_danh_muc_test` gọi qua repository, không nhắc kiểu `Category` — tự theo.

**Nghiệm thu máy ảo `FlowMoney_16G`** (`-gpu host`, bản debug, cuộn giữ-rồi-thả, cắt 100 px thanh trạng thái). "Trước" = bản **đang cài**
`94394e4c…` (mã `3252db88`; `lib/` không đổi tới `6971dfab` — không dựng lại); "sau" xác nhận bằng
`dumpsys package com.flowmoney.flowmoney | grep lastUpdateTime` **và** SHA-1 APK. **Không ghi dữ liệu thử** (chốt 3 lật khi soát —
mục 1): màn C1 và thẻ *"Có N giao dịch chưa có danh mục"* không chụp được trên máy ảo (`demChuaGan` = 0, như đợt 2) — ghi **lỗ** vào
biên bản; `gan_danh_muc_page`, `chon_danh_muc_gan_sheet` và `GanDanhMucNguon` do widget test / test nguồn phủ (đếm số ca khi xong).
Thẻ gợi ý ở Thêm giao dịch chụp bằng cách gõ ghi chú có từ khoá seed (vd. `cafe`) **không Lưu**, thoát bằng Back. Màn: Danh mục (ba tab,
nhóm) · Thêm / Sửa danh mục (khối từ khoá, công tắc Cố định) · Chọn danh mục · Thêm giao dịch có thẻ gợi ý · Sổ + chip lọc danh mục ·
Trang chủ · Hoá đơn Thêm / Sửa (dropdown danh mục — ca canh đẳng thức 4.1) + chi tiết · Ngân sách form + *Đề xuất cân đối* nếu dữ liệu có ·
Chi tiết mục tiêu (lịch sử tích luỹ — 8.1). Mục tiêu **0 px khác** ngoài lệch thời gian đã biết (`20_ns_chi_tiet` đợt 2), vàng
thuần `#FFFF00` **0**. Tool `danh_muc` / `goi_y_han_muc` của Trợ lý AI không đo trên máy ảo (rơi về mẫu câu) — `cong_cu_danh_muc_test`,
`cong_cu_goi_y_han_muc_test` phủ. Ảnh ở scratchpad, không vào repo.

**Phép đo kết luận** (chạy từ `src/Client-app`):
- `grep -rlE "\bCategory(\?|>| [a-z_]+\b|,|\)|;)" lib/features/*/presentation lib/features/*/domain lib/shared lib/core --include=*.dart`
  = 0 ngoài `core/database`, `core/sync`.
- `grep -rn "watchAllRows\|getRowById" lib` = 0; `grep -rln "AiRebalancingFeedbacksCompanion" lib/features` = chỉ `budget/data/tai_phan_bo_nguon.dart`.
- `grep -rnE "(Stream|Future|List|Iterable)<dynamic>" lib/features/*/data` = 0.
- `grep -rlE "core/database|package:drift" lib/features/*/domain` = 0.
- `grep -rcE "^(import|export) .*features/" lib/core` = 185 (142 điểm ghép + 43).

## 12. Ngoài phạm vi — quan sát, không sửa

- `analytics_repository_impl` / `bao_cao_repository_impl` đọc DAO thẳng (ví, giao dịch, hoá đơn, mục tiêu, danh mục) — mảng Phân tích, chưa có lịch.
- `AppNotification` ở 2 tệp giao diện + 7 tệp `core/notification` — đợt Thông báo (4/4), gắn với gạch 5.
- `CategoryEntity` không mang `isLocalOnly` / `deletedAt` — không chỗ đổi kiểu nào đọc; mở khi có chỗ đọc thật.
- `core/sync` đọc payload JSON bằng `List<dynamic>` — đúng vai, luật 3 cố ý không quét.
- `GoalEntity` / `BudgetEntity` không đổi; `goal_repository.dart` **không** còn hàm nào trả hàng Drift theo kiểu rõ (đo 2026-10-15:
  `grep -nE "<(Goal|Transaction|Wallet)[>?]|\bGoal\b [a-z]|\bTransaction\b [a-z]"` = 0) — sau 8.1 interface ấy sạch Drift cả kiểu rõ
  lẫn `dynamic`.
- `vi_trung_ten_nguon.banGhiBiGiuTuHang` cố ý ở Drift.

## 13. Tài liệu cập nhật khi xong

Grep theo từ khoá quyết định cũ trên `docs/` + `CLAUDE.md` + chú thích `lib/`: `loadBangTraTen|watchAllRows|getRowById|lối chuyển
tiếp|4 lối|conChoDomain|8 tệp|5/14|chưa có Entity|watchGoalTransactions|goal_auto_deposit_runner|goal/domain/goal_auto|ghiPhanHoi|
phanHoiTu|AiRebalancingFeedbacksCompanion|DanhMucRowsGia`. Dự kiến: `docs/KIEN_TRUC_CLIENT_APP.md` (mục 1 *Entity 6/14*, câu Mục tiêu /
Ngân sách viết lại thành *đã trả ba nợ, ngoài lộ trình chỉ còn cách gọi DAO ở Phân tích*; mục 4 bảng + *"còn 4"* → 0; mục 6 quét 27
ba luật; mục 9 / 10), `docs/CLIENT_APP_KNOWN_GAPS.md` (G88 gạch 3 đợt 3/4 đóng + số đo; mục 3 câu *"Mục tiêu / Ngân sách còn nợ"* và
đoạn ⚠️ `watchGoalTransactions`; mục 4 ratchet 43 giữ; bảng tóm tắt; dòng *Cập nhật*), `docs/PROJECT_CONTEXT.md` (mục 14 khối mới;
mốc test), `CLAUDE.md` (hàng *presentation*: *"4 lối chuyển tiếp"* → 0, mô tả quét 27 ba luật, *"còn 8 tệp chờ"*; hàng *hoá đơn* câu
*"còn 8 tệp chờ"*; hàng *mục tiêu* / *trích tiền tự động* nếu nêu đường `goal/domain/goal_auto_deposit_runner`; mốc test; dòng ⭐),
`docs/GOAL_FEATURE.md` / `docs/AI_EDGE_FEATURE.md` / `docs/QUET_ANH_FEATURE.md` chỗ nêu đường runner hay `phanHoiTu` / `ghiPhanHoi`
(grep ra ba tệp này 2026-10-15 — đọc từng chỗ, chỉ sửa chỗ nói về đường tệp hay kiểu trả), spec đợt 2 mục 11 (ba nợ đã trả, ghi ngày),
`docs/CATEGORY_RATIONALE.md` một dòng ở đầu mục 5 hoặc 7: *kiểu dữ liệu danh mục từ repository trở lên là `CategoryEntity` (2026-10-15,
spec này)*, chú thích `them_giao_dich_nguon.dart` (câu *"còn `Category`"* nếu có), `category_management_repository.dart` docstring ba lối.
Mọi con số đếm lại bằng máy, ghi ngày.

## Phụ lục A — 20 tệp giao diện cầm `Category` Drift (đo 2026-10-15 = `conChoKieu['Category']`; `features/` bỏ tiền tố)

Danh mục (5): `category/presentation/pages/category_add_page` · `category_group_page` · `category_page` · `gan_danh_muc_page` ·
`category/presentation/widgets/chon_danh_muc_gan_sheet`. Giao dịch (8): `transaction/presentation/bloc/them_giao_dich_cubit` ·
`them_giao_dich_state` · `pages/add_transaction_page` · `choose_category_page` · `transaction_page` · `widgets/khoi_tach` ·
`sheet_them_phan` · `transaction_filter_bar`. Hoá đơn (4): `bill/presentation/pages/bill_add_page` · `bill_detail_page` ·
`bill_edit_page` · `bill/presentation/widgets/the_khoan_lap`. Ngân sách (2): `budget/presentation/bloc/budget_state` ·
`budget/presentation/pages/budget_form`. Trang chủ (1): `home/presentation/pages/home_page`.

## Phụ lục B — Fake / fixture test phải đổi (đo 2026-10-15; `test/` bỏ tiền tố)

- `implements CategoryManagementRepository` (5): `features/ai_edge/data/bo_cong_cu_test` · `cong_cu_danh_muc_test` ·
  `features/category/presentation/category_test_fakes` · `features/transaction/data/them_giao_dich_nguon_test` · `helpers/nguon_doc_gia`.
- `implements TaiPhanBoNguon` (4): `features/ai_edge/data/bo_cong_cu_test` · `cong_cu_ngan_sach_test` · `features/budget/budget_cubit_ke_hoach_test` ·
  `features/budget/data/tai_phan_bo_nguon_test`.
- `implements DeXuatHoaDonNguon` (2): `features/bill/presentation/pages/bill_page_khoan_lap_test` · `features/bill/presentation/the_khoan_lap_test`.
- `implements BudgetLocalDataSource` (1): `features/budget/data/repositories/budget_repository_nhip_chi_test`.
- `implements ThemGiaoDichNguon` (1): `features/transaction/data/them_giao_dich_nguon_test`; helper `helpers/them_giao_dich_nguon_gia` (`List<Category>` :35, :49, :69, :73).
- Khai `getExpenseCategories` (6): `features/ai_edge/data/bo_cong_cu_test` · `cong_cu_goi_y_han_muc_test` ·
  `features/bill/presentation/pages/bill_page_ten_danh_muc_mac_dinh_test` · `features/budget/domain/de_xuat_ngan_sach_test` ·
  `features/budget/presentation/bloc/budget_cubit_test` · `tool/kiem_csdl_that_test` (gọi repository thật — tự theo).
- `GoalRepository` khai `watchGoalTransactions` (2): `features/goal/presentation/pages/goal_detail_live_test` · `goal_detail_phieu_tran_test`;
  ca gọi: `features/goal/data/repositories/goal_repository_impl_test` (3 ca).
- Nhắc `AiRebalancingFeedbacksCompanion` / `phanHoiTu` / `GhiPhanHoi` (7): `core/database/schema_v24_test` (**giữ**) ·
  `features/ai_edge/data/bo_cong_cu_test` · `features/ai_edge/domain/ap_dung_ke_hoach_test` · `features/ai_edge/presentation/ke_hoach_sheet_test` ·
  `features/budget/budget_cubit_ke_hoach_test` · `features/budget/data/tai_phan_bo_nguon_ghi_test` · `tai_phan_bo_nguon_test`.
- Import runner (4): `core/notification/notification_deeplink_test` · `notification_rules_goal_wallet_test` · `notification_scanner_khoa_test` ·
  `features/goal/goal_auto_deposit_runner_test` (dời).

## Phụ lục C — 11 tệp test dựng `Category(` bằng tay (đo 2026-10-15)

`features/budget/presentation/bloc/budget_cubit_test` · `features/budget/presentation/pages/budget_form_cycle_row_test` ·
`budget_form_dien_san_test` · `budget_form_suggestion_test` · `budget_form_test` · `budget_form_threshold_zero_test` ·
`features/category/data/category_suggestion_engine_test` · `features/category/domain/ban_sao_mac_dinh_test` ·
`features/category/presentation/category_form_tu_khoa_test` · `category_management_widget_test` · `category_test_fakes` (`makeCategory`).
Tệp chỉ dựng `CategoriesCompanion` để ghi CSDL thật **giữ nguyên** (không đếm ở đây).
