# Thống nhất Entity cho mảng Giao dịch + Ví — G88 gạch 3, đợt 2/4

**Ngày:** 2026-10-14 · **Nhánh:** `TranQuangDat` · **HEAD lúc viết:** `12b8fa0d` · **Trạng thái:** người dùng duyệt bốn chốt
và sáu phần trong chat, rồi **duyệt bản viết** (`c2c723cb`, cùng ngày — kể cả hai điểm đổi sau lượt soát: `TransactionEntity` thêm
`billId` / `deletedAt` chỉ đọc; điểm ghép không miễn trừ ở luật 1 quét 27). Kế hoạch: `docs/superpowers/plans/2026-10-14-entity-giao-dich-vi.md`
(gitignore).

Đợt **thứ hai** của G88 gạch 3 (`docs/CLIENT_APP_KNOWN_GAPS.md`; lộ trình người dùng chốt 2026-10-11: Hoá đơn → **Giao dịch + Ví**
→ Danh mục → Thông báo). Tiền lệ trực tiếp: `specs/2026-10-14-entity-hoa-don-design.md` (đợt 1/4, thi công xong cùng ngày). Người
dùng app **không thấy gì đổi**; cái đổi là từ repository trở lên, Ví và Giao dịch mỗi mảng chỉ còn **một** kiểu dữ liệu
(`WalletEntity` / `TransactionEntity` — cả hai đã có sẵn ở `data/models/`, đợt này chỉ làm chúng thành kiểu duy nhất), sáu lối
chuyển tiếp `…Rows` biến mất, và test quét 27 giữ cho chúng không quay lại.

## 1. Quyết định đã chốt (trong chat, 2026-10-14)

| # | Câu hỏi | Chốt | Lý do ngắn |
|---|---|---|---|
| 1 | Ba tệp `core/notification` cầm `Wallet` / `Transaction` Drift, **chưa** import `features/wallet` hay `features/transaction` | **Đổi sang Entity, ratchet quét 25 +3** (`notification_rules` 11 → 12, `notification_scanner` 6 → 7, `de_xuat_thong_bao_nguon` 0 → 1 mục mới; tổng 40 → **43**) | Sau đợt `lib/core` (trừ `database`, `sync`) nhắc `Wallet` / `Transaction` = 0 như Hoá đơn. Giá: câu luật tăng viết hôm qua (*"chỉ khi Entity của chính mảng đã import"*) phải viết lại — mục 8 |
| 2 | Tên hàm sau khi bỏ sáu lối `…Rows` | **Gộp tên**: `WalletRepository` thêm `getActive`, dùng lại `getAll` / `watchAll` / `getById` có sẵn; `TransactionRepository` thêm `getAll` / `watchAll`. **Quét 2 phân loại đủ**: +6 chỗ đang gọi `getAll` / `watchAll` Entity chưa từng được phân loại | Một cửa, một tên cho một phép đọc (chốt 3 đợt Hoá đơn). Quét 2 mở rộng đúng triết lý của nó: mọi người đọc mọi ví phải trả lời *"có được thấy ví lưu trữ không?"* |
| 3 | `bill/domain/de_xuat_hoa_don.dart` nhận `List<GoiYHoaDonPhanHoi>` (hàng Drift bảng phụ cục bộ) | **Record 3 trường** `({String khoaNhom, String ketQua, DateTime createdAt})`, nguồn `de_xuat_hoa_don_nguon` (bill/data) dựng | Hàm chỉ đọc ba trường ấy; `bill/domain` import `core/database` về **0** như bàn giao hẹn; không đẻ Entity cho bảng phụ |
| 4 | Nghiệm thu | **Máy ảo so ảnh + `lastUpdateTime`** + hai phép đo không chụp (Nhập nhanh câu nêu tên ví; thời gian `fromDrift` toàn sổ) | Không máy thật lúc viết; bài học bàn giao: `Success` của `adb install` là bằng chứng yếu |
| 5 | *(từ bàn giao đợt 1, chi phí 0 — đo: 0 tệp bắt thêm)* siết quét 27 cùng đợt | Luật 1 **mở rộng sang `lib/core`** (trừ `database`, `sync`); `mauKieu` thêm `;` · `.fromJson` (hai vế bàn giao nêu mà mẫu cũ hở — `>[` · `>(` mẫu cũ đã bắt qua `>`, không thêm); luật 2 thêm `package:drift` | *"core nhắc `Bill` = 0"* từ số đo thành luật; hai vế siết không bắt tệp nào mới nên đưa vào ngay |
| 6 | Lối thi công | Hỏi sau khi có kế hoạch (inline · agent con) | Bộ nhớ *thực thi kế hoạch* |

Tiền lệ giữ nguyên từ đợt Hoá đơn, không hỏi lại: domain + giao diện + **mọi** tệp ngoài mảng cùng đổi (bỏ `…Rows` là mọi người
gọi buộc phải đổi, không có phương án *"bộ chọn ví của Hoá đơn / Mục tiêu để sau"*); repository là cửa duy nhất; đổi kiểu không
đổi thân; dời nguyên văn; `dart format` chỉ tệp mới; mỗi bước TDD, mỗi bước một commit.

## 2. Hiện trạng đo được (2026-10-14, HEAD `12b8fa0d`)

Mọi số đếm bằng `grep` / `wc -l` / công cụ Grep, chạy từ `src/Client-app`. Mẫu *"nhắc kiểu"* là `mauKieu` của quét 27.

