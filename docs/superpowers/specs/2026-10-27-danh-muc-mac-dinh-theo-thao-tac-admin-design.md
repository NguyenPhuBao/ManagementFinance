# Danh mục mặc định theo thao tác Admin-web — thiết kế

> **Ngày:** 2026-10-27 (phiên 15, Opus 5.5, inline) · **Trạng thái:** ✅ mã xong 2026-10-27, chờ nghiệm thu máy thật (mục 9)
> **Phạm vi:** chỉ `src/Client-app` (quy tắc 1). Server, Admin-web, `/sync/*` không đổi; không cần đơn backend để làm phần này.
> **Liên quan:** `2026-09-07-per-account-default-categories-design.md` (bản sao theo tài khoản — spec này mở rộng nó), quy tắc
> 7–8 `CLAUDE.md`, `docs/CATEGORY_RATIONALE.md`, G16 `CLIENT_APP_KNOWN_GAPS.md`.

## 0. Bối cảnh — đo được trước khi thiết kế (2026-10-27)

Admin-web (`CategoryPage.jsx`, `admin.api.js`) có năm thao tác trên danh mục **hệ thống** (`Is_default = true`); danh mục của
người dùng bị chặn 403 ở cả năm:

| Thao tác Admin-web | Backend | Ghi gì |
|---|---|---|
| Thêm | `admin.service.js addCategory` | Hàng mới; nếu trùng (tên, loại) với một khuôn đã xoá mềm thì **mở lại đúng hàng ấy** (giữ id) |
| Sửa | `updateCategory` | `name_category`, `classify`, `keyword`, `icon`; `server_update_at` nâng bằng trigger `set_server_update_at` (`database/20`) |
| Xoá | `deleteCategory` | `delete_at = now()` (xoá mềm) |
| Khôi phục | `restoreCategory` (`PATCH/POST /admin/restorecategory/:id`) | `delete_at = NULL`, nâng `update_at` + `server_update_at` |

Cả năm đi tới client qua `/sync/pull` (`getCategoriesByAccount`: `is_default = true` **hoặc** `create_by = tài khoản`, theo
`server_update_at > since`, **kể cả hàng đã xoá**). Socket `admin.category_updated` chỉ phát vào `admin_room` — app người dùng
không nhận, nên mọi thay đổi tới ở **lượt kéo về kế tiếp**.

Hành vi client **trước** spec này:

- Hàng khuôn (`idaccount = 0`) ẩn khỏi mọi danh sách; mỗi tài khoản có **bản sao** do `DefaultCategorySeeder` tạo sau mỗi lượt
  kéo về. Bản sao không có mối nối với khuôn — nhận ra bằng **tên chuẩn hoá + loại** (`laBanSaoMacDinh`).
- Xoá khuôn: tài khoản **chưa** có bản sao thôi nhận; bản sao đã có **không đổi gì**. Khôi phục: tài khoản chưa từng có bản sao
  nhận bản sao ở lượt kéo kế. Bản sao người dùng tự xoá **không** mọc lại (luật "kể cả đã xoá", G16).
- **Ba lỗi lộ ra khi soát:**
  1. Bộ tạo bản sao so **tên + loại**, còn chỉ mục `uq_category_owner_name` của server (và quy tắc 7) chỉ so **tên** → người
     dùng có *"Trả nợ"* loại **Chi**, khuôn *"Trả nợ"* **Vay/nợ** sống lại / được thêm → bản sao cùng tên → đẩy lên
     `CATEGORY_NAME_DUPLICATE` (vĩnh viễn, bị chặn theo bậc) → lượt kéo sau có danh mục đổi thì
     `mergeDuplicatePersonalCategories` gộp nó vào danh mục Chi và **xoá cứng** → bộ tạo bản sao tạo lại → lặp. Ca test
     `default_category_seeder_test.dart` *"cùng tên nhưng KHÁC loại thì vẫn tạo bản sao"* ghim hành vi này, lý do ghi trong ca
     viện `uq_category_owner_name_classify` — chỉ mục đã DROP (định nghĩa hiện hành đo bằng `pg_indexes` 2026-10-27; tệp `database/)2_can_lam_all_migrations.sql` từng chứa nó đã bị backend xoá ở `850fe23b` — xem bản `6e6a783d`).
  2. Admin **đổi tên** khuôn → bản sao (tên cũ) không còn khớp → mọi tài khoản mọc thêm một bản sao mang tên mới.
  3. Trần Premium *"danh mục riêng"* (`dem_dang_hoat_dong.dart`) loại bản sao bằng khuôn **còn sống** → xoá khuôn là bản sao
     của nó bị đếm oan vào trần Basic (5).
