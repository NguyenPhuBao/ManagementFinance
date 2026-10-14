# Thống nhất Entity cho mảng Hoá đơn — G88 gạch 3, đợt 1/4

**Ngày:** 2026-10-14 · **Nhánh:** `TranQuangDat` · **HEAD lúc viết:** `2437c935` · **Trạng thái:** người dùng duyệt sáu
phần trong chat (phạm vi, ratchet, phương án, phần 1–6), chờ duyệt bản viết. Kế hoạch: `docs/superpowers/plans/2026-10-14-entity-hoa-don.md`
(gitignore) — viết sau khi bản này được duyệt.

Đợt này là đợt **đầu** của G88 gạch 3 (`docs/CLIENT_APP_KNOWN_GAPS.md`, người dùng chốt hướng A ngày 2026-10-11: *giao
diện không cầm hàng Drift, từng mảng một đợt — Hoá đơn → Giao dịch + Ví → Danh mục → Thông báo*). Người dùng app **không
thấy gì đổi**; cái đổi là từ repository trở lên, mảng Hoá đơn chỉ còn **một** kiểu dữ liệu (`BillEntity`), và test quét 27
giữ cho nó không quay lại.

> ✅ **Số đo sau thi công (2026-10-14, HEAD `a085deb0`; đếm bằng máy, đừng cộng dồn).** Thi công xong 6 commit mã
> (`2a912871` quét 27 + ratchet · `f0db5cc6` `BillEntity` + companion · `1299f6f4` `paymentsOf` · `bad1ff73` Thêm / Sửa chở
> `BillDraft` · `94142dea` runner về `data/services` · `a085deb0` `Bill` → `BillEntity` mọi nơi).
> Tệp `domain/` import `core/database`: **24 → 12** (Hoá đơn 11 → **1** — `de_xuat_hoa_don.dart` còn cần `Transaction` +
> `GoiYHoaDonPhanHoi`, nợ đợt Giao dịch; mục 5 spec ghi "11 → 0" là sai, xem khối 🔧 kế hoạch). `Bill` Drift ở `presentation/` + `shared/`:
> **0**. Lối chuyển tiếp trả hàng Drift: **11 → 10**. Entity: **5/14** mảng. `flutter test` 7.047 → **7.056** (+9 skip);
> `flutter analyze` **20**. Dòng: `bill_entity.dart` 192 · `bill_draft_companion.dart` 78 · `bill_repository_impl.dart` 426.
> Máy ảo `FlowMoney_16G` (APK trước `7af9d631…`, sau `b0164475…`): **15/15 cặp ảnh giống hệt SHA-1**; trả → hoàn tác,
> bỏ qua → hoàn tác đạt. Trang Hoá đơn có **hai** tab (kế hoạch ghi ba). Thẻ B2 *"Có vẻ là khoản lặp"* không hiện ở cả hai bản →
> không kiểm được bằng ảnh. Bằng chứng đổi bản yếu: chỉ `Success` của `adb install` + hai APK khác SHA-1, không `dumpsys`.
> `Iterable<Bill>` ở `wallet/data/vi_trung_ten_nguon.dart` còn lại **cố ý** (mục 7).

## 1. Quyết định đã chốt (trong chat, 2026-10-14)