| Thứ | Số | Ghi chú |
|---|---|---|
| Tệp `transaction/domain/` import `core/database` | **4 / 26** | `dien_san_bien_dong` (chỉ `Category`) · `doc_cau_giao_dich` (`Wallet` + `Category`) · `khoan_lap` (`Transaction`) · `transaction_lookup` (`Wallet` + `Category`) |
| Tệp `wallet/domain/` import `core/database` | **0 / 9** | domain Ví đã nhận `WalletEntity` từ trước (`rang_buoc_vi`, `vi_trung_ten`) |
| `presentation/` + `shared/` nhắc `Wallet` Drift | **14** tệp | Giao dịch 6 · Hoá đơn 4 · Mục tiêu 3 · Trang chủ 1 (phụ lục A) |
| `presentation/` + `shared/` nhắc `Transaction` Drift | **1** | `home_page.dart` |
| `lib` (trừ `core/database`, `core/sync`) nhắc `Wallet` Drift | **27** tệp | gồm 14 trên + 3 domain + 2 `core/notification` + 8 `data/` (trong đó `vi_trung_ten_nguon` cố ý) |
| `lib` (trừ `core/database`, `core/sync`) nhắc `Transaction` Drift | **13** tệp | `home_page` · 4 domain (`khoan_lap`, `thu_chi_thang`, `gan_hang_loat`, `de_xuat_hoa_don`) · `de_xuat_thong_bao_nguon` · 7 `data/` (kể `transaction_entity` chính nó, `vi_trung_ten_nguon` cố ý) |
| Lời gọi sáu lối `…Rows` trong `lib` | **20** / 10 tệp | phụ lục C |
| Lối chuyển tiếp trả hàng Drift (`KIEN_TRUC` mục 4) | **10 → 4** sau đợt | còn `CategoryManagementRepository.loadBangTraTen` · `watchAllRows` · `getRowById` + `TaiPhanBoNguon.ghiPhanHoi` |
| `lib/core` (trừ `database`, `sync`) nhắc kiểu Drift | `Wallet` 2 · `Transaction` 1 · `AppNotification` **7** | bảy tệp `core/notification` — danh sách chờ của luật 1 mở rộng, rút ở đợt Thông báo; `Category` / `Goal` / `Budget` / `Bill` = 0 |
| Tệp `domain/` import `package:drift` | **2** | `ai_edge/domain/ap_dung_ke_hoach` · `goal/domain/goal_auto_deposit_runner` — cả hai đã trong `conChoDomain`, siết luật 2 không thêm tệp nào |
| `mauKieu` siết (thêm `;` · `.fromJson`) bắt thêm | **0** tệp | đo trên `presentation/` + `shared/` cho cả bảy kiểu (phép đo chạy với cả `>[` · `>(` — cũng 0) |
| Chú thích khối `/* */` trong `presentation/` + `shared/` | **0** tệp | bàn giao hẹn siết — không cần |
| Tệp nhắc `WalletRepository` ∧ gọi `.getAll(` / `.watchAll(` | **10** | trong đó **6** chưa phân loại ở quét 2 (mục 8); DI, datasource, impl đã có; `them_giao_dich_nguon` khớp **giả** — dòng ấy là `sl<ThongBaoNguon>().getAll(` (hàng chờ D1), không phải ví |
| Cột không có trên `TransactionEntity` mà tệp sắp đổi kiểu đang đọc | **4 chỗ / 3 tệp** | `khoan_lap.khoaNhomCua` đọc `t.deletedAt` (:114) **và `t.billId`** (:119 — khoản trả hoá đơn không là khoản lặp, luật B2); `gan_hang_loat.xetGan` đọc `t.deletedAt` (:30); `de_xuat_thong_bao_nguon.mocGhiGiaoDichTu` đọc `t.deletedAt` (:26). → **Entity thêm hai trường chỉ đọc** (mục 4.0), không bỏ vế nào. `analytics_repository_impl._laKhoanCamKet` đọc `t.billId` — tệp ấy **giữ** Drift nội bộ, map tại chỗ cho lời gọi `khoaNhomCua`. ⚠️ Lượt đo đầu (một lệnh `grep` gộp 20 tệp + ống `grep -v`) trả **0** — bị rtk cắt im lặng, đúng bẫy *"grep qua rtk"* của `CLAUDE.md`; số trên là lượt đo lại **từng tệp một lệnh** |
| Cột không có trên `WalletEntity` mà tệp sắp đổi kiểu đang đọc | **0** | cùng lượt đo từng tệp (`deletedAt` · `bankCassoId` · ba cột sync lỗi); hai dòng `e.billId` ở `notification_rules` là của `BillAutoPayEvent` |
| Bảng `Wallets` | **21** cột | `WalletEntity` 16 trường = 21 − 5 (`bankCassoId` · `deletedAt` · `syncRetryCount` · `syncError` · `syncBlockedUntil`) |
| Fake `implements WalletRepository` / `TransactionRepository` trong test | **21** / **14** (hợp **32** tệp) | gồm `test/helpers/nguon_doc_gia.dart` (`ViRowsGia`, `GiaoDichRowsGia`) |
| Tệp test dựng `Wallet(` / `Transaction(` bằng tay | **6** / **6** | phụ lục D; 84 / 43 tệp khác chỉ `WalletsCompanion` / `TransactionsCompanion` ghi CSDL thật — giữ |
| Tệp test cầm `List<Wallet>` / `List<Transaction>` | **27** | |
| Tệp test nhắc sáu lối `…Rows` | **8** | hai `*_repository_rows_test` + `nguon_doc_gia` + 3 fake + `wallet_picker_sources_test` + `category_repository_rows_test` (không đụng) |
| Tệp `presentation` lớn nhất của hai mảng | `them_giao_dich_cubit` 1.132 dòng | trần 1.200 (quét 23) — đổi kiểu không thêm dòng |
| `flutter test` · `flutter analyze` | **7.057** (+9 skip) · **20** | đo chiều 2026-10-14 sau đợt Hoá đơn |

Tiền lệ: `ThemGiaoDichNguon` đã là cổng tiêm được; `vi_chon_san.dart` generic `<T>`; `tim_giao_dich`, `transaction_row_content`,
`transaction_detail_sheet` đã cầm `TransactionEntity` — đợt này không phải dựng cửa mới, chỉ đổi kiểu đi qua cửa có sẵn.

## 3. Quy tắc đổi mã