- Supabase dùng chung (`.env`, đo 2026-10-27 bằng truy vấn đọc): **16** khuôn sống, **0** khuôn xoá mềm — 13 mã ổn định + *Thu
  nợ*, *Trả nợ* (Vay/no), *Xăng xe* (Chi). `PersonFinance` cục bộ chưa đo. (Quy tắc 8 `CLAUDE.md` ghi "13 sống + 5 xoá mềm" —
  ảnh chụp cũ.)

## 1. Quyết định người dùng chốt (2026-10-27, câu hỏi chọn được)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Admin xoá mềm khuôn — bản sao trên máy người dùng ra sao? | **Ẩn khỏi danh sách, giữ lịch sử**; admin khôi phục → hiện lại |
| 2 | Bản sao người dùng đã sửa? | **Đổi tên thì giữ** (thành danh mục của họ); đổi biểu tượng / màu / từ khoá **vẫn ẩn** |
| 3 | Admin sửa khuôn thì máy theo gì? | **Đổi tên** · **đổi biểu tượng** · **thêm từ khoá** — theo; **đổi loại** — không theo |
| 4 | Người dùng tạo danh mục trùng tên một bản sao đang ẩn? | **Báo rõ, gợi ý đặt tên khác** — không cần backend |
| 5 | Áp luật ẩn cho khuôn đã xoá TỪ TRƯỚC (lượt dọn về 13 mã)? | **Không — chỉ khuôn bị xoá từ ngày thi công** |
| 6 | Hướng làm | **Tính "ẩn" lúc đọc, không thêm cột** (loại: cột cục bộ v32; xoá mềm bản sao qua đồng bộ) |

Hai hướng bị loại, lý do:

- **Cột cục bộ `an_theo_khuon` (v32), tính lại sau mỗi lượt kéo về** — người dùng thấy y hệt, nhưng thêm một trạng thái nhân
  đôi phải giữ khớp, một bước di trú và một hàng quét 15.
- **Xoá mềm bản sao + đẩy lên, khôi phục thì gỡ** — máy thứ hai không phân biệt *"admin ẩn"* với *"người dùng xoá"* (tái hiện
  G16); gỡ xoá qua `/sync/push` dựa vào đúng hồi quy của đơn 53 (`is_deleted: false` làm sống lại hàng); và Admin-web cấm đụng
  danh mục người dùng.

## 2. Người dùng thấy gì

Lấy khuôn *"Xăng xe"* (Chi) làm ví dụ.

| Admin làm | Trên máy người dùng (sau lượt kéo về kế tiếp) |
|---|---|
| Xoá *"Xăng xe"* | Bản *"Xăng xe"* biến khỏi màn Danh mục, màn Chọn danh mục (Thêm giao dịch), form Hoá đơn, form Ngân sách, thẻ *Chưa đặt ngân sách*, gợi ý B1 / số tiền / từ khoá, Nhập nhanh, Quét, Gắn danh mục C1, tool AI, lệnh tạo C3. Giao dịch / ngân sách / hoá đơn cũ **vẫn hiện tên** *"Xăng xe"* ở Sổ giao dịch, Trang chủ, Phân tích, báo cáo, và vẫn chạy (hoá đơn tự trả vẫn ghi vào nó). Form **sửa** một mục đang gắn *"Xăng xe"* vẫn hiện nó là giá trị hiện tại. Tạo danh mục tên *"Xăng xe"* → *"'Xăng xe' là danh mục hệ thống đang tạm ngừng — hãy đặt tên khác"*. Không bị đếm vào trần *danh mục riêng* |
| Khôi phục | *"Xăng xe"* hiện lại đủ mọi chỗ. Bản người dùng **tự xoá** trước đó vẫn xoá |
| Đổi tên thành *"Xăng dầu"* | Bản sao còn mang tên *"Xăng xe"* đổi thành *"Xăng dầu"* (kể cả bản đã xoá mềm — để không mọc lại); không mọc bản thứ hai |
| Đổi biểu tượng | Bản sao còn đúng biểu tượng cũ của khuôn đổi theo; bản người dùng đã tự đổi biểu tượng giữ nguyên |
| Thêm từ khoá *"petrolimex"* | Bản sao có thêm từ khoá ấy; từ khoá người dùng tự gõ / tự xoá trước đó không bị đụng |
| Đổi loại Chi → Thu | Bản sao giữ loại Chi; không mọc bản trùng tên |
| Thêm khuôn mới | Như trước: mọi tài khoản chưa có danh mục **cùng tên** nhận bản sao |