| # | Câu hỏi | Chốt | Lý do ngắn |
|---|---|---|---|
| 1 | Ranh giới | **Domain + giao diện + 8 tệp ngoài mảng** — `BillEntity` là kiểu duy nhất từ repository trở lên | Domain nhận `Bill` Drift thì trang phải đổi ngược entity về hàng Drift trước khi gọi — vô nghĩa. Luật mục 4 `KIEN_TRUC`: domain không Drift |
| 2 | Ratchet quét 25 (+1 ở `notification_rules`, `notification_scanner`, `lich_nen`) | **Nâng ba số đúng +1, ghi lý do**; câu *"lần tăng DUY NHẤT"* thành luật *tăng chỉ khi thay kiểu Drift bằng Entity của chính mảng đã import* | Không thêm mảng mới vào `core`; ba dòng về 0 ở gạch 5 (dời `core/notification`). Giữ thứ tự gạch 3 → 4+5 |
| 3 | Phương án | **Repository là cửa duy nhất**: không thêm hàm `…Rows` chuyển tiếp cho Hoá đơn | Domain không "song song" được theo kiểu; hai cửa chỉ là cách 1 cộng nợ |
| 3a | Đường Thêm / Sửa | Event và repository chở **`BillDraft`** + `id` / `idaccount` / `now`; repository tự dựng `BillsCompanion` | Form đã có `BillDraft`; đường Sửa giữ nghĩa *"chỉ ghi cột form sở hữu"*; ánh xạ Drift thuộc tầng data |
| 3b | `bill_auto_pay_runner.dart` | **Dời về `data/services/`** (dời nguyên văn cả `BillAutoPayEvent`) | Cầm `AppDatabase` = bộ điều phối (hàng mục 8); để ở domain thì *"domain Hoá đơn không Drift"* không về 0 |
| 4 | Test quét 27 | Canh theo **tên kiểu** (không theo import), bỏ dòng chú thích trước khi so; danh sách chờ theo kiểu, chỉ-được-giảm | 7/10 tệp giao diện Hoá đơn còn cầm `Wallet` / `Category` (nợ đợt Ví, Danh mục) nên luật "không import `core/database`" không đo được tiến độ của đợt này |
| 5 | Nghiệm thu | So ảnh trước / sau trên máy ảo, mục tiêu 0 px khác (như đợt tách trang) | Không đổi giao diện; so ảnh là phép đo rẻ nhất cho "không đổi" |
| 6 | Lối thi công | Hỏi sau khi có kế hoạch (inline · agent con) | Bộ nhớ *thực thi kế hoạch* |

## 2. Hiện trạng đo được (2026-10-14, HEAD `2437c935`)

Mọi số đếm bằng `grep` / `wc -l`, chạy từ `src/Client-app`.

| Thứ | Số | Ghi chú |
|---|---|---|
| Tệp `bill/domain/` import `core/database` | **11 / 14** | chỉ để lấy kiểu `Bill` (`bill_draft` thêm `drift` cho `BillsCompanion`; `bill_auto_pay_runner` cầm `AppDatabase`) |
| Tệp `presentation/` + `shared/` nhắc kiểu `Bill` | **8** | `bill_bloc` · `bill_event` · `bill_state` · `bill_page` · `bill_detail_page` · `bill_edit_page` · `bill_actions` · `bill_payment_sheet` (+ `bill_add_page` dựng `BillsCompanion`) |
| Tệp giao diện Hoá đơn import `core/database` | **10 / 10** | 7 tệp còn cầm `Wallet` (`getActiveRows` / `getAllRows`) hoặc `Category` (`loadBangTraTen` / `getRowById`) — **ở lại** sau đợt |
| Tệp ngoài mảng nhận `List<Bill>` / gọi hàm domain Hoá đơn trên hàng Drift | **8** | `core/notification/notification_rules` · `notification_scanner` · `core/nen/lich_nen` · `ai_edge/domain/goi_so_hoa_don` · `hang_hoa_don` · `analytics/domain/du_bao_dong_tien` (6 đổi chữ ký) + `analytics/data/repositories/analytics_repository_impl` · `premium/data/dem_dang_hoat_dong` (2 map tại chỗ). `wallet/data/vi_trung_ten_nguon` cố ý ở Drift (mục 7) |
| `core` (trừ `database`, `sync`) nhắc kiểu `Bill` | 4 tệp | ba tệp trên + `router/app_router` (`s.extra as Bill?` ×2) |
| Ratchet quét 25 | `notification_rules` 10 · `notification_scanner` 5 · `lich_nen` 3 | import `core/database` **không** tính; import `features/bill/data/models/` **có** tính |
| Fake `BillRepository` trong test | **19** tệp | gồm `test/helpers/nguon_doc_gia.dart` (`HoaDonRowsGia` trả thẳng hàng DAO) |
| Tệp test dựng `Bill(` bằng tay | **31** | đổi `Bill(` → `BillEntity(`; 32 tệp khác chỉ `BillsCompanion` ghi CSDL thật — giữ |
| Tệp giao diện lớn nhất của mảng | `bill_add_page` 866 dòng | trần 1.200 (quét 23) còn xa |
| `flutter test` · `flutter analyze` | **7.047** (+9 skip) · **20** | đo sáng 2026-10-14 sau G93 |