1. **Đổi kiểu, không đổi thân.** `WalletEntity` mang đúng tên mọi trường mã sắp đổi đang đọc; `TransactionEntity` **thiếu hai**
   (`billId`, `deletedAt` — đo mục 2) nên **thêm chúng vào Entity** (mục 4.0) thay vì sửa ba thân hàm. Thân hàm, widget, luật giữ
   từng dòng; chỉ chữ ký, import và fixture đổi. **Một ngoại lệ có tên:** `de_xuat_hoa_don_nguon` dựng record (mục 4.5).
2. **Ánh xạ Drift chỉ ở tầng data**: `WalletEntity.fromDrift` (mới, dời từ datasource), `TransactionEntity.fromDrift` (có sẵn).
   `domain/`, `presentation/` và `core/notification` không import `core/database` cho hai kiểu này nữa.
3. **"Thêm trước, rút sau"** — khác đợt Hoá đơn: sáu lối `…Rows` có 20 lời gọi ở 10 tệp thuộc 5 mảng, rút ngay là commit
   không biên dịch. Bước 3 **thêm** hàm Entity bên cạnh lối cũ; bước 4–6 chuyển từng tầng; bước 7 mới rút (mục 10).
4. **Map tại chỗ** ở `data/` của mảng khác (tiền lệ `dem_dang_hoat_dong` đợt 1): tệp data đọc DAO rồi gọi hàm domain vừa đổi
   kiểu thì `.map(X.fromDrift)` ngay chỗ gọi, không mở repository mới, không đổi constructor.
5. `dart format` **chỉ** trên tệp mới (`wallet_entity_test`, hai test datasource / repository đổi tên, test quét sửa).
6. Mỗi bước TDD, mỗi bước một commit, toàn bộ test xanh ở mỗi commit.
7. Không đụng `core/sync/*`, `core/database/*` (trừ chú thích), `wallet/data/services/*`, `wallet/data/datasources/*` (ngoài
   dời `_toEntity`), `vi_trung_ten_nguon`, `budget_local_data_source`, `bill_payment_conflict_resolver`.

## 4. Entity, repository, nguồn

### 4.0 `TransactionEntity` thêm hai trường **chỉ đọc** `billId`, `deletedAt`

Ba hàm domain sắp nhận Entity đọc `t.deletedAt` (ba chỗ) và `t.billId` (một chỗ — `khoaNhomCua` loại khoản trả hoá đơn khỏi
phép tìm khoản lặp; bỏ vế ấy là đổi luật B2). Thêm `final String? billId; final DateTime? deletedAt;` theo đúng khuôn
`WalletEntity.biTuChoiTrungTen` đã có: **`fromDrift` chép, `toCompanion` KHÔNG mang** (đường ghi giữ nguyên — `insert` để mặc định
NULL như hôm nay; `updateRow` ghi bằng `write` nên cột không mang thì không đụng), `copyWith` chuyền nguyên giá trị, **không** nhận
tham số đặt hai trường ấy. Hai cờ xoá mềm tồn tại song song trên bảng (`isDeleted` bool + `deletedAt` mốc; DAO lọc theo
`deletedAt`), Entity nay thấy cả hai nên `xetGan` / `khoaNhomCua` / `mocGhiGiaoDichTu` giữ đúng vế đang có.

Test mới `test/features/transaction/data/models/transaction_entity_test.dart` (chưa có tệp nào ở thư mục ấy): `fromDrift` chép
`billId` và `deletedAt` (fixture khác mặc định); `toCompanion().billId.present` và `.deletedAt.present` đều **false** — ca canh khuôn
chỉ-đọc, bản sai có chủ ý (mang `Value(billId)`) phải đỏ. Ba chỗ dựng `TransactionEntity(` trong `lib` và mọi fixture test không đổi
(hai tham số tuỳ chọn, mặc định `null`).

### 4.1 `WalletEntity.fromDrift(Wallet)`