Người dùng **đã đổi tên** bản sao (vd *"Xăng xe máy"*) → đó là danh mục của họ: không ẩn, không lan truyền.

## 3. Luật "ẩn theo khuôn" — một định nghĩa

Tệp `lib/features/category/domain/ban_sao_mac_dinh.dart` (cạnh `laBanSaoMacDinh`), Dart thuần:

```dart
/// 00:00 giờ VN 2026-10-27 — khuôn xoá mềm TRƯỚC mốc này (lượt dọn về 13 mã ổn định) không làm bản sao ẩn (chốt 5).
final DateTime kMocAnTheoKhuon = DateTime.utc(2026, 10, 26, 17);

bool dangAnTheoKhuon(CategoryEntity c, List<CategoryEntity> khuon, {DateTime? moc});
```

`c` **đang ẩn** ⇔ cả bốn:

1. `c` là danh mục của tài khoản: `!c.isDefault`, `!c.isDeleted`, `!c.isGroup` (bản sao không bao giờ là nhóm).
2. Có khuôn `t` **đã xoá mềm** (`t.isDeleted`, `t.deletedAt != null`) với `t.deletedAt >= moc` và `laBanSaoMacDinh(c, [t])`
   (tên chuẩn hoá + loại).
3. **Không** có khuôn **còn sống** nào cùng **TÊN** chuẩn hoá với `c`, **bất kể loại** (người dùng chốt 2026-10-27 — bước 3 so
   chỉ tên, không so loại như bước 2). Admin xoá *"Trả nợ"* rồi thêm *"Trả nợ"* khác thì bản sao vẫn hiện; admin xoá
   *"Trả nợ"* loại Chi mà *"Trả nợ"* loại Vay/nợ vẫn sống thì bản Chi cũng KHÔNG ẩn. Lý do: bộ tạo bản sao so chỉ tên
   (mục 6; `uq_category_owner_name` không có loại) nên không bao giờ tạo bản Vay/nợ khi đã có bản Chi — ẩn bản Chi là người
   dùng không còn *"Trả nợ"* nào để chọn. Bước 2 (khớp khuôn ĐÃ XOÁ) giữ tên + loại.
4. (hệ quả của 1–3, ghi ra để test) đổi tên → không còn khớp → hiện; khác loại → không khớp → hiện.

Ghi chú:

- Luật đọc hàng khuôn **có trên máy** (kéo về kèm `delete_at`) → mọi máy cùng tài khoản cho cùng kết quả; khôi phục / xoá có hiệu
  lực ngay khi hàng khuôn về, không cần bước tính lại.
- `CategoryEntity` thêm trường `deletedAt` (`DateTime?`, vào `props`) — `fromDrift` đọc cột sẵn có.
- `laBanSaoMacDinh` **không đổi** (tên + loại) — nó là phép **nhận diện bản sao** cho luật ẩn và trần Premium. Bộ tạo bản sao
  dùng phép khác (mục 6).

## 4. Ai đọc luật — danh sách CHỌN vs bảng TRA

Kiểm kê bằng script 2026-10-27: bốn hàm danh sách của `CategoryDao` có chỗ gọi — `getAll` (`dem_dang_hoat_dong`), `watchAll`
(`category_management_repository_impl`, `bao_cao_repository_impl`), `getCategoryRows` (`category_management_repository_impl` ×2,
`budget_local_data_source`), `watchCategoryRows` (`category_management_repository_impl`) — từ bốn tệp; `getByClassify` 0 chỗ gọi.

**Danh sách để CHỌN — bỏ bản ẩn.** Cả cây danh sách chọn đi qua `CategoryDao.getCategoryRows` / `watchCategoryRows`:

| Cửa | Ai dùng |
|---|---|
| `CategoryManagementRepositoryImpl.watchTree` / `loadTree` | Màn Danh mục, chọn nhóm cha (`category_add_page`, `category_group_page`), `choose_category_page` (Thêm giao dịch) |
| `…selectableChildren` / `selectableChildrenAll` | form Hoá đơn thêm / sửa, `ThemGiaoDichNguon` (Thêm giao dịch, Nhập nhanh, B1, gợi ý số tiền), `quet_anh_page`, `GanDanhMucNguon` (C1), `cong_cu_danh_muc` (tool AI), `nguon_lenh_tao` (C3), `category_group_page` |
| `BudgetLocalDataSource.getExpenseCategories` | form Ngân sách, thẻ *Chưa đặt ngân sách* — **thôi gọi DAO thẳng**, đi qua cửa `danh_sach_chon_danh_muc.dart` (cùng cửa với repository; không đổi interface `BudgetRepository` — 17 bản hiện thực) |