Tiền lệ đã có: 19 tệp `domain/` của Mục tiêu / Ví / Ngân sách / Giao dịch import `../data/models/<x>_entity.dart` — domain
cầm Entity ở `data/models/` là nếp của dự án, không phải điều mới.

## 3. Quy tắc đổi mã

1. **Đổi kiểu, không đổi thân.** `BillEntity` mang **đúng tên trường** của hàng Drift (`dueDate`, `payStatus`, `isPaid`,
   `deletedAt`, `generatedFromBillId`, `anchorDay`…) nên thân hàm domain, widget, luật thông báo giữ từng dòng; chỉ chữ ký và
   import đổi. Mọi ca test giữ nguyên kỳ vọng — chỉ fixture đổi `Bill(` → `BillEntity(`.
2. **Ánh xạ Drift chỉ ở tầng data** (`bill/data/`): `BillEntity.fromDrift` và hai hàm dựng `BillsCompanion` (rời `BillDraft`).
   `domain/` và `presentation/` của Hoá đơn **không** import `core/database` cho kiểu `Bill` nữa.
3. **Dời nguyên văn** khi chuyển tệp (runner): giữ docstring, thứ tự, tên riêng tư; chỉ sửa import và hai lượt đọc hoá đơn.
4. `dart format` **chỉ** chạy trên tệp mới (`bill_entity.dart`, test quét 27, test entity). Tệp cũ viết dòng dài; format là
   đổi cả tệp (vấp 2026-10-14 với `phien_dieu_phoi_that.dart`, 208 dòng nhiễu).
5. Mỗi bước là TDD: test đỏ trước (quét 27 đỏ trên 8 + 11 tệp; test entity; test repository), rồi mã, rồi xanh.
6. Không đụng `core/sync/*`, `core/database/daos/*` (trừ một dòng chú thích), `wallet/data/*`, `bill_payment_conflict_resolver`.

## 4. `BillEntity` và `BillRepository`

### 4.1 Tệp mới `features/bill/data/models/bill_entity.dart` (hàng *Entity, model* mục 8)

- Lớp bất biến; **25 trường** = 28 cột của bảng `Bills` (đếm `other_tables.dart` 2026-10-14) trừ ba cột lỗi đồng bộ
  `syncRetryCount` · `syncError` · `syncBlockedUntil` (không chỗ nào ngoài `core/sync` đọc): `id` · `idaccount` · `walletId?` ·
  `categoryId?` · `name` · `amount` · `startDate?` · `dueDate` · `payStatus` · `isPaid` · `timeNotification?` · `isRecurrence` ·
  `timeRecurrence` · `recurrence` · `icon` · `colour` · `note` · `generatedFromBillId?` · `periodEnd?` · `autoPayEnabled` ·
  `anchorDay?` · `deletedAt?` · `isDeleted` · `syncStatus` · `updatedAt`. Khuôn `GoalEntity`: `fromDrift(Bill)`, `copyWith`,
  `==` / `hashCode` theo mọi trường (test so danh sách bằng `equals`).
- **Không** có `toCompanion` trên entity — đường ghi đi qua `BillDraft` (4.3). Test `bill_entity_test`: `fromDrift` chép đủ
  trường — **đếm cột của bảng bằng máy** (`db.bills.$columns.length − 3` so với số trường qua `toString` / bảng ánh xạ)
  chứ không chép số 25.

### 4.2 `BillDraft` thành Dart thuần