**Dời** nguyên văn thân `WalletLocalDataSourceImpl._toEntity` (16 phép gán) thành `factory WalletEntity.fromDrift(Wallet w)` ở
`wallet/data/models/wallet_entity.dart`; datasource gọi `WalletEntity.fromDrift` ở 5 chỗ đang gọi `_toEntity`. Tệp entity thêm
import `core/database` — cùng khuôn `BillEntity` / `TransactionEntity` / `GoalEntity` / `BudgetEntity` (docstring hiện có *"tách
biệt khỏi Drift"* sửa thành *"tách biệt khỏi Drift ở mọi tầng trên; phép ánh xạ ở đây là một định nghĩa"*). `_toCompanion`
**ở lại** datasource (đường ghi; chú thích về `biTuChoiTrungTen` giữ nguyên).

Test mới `test/features/wallet/data/models/wallet_entity_test.dart`: `fromDrift` chép đủ trường — **đếm cột bằng máy**
(`db.wallets.$columns.length − 5` so với số trường đọc được qua `props.length`), fixture mang giá trị **khác mặc định ở mọi
trường** (bài học review đợt 1: fixture bằng mặc định thì ca "chép đủ" mù trường ấy).

### 4.2 `TransactionLocalDataSource.getAll` / `watchAll`

Thêm hai hàm trả Entity (`transactionDao.getAll` / `watchAll` → `.map(TransactionEntity.fromDrift)`), cùng khuôn `watchKhoang`
có sẵn. Test: lọc theo tài khoản, bỏ hàng `deletedAt`, thứ tự `date` giảm dần (ba điều DAO đã làm — ca canh để ai đổi DAO
sau này biết datasource dựa vào chúng).

### 4.3 Chữ ký repository

| Trước | Sau |
|---|---|
| `WalletRepository.getActiveRows(id) → List<Wallet>` | **mới** `getActive(int idaccount) → Future<List<WalletEntity>>` (→ datasource `getActive`, đã có) |
| `getAllRows` · `watchAllRows` → `Wallet` | **bỏ**; người gọi dùng `getAll` · `watchAll` (có sẵn, Entity) |
| `getRowById(id) → Wallet?` | **bỏ**; người gọi dùng `getById` (có sẵn; cùng `walletDao.getById` nên **vẫn trả hàng xoá mềm** — bẫy 4.8 `GOAL_FEATURE`, ca canh chuyển từ `wallet_repository_rows_test`) |
| `TransactionRepository.getAllRows` · `watchAllRows` → `Transaction` | **bỏ**; **mới** `getAll(int)` · `watchAll(int)` → Entity, qua datasource 4.2 |

Hai interface **thôi import `core/database`**. Khối chú thích *"Bốn lối CHUYỂN TIẾP, không luật"* ở `wallet_repository.dart`
xoá. Hai test `wallet_repository_rows_test.dart` / `transaction_repository_rows_test.dart` **chuyển** (không xoá) sang hàm Entity,
đổi tên tệp `wallet_repository_doc_vi_test.dart` / `transaction_repository_doc_so_test.dart`, giữ ba khẳng định: `getActive` chỉ ví
hoạt động · `getAll` / `watchAll` gồm lưu trữ, bỏ xoá · `getById` trả hàng xoá mềm.

### 4.4 `ThemGiaoDichNguon`

`napViDangDung → FutureOr<List<WalletEntity>>`; `viTiem: List<WalletEntity>?`; `_hocTuSo` và `khoanTrongSo` đọc
`sl<TransactionRepository>().getAll(` — thân hai hàm giữ nguyên (chỉ đọc `id` · `type` · `categoryId` · `walletId` · `note` ·
`amount` · `date` · `isDeleted`, đều trên Entity). Docstring ⚠️ đầu tệp đổi chuỗi: `sl<WalletRepository>().getActive(` và
`sl<TransactionRepository>().getAll(` **phải nằm trên một dòng** (quét 2 nhận diện theo chuỗi). Tệp thôi import `core/database`
**chưa được** — còn `Category` (đợt Danh mục).

### 4.5 `de_xuat_hoa_don_nguon` dựng record

`chonDeXuatHoaDon(phanHoi: List<({String khoaNhom, String ketQua, DateTime createdAt})>, giaoDich: List<TransactionEntity>, …)`.
Nguồn (bill/data) map hàng `goiYHoaDonDao.getAll` thành record và `getByDateRange` thành Entity ngay chỗ gọi; `timKhoanLap`
nhận cùng danh sách Entity. Thân `chonDeXuatHoaDon` giữ từng dòng (ba trường cùng tên). Test `de_xuat_hoa_don_test` fixture
đổi kiểu, kỳ vọng không đổi.

## 5. Domain (7 tệp)

| Tệp | Đổi | `conChoDomain` |
|---|---|---|
| `transaction/domain/khoan_lap.dart` | `khoaNhomCua(TransactionEntity)` · `KhoanLap.ganNhat` · `timKhoanLap(List<TransactionEntity>)`; import `../data/models/transaction_entity.dart`; hai vế `t.deletedAt` / `t.billId` **giữ** (4.0) | **rút** |
| `transaction/domain/transaction_lookup.dart` | `Iterable<WalletEntity> wallets` · `Map<String, WalletEntity>` · `WalletEntity? wallet(id)`; **`Category` giữ Drift** | ở lại (Category) |
| `transaction/domain/doc_cau_giao_dich.dart` | `List<WalletEntity> vi` · `KhopMot<WalletEntity>` · `_cauNhacVi(String, WalletEntity)` · `_ViNhac` · `_viNhacTrongCau` · `_tenGoiViTrongCau` · `_docChuyenVi` (10 chỗ); **`Category` giữ** | ở lại (Category) |
| `home/domain/thu_chi_thang.dart` | `thuChiThangCua(Iterable<TransactionEntity>, now)` | **rút** |
| `category/domain/gan_hang_loat.dart` | `DongGanDanhMuc.giaoDich` · `xetGan(TransactionEntity)` · `demChuaGan(List<TransactionEntity>)` · tham số `giaoDich`; **`Category` giữ** | ở lại (Category) |
| `analytics/domain/du_bao_dong_tien.dart` | `vi: List<WalletEntity>` · `viTheoId: Map<String, WalletEntity>` (4 chỗ); import `wallet_entity.dart` thay `core/database` | **rút** |
| `bill/domain/de_xuat_hoa_don.dart` | Entity + record (4.5); bỏ import `core/database` | **rút** |

`dien_san_bien_dong.dart` **không chạm** (chỉ `Category`). `conChoDomain` 12 → **8** (phụ lục B). Các domain Ví / Giao dịch còn
lại (`vi_chon_san` generic, `vi_hay_dung`, `tim_giao_dich`, `gop_giao_dich`, `goi_y_chuyen_khoan`…) đã không cầm Drift — không chạm.

## 6. Giao diện (16 tệp — 14 tệp nhắc kiểu + `bill_page`, `bill_detail_page` chỉ đổi tên hàm; đổi kiểu, giữ `Key` và chữ)

- **Giao dịch (6):** `them_giao_dich_cubit` (8 chỗ: `_napVi`, `_timVi`, `_viHayDungCho`, `chonVi`, `chonViDich`, hai biến cục bộ
  :936–937; `chonViChonSan<WalletEntity>`), `them_giao_dich_state` (`vi` · `viNguon` · `viDich` + `copyWith`), `add_transaction_page`
  (1 chỗ), `transaction_page` (`_wallets` → `sl<WalletRepository>().watchAll(`; thẻ chưa gắn → `sl<TransactionRepository>().watchAll(`
  `.map(demChuaGan)`; `const <WalletEntity>[]`), `widgets/them_giao_dich/bang_chon_vi` (`List<WalletEntity>`, `ValueChanged<WalletEntity>`),
  `widgets/transaction_filter_bar` (`List<WalletEntity> wallets`).
- **Trang chủ (1):** `home_page` — năm `watchAllRows` → `watchAll` (ví ×3 :112, 157, 593 · giao dịch ×2 :152, 590 — vẫn **trên một dòng** `sl<WalletRepository>().watchAll(`),
  `StreamBuilder<List<WalletEntity>>` / `<List<TransactionEntity>>`, `_buildRecentTransactions(List<TransactionEntity>, …)`, **bỏ**
  `TransactionEntity.fromDrift(tx)` :459, `_tongTaiSan(List<WalletEntity>)` (thân giữ — `viTinhVaoTong`, quét 2 vế *tổng tài sản* còn
  canh).
- **Hoá đơn (6):** `bill_add_page` · `bill_edit_page` · `bill_actions` → `sl<WalletRepository>().getActive(`; `bill_payment_sheet`
  (`List<WalletEntity> wallets`, callback, `_vi`, `_viMacDinh`, `_dongVi`); `bill_page` · `bill_detail_page` → `sl<WalletRepository>().getAll(`
  cho `TransactionLookup` (hai tệp này không nhắc kiểu — chỉ đổi tên hàm). `DropdownButton<WalletEntity>`: `WalletEntity` là
  `Equatable` nên `value` khớp theo **giá trị**, không theo tham chiếu như hàng Drift (Drift data class cũng so theo giá trị) — hành
  vi không đổi; mọi ca test hiện có của bốn tệp Hoá đơn phải giữ xanh không đổi kỳ vọng.
- **Mục tiêu (3):** `goal_detail_page` (`getActive` ×3, `getById` ×2, hai hàm nhận `WalletEntity vi`), `phieu_nap_tien` · `phieu_rut_tien`
  (`List<WalletEntity>`, `DropdownButton<WalletEntity>`).

Quét 27 luật 1: **rút 14 tệp khỏi khoá `Wallet` và 1 khỏi `Transaction`**, rồi **xoá hai khoá** ở bước 7. Các widget đã cầm
Entity (`transaction_list_row`, `transaction_row_content`, `transaction_detail_sheet`, `the_chua_gan_danh_muc`…) không chạm.

## 7. Ngoài mảng: `core`, DI và `data/` của mảng khác

| Nơi | Đổi |
|---|---|
| `core/notification/notification_rules.dart` | `NotificationRuleInput.wallets: List<WalletEntity>`; `hangSapCanLoiThoi(…, List<WalletEntity>, …)` · `hangAmDaHoi(…, List<WalletEntity>)` (thân đọc `isDeleted` · `id` · `balance` · `allowNegative` — giữ); +import `wallet_entity.dart` (**ratchet 11 → 12**); docstring `hangCuaViDaXoa` *"bộ quét đọc ví qua `walletDao.getAll`"* → *"qua `WalletRepository.getAll`"* |
| `core/notification/notification_scanner.dart` | `typedef WalletsLoader = Future<List<WalletEntity>> Function(int, DateTime)` (**6 → 7**) |
| `core/notification/de_xuat_thong_bao_nguon.dart` | `mocGhiGiaoDichTu(List<TransactionEntity>)` — thân giữ nguyên kể cả vế `t.deletedAt == null` (4.0); nguồn map `.map(TransactionEntity.fromDrift)`; +import (**mục mới `: 1`**, thêm **cùng commit** — quét 25 đỏ *"đã sạch — rút"* nếu thêm trước). Không có test gọi thẳng hàm này (đo) — thêm **một** ca thuần: hàng `isDeleted` / hàng `deletedAt` bị bỏ, hàng ghi trong ngày được giữ |
| `core/di/injection_container.dart` (điểm ghép) | `loadWallets: (id, now) => sl<WalletRepository>().getAll(id)` (DI đã trong `duocDocMoiVi`); `loadViDaDung`, `loadViDaXoa`, `loadDotAm`, `loadWeekActivity` giữ DAO (trả id / mốc, không hàng) |
| `analytics/data/repositories/analytics_repository_impl.dart` | `vi` nạp thành `List<WalletEntity>` (`.map(WalletEntity.fromDrift)`) để truyền `du_bao_dong_tien`; `_laKhoanCamKet` **giữ** `Transaction` Drift (đọc `t.billId`) và gọi `khoaNhomCua(TransactionEntity.fromDrift(t), now: now)` tại chỗ; `dungKhoan`, `_dung` giữ `List<Transaction>` |
| `budget/data/repositories/budget_repository_impl.dart` | `lookupFor`: `wallets: (await localDataSource.getWallets(id)).map(WalletEntity.fromDrift)`; `budget_local_data_source` **không đổi** |
| `category/data/gan_danh_muc_nguon.dart` | `apDungGan`: tách điều kiện — `hienTai == null` → ném như cũ; rồi `before = TransactionEntity.fromDrift(hienTai)` (dòng đã có); rồi `!xetGan(before)` → ném cùng `StateError`. Thứ tự kiểm `null` **trước** `fromDrift` giữ nguyên. `demChuaGan` / `DongGanDanhMuc` nhận Entity ở nơi dựng |
| `bill/data/de_xuat_hoa_don_nguon.dart` | mục 4.5 |

**Không chạm (và vì sao):** `wallet/data/vi_trung_ten_nguon.banGhiBiGiuTuHang` nhận `Iterable<Wallet>` / `Transaction` / `Bill` Drift —
cổng đọc của ví cho engine đồng bộ (đợt 1 mục 7). `wallet/data/services/*` ghi qua DAO. `budget_local_data_source.getExpenses` /
`khoanThuocNganSach` nội bộ ngân sách. `core/sync/*`, `core/database/*`. `core/nen/lich_nen` không cầm hai kiểu này.

Sau đợt: `lib/core` (trừ `database`, `sync`) nhắc `Wallet` / `Transaction` = **0**; còn `AppNotification` 7 tệp (đợt Thông báo).

## 8. Test quét 27 · ratchet quét 25 · quét 2

**Quét 27** (`test/core/ui/presentation_domain_khong_kieu_drift_test.dart`):
- Luật 1 quét thêm `lib/core` trừ `core/database`, `core/sync`. **Ba điểm ghép (`core/di`, `core/router`, `core/nen`) không được miễn
  trừ** — khác ratchet quét 25: điểm ghép được biết mọi mảng, nhưng biết qua repository / Entity, không qua kiểu hàng Drift (đo
  2026-10-14: cả ba = 0, và vì `conChoKieu` chỉ-được-giảm nên từ nay DI không được nêu tên kiểu hàng Drift nữa; DI gọi DAO trả id /
  mốc thì vẫn được — mẫu chỉ bắt **tên kiểu**). `conChoKieu` nạp hiện trạng ở bước 1: `Wallet` +2 (`core/notification/notification_rules`,
  `notification_scanner`), `Transaction` +1 (`de_xuat_thong_bao_nguon`), `AppNotification` +7 (phụ lục A). Ca tiền đề thêm một khẳng
  định: phép quét thấy ≥ 1 tệp `core/`.
- `mauKieu` thành `\b<Kiểu>(\?|>| [a-z_][A-Za-z0-9_]*\b|,|\)|;|\.fromJson)` — ca tiền đề thêm `as Wallet;` · `Wallet.fromJson(` khớp,
  `WalletEntity.fromDrift(` không khớp. Luật 2 cấm cả dòng `import 'package:drift…'` (ca tiền đề: 2 tệp đã chờ).
- Mỗi bước rút tệp đã sạch; bước 7 **xoá khoá** `Wallet` / `Transaction` — từ đó nhắc tới là đỏ ngay như `Bill`. `conChoDomain`
  12 → **8**. Trước commit bước 1: bản sai có chủ ý (bỏ `notification_rules` khỏi danh sách) phải đỏ.

**Ratchet quét 25** (`conChoCoreImport`, là **trần**): bước 1 nâng `notification_rules` 11 → **12**, `notification_scanner` 6 → **7**, chú
thích `// 2026-10-14 G88 gạch 3 đợt 2: Wallet (Drift, không tính) → WalletEntity (features/wallet/data/models, tính); về 0 ở gạch 5.`;
mục mới `'lib/core/notification/de_xuat_thong_bao_nguon.dart': 1` **cùng commit** bước 6. Câu luật tăng viết lại ở **mọi** chỗ đang chép
(grep `không bao giờ vì` + `chính mảng` trên `test/`, `docs/`, `CLAUDE.md` — ít nhất chú thích `sync_engine` trong test, G88 gạch 4,
spec đợt 1 mục 8): *"Tăng chỉ khi thay một kiểu Drift bằng Entity trong lộ trình G88 gạch 3; không bao giờ vì ghép một mảng mới
vào `core` — ba số ấy về 0 ở gạch 5."*

**Quét 2** (`test/features/wallet/wallet_picker_sources_test.dart`):
- Chuỗi nhận diện: `WalletRepository>().getActiveRows(` → `getActive(`; `getAllRows(` / `watchAllRows(` → `getAll(` / `watchAll(`;
  `tepDocViQuaTruong` regex → `\.(getAll|watchAll)\(`, **thêm** vế loại trừ dòng chứa `ThongBaoNguon>()` bên cạnh hai vế có sẵn
  (`TransactionRepository>()` / `CategoryManagementRepository>()`) — không thêm là `them_giao_dich_nguon` (bộ chọn ví) bị gắn nhãn
  *đọc mọi ví* vì dòng `sl<ThongBaoNguon>().getAll(` của hàng chờ D1; ca tiền đề mới: `them_giao_dich_nguon` **không** nằm trong
  `tepDocViQuaTruong()`. Bước 3–6 test nhận **cả hai** dạng (cũ ∨ mới); bước 7 bỏ dạng cũ.
- `duocDocMoiVi` **+6**, lý do đọc từ mã lúc thi công (dự kiến): `features/ai_edge/data/nguon_goi_so.dart` (gói số khối Nhận xét
  truyền **mọi** ví kể cả lưu trữ — bất biến ⑤ `CLAUDE.md`), `cong_cu_vi.dart` · `cong_cu_muc_tieu.dart` (tool AI kể ví / ví nguồn
  mục tiêu có thể đã lưu trữ), `features/wallet/presentation/bloc/wallet_cubit.dart` (Quản lý ví thấy cả hai nhóm),
  `features/wallet/presentation/pages/wallet_add_page.dart` (kiểm trùng tên — ví lưu trữ vẫn giữ chỗ), `features/wallet/data/services/default_account_data_initializer.dart`
  (seed đếm ví đã có kể cả lưu trữ). Mục nào đọc mã thấy lý do khác thì ghi lý do thật; mục nào hoá ra là **bộ chọn** thì là lỗi có
  sẵn — ghi G mới, không sửa lén.
- Docstring tệp test: *"tên có hậu tố `Rows`"* → *"`getActive` / `getAll` / `watchAll`"*.

## 9. Đối chiếu luật kiến trúc và lộ trình G88

| Luật / gạch | Khớp? | Ghi chú |
|---|---|---|
| Mục 8: Entity → `data/models/` | ✓ | `wallet_entity.dart` nhận `fromDrift`, không tệp mới |
| Mục 4: domain không Drift | ✓ (4 tệp rút) | `transaction_lookup`, `doc_cau_giao_dich`, `gan_hang_loat`, `dien_san_bien_dong` ở lại vì `Category` — đợt Danh mục |
| Mục 4: `core` không import `features/` (ratchet) | ⚠️ +3, có lý do | quyết định 1; về 0 ở gạch 5 |
| Mục 4: lối chuyển tiếp | 10 → **4** | còn Danh mục 3 + `ghiPhanHoi` |
| Quét 22 (presentation không DAO) | ✓ | không thêm lối DAO; `conCho` vẫn rỗng |
| Quét 23 (≤ 1.200 dòng) | ✓ | lớn nhất 1.132 (`them_giao_dich_cubit`, không thêm dòng) |
| Quét 25 (vị trí tệp, soi gương test) | ✓ | hai test đổi tên ở cùng thư mục; `wallet_entity_test` ở `test/features/wallet/data/models/` |
| Quét 2 (nguồn ví) | ✓ mở rộng | +6 phân loại; `laBoChonVi` giữ 5 tệp |
| G88 gạch 3 | **tiến** | thống nhất **3/5** mảng có Entity (Hoá đơn, Ví, Giao dịch); còn Danh mục (chưa Entity) → Thông báo |
| G88 gạch 4 (`core` → `features`) | 40 → 43 tạm | gạch 5 trả |

## 10. Kiểm thử và nghiệm thu

**Thứ tự thi công** (mỗi bước một commit, toàn bộ test xanh; *"thêm trước, rút sau"*):

1. Quét 27 mở rộng `core` + siết `mauKieu` / luật 2, danh sách chờ hiện trạng; ratchet +1 ×2 + câu luật mới. Bản sai thử đỏ.
2. `TransactionEntity` + `billId` / `deletedAt` chỉ đọc + `transaction_entity_test`; `WalletEntity.fromDrift` (dời `_toEntity`) +
   `wallet_entity_test`; `TransactionLocalDataSource.getAll` / `watchAll` + test.
3. Hai repository **thêm** `getActive` / `getAll` / `watchAll` (giữ sáu lối Rows tạm); hai test rows **chuyển** + đổi tên; `nguon_doc_gia`;
   quét 2 nhận cả hai dạng + 6 phân loại.
4. Domain 7 tệp (+ record 4.5) + 4 tệp `data/` map tại chỗ + fixture test domain; rút 4 tệp khỏi `conChoDomain`.
5. Giao diện: Giao dịch (Cubit · state · nguồn · 2 trang · 2 widget) → Trang chủ → Hoá đơn 6 tệp → Mục tiêu 3 tệp, + fixture; rút 15
   mục (14 tệp — `home_page` ở cả hai khoá) khỏi `conChoKieu`.
6. `core/notification` 3 tệp + DI `loadWallets` + ca thuần `mocGhiGiaoDichTu`; ratchet mục mới; rút 3 tệp `core` khỏi danh sách chờ.
7. **Rút** sáu lối Rows (interface + impl); xoá khoá `Wallet` / `Transaction` quét 27; quét 2 bỏ dạng cũ; bỏ override Rows ở fake (≤ 32 tệp);
   docstring `them_giao_dich_nguon`, chú thích `add_transaction_page:125`, khối *"Bốn lối CHUYỂN TIẾP"* ở `wallet_repository.dart`.
8. Tài liệu + số đo + nghiệm thu máy ảo.

**Không đổi kỳ vọng ca nào**; fixture Drift đặt `deletedAt:` để tả xoá (`gan_hang_loat_test` `_gd(deletedAt:)`) **giữ nguyên nghĩa** vì
Entity nay có `deletedAt` (4.0). `flutter test` tăng đúng số ca mới (đếm khi xong), `flutter analyze` **20**.

**Nghiệm thu máy ảo `FlowMoney_16G`** (`-gpu host`, bản debug, demo mode 12:00, cuộn giữ-rồi-thả, cắt 100 px thanh trạng thái):
"trước" = bản **đang cài** (`b0164475…` = mã `a085deb0`, `lib/` chưa đổi) — không dựng lại; "sau" = bản mới. Đổi bản xác nhận bằng
`dumpsys package com.flowmoney.flowmoney | grep lastUpdateTime` **và** SHA-1 APK (bài học bàn giao). Màn: Trang chủ (tổng tài sản,
giao dịch gần đây) · Sổ giao dịch + lọc theo ví + thẻ *chưa có danh mục* · Thêm giao dịch (bộ chọn ví, thẻ gợi ý) · Hoá đơn Thêm /
Sửa / bảng Thanh toán · Mục tiêu chi tiết phiếu Nạp / Rút · Ngân sách chi tiết · Phân tích *Dự báo 30 ngày* · Trung tâm thông báo
sau một lượt quét · Quản lý ví · Gắn danh mục (C1). Mục tiêu **0 px khác**, vàng thuần 0. Hai phép đo không chụp: Nhập nhanh *"45k
tiền mặt"* điền đúng ví (`doc_cau_giao_dich` đổi kiểu); thời gian `rows.map(TransactionEntity.fromDrift)` cho toàn sổ trên bản sao CSDL
máy ảo (test tool `--run-skipped`, chép cả `-wal` / `-shm`) — ghi số vào tài liệu, **không tối ưu trước khi đo** (Trang chủ / Sổ nay
map mọi hàng mỗi lần phát; trước đây chỉ N hàng hiển thị).

**Phép đo kết luận:** `grep -rlE "\bWallet(\?|>| [a-z_]+\b|,|\))" lib/features/*/presentation lib/features/*/domain lib/shared lib/core`
= 0 ngoài `core/database`, `core/sync`; cùng mẫu cho `Transaction`; `grep -rn "getActiveRows\|getAllRows\|watchAllRows\|getRowById"
lib` chỉ còn `CategoryManagementRepository`.

## 11. Ngoài phạm vi — quan sát, không sửa

- `goal/domain/goal_auto_deposit_runner.dart` cầm `AppDatabase` + `package:drift` — đợt Mục tiêu dời về `data/services/` (cùng mùi
  `BillAutoPayRunner`).
- `analytics_repository_impl` đọc `db.transactionDao` / `db.walletDao` / `db.billDao` thẳng — mảng Phân tích, chưa có lịch.
- `TransactionEntity` vẫn không mang `status` / `provider` / `bankTranId` / `bankCasoId` — không chỗ đổi kiểu nào đọc (đo từng tệp); mở
  rộng khi một chỗ đọc thật cần, không mở trước (đợt này mở đúng hai trường có chỗ đọc thật — 4.0).
- Lối `…Rows` của Danh mục (3) + `TaiPhanBoNguon.ghiPhanHoi` — đợt Danh mục.
- `vi_trung_ten_nguon.banGhiBiGiuTuHang` cố ý ở Drift.

## 12. Tài liệu cập nhật khi xong

Grep theo từ khoá quyết định cũ trên `docs/` + `CLAUDE.md` + chú thích `lib/`: `getActiveRows|getAllRows|watchAllRows|getRowById|lối chuyển
tiếp|10 lối|chính mảng`. Dự kiến: `docs/KIEN_TRUC_CLIENT_APP.md` (mục 4 bảng presentation bỏ vế Ví / Giao dịch, *"10 lối"* → 4; mục 6
mô tả quét 27 — phạm vi `core`; mục 9 *thống nhất 3/5*), `docs/CLIENT_APP_KNOWN_GAPS.md` (G88 gạch 3 đợt 2 đóng + số đo; gạch 4 số
**43** + câu luật mới; bảng tóm tắt; dòng *Cập nhật*), `docs/PROJECT_CONTEXT.md` (mục 14 khối mới; *"10 lối"*; mốc test), `CLAUDE.md`
(hàng *presentation*: 4 lối + chuỗi một dòng `getActive(` / `getAll(` / `watchAll(`; hàng *quản lý ví* ④ *"`getActive` cho bộ chọn"*;
hàng *hoá đơn* câu nợ `de_xuat_hoa_don` đã trả; mốc test; dòng ⭐), spec đợt 1 (mục 5 / 11 ghi nợ đã trả), `docs/NOTIFICATION_FEATURE.md`
/ `docs/bill/BILL_DOCUMENTATION.md` nếu nhắc `walletDao.getAll` loader hay `GoiYHoaDonPhanHoi`, chú thích `hangCuaViDaXoa`,
`add_transaction_page.dart:125`, `them_giao_dich_nguon.dart` docstring.

## Phụ lục A — Danh sách chờ luật 1 sau đợt (`features/` bỏ tiền tố)

**Wallet, Transaction:** khoá **xoá** (bước 7). Trước đợt: Wallet 14 — `bill/presentation/pages/bill_add_page` · `bill_edit_page` ·
`bill/presentation/widgets/bill_actions` · `bill_payment_sheet` · `goal/presentation/pages/goal_detail_page` ·
`goal/presentation/widgets/chi_tiet_muc_tieu/phieu_nap_tien` · `phieu_rut_tien` · `home/presentation/pages/home_page` ·
`transaction/presentation/bloc/them_giao_dich_cubit` · `them_giao_dich_state` · `transaction/presentation/pages/add_transaction_page` ·
`transaction_page` · `transaction/presentation/widgets/them_giao_dich/bang_chon_vi` · `transaction_filter_bar`; Transaction 1 — `home_page`;
`core/notification/notification_rules` · `notification_scanner` (Wallet) · `de_xuat_thong_bao_nguon` (Transaction) — nạp ở bước 1, rút ở bước 6.

**Category (20, không đổi):** như phụ lục A spec đợt 1.

**AppNotification (2 + 7):** `notification/presentation/pages/notification_center_page` · `notification/presentation/widgets/notification_panel`
+ `lib/core/notification/hoc_gio_thong_bao` · `nhap_bien_dong` · `nhap_bien_lai` · `nhap_phien_ngan_hang` · `notification_rules` ·
`notification_scanner` · `thong_bao_nguon` (đo 2026-10-14; rút ở đợt Thông báo / gạch 5).

**Goal, Budget, Bill:** 0.

## Phụ lục B — `conChoDomain` sau đợt (8)

`ai_edge/domain/ap_dung_ke_hoach` · `ai_edge/domain/hang_danh_muc` · `category/domain/ban_sao_mac_dinh` · `category/domain/gan_hang_loat`
(Category) · `goal/domain/goal_auto_deposit_runner` · `transaction/domain/dien_san_bien_dong` (Category) · `transaction/domain/doc_cau_giao_dich`
(Category) · `transaction/domain/transaction_lookup` (Category). Rút: `transaction/domain/khoan_lap` · `home/domain/thu_chi_thang` ·
`analytics/domain/du_bao_dong_tien` · `bill/domain/de_xuat_hoa_don`.

## Phụ lục C — 20 lời gọi sáu lối `…Rows` trong `lib` (đo 2026-10-14)

| Lối | Chỗ gọi |
|---|---|
| `WalletRepository.getActiveRows` (7) | `bill_actions:25` · `bill_add_page:106` · `bill_edit_page:88` · `goal_detail_page:230, 325, 384` · `them_giao_dich_nguon:160` |
| `WalletRepository.getAllRows` (2) | `bill_page:90` · `bill_detail_page:86` |
| `WalletRepository.watchAllRows` (4) | `home_page:112, 157, 593` · `transaction_page:137` |
| `WalletRepository.getRowById` (2) | `goal_detail_page:190, 205` |
| `TransactionRepository.getAllRows` (2) | `them_giao_dich_nguon:178, 304` |
| `TransactionRepository.watchAllRows` (3) | `home_page:152, 590` · `transaction_page:140` |

## Phụ lục D — Test đổi fixture / fake (đo 2026-10-14)

- Dựng `Wallet(` (6): `category/presentation/category_test_fakes` · `bill/presentation/widgets/bill_payment_sheet_test` ·
  `core/notification/notification_rules_goal_wallet_test` · `notification_deeplink_test` · `notification_scanner_test` ·
  `analytics/du_bao_dong_tien_test`.
- Dựng `Transaction(` (6): `category/presentation/gan_danh_muc_page_test` · `bill/domain/de_xuat_hoa_don_test` ·
  `category/domain/gan_hang_loat_test` · `home/thu_chi_thang_test` · `transaction/domain/khoan_lap_test` · `transaction/data/them_giao_dich_nguon_test`.
- Fake `implements WalletRepository` / `TransactionRepository` (32 tệp, phần lớn `noSuchMethod`): bỏ override `…Rows` nếu có
  (`category_test_fakes`, `them_giao_dich_nguon_test`, `wallet_cubit_total_test`, `nguon_doc_gia`); thêm `getActive` / `getAll` /
  `watchAll` ở fake nào trang đang đi qua.
- 27 tệp cầm `List<Wallet>` / `List<Transaction>` — đổi kiểu, kỳ vọng giữ.