- `CategoryDao` nằm ở `core/database` — luật 5 quét 25 **cấm** nó đọc `features/*/domain` → bộ lọc đặt ở **cửa** `features/category/data/danh_sach_chon_danh_muc.dart` (`hangChonDuoc` / `theoDoiHangChonDuoc`), gọi bởi
  `CategoryManagementRepositoryImpl` VÀ `BudgetLocalDataSource` (ngân sách). DAO giữ tên `getCategoryRows` / `watchCategoryRows`
  nhưng trả record kèm khuôn. Giao dịch đã giữ sẵn danh mục đang gắn (không sửa); ngân sách giữ qua `BudgetCubit.danhMuc`.
- `getCategoryRows` / `watchCategoryRows` đổi kiểu trả thành record `({List<Category> rows, List<Category> khuon})`: **một**
  truy vấn `(idaccount = tài khoản ∧ classify ∧ !isDeleted) ∨ isDefault` (khuôn **kể cả đã xoá**), tách trong Dart; phép khử
  trùng lặp theo tên hiện có chỉ áp cho `rows`. Một truy vấn → stream phát lại khi hàng khuôn đổi (xoá / khôi phục).
- Repository (`_treeFromRows`, `selectableChildren`) và datasource ngân sách lấy hàng qua cửa, không lọc tay.
- **Test quét số 40** (`test/features/category/danh_sach_chon_danh_muc_mot_cua_test.dart`): ngoài DAO và cửa
  `danh_sach_chon_danh_muc.dart` không tệp `lib/` nào gọi `getCategoryRows` / `watchCategoryRows` (không phải repository impl).

**Bảng TRA tên — giữ nguyên, vẫn thấy bản ẩn:** `CategoryManagementRepository.watchAll` (tra tên ở Sổ giao dịch, Trang chủ —
`TransactionLookup`), `getBangTraTen` / `watchBangTraTen` (báo cáo, phân tích, ngân sách, hoá đơn, tái phân bổ),
`BaoCaoRepositoryImpl.watchDanhMuc` (bộ lọc Xuất báo cáo — lọc theo lịch sử), `getById`.

**Form SỬA giữ giá trị đang chọn.** Sửa hoá đơn / ngân sách / giao dịch đang gắn một bản ẩn: bản ẩn
không xuất hiện ở form TẠO và các bộ chọn khác; form SỬA của hoá đơn / ngân sách / giao dịch đang gắn nó thì kèm nó làm giá trị
hiện tại (bản ẩn CÓ trong `items` của form sửa — `kemDanhMucDangGan`). Bắt buộc vì `DropdownButton` **ném** khi `value` không nằm trong `items`. Kế hoạch soát từng
form (`bill_edit_page`, form ngân sách, `ThemGiaoDichCubit` / `choose_category_page` khi sửa) và có test cho từng form — hoá đơn: widget; ngân sách + giao dịch: cubit (mục 8).

**Trần Premium *danh mục riêng*** (`dem_dang_hoat_dong.dart`): so bản sao với **mọi khuôn kể cả đã xoá** (DAO thêm
`getTatCaKhuon()`), nên bản ẩn và bản sao của khuôn cũ không bị đếm là danh mục tự tạo (đóng lỗi 3 mục 0).

**Trùng tên** (`_hasDuplicateName`): giữ luật (quy tắc 7 — bản ẩn **vẫn chiếm** tên, server cũng tính nó vì nó còn sống ở
server). Hàng va chạm là bản đang ẩn → ném `CategoryValidationException('‘<tên>’ là danh mục hệ thống đang tạm ngừng — hãy đặt
tên khác.')`; trường hợp khác giữ câu cũ.

## 5. Lan truyền khi admin sửa khuôn

**Thu thay đổi lúc kéo về** (`core/sync/ap_du_lieu_keo_ve.dart`, nhánh *3. Categories*): trước khi `upsertAll` ghi đè, với mỗi
hàng về có `is_default = true` — **còn sống HAY ĐÃ XOÁ** (người dùng chốt 2026-10-27) — mà `existingLocal` là **khuôn đã có
trên máy**, so cũ / mới:

- tên (`normalizeCategoryName`), biểu tượng, tập từ khoá (cũ = hàng `CategoryKeywords` của khuôn trên máy; mới = chuỗi
  `keyword` tách dấu phẩy, như nhánh hiện có).