`toInsertCompanion` / `toUpdateCompanion` (cùng docstring *"Companion cho đường SỬA — chỉ những cột form thật sự sở hữu"*)
chuyển **nguyên văn** thành hàm riêng tư của `BillRepositoryImpl` (`_companionTao(draft, id, idaccount, now)` /
`_companionSua(...)`). `bill_draft.dart` bỏ `import 'package:drift/drift.dart'` và `core/database`; giữ `periodEndHieuLuc`,
`anchorDayHieuLuc`, `dateError`, `_legacyRecurrence`. Chú thích `other_daos.dart:216` trỏ tên hàm mới.

### 4.3 Chữ ký `BillRepository`

| Trước | Sau |
|---|---|
| `Stream<List<Bill>> watchBills(id)` · `Future<List<Bill>> getBills(id)` · `Future<Bill?> getById(id)` | cùng tên, `BillEntity` |
| `Future<Map<String, Transaction>> paymentsOf(id)` | `Map<String, TransactionEntity>` (`TransactionEntity.fromDrift` có sẵn) |
| `addBill(BillsCompanion)` · `editBill(BillsCompanion)` | `addBill(BillDraft draft, {required String id, required int idaccount, required DateTime now})` · `editBill(...)` cùng tham số |
| `payBill({required Bill bill, …})` | `required BillEntity bill` — bản thi hành vẫn đọc lại hàng tươi theo `bill.id` (chốt bấm-hai-lần) |
| — | **mới** `Future<List<BillEntity>> getUpcoming(int idaccount, {required int days, required DateTime now})` (bọc `billDao.getUpcoming`) |
| — | **mới** `Future<List<BillEntity>> getAllIncludingDeleted(int idaccount)` (bọc `billDao.getTatCaKeCaDaXoa`) |

Hai hàm mới để DI và runner **thôi gọi `billDao` để đọc**. `BillLocalDataSource` giữ nguyên (tầng data, cầm Drift là đúng).
`bill_repository_impl.dart` 410 → ≈ 500 dòng (không trần ở `data/`). Sau đợt, lối chuyển tiếp `BillRepository.getById` trong
danh sách *"11 lối"* của `KIEN_TRUC` mục 4 không còn là lối chuyển tiếp → **10**.

## 5. Domain (11 tệp) và runner

- Mười tệp `bill/domain/` đổi `import '../../../core/database/app_database.dart'` → `'../data/models/bill_entity.dart'` và
  `Bill` → `BillEntity` ở chữ ký: `anHanCua` · `denLuotTuTra` · `kyTruocCua` / `chuoiKyCua` · `kyKeTiepCua` /
  `cacKyChieuCua` · `_song` / `_gocCua` / `_khoa` / `_nhomSong` / `kyTrungCanGo` / `kyCungKyDaDong` · `daCoKhoanChi` /
  `daBoQua` / `conPhaiTra` · `BillSchedule.fromBill` · `billDisplayStatusOf` / `BillSections` / `splitBills` /
  `summarizeBills` · `deXuatHoaDon(hoaDon:)`. Bốn hằng `kBill*` ở lại `bill_pay_status.dart` (DAO cần cho SQL, import đã
  trong ratchet `other_daos` 1).
- **`bill_auto_pay_runner.dart` → `features/bill/data/services/bill_auto_pay_runner.dart`**, dời nguyên văn cả
  `BillAutoPayEvent`. Bên trong: `db.billDao.getAll` → `repository.getBills`; `db.billDao.getTatCaKeCaDaXoa` →
  `repository.getAllIncludingDeleted`; **giữ** `db.walletDao.getById`, `db.billDao.getGeneratedFrom`;
  `repository.payBill(bill: entity)`. Ba nơi import đổi đường (`notification_rules`, `notification_scanner`, DI) — số dòng
  ratchet không đổi. Test `bill_auto_pay_runner_test.dart` dời theo sang `test/features/bill/data/services/` (quét 25 soi
  gương thư mục).