- Khuôn về **đã xoá** (`delete_at != null`) vẫn lan truyền **tên và biểu tượng**, KHÔNG so từ khoá (nơi gọi truyền
  `tuKhoaCu = tuKhoaMoi`). Lý do: admin đổi *"Ăn uống"* → *"Ăn ngoài"* RỒI xoá, cả hai giữa hai lượt kéo → hàng về đã xoá; bỏ
  qua nó thì bản sao *"Ăn uống"* không khớp khuôn đã xoá nào (*"Ăn ngoài"*) nên vẫn HIỆN, và khi admin khôi phục khuôn bộ tạo
  bản sao mọc thêm bản *"Ăn ngoài"* thứ hai.
- Khác ít nhất một thứ → một bản ghi thuần **`ThayDoiKhuon`** `{id, loai, tenCu, tenMoi, iconCu, iconMoi, tuKhoaCu, tuKhoaMoi}`
  — `loai` là loại **cũ** (bản sao giữ loại cũ khi admin đổi loại, chốt 3).
- `existingLocal == null` (máy chưa từng thấy khuôn) → không ghi gì.

`ThayDoiKhuon` đặt trong `core/sync/sync_models.dart` (một trong sáu tệp `cuaCongKhai`, quét 35). Cổng
`SyncEngine.sauKeoVe` đổi chữ ký thành `Future<int> Function(int idaccount, List<ThayDoiKhuon> thayDoiKhuon)`; nhánh kéo về
trả danh sách cùng kết quả lượt kéo, `_sauMoiLuotKeoVe` chuyển nó cho cổng.

**Áp thay đổi** — lớp mới `lib/features/category/application/lan_truyen_khuon.dart` (`LanTruyenKhuon.apDung(idaccount,
thayDoi)` → số hàng đã ghi). DI nối cổng: `sauKeoVe: (id, doi) async => await lanTruyen.apDung(id, doi) + await
seeder.seedForAccount(id)` — **lan truyền TRƯỚC, tạo bản sao SAU** (bản đã đổi tên chặn bộ tạo bản sao đẻ bản tên mới).

Với mỗi `ThayDoiKhuon`, trên các danh mục của tài khoản (`isDefault = false`):

1. **Đổi tên** (`tenCu ≠ tenMoi` sau chuẩn hoá): mọi hàng khớp `(tenCu, loai)` — **kể cả đã xoá mềm** (bỏ sót là bộ tạo bản sao
   thấy tên mới trống và đẻ lại thứ người dùng đã xoá, dạng G16) — đổi `name = tenMoi`. Bỏ qua hàng ấy nếu tài khoản đã có danh
   mục khác (chưa xoá, mọi loại) mang tên mới.
2. **Đổi biểu tượng**: hàng **chưa xoá** khớp `(tenMoi, loai)` sau bước 1 (hàng bị bỏ qua ở bước 1 vẫn mang `tenCu` nên không
   đổi) mà `icon == iconCu` → `icon = iconMoi`.
3. **Thêm từ khoá**: `them = tuKhoaMoi − tuKhoaCu` (theo `normalizedKeyword`); hàng chưa xoá khớp → thêm những từ chưa có, không
   xoá từ nào. Cập nhật luôn hàng từ khoá **của khuôn** thành `tuKhoaMoi` (`replaceKeywords`) để bản sao tạo sau nhận bộ mới và
   lần so sau đúng.
4. Đổi loại: không làm gì.
5. Hàng **chưa xoá** vừa sửa: `syncStatus = 'pending'`, `updatedAt = now` → đẩy lên (từ khoá đi trong payload danh mục, khoá
   `keyword`). Máy thứ hai cùng tài khoản nhận qua đồng bộ, hoặc tự áp ra cùng kết quả (luỹ đẳng: lần áp thứ hai không còn hàng
   khớp tên cũ / biểu tượng cũ, từ khoá đã có).
6. ⚠️ Hàng **đã xoá mềm** đổi tên ở bước 1 **chỉ ghi cục bộ — KHÔNG đánh dấu `pending`, không đổi `updatedAt`.** Hàng xoá mềm mà
   `pending` được `thu_gom_day.dart` đẩy thành `operation: delete` → server `softDelete` bỏ qua tên mới nhưng vẫn nâng
   `server_update_at` → lượt kéo kế mang hàng về với **tên cũ** đè lên tên vừa đổi → bộ tạo bản sao thấy tên mới trống và đẻ lại
   thứ người dùng đã xoá. Không đẩy thì server không đổi, hàng không bị kéo lại; máy khác tự đổi tên bản đã xoá của nó khi thấy
   cùng `ThayDoiKhuon` (vấp khi soát spec 2026-10-27, trước khi thi công).

## 6. Sửa bộ tạo bản sao

`DefaultCategorySeeder._daCoBanSao`: *"đã có"* ⇔ tài khoản **từng** có (kể cả đã xoá mềm) một danh mục cùng **tên chuẩn hoá**
— bỏ vế loại. Khớp quy tắc 7 và `uq_category_owner_name`; đóng lỗi 1 mục 0. Ca *"cùng tên nhưng KHÁC loại thì vẫn tạo bản sao"*
lật thành *"… thì KHÔNG tạo"*, `reason:` viện chỉ mục thật. Mọi ca G16 giữ nguyên.

## 7. Giới hạn biết trước (ghi vào tài liệu, không chặn)

- Bản sao đã xoá mềm chỉ đổi tên cục bộ (mục 5 bước 6) → máy kéo toàn bộ lại (cài mới) nhận tên cũ; nếu khuôn đã đổi tên thì bộ
  tạo bản sao tạo bản tên mới cho tài khoản ấy (thứ người dùng từng xoá mọc lại dưới tên mới) — cùng lớp với gạch dưới.
- **Máy chưa từng thấy bản cũ của khuôn** (cài mới, đăng nhập máy mới) không lan truyền được. Nếu cả tài khoản không có máy nào
  kéo về giữa lúc admin đổi tên và lúc ấy, bản sao còn tên cũ và bộ tạo bản sao thêm bản tên mới — người dùng thấy cả hai.
- Cổng `sauKeoVe` hỏng (lỗi CSDL) hoặc phiên đổi giữa lượt → mất lần lan truyền ấy (bộ tạo bản sao tự thử lại ở lượt sau, lan
  truyền thì không).
- Admin đổi loại khuôn → bản sao loại cũ không còn khớp `laBanSaoMacDinh` → bị đếm vào trần *danh mục riêng*.
- Bản client cũ trên máy khác của cùng tài khoản: không ẩn, không lan truyền, nhưng nhận các bản sao đã đổi qua đồng bộ.
- App chỉ biết thay đổi ở lượt kéo về kế tiếp (không có socket tới app người dùng).
- Lan truyền khớp `(tenMoi, loai)` nên danh mục người dùng TỰ TẠO trùng đúng
  tên mới + loại cũ cũng nhận biểu tượng / từ khoá của khuôn — đúng spec, không đổi mã (`lan_truyen_khuon.dart:51` hàm `khop`,
  `:78` bộ lọc `song`; đo 2026-10-27 sau đợt sửa review toàn nhánh).
- Khuôn bị xoá TRƯỚC `kMocAnTheoKhuon` mà vẫn được đổi tên lúc về (mục 5 — khuôn đã xoá vẫn lan truyền tên / biểu tượng) → bản
  sao đổi theo tên mới nhưng **không** ẩn (mốc chỉ quyết việc ẩn); vẫn không bị đếm trần vì khớp khuôn đã xoá theo tên mới.
  Supabase đo 2026-10-27: 0 khuôn xoá mềm.
- `_deletedAtFrom` (`core/sync/anh_xa_keo_ve.dart:430`) rơi về `DateTime.now()` khi `delete_at` đọc hỏng → khuôn xoá cũ thành
  *"xoá sau mốc"* → bản sao ẩn; và `Delete_at` là timestamp không múi giờ (lệch ≤ 7 giờ quanh mốc nếu CSDL ghi giờ VN) — không
  đổi mã vì server luôn gửi ISO, Supabase đo 2026-10-27 có 0 khuôn xoá mềm.
- Lối TẠO có điền sẵn (thẻ B2 `/bills/add?…`, lệnh C3) mang id bản ẩn → `bill_add_page.dart:150` `firstWhere(orElse: …first)` chọn
  danh mục ĐẦU danh sách thay vì để trống (hành vi có sẵn với mọi id vắng).
- `_tinhDeXuat` (`them_giao_dich_cubit.dart:522`) có thể đề xuất thêm từ khoá cho danh mục đang ẩn khi sửa giao dịch gắn nó —
  vô hại.
- Danh mục người dùng tự tạo trùng đúng (tên, loại) một khuôn đã xoá cũng không bị đếm vào trần *danh mục riêng*
  (`dem_dang_hoat_dong.dart:50`) — vô hại (giới hạn bởi số khuôn đã xoá).
- ⚠️ **G110** (người dùng chốt 2026-10-27): danh mục người dùng TỰ TẠO trùng (tên, loại) một khuôn — khi admin xoá khuôn nó ẩn
  y như bản sao (luật ẩn không phân biệt hai loại), và màn Danh mục không có lối nào để đổi tên một danh mục đang ẩn (dữ liệu còn
  nguyên, admin khôi phục khuôn là hiện lại). Đề xuất lối thoát ở `CLIENT_APP_KNOWN_GAPS.md` G110 (mục *"Đang tạm ngừng"*).