- **Kết quả đo:** `grep -rl core/database lib/features/bill/domain` = **0**.

## 6. Giao diện Hoá đơn

- **Bloc (3 tệp, thôi import `core/database`):** `BillState.bills: List<BillEntity>`, `payments: Map<String, TransactionEntity>`;
  `AddBillEvent` / `EditBillEvent`: `{required BillDraft draft, required String id, required int idaccount, required DateTime now}`;
  `PayBillEvent.bill: BillEntity`; `bill_bloc` `emit.onEach<List<BillEntity>>`, chuyển `draft` + ids cho repository.
- **Trang / widget — đổi kiểu, giữ `Key` và chữ:** `bill_add_page` :205 và `bill_edit_page` :183 gửi event mới thay vì
  `draft.toInsertCompanion` / `toUpdateCompanion`; `BillEditPage.bill: BillEntity?`, `BillDetailPage.bill: BillEntity?`;
  router `s.extra as BillEntity?` (2 chỗ). `bill_page` (`List<BillEntity>`, `Map<String, TransactionEntity>`,
  `_moKhoanChi(TransactionEntity)` bỏ dòng `TransactionEntity.fromDrift(tx)`), `bill_detail_page` (`_bill`, `_chuoi`,
  `_khoanChi`), `bill_actions` (4 hàm), `bill_payment_sheet.bill`.
- **Không chạm:** `the_khoan_lap` (chỉ cầm `Category`), `bill_delete_page`, `bill_status_header`, `bill_grace_selector`,
  `bill_status_visuals`.
- **Ở lại, cố ý:** 7 tệp vẫn import `core/database` cho `Wallet` / `Category` — vào danh sách chờ theo kiểu của quét 27
  (phụ lục A). Đợt Ví / Danh mục rút.

## 7. Tám tệp ngoài mảng và DI

| Nơi | Đổi |
|---|---|
| `core/notification/notification_rules.dart` | `NotificationRuleInput.bills: List<BillEntity>`; `billLeadDays(BillEntity)`; +import `bill_entity.dart` (**ratchet 10 → 11**); đường import runner → `data/services/` |
| `core/notification/notification_scanner.dart` | `typedef BillsLoader = Future<List<BillEntity>> Function(...)` (**5 → 6**); đường import runner |
| `core/nen/lich_nen.dart` | `bills: List<BillEntity>` (**3 → 4**) |
| `core/di/injection_container.dart` (điểm ghép, không trần) | hai `loadBills` → `sl<BillRepository>().getUpcoming(id, days: NotificationScanner.cuaSoSuKien.inDays, now: now)`; `lichNenKeTiep(bills: await sl<BillRepository>().getBills(id))`; `BillAutoPayRunner` import đường mới. **Giữ** `billDao.markOverdue` (DAO ghi, không qua repository) |
| `core/router/app_router.dart` | `s.extra as BillEntity?` ×2 |
| `ai_edge/domain/goi_so_hoa_don.dart` · `hang_hoa_don.dart` | `List<BillEntity>`; **bỏ** import `core/database` (chỉ cầm `Bill`) |
| `analytics/domain/du_bao_dong_tien.dart` | `hoaDon: List<BillEntity>` (2 chữ ký); **giữ** import `core/database` vì còn `Wallet` (4 chỗ) — nợ đợt Ví |
| `analytics/data/repositories/analytics_repository_impl.dart` | `db.billDao.watchAll(id)` → `.map((rows) => rows.map(BillEntity.fromDrift).toList())` tại chỗ; `List<BillEntity>? hoaDon`; giữ constructor `(db)` |
| `premium/data/dem_dang_hoat_dong.dart` | `(await db.billDao.getAll(id)).map(BillEntity.fromDrift).where(conPhaiTra).length` |

**Không chạm (và vì sao):** `wallet/data/vi_trung_ten_nguon.banGhiBiGiuTuHang` nhận `Iterable<Bill>` / `Goal` /
`Transaction` Drift — bộ đổi *"hàng đang chờ đẩy"* cho engine đồng bộ và `ThaViBiGiu`, chỉ đọc `id` / `walletId` /
`generatedFromBillId`, không gọi hàm domain (hai mảng kia đã có Entity mà nó vẫn nhận Drift — đúng vai). `core/sync/*`
dựng `BillsCompanion` và đọc hằng. `core/database/daos` đọc hằng. `bill_payment_conflict_resolver` chỉ cầm `billId`.
`wallet/data/services/{gop_vi_service,tha_vi_bi_giu}` ghi `BillsCompanion` qua DAO.

Sau đợt: `lib/core` (trừ `database`, `sync`) nhắc kiểu `Bill` = **0**.

## 8. Test quét 27 và ratchet quét 25

**`test/core/ui/presentation_domain_khong_kieu_drift_test.dart`** — docstring ghi *"thứ hai mươi bảy"*; khuôn quét 22/25
(ca tiền đề thấy ≥ 14 mảng; danh sách chờ chỉ-được-giảm; sạch mà quên rút thì đỏ):

1. **`lib/features/*/presentation/` + `lib/shared/` không nhắc tên kiểu hàng Drift.** Kiểu canh: `Bill`, `BillsCompanion`,
   `Wallet`, `Category`, `Transaction`, `Goal`, `Budget`, `AppNotification` và `<Kiểu>sCompanion` tương ứng. Mẫu
   `\b<Kiểu>(\?|>| [a-z_]+\b|,|\))` trên nội dung **đã bỏ dòng chú thích** (`//`, `///`; chuỗi ký tự không bỏ — quét cũ
   đọc cả chú thích, vùng này docstring hay nhắc *"đối tượng `Bill`"*). `Bill` / `BillsCompanion`: **không có** danh sách
   chờ. Danh sách chờ theo kiểu (phụ lục A): sau đợt Wallet 14 · Category 20 · Transaction **1** (ba tệp Hoá đơn rút nhờ
   `paymentsOf`) · AppNotification 2.
2. **`lib/features/*/domain/` không import `core/database`.** Danh sách chờ (phụ lục B): sau đợt **11** tệp (hôm nay 13
   ngoài Hoá đơn, `ai_edge` rút 2). Hoá đơn 11 → 0.

**Cách đưa vào mà nhánh không đỏ giữa chừng:** viết test ở bước đầu với danh sách chờ gồm **cả** `Bill` (8 tệp +
`bill_add_page` cho `BillsCompanion`) và 11 tệp `bill/domain` — xanh ngay; mỗi bước rút tệp đã sạch (quên rút là đỏ);
bước cuối **xoá khoá `Bill` / `BillsCompanion`** khỏi danh sách chờ — từ đó hai kiểu ấy không có chỗ chờ. Bằng chứng test
canh được: trước khi commit bước đầu, thử bản sai có chủ ý (bỏ một tệp khỏi danh sách) và thấy đỏ.

**Ratchet quét 25** (`conChoCoreImport`): ba số +1 kèm chú thích
`// 2026-10-14 G88 gạch 3: Bill (Drift, không tính) → BillEntity (features/bill/data/models, tính) — cùng mảng đã import; về 0 ở gạch 5.`
Câu *"Lần tăng DUY NHẤT"* ở chú thích `sync_engine` sửa thành luật: *"Tăng chỉ khi thay một kiểu Drift bằng Entity của
chính mảng tệp ấy đã import; không bao giờ vì một mảng mới."*

## 9. Đối chiếu luật kiến trúc và lộ trình G88