- Bản sao còn mang tên cũ (đổi tên bị bỏ vì tên mới đã có, hoặc lần lan truyền bị mất) bị đếm vào trần *danh mục riêng* —
  `laBanSaoMacDinh` không còn khớp khuôn nào.
- (`78afc043`; `ap_du_lieu_keo_ve.dart:116`, biến `keoToanBo`.) Lượt kéo TOÀN BỘ (`isLocalDbEmpty || _lastPullTime == null`)
  bỏ so từ khoá khuôn — vì đổi tài khoản trên cùng máy, purge giữ hàng khuôn nhưng dọn từ khoá của tài khoản; hệ quả: tài khoản
  không còn ví sống (mọi lượt là toàn bộ) hoặc mốc kéo về bị bỏ thì thay đổi từ khoá của khuôn ở lượt ấy không lan truyền.
- Hàng khuôn dùng chung cả máy → tài khoản kéo về ĐẦU TIÊN sau khi admin sửa nhận `ThayDoiKhuon`, tài khoản thứ hai trên cùng
  máy không nhận cho bản sao của mình (giới hạn thiết kế).
- Lượt kéo hỏng SAU bước danh mục: hàng khuôn đã ghi đè → mất lần lan truyền tên / biểu tượng ấy (từ khoá có thể được phát hiện
  lại ở lượt sau).
- Khuôn về LẦN ĐẦU ở trạng thái đã xoá (không được gieo từ khoá) rồi admin khôi phục → `tuKhoaCu` rỗng — hiếm.
- (`55b7c39e`, `lan_truyen_khuon.dart`.) Bản sao đã xoá mà lệnh xoá còn `pending` (đẩy hỏng) lúc lan truyền đổi tên → lệnh
  xoá vẫn được đẩy, server bỏ tên mới, lượt kéo sau đè tên cũ và bộ tạo bản sao đẻ lại bản mang tên mới — cùng cơ chế bước 6,
  hiếm (đẩy chạy trước kéo).
- Đua hai máy: máy kia cùng tài khoản tạo danh mục mang đúng tên mới trong khoảng giữa lượt kéo và lượt đẩy đổi tên của máy này →
  hàng đổi tên gặp `CATEGORY_NAME_DUPLICATE` (ca máy kia đẩy TRƯỚC lượt kéo đã chặn bằng phép kiểm tên mới).

## 8. Kiểm thử (TDD — mọi ca canh thử bằng bản sai có chủ ý và thấy đỏ)

| Lớp | Tệp (dưới `test/`) | Ca chính |
|---|---|---|
| Domain luật ẩn | `features/category/domain/ban_sao_mac_dinh_test.dart` | xoá sau mốc → ẩn · trước mốc → hiện · còn khuôn sống cùng (tên, loại) → hiện · **còn khuôn sống cùng TÊN khác loại → hiện** · đổi tên → hiện · khác loại → hiện · bản tự xoá / nhóm → không xét |
| Repository | `features/category/category_repository_doc_danh_muc_test.dart` (Drift bộ nhớ) | `watchTree` / `loadTree` / `selectableChildren(All)` bỏ bản ẩn · `watchAll` / bảng tra tên giữ · stream **phát lại** khi khuôn xoá rồi khôi phục **và khi khuôn sống bị xoá** (bản sao ẩn ngay) · `saveGroup` không gỡ nhóm của bản sao ẩn (giữ `parentId`, `syncStatus`, `updatedAt`) |
| Ngân sách | `features/budget/data/datasources/budget_local_data_source_test.dart` | `getExpenseCategories` bỏ bản ẩn |
| Form sửa | hoá đơn = widget test (`bill_edit_page`); ngân sách + giao dịch = test cubit (`BudgetCubit.danhMuc`, `ThemGiaoDichCubit`) | mở form gắn bản ẩn: không ném, hiện tên. ⚠️ `budget_form.dart` tự chặn `value` không nằm trong `items`, nên widget test ngân sách không canh được — canh ở cubit |
| Trùng tên | test repository | tạo / đổi tên trùng bản ẩn → câu mới; trùng hàng thường → câu cũ |
| Trần Premium | `features/premium/data/dem_dang_hoat_dong_test.dart` | bản ẩn / bản sao khuôn cũ không đếm |
| Lan truyền | `features/category/application/lan_truyen_khuon_test.dart` | đổi tên cả bản đã xoá — bản đã xoá **không** `pending`, giữ `updatedAt` · bỏ qua khi tên mới đã có · biểu tượng chỉ khi còn đúng cũ · từ khoá chỉ thêm · từ khoá khuôn cập nhật · `pending` · luỹ đẳng · đổi tên theo khuôn đã xoá → bản sao mang tên mới và **ẩn** · một thay đổi hỏng (TRIGGER `RAISE(ABORT)`) không làm mất các thay đổi sau |
| Ngân sách — đọc danh mục gắn ném | `features/budget/presentation/bloc/budget_cubit_test.dart` | `getById` ném → form không `BudgetError`, rơi về danh sách cũ |
| Kéo về | `core/sync/…` (ca mới cạnh `sync_gieo_sau_keo_ve_test.dart`) | ghi `ThayDoiKhuon` chỉ khi khuôn đã có trên máy và khác · lượt đầu không ghi · cổng nhận danh sách · thứ tự lan truyền → tạo bản sao · **khuôn về đã xoá vẫn ghi đổi tên, không ghi từ khoá** · máy có ví mà chưa có mốc → không so từ khoá · đổi biểu tượng |
| Bộ tạo bản sao | `features/category/application/default_category_seeder_test.dart` | so theo tên (ca lật) · ca G16 xanh · hai khuôn cùng tên khác loại → một bản sao |
| Quét 40 | mục 4 | `getCategoryRows` / `watchCategoryRows` chỉ ở DAO và cửa `danh_sach_chon_danh_muc.dart` (repository impl cũng bị cấm) |