| Luật / gạch | Khớp? | Ghi chú |
|---|---|---|
| Mục 8: Entity → `data/models/` | ✓ | `bill/data/models/bill_entity.dart` — thư mục mới cho mảng, cùng khuôn 4 mảng có sẵn |
| Mục 8: bộ điều phối → `data/services/` | ✓ | runner dời; `goal_auto_deposit_runner` cùng mùi, **để đợt Mục tiêu** |
| Mục 4: domain không Drift | ✓ (Hoá đơn) | 11 → 0; các mảng khác vào danh sách chờ luật 2 |
| Mục 4: `core` không import `features/` (ratchet) | ⚠️ +3, có lý do | quyết định 2; về 0 ở gạch 5 |
| Quét 22 (presentation không DAO) | ✓ | không thêm lối DAO nào; `conCho` vẫn rỗng |
| Quét 23 (≤ 1.200 dòng) | ✓ | lớn nhất 866 |
| Quét 25 (vị trí tệp, soi gương test) | ✓ | runner + test dời cùng thư mục |
| Quét 2 (nguồn ví) | ✓ | không đổi lời gọi `getActiveRows` / `getAllRows` |
| G88 gạch 3 | **tiến** | Entity 4/14 → **5/14**; lối chuyển tiếp 11 → 10 |
| G88 gạch 4 (37 dòng `core` → `features`) | −0/+3 tạm | gạch 5 trả |
| G88 gạch 6 (đổi tên `data/services`) | ✓ | thêm một tệp vào đúng thư mục sẽ đổi tên |

## 10. Kiểm thử và nghiệm thu

- **Thứ tự thi công (mỗi bước một commit, toàn bộ test xanh ở mỗi commit):** (1) quét 27 với danh sách chờ gồm cả Hoá
  đơn (mục 8) + ratchet quét 25 → (2) `bill_entity.dart` + test → (3) repository (chữ ký, hai hàm mới, companion rời
  `BillDraft`) + fake `test/helpers` + fixture test repository → (4) domain 10 tệp + fixture test domain, rút 10 tệp khỏi
  danh sách chờ luật 2 → (5) runner dời (+ test dời), rút tệp thứ 11 → (6) Bloc + trang + router + fixture test giao diện,
  rút 9 tệp khỏi luật 1 → (7) tám tệp ngoài mảng + DI + fixture, rút `ai_edge` ×2 và `Transaction` ×3 → (8) xoá khoá
  `Bill` / `BillsCompanion` khỏi danh sách chờ → (9) tài liệu.
- **Không đổi kỳ vọng ca nào**; `flutter test` tăng đúng số ca mới (entity, repository, quét 27 — đếm khi xong), analyze
  **20**.
- **Nghiệm thu máy ảo `FlowMoney_16G`** (`-gpu host`, bản debug, cuộn giữ-rồi-thả, cắt 100 px thanh trạng thái): trang
  Hoá đơn ba tab · chi tiết (chuỗi kỳ, khoản chi đã trả) · thêm · sửa · bảng thanh toán · trả → hoàn tác · bỏ qua → hoàn
  tác · thẻ *Có vẻ là khoản lặp* · khối Nhận xét · Phân tích *Dự báo 30 ngày* · trung tâm thông báo sau một lượt quét.
  Mục tiêu **0 px khác**, vàng thuần 0. Tài khoản Premium trên máy có hoá đơn Netflix (G87) — dùng được.
- **Phép đo kết luận:** `grep -rl core/database lib/features/bill/domain` = 0; `grep -rlE "\bBill(\?|>| [a-z_]+\b|,|\))"
  lib/features/*/presentation lib/shared lib/core --include=*.dart` = 0 ngoài `core/database`.

## 11. Ngoài phạm vi — quan sát, không sửa

- `goal/domain/goal_auto_deposit_runner.dart` cầm `AppDatabase` (`db.goalDao`, `db.walletDao`, `db.update(db.goals)`) —
  cùng mùi với runner Hoá đơn; đợt Mục tiêu dời.
- `analytics/domain/du_bao_dong_tien.dart` còn `Wallet` Drift (4 chỗ); `transaction_lookup`, `thu_chi_thang`… — danh sách
  chờ luật 2 (phụ lục B).
- Lối `…Rows` của Ví / Danh mục / Giao dịch (10 lối) — rút ở đợt tương ứng.
- `vi_trung_ten_nguon.banGhiBiGiuTuHang` cố ý ở Drift (mục 7).

## 12. Tài liệu cập nhật khi xong

`docs/KIEN_TRUC_CLIENT_APP.md` (mục 1 câu *"Entity chỉ có ở…"*, mục 4 *"11 lối"* → 10 và *"hoá đơn trả hàng Drift"*, mục 6
bảng quét +**27**, mục 9 *"Entity 4/14"* → 5/14, mục 10 điểm 5) · `docs/CLIENT_APP_KNOWN_GAPS.md` (G88 gạch 3: Hoá đơn xong
+ số đo mới + ba số ratchet; bảng tóm tắt; dòng *Cập nhật*) · `docs/PROJECT_CONTEXT.md` (mục 14 khối mới; :807 *"11 lối"*)
· `docs/bill/BILL_DOCUMENTATION.md` (:585 đường runner; :1079 tên hàm companion; bảng test :1187 đường test) ·
`docs/AI_AGENT_ARCHITECTURE.md`:298 chữ ký `summarizeBills` · `CLAUDE.md` (bảng test quét +27, *"số tiếp theo là 28"*, hàng
*Đụng vào hoá đơn* — payload / `BillEntity`, hàng *presentation* — 10 lối) · chú thích `other_daos.dart:216`.

## Phụ lục A — Danh sách chờ luật 1 (đo 2026-10-14, trước đợt; `features/` bỏ tiền tố)

**Wallet (14):** `bill/presentation/pages/bill_add_page` · `bill_edit_page` · `bill/presentation/widgets/bill_actions` ·
`bill_payment_sheet` · `goal/presentation/pages/goal_detail_page` · `goal/presentation/widgets/chi_tiet_muc_tieu/phieu_nap_tien` ·
`phieu_rut_tien` · `home/presentation/pages/home_page` · `transaction/presentation/bloc/them_giao_dich_cubit` ·
`them_giao_dich_state` · `transaction/presentation/pages/add_transaction_page` · `transaction_page` ·
`transaction/presentation/widgets/them_giao_dich/bang_chon_vi` · `transaction_filter_bar`.

**Category (20):** `bill/presentation/pages/bill_add_page` · `bill_detail_page` · `bill_edit_page` ·
`bill/presentation/widgets/the_khoan_lap` · `budget/presentation/bloc/budget_state` · `budget/presentation/pages/budget_form` ·
`category/presentation/pages/category_add_page` · `category_group_page` · `category_page` · `gan_danh_muc_page` ·
`category/presentation/widgets/chon_danh_muc_gan_sheet` · `home/presentation/pages/home_page` ·
`transaction/presentation/bloc/them_giao_dich_cubit` · `them_giao_dich_state` · `transaction/presentation/pages/add_transaction_page` ·
`choose_category_page` · `transaction_page` · `transaction/presentation/widgets/khoi_tach` · `sheet_them_phan` ·
`transaction_filter_bar`.

**Transaction (4 → 1 sau đợt):** ~~`bill/presentation/bloc/bill_state`~~ · ~~`bill/presentation/pages/bill_detail_page`~~ ·
~~`bill_page`~~ · `home/presentation/pages/home_page`.

**AppNotification (2):** `notification/presentation/pages/notification_center_page` · `notification/presentation/widgets/notification_panel`.

**Goal, Budget:** 0.

## Phụ lục B — Danh sách chờ luật 2 (đo 2026-10-14, trước đợt; ngoài Hoá đơn)

`ai_edge/domain/ap_dung_ke_hoach` · ~~`goi_so_hoa_don`~~ · `hang_danh_muc` · ~~`hang_hoa_don`~~ ·
`analytics/domain/du_bao_dong_tien` · `category/domain/ban_sao_mac_dinh` · `gan_hang_loat` · `goal/domain/goal_auto_deposit_runner` ·
`home/domain/thu_chi_thang` · `transaction/domain/dien_san_bien_dong` · `doc_cau_giao_dich` · `khoan_lap` · `transaction_lookup`
— 13 trước, **11** sau đợt (hai tệp gạch rút).