## 9. Nghiệm thu máy thật

Realme hoặc OnePlus, backend + Admin-web trỏ **`PersonFinance` cục bộ** (⚠️ **không** Supabase dùng chung — thêm / xoá khuôn ở đó
làm mọi tài khoản thật mọc / mất danh mục). Dùng một khuôn thử riêng, vd *"Thử khuôn"* (Chi), ghi một giao dịch + một hoá đơn +
một ngân sách vào bản sao của nó trước. Kiểm danh tính CSDL trước khi bật backend (*Ghi chú vận hành* `CLAUDE.md`).

1. Admin xoá → sau đồng bộ: mất ở màn Danh mục, Chọn danh mục, form Hoá đơn, form Ngân sách; giao dịch cũ vẫn hiện tên; mở sửa
   hoá đơn / ngân sách / giao dịch không văng; tạo *"Thử khuôn"* → câu mới.
2. Admin khôi phục → hiện lại đủ chỗ.
3. Admin đổi tên → bản sao đổi tên, không mọc bản thứ hai; đổi biểu tượng → đổi theo; thêm từ khoá → có thêm.
4. Hai máy cùng tài khoản nếu có (một máy ảo + một máy thật).
5. Dọn: xoá khuôn thử **mềm** qua Admin-web (quy tắc 5).

## 10. Tài liệu phải sửa cùng lượt

- `docs/CATEGORY_RATIONALE.md` — mục mới: luật ẩn, lan truyền, sửa bộ tạo bản sao, hai hướng bị loại, giới hạn mục 7.
- Banner đầu spec `2026-09-07-per-account-default-categories-design.md` trỏ về spec này.
- `CLAUDE.md` quy tắc 8 — thêm luật ẩn + `ThayDoiKhuon` / cổng `sauKeoVe`, sửa câu "13 sống + 5 xoá mềm" thành số đo có ngày
  (commit bằng mẹo blob — hai dòng 🔬 chưa commit của luồng nghiên cứu để nguyên).
- `docs/PROJECT_CONTEXT.md` mục 14 — khối mới.
- `docs/CLIENT_APP_KNOWN_GAPS.md` — mục G mới cho lỗi 1 mục 0 (đóng cùng lượt), dòng *Cập nhật*.
- `docs/superpowers/sync/SYNC_DOCUMENTATION.md` — cổng `sauKeoVe` và `ThayDoiKhuon`.
- Bảng test quét trong `CLAUDE.md` — hàng 40, số kế tiếp 41.

## 11. Ngoài phạm vi

- Backend `restoreCategory` không kiểm `uq_category_default_name` trước khi gỡ xoá (khôi phục khi đã có khuôn sống cùng tên → 23505
  → admin nhận 500); `addCategory` kiểm (tên, loại) trong khi chỉ mục chỉ có tên. Thuộc backend — đơn CAN-LAM riêng nếu người
  dùng muốn.
- Mối nối bản sao ↔ khuôn trên server (cột mới) — người dùng chọn không cần ở câu 2 và 4.
- Lan truyền màu (Admin-web không sửa màu khuôn) và đổi loại.
