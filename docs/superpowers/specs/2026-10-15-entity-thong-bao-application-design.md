# Thống nhất Entity cho mảng Thông báo, dời `core/notification` về `features/notification/`, tầng `application/` — G88 gạch 3 (đợt 4/4) + gạch 5 + gạch 6

**Ngày:** 2026-10-15 · **Nhánh:** `TranQuangDat` · **HEAD lúc viết:** `a4daec33` · **Trạng thái:** người dùng duyệt **bốn chốt** (phạm vi,
gạch 6, tên tầng, cổng mảng) và **bốn phần** thiết kế trong chat cùng ngày; **bản viết chờ soát**. Kế hoạch:
`docs/superpowers/plans/2026-10-15-entity-thong-bao-application.md` (gitignore, viết sau khi duyệt spec). Lối thi công (inline · agent con)
hỏi sau khi có kế hoạch (bộ nhớ *thực thi kế hoạch*).

Đợt **thứ tư và cuối** của G88 gạch 3 (`docs/CLIENT_APP_KNOWN_GAPS.md`; lộ trình người dùng chốt 2026-10-11: Hoá đơn → Giao dịch + Ví →
Danh mục → **Thông báo**), gộp **gạch 5** (`core/notification` là một mảng nghiệp vụ nằm trong `core`) và **gạch 6** (đổi tên `data/services/`,
người dùng chốt 2026-10-11 *"ghép vào đợt gạch 4 + 5, tên chốt ở spec đợt ấy"*). Tiền lệ trực tiếp: ba spec Entity
`2026-10-14-entity-hoa-don`, `2026-10-14-entity-giao-dich-vi`, `2026-10-15-entity-danh-muc`, cả ba thi công xong. Người dùng app
**không thấy gì đổi** trên bất kỳ màn nào; cái đổi là kiểu dữ liệu từ repository trở lên (Thông báo chỉ còn **một** kiểu `NotificationEntity`),
vị trí 35 tệp (`core/notification` không còn), tên một thư mục ở bốn mảng (`data/services/` → `application/`), và ba test quét học thêm năm điều.

**Vì sao Entity và gạch 5 không tách được** (phát hiện quyết định phạm vi): quét 27 luật 1 quét `presentation/` · `shared/` · `lib/core` (trừ
`database`, `sync`) · `features/*/domain/` — **miễn `features/*/data/`**. Trong 9 tệp chờ của `AppNotification`, bốn tệp (`notification_scanner`,
`nhap_bien_dong`, `nhap_bien_lai`, `nhap_phien_ngan_hang`) chỉ **dựng Companion** đúng vai tầng dữ liệu — dời chúng khỏi `core` là hợp lệ, không
cần Entity; làm Entity mà chưa dời thì phải gỡ Companion khỏi bốn tệp đang nằm ở `core` một cách vô ích, rồi đợt sau dời lại. Ngược lại dời trước
thì `notification_rules` / `hoc_gio_thong_bao` rơi vào `domain/` đỏ ngay luật 1 + 2. Nên **một spec, Entity trước, dời sau**.

---

## 1. Quyết định đã chốt (trong chat, 2026-10-15)

| # | Câu hỏi | Chốt | Lý do ngắn |
|---|---|---|---|
| 1 | Phạm vi đợt 4/4 | **Entity + gạch 5, một spec**; Entity trước, dời sau | Lý lẽ ở lời mở; "chỉ Entity" sửa cùng tệp hai lần; "dời trước" phải mở lại danh sách chờ quét 27 |
| 2 | Gạch 6 (đổi tên `data/services/`) | **Gộp — task cuối, một commit riêng** | Đợt đẻ 8 tệp dịch vụ Thông báo vào đúng thư mục ấy; đổi tên sau là dời hai lần |
| 3 | Tên và vị trí tầng mới | **`features/<x>/application/`**, ngang `data` · `domain` · `presentation`; **chiều một hướng** (mục 8) | Tên người dùng gợi ý 2026-10-11; đo: 3 repository impl + 1 tệp domain gọi vào `data/services` → hai tệp đổi chỗ để chiều đúng (mục 7) |
| 4 | Cổng `ThongBaoNguon` | **`ThongBaoRepository` + `ThongBaoRepositoryImpl`**, tách tệp ở `data/repositories/` | Cổng đọc / ghi của **cả mảng** là repository; Thông báo là mảng duy nhất chưa có; luật 4 mới của quét 27 phủ tự động |
| P1 | Entity | **`NotificationEntity`**, **14** trường = 15 cột − `osScheduledId`; `Equatable`; `fromDrift`; **`chenLai(NotificationEntity)`** thay `insertIfAbsent(Companion)`; record **`SuKienNhatKy`** 3 trường thay `List<AppNotificationEvent>`; `AppNotificationEvent` vào `kieuDrift` | Khuôn sáu Entity có sẵn (English theo tên bảng); cột chết 0 đọc 0 ghi; chỗ dựng Companion duy nhất ở giao diện là *Hoàn tác* D1 |
| P2 | Bản đồ 35 tệp + 4 chỗ dời ngoài mảng + 2 ranh giới | Mục 6, 7; `phien_dieu_phoi_that` vào `diemGhep` quét 25; `ten_tep_bien_lai` → `core/ocr` | Bảng mục 8 `KIEN_TRUC`; `core/ocr` cần hàm thuần ấy; `KIEN_TRUC` mục 4 đã gọi điều phối phiên là điểm ghép thứ tư |
| P3 | Luật và test quét | Hàng `application/` ở mục 4 / 8 `KIEN_TRUC`; quét 25 đổi 5 chỗ; quét 27 đổi 4 chỗ (mục 9) | Luật 4 nối vào quét 27 (không mở số 28 — tiền lệ C1 đợt 3); cấm `data` / `domain` import `application` |
| P4 | Thi công / nghiệm thu | **8 bước** (mục 11); bước 3 **một commit** đổi kiểu trục Thông báo; nghiệm thu **máy ảo**, chụp bộ "trước" ở **đầu** kế hoạch | Tiền lệ D1 đợt 3; bài học đợt 3: APK trước bị build đè |

Tiền lệ giữ nguyên từ ba đợt trước, không hỏi lại: domain + giao diện + **mọi** tệp ngoài mảng cùng đổi; repository là cửa duy nhất; **đổi kiểu
không đổi thân** (ngoại lệ có tên ở mục 3); **dời nguyên văn** (`git mv`); `dart format` chỉ tệp mới; mỗi bước TDD, mỗi bước một commit, toàn bộ
test xanh ở mỗi commit; mọi số đếm bằng máy, ghi kèm ngày.

## 2. Hiện trạng đo được (2026-10-15, HEAD `a4daec33`)

Mọi số đếm bằng `grep` / `find` / công cụ Grep, chạy từ `src/Client-app`. Mẫu *"nhắc kiểu"* là `mauKieu` của quét 27.

| Thứ | Số | Ghi chú |
|---|---|---|
| `conChoKieu['AppNotification']` | **9** tệp | 2 giao diện (`notification_center_page` 718 dòng · `notification_panel` 161) + 7 `core/notification` (phụ lục A) |
| Trong 9 tệp: chỉ dựng Companion / đọc hàng cho chính mình (vai data) | **4** | `notification_scanner` · `nhap_bien_dong` · `nhap_bien_lai` · `nhap_phien_ngan_hang` → `application/`, ngoài phạm vi luật 1 |
| Cần Entity thật | **5** + cổng | 2 trang; `thong_bao_nguon` (57 dòng, interface + bản Drift một tệp, 12 lối); 3 hàm `hang*` ở `notification_rules` (:884 · :906 · :914; tệp 1.065 dòng); `deXuatThongBao` ở `hoc_gio_thong_bao` (:125; 243 dòng) |
| Trường của `AppNotification` giao diện / luật đang đọc | **14** | `id · idaccount · kind · dedupeKey · title · body · severity · subjectType · subjectId · deeplink · createdAt · readAt · dismissedAt · osDeliveredAt` |
| Cột `osScheduledId` | **0** đọc · **0** ghi trong `lib` | `grep -rn "\.osScheduledId\b\|osScheduledId:" lib` ngoài `.g.dart` = 0 — cột chết, mục 12 |
| Chỗ giao diện dựng Companion | **1** | `notification_center_page.dart:558` `dao.insertIfAbsent(item.toCompanion(true))` — *Hoàn tác* sau vuốt xoá cứng hàng D1 |
| Trường của `AppNotificationEvent` mà `deXuatThongBao` đọc | **3** | `dedupeKey` (5 lần) · `suKien` (4) · `luc` (9); bảng có 6 cột (`id · idaccount · dedupeKey · suKien · luc · osId`) |
| Tệp `lib` ngoài `core/database` / `core/sync` nhắc `AppNotificationEvent` / Companion | **2** | `hoc_gio_thong_bao` (kiểu) · `nhat_ky_thong_bao` (Companion) — khoá chờ tạm ở bước 1, rút ở bước 4 / 6 |
| `core/notification` | **35** tệp · **6.869** dòng | gồm `os/` 6 · `prefs/` 2; bảng đích ở mục 6 |
| Tệp `lib` ngoài mảng import `core/notification` | **26** | 22 qua `core/notification/` + 4 tệp `lib/core` qua đường tương đối `../notification/` (`phien_dieu_phoi_that` · `injection_container` · `chay_nen` · `kho_anh_quet`) — phụ lục A |
| Dòng import ở điểm ghép | DI **18** · `main.dart` **9** · router **3** · `chay_nen` **2** | chỉ đổi đường dẫn |
| `test/core/notification` | **40** tệp | 35 + `os/` 3 + `prefs/` 2 — đích ở phụ lục C; test ngoài thư mục ấy import `core/notification`: **22** tệp |
| Ratchet quét 25 `conChoCoreImport` | **43** → dự kiến **18** | 7 mục thông báo = 25 dòng rút (`notification_rules` 12 · `scanner` 7 · `reminder_scheduler` 2 · `nhap_bien_lai` 2 · `de_xuat_thong_bao_nguon` 1 · `nhap_bien_dong` 1); còn `sync_engine` 7 · `lich_nen` 4 · `sync_payload_normalizer` 2 · `noi_bo_nghe_ket_qua_day` 2 · `kho_anh_quet` 1 · `wallet_dao` 1 · `other_daos` 1 |
| `notification_rules` import ngoài mảng không hợp `domain/` | **3** dòng | `budget/presentation/widgets/budget_visuals.dart` (chỉ dùng `budgetHealthOf` :423) · hai runner (chỉ dùng `GoalAutoDepositEvent` / `BillAutoPayEvent` — lớp dữ liệu thuần khai trong tệp runner) |
| Chỗ dùng `budgetHealthOf` / `BudgetHealth` | **5** tệp | rules · `budget_visuals` · `budget_detail_view` · `budget_tabs_view` · `home_budget_card` |
| Chỗ import hai lớp `*Event` | **5** tệp | DI · rules · scanner · hai runner |
| Tệp nhắc `ThongBaoNguon` (**từ trọn** `\bThongBaoNguon\b` — lượt đo chuỗi con dính `DeXuatThongBaoNguon`) | **10** lib + **7** test | phụ lục B (3 trong 7 test chỉ nhắc `ThongBaoNguonDrift`); `notification_settings_page` và `de_xuat_thong_bao_nguon` chỉ dùng `DeXuatThongBaoNguon` — **không đổi**; tài liệu được theo dõi 19 dòng (`KIEN_TRUC` 4 · `CLAUDE.md` 1 · `PROJECT_CONTEXT` 1 · `KNOWN_GAPS` 1 · spec cũ 12) |
| `features/*/data/services/` | **12** tệp lib · **3** test | ví 6 · danh mục 3 · hoá đơn 2 · mục tiêu 1 (mục 8); 48 tệp lib / test mang đường dẫn ấy; tài liệu được theo dõi 57 dòng |
| Ai gọi vào `data/services` ngược chiều (nếu nó thành tầng trên `data`) | **3** repository impl + **1** domain | `bill` / `goal` / `transaction_repository_impl` → `so_du_vi_service`; `transaction/domain/doc_cau_giao_dich` → `category_suggestion_engine` (thuần: Entity + `core/category/category_name`) |
| `<dynamic>` trần ở 12 tệp `data/services` + 8 tệp Thông báo sắp vào `application/` | **0** | luật 3 quét 27 mở rộng sang `application/` không cần danh sách chờ |
| Interface `features/*/data/repositories/*_repository.dart` (không `_impl`) import `core/database` / `package:drift` | **0 / 10** | luật 4 mới quét 27 — đo lại 2026-10-15 khớp bàn giao đợt 3; sau đợt 0 / 11 |
| `is <Kiểu Drift> &&` / `\|\|` trên dòng mã ngoài `.g.dart` | **0** | `mauKieu` mở rộng không đổi kết quả hiện tại; cần bản sai ở ca tiền đề |
| Tệp `.dart`: `presentation/` + `shared/` · `core` trừ `database` / `sync` · `features/*/domain/` · `features/*/data/` | **206 · 77 · 163 · 105** | sàn quét 27 hiện tại (> 100 · > 20 · > 80 · > 50) vẫn đúng sau đợt: `core` 77 − 35 + 3 = **45** > 20; `data` 105 − 12 + ~17 = ~110 |
| `lib/core/auth/phien_dieu_phoi_that.dart` | import `NotificationScanner` (:11, :21, :49) | không nằm trong `diemGhep` (3 tệp) lẫn `conChoCoreImport` → dời là đỏ luật 5 nếu không chốt |
| `lib/core/ocr/kho_anh_quet.dart` | import `ten_tep_bien_lai.dart` (:18; dùng 4 lần) | đã có 1 dòng `features/` trong ratchet; dời tệp ấy vào mảng là +1, ngược *Luật tăng* |
| Test đọc Kotlin / manifest (`*_noi_day_test`, `android_manifest_receivers_test`) | đường dẫn **từ cwd** (`android/app/src/main/...`) | dời test không vỡ — nhưng `bien_lai_noi_day_test` :51 và `phien_ngan_hang_noi_day_test` :105 còn đọc `lib/core/notification/kenh_*.dart` **bằng chuỗi**, và quét 5 :79 / :107 đọc chuỗi `features/bill/data/services/…` → ba chuỗi đổi ở bước 6 / 7 |
| Fake `implements ThongBaoNguon` trong `test/` | **0** | test dùng bản Drift thật qua `dangKyNguonDocGia` (`test/helpers/nguon_doc_gia.dart`) |
| 4 test quét kiến trúc (22 · 23 · 25 · 27) | xanh (10 ca) | chạy 2026-10-15 trước khi viết |
| `flutter test` · `flutter analyze` | **7.069** (10 skip, 0 fail) · **20** | đo ở `0042086c` (bàn giao đợt 3) |

## 3. Quy tắc đổi mã

1. **Đổi kiểu, không đổi thân.** `NotificationEntity` mang đúng tên 14 trường mọi tệp sắp đổi đang đọc (mục 2), nên thân hàm, widget, luật giữ
   từng dòng; chỉ chữ ký, import, generic, fixture và **tên cổng** (`ThongBaoNguon → ThongBaoRepository`, `ThongBaoNguonDrift →
   ThongBaoRepositoryImpl`) đổi. **Ngoại lệ có tên (duy nhất):** `notification_center_page._xoaCoHoanTac` :558 `dao.insertIfAbsent(item.toCompanion(true))`
   → `dao.chenLai(item)` — Entity không có `toCompanion`, ánh xạ ngược nằm ở tầng data (4.3).
2. **Ánh xạ Drift chỉ ở tầng data, mỗi kiểu MỘT định nghĩa:** `NotificationEntity.fromDrift` (mới); `companionTu(NotificationEntity)` (mới, 4.3);
   hàng sự kiện → record `SuKienNhatKy` ở `DeXuatThongBaoNguon.tai` (một chỗ, 4.4).
3. **Map tại chỗ** ở `application/` đọc DAO thẳng (quy tắc 4 đợt 3): `notification_scanner` gọi ba hàm `hang*` thì
   `.map(NotificationEntity.fromDrift).toList()` **một lần** trước khi gọi, không mở repository; bốn tệp vai data (mục 2) **giữ hàng Drift và Companion**.
4. **Dời nguyên văn bằng `git mv`**, chỉ sửa dòng `import` / `export` / `part` và đường dẫn trong docstring của chính tệp; người soát đọc bằng
   `git diff -M` (mục 11). Không "tiện tay" đổi tên lớp, hằng, hàm khi dời — kể cả `kKenhBienDong`, `kTepHangCho`, mã hành động (`hanhDongHoan` nằm
   trong lịch AlarmManager đã đặt — bẫy ghi ở `notification_actions.dart`).
5. `dart format` **chỉ** trên tệp mới (`notification_entity.dart`, `notification_entity_companion.dart`, `thong_bao_repository.dart`,
   `thong_bao_repository_impl.dart`, `budget_health.dart`, test mới); tệp dời là tệp cũ — không format.
6. Mỗi bước TDD, mỗi bước một commit, toàn bộ test xanh ở mỗi commit.
7. **Không đụng:** `core/database/*` (trừ chú thích đường dẫn ở `notification_event_dao.dart` :11), `core/sync/*`, mã Kotlin, `AndroidManifest.xml`,
   `proguard-rules.pro`, thân mọi luật thông báo và bộ quét (`NOTIFICATION_FEATURE.md` mục 7 — mười ba cái bẫy đều ở phần hệ điều hành / lịch, không
   bước nào của đợt chạm chúng), khoá chống trùng, `SyncEntityType` (quy tắc 9 `CLAUDE.md`: bảng thông báo cục bộ — Entity không đổi điều đó).

## 4. `NotificationEntity`, repository, ánh xạ

### 4.1 Tệp mới `features/notification/data/models/notification_entity.dart`

Lớp bất biến, `Equatable`, **14 trường chỉ đọc** cùng tên và kiểu với cột: `String id` · `int idaccount` · `String kind` · `String dedupeKey` ·
`String title` · `String body` · `String severity` · `String? subjectType` · `String? subjectId` · `String? deeplink` · `DateTime createdAt` ·
`DateTime? readAt` · `DateTime? dismissedAt` · `DateTime? osDeliveredAt`. **Bỏ** `osScheduledId` (cột chết — mục 2, mục 12). `kind` và `severity`
giữ `String` (đổi kiểu không đổi thân: giao diện so `item.kind == NotificationKind.bienDongSoDu.name`). `factory NotificationEntity.fromDrift(AppNotification)`
là định nghĩa duy nhất; `const` constructor cho fixture test. Test `notification_entity_test.dart`: đếm cột bảng = 15 (`grep -cE "Column\s+get"` trên
`notification_table.dart`) và Entity = 14 — đổi bảng mà quên Entity là đỏ; đẳng thức; `fromDrift` chép đủ 14 trường kể cả `null`.

### 4.2 `ThongBaoRepository` — `features/notification/data/repositories/thong_bao_repository.dart`

Interface **chỉ import Entity và Dart thuần** (luật 4 mới quét 27 canh). **12 lối**, 11 giữ tên và tham số của `ThongBaoNguon`:

| Lối | Chữ ký sau đợt | Đổi gì |
|---|---|---|
| `watchUnreadCount(int idaccount)` | `Stream<int>` | — |
| `watchFeed(int idaccount, {int limit = 50, List<String>? kinds, bool chiChuaDoc = false})` | `Stream<List<NotificationEntity>>` | kiểu trả |
| `getAll(int idaccount)` | `Future<List<NotificationEntity>>` | kiểu trả |
| `watchDemBienDong(int idaccount)` | `Stream<int>` | — |
| `markRead(String id)` · `markAllRead(int idaccount)` · `markUnread(String id)` | `Future<void>` | — |
| `khoaChuaDoc(int idaccount)` | `Future<List<String>>` | — |
| `dismiss(String id)` · `khoiPhuc(String id)` | `Future<void>` | — |
| **`chenLai(NotificationEntity hang)`** | `Future<bool>` — `true` chỉ khi hàng thật sự được ghi (`insertOrIgnore`, giữ hợp đồng `insertIfAbsent`) | **thay** `insertIfAbsent(AppNotificationsCompanion)`; chỗ gọi duy nhất ngoài data: *Hoàn tác* D1 |
| `xoaCung(int idaccount, String dedupeKey)` | `Future<int>` | — |

`thong_bao_repository_impl.dart`: `class ThongBaoRepositoryImpl implements ThongBaoRepository`, nhận `NotificationDao`, chuyển tiếp 1–1 như
`ThongBaoNguonDrift` nay; `watchFeed` / `getAll` map `fromDrift`; `chenLai` gọi `_dao.insertIfAbsent(companionTu(hang))`. DI:
`sl.registerLazySingleton<ThongBaoRepository>(() => ThongBaoRepositoryImpl(sl<AppDatabase>().notificationDao))` thay dòng :467. Docstring đầu tệp
`thong_bao_nguon.dart` (lý do cổng ra đời, spec bịt điểm rò mục 4.4) chuyển sang interface mới, cập nhật câu *"Mảng thông báo không có tầng data"*.
Tệp `thong_bao_nguon.dart` **xoá**; test `thong_bao_nguon_test.dart` → `test/features/notification/data/repositories/thong_bao_repository_test.dart`
(đổi tên + thêm ca `chenLai`).

### 4.3 `companionTu` — `features/notification/data/models/notification_entity_companion.dart`

Tiền lệ `bill_draft_companion.dart`: hàm top-level `AppNotificationsCompanion companionTu(NotificationEntity)` dựng Companion **đủ 14 trường**
(kể cả `readAt` · `dismissedAt` · `osDeliveredAt` qua `Value(...)`) để *Hoàn tác* trả hàng về **y nguyên** như `toCompanion(true)` từng làm;
`osScheduledId` để `Value.absent()`. Test: `companionTu(fromDrift(row))` ghi lại rồi đọc ra bằng `fromDrift` phải `==` Entity gốc (vòng tròn),
canh bằng bản sai bỏ một trường.

### 4.4 `SuKienNhatKy` và `DeXuatThongBaoNguon`

Trong `hoc_gio_thong_bao.dart` (sẽ ở `domain/`): `typedef SuKienNhatKy = ({String dedupeKey, String suKien, DateTime luc});` — đúng ba trường hàm
đọc (mục 2); tiền lệ record 3 trường của đợt 2 (`spec entity-giao-dich-vi`). `deXuatThongBao({required List<SuKienNhatKy> nhatKy, required
List<NotificationEntity> thongBao, …})` — thân giữ nguyên (chỉ đọc ba trường ấy và `osDeliveredAt` · `dedupeKey` của thông báo).
`DeXuatThongBaoNguon.tai` map `db.notificationEventDao.getAll(idaccount)` → `[for (final e in rows) (dedupeKey: e.dedupeKey, suKien: e.suKien, luc: e.luc)]`
và `db.notificationDao.getAll(idaccount)` → `.map(NotificationEntity.fromDrift)` — hai phép map **một chỗ**; tệp này ở tầng data, được cầm hàng Drift.
Test `hoc_gio_thong_bao_test` (14,5 KB): fixture `AppNotificationEvent(` → record, `AppNotification(` → `NotificationEntity(`; kỳ vọng không đổi.

### 4.5 Chỗ gọi đổi tên

10 tệp lib (phụ lục B — đếm từ trọn): `sl<ThongBaoNguon>()` → `sl<ThongBaoRepository>()` **trên một dòng** (quét 22 nhận diện nguồn đăng ký DI theo tên lớp —
sửa chữ ở test ấy; quét 2 `wallet_picker_sources_test` nhắc tên cổng trong phân loại — sửa chữ). Tham số kiểu `ThongBaoNguon dao` ở
`notification_center_page` (`_danhSach`, `_doiTrangThaiDoc`, `_xoaCoHoanTac`) đổi kiểu, giữ tên biến `dao` (không đổi thân). `them_giao_dich_nguon`
:290 đọc `n.deeplink` · `n.kind` · `n.dismissedAt` — trường Entity cùng tên, thân giữ. Helper `test/helpers/nguon_doc_gia.dart` đăng ký
`ThongBaoRepositoryImpl`.

## 5. Hai tệp luật nhận Entity; bộ quét map tại chỗ

- `notification_rules.dart`: `hangSapCanLoiThoi(Iterable<NotificationEntity> hang, List<WalletEntity> wallets, int nguong)` ·
  `hangCuaViDaXoa(Iterable<NotificationEntity> hang, Set<String> viDaXoa)` · `hangAmDaHoi(Iterable<NotificationEntity> hang, List<WalletEntity> wallets)`
  — thân đọc `kind · dismissedAt · subjectId · subjectType · id`, giữ từng dòng. Import `app_database.dart` (:1) thay bằng `notification_entity.dart`;
  hai import runner (:5, :8) → `goal/domain/goal_auto_deposit.dart` (đã import :4) và `bill/domain/bill_auto_pay.dart` (đã import :6) sau mục 7.1;
  import `budget_visuals` (:9) → `budget/domain/budget_health.dart` (7.2); `tuan_iso` → `core/utils/tuan_iso.dart` (mục 6). Sau đó tệp **không
  import Flutter, Drift, `core/database`, `presentation/`, `application/`** — đủ điều kiện `domain/`.
- `notification_scanner.dart` :670 `final hang = await dao.getAll(idaccount);` → `.map(NotificationEntity.fromDrift).toList()` một lần; ba lời gọi
  `hang*` và hai dòng đọc `hang` phía dưới (:671 `subjectType` / `dismissedAt`, :678 `theoId[id]!.dedupeKey`) giữ nguyên. `_toCompanion`
  (`NotificationCandidate` → Companion) **giữ** — bộ quét ở `application/`.
- Test: `notification_rules_goal_wallet_test` (3 chỗ dựng `AppNotification(`) và `notification_panel_test` (1) → `NotificationEntity(`;
  `notification_scanner_test` (62,9 KB) không đổi kỳ vọng — chỉ import.

## 6. Bản đồ đích 35 tệp `core/notification` (và 3 tệp ở lại `core`)

Luật xếp theo bảng mục 8 `KIEN_TRUC`: hàm thuần → `domain/`; bọc DAO / API / tệp / kênh → `data/datasources/`; `*_nguon` · `*_store` → tệp rời `data/`
(tiền lệ 52 tệp rời không canh); bộ điều phối nhiều bước → `application/` (mục 8); hạ tầng không biết mảng → `core/<chủ đề>/`. Dời **nguyên văn**.

| Đích | Tệp (từ `core/notification/`) | Ghi chú |
|---|---|---|
| `features/notification/domain/` (10) | `notification_rules` · `hoc_gio_thong_bao` · `notification_deeplink` · `notification_actions` · `cham_hdh` · `su_kien_thong_bao` · `nhom_tu_khoa` · `prefs/notification_prefs` → `notification_prefs` · `phien_ngan_hang` · `os/os_scheduled_id` → `os_scheduled_id` | `os_scheduled_id` là hàm băm thuần (gói `crypto`, Dart thuần); `notification_prefs` giữ hai `switch` không `default` (bẫy `NOTIFICATION_FEATURE` — thêm loại là lỗi biên dịch, cố ý) |
| `features/notification/data/datasources/` (10) | `nhat_ky_thong_bao` · `hang_cho_su_kien` · `kho_bien_lai` · `kenh_bien_dong` · `kenh_phien_ngan_hang` · `os/os_notifier` · `os/os_notifier_native` · `os/os_notifier_stub` · `os/os_notifier_web` · `os/os_notifier_factory` (bỏ thư mục `os/`, giữ tiền tố) | `os_notifier_native` vẫn là tệp duy nhất import `flutter_local_notifications` (bẫy 7.7); `nhat_ky_thong_bao` vẫn là cửa ghi duy nhất bảng sự kiện; `kenh_*` là `MethodChannel` ↔ Kotlin (hằng tên kênh khớp tay — test `*_noi_day`) |
| `features/notification/data/` tệp rời (3) | `de_xuat_thong_bao_nguon` · `prefs/notification_prefs_store` → `notification_prefs_store` · `moc_phien_store` | tiền lệ `*_nguon` / `*_store` |
| `features/notification/data/repositories/` (1 → 2) · `data/models/` (2 mới) | `thong_bao_nguon` → `thong_bao_repository` + `thong_bao_repository_impl` · `notification_entity` · `notification_entity_companion` | mục 4 |
| `features/notification/application/` (8) | `notification_scanner` · `reminder_scheduler` · `badge_updater` · `notification_tap_router` · `nhap_bien_dong` · `nhap_bien_lai` · `nhap_phien_ngan_hang` · `mo_tu_tom_tat_bien_dong` | cầm DAO + Companion đúng vai; ngoài phạm vi luật 1 quét 27; `typedef BillsLoader` / `GoalsLoader` ở scanner cho scheduler dùng — cùng tầng |
| ở lại `core` (3) | `tuan_iso` → `core/utils/tuan_iso.dart` · `app_lifecycle_watcher` → `core/nen/app_lifecycle_watcher.dart` · `ten_tep_bien_lai` → `core/ocr/ten_tep_bien_lai.dart` | `tuan_iso` 0 import, `ai_edge` / `analytics` domain dùng (3 tệp); watcher là chỗ duy nhất bọc `WidgetsBinding` thành stream (nền = vòng đời, `core/nen`); `ten_tep_bien_lai` là hàm thuần mà `core/ocr/kho_anh_quet` cần — hàng *"kiểu / hàm Dart thuần hạ tầng `core` cần"* của mục 8 (tiền lệ `buoc_dang_xuat`, `category_name`) |

Đếm: 10 + 10 + 3 + 1 + 8 + 3 = **35** ✓. Thư mục `lib/core/notification/` **không còn**; `chuDeCore` của quét 25 bỏ `notification` (16 → 15).
Test soi gương theo thư mục (luật 6 quét 25) — 40 tệp, đích ở **phụ lục C**; ba test `*_noi_day` và `android_manifest_receivers_test` đọc Kotlin / manifest
từ cwd nên chỉ đổi import.

**Chiều import sau khi dời** (kiểm bằng máy ở bước 6): `domain/` chỉ import `domain/` (kể cả mảng khác: `bill`, `goal`, `budget`, `analytics`,
`ai_edge`), Entity ở `data/models/` (`bill` · `goal` · `budget` · `wallet` · `notification`), `core/utils/tuan_iso`, gói Dart thuần;
`data/datasources/` được `core/database`, plugin, `domain/`; `application/` được mọi thứ trừ widget; **không tệp `data/` / `domain/` nào import
`application/`** (luật 7 quét 25). Riêng `notification_deeplink` (domain) giữ hằng `nhanhThanhTab` đồng bộ **tay** với router — không đổi (bẫy hàng
*điều hướng* `CLAUDE.md`).

## 7. Bốn chỗ dời ngoài mảng (nguyên văn, chỉ đổi import)

1. **Hai lớp `*Event`** — `GoalAutoDepositEvent` (`goal_auto_deposit_runner.dart` :14–:39) → `goal/domain/goal_auto_deposit.dart` (cạnh `LoaiTrich`);
   `BillAutoPayEvent` (`bill_auto_pay_runner.dart` :13–:38) → `bill/domain/bill_auto_pay.dart` (cạnh `LoaiTuTra`). Lớp dữ liệu thuần, không import gì;
   docstring *"Cố ý không mang câu chữ…"* đi theo. 5 chỗ import đổi: DI · rules · scanner · hai runner (runner import domain của chính mảng — đúng chiều).
   Lý do: tệp runner sắp là `application/`, mà `notification_rules` ở `domain/` không được import `application/`.
2. **`budget_health.dart`** — `enum BudgetHealth`, `_cautionAt` / `_criticalAt`, `budgetHealthOf(BudgetEntity)`, `budgetHealthOfRatio` (`budget_visuals.dart`
   :12–:50) → `budget/domain/budget_health.dart` (thuần: chỉ `BudgetEntity`); `budget_visuals.dart` giữ `budgetHealthColour` · `budgetIconFor` ·
   `budgetColorFrom`, **import + `export 'package:…/budget/domain/budget_health.dart';`** nên 3 widget đang dùng không đổi (tiền lệ `export` ở
   `nhat_ky_thong_bao.dart`). `notification_rules` import domain. Test `budget_health_test.dart` (nay ở `test/features/budget/presentation/widgets/`)
   dời về `test/features/budget/domain/`, kỳ vọng không đổi.
3. **`category_suggestion_engine.dart`** → `category/domain/category_suggestion_engine.dart` — thuần (Entity + `category_suggestion` model +
   `core/category/category_name`), đo mục 2. 4 chỗ import đổi: DI · `transaction/domain/doc_cau_giao_dich` (hết lệch domain → `data/services`) ·
   `them_giao_dich_cubit` · `add_transaction_page`. Test `category_suggestion_engine_test` dời soi gương (`test/features/category/domain/`).
4. **`so_du_vi_service.dart`** → `wallet/data/so_du_vi_service.dart` (tệp rời tầng data, tiền lệ `vi_trung_ten_nguon.dart` cùng thư mục) — bộ ghi `balance`
   bọc DAO (bất biến ⑥ hàng *quản lý ví* `CLAUDE.md`), được 3 repository impl + `sync_engine` + DI gọi; nằm ở `application/` là `data` gọi ngược lên.
   Quét 6 (`so_du_mot_noi_ghi_test`) canh theo tên lớp `SoDuViService`, không đổi; test `so_du_vi_service_test` (nếu ở `data/services/`) dời theo.

Kiểm sau 7.1–7.4: `grep -rn "import.*data/services/" lib/features/*/domain lib/features/*/data/repositories` = 0.

## 8. Gạch 6 — `features/<x>/application/`

**18 tệp** vào `application/`: 10 từ `data/services/` — ví 5 (`default_account_data_initializer` · `dieu_chinh_so_du_service` · `gop_vi_service` ·
`tha_vi_bi_giu` · `vi_trung_ten_resolver`; `so_du_vi_service` ở lại `data/` — 7.4) · danh mục 2 (`default_category_seeder` · `personal_default_categories`;
`category_suggestion_engine` về `domain/` — 7.3) · hoá đơn 2 (`bill_auto_pay_runner` · `bill_payment_conflict_resolver`) · mục tiêu 1
(`goal_auto_deposit_runner`) — cộng 8 tệp Thông báo (mục 6). 3 test `test/features/{bill,category,goal}/data/services/` → `test/features/<x>/application/`;
48 tệp lib / test sửa đường dẫn. Thư mục `data/services/` **không còn ở mảng nào** (luật đọc: không tạo lại).

**`KIEN_TRUC` mục 4 — hàng mới:**

| Tầng | Trách nhiệm | Được phép import | Không được |
|---|---|---|---|
| `application/` | Bộ điều phối nhiều bước: ghi qua nhiều repository / DAO trong một giao tác, chạy nền, nhập hàng chờ, bộ quét | `data/` (repository, DAO, Entity, datasource), `domain/`, `core/`, `application/` mảng khác (bộ quét gọi hai runner) | widget; **không được `data/` hay `domain/` import ngược lên** (quét 25 luật 7) |

Chiều một hướng: `presentation` → `application` → `data` / `domain`; `presentation` vẫn được gọi thẳng `data` (repository). Mục 8: hàng *"Bộ điều phối
nhiều bước"* → `features/<x>/application/`, bỏ vế *"tầng application chưa đổi tên; không thêm tầng mới"*; thêm hàng test soi gương `test/features/<x>/application/`.
Mục 1 / 3 / 9 / 10: Entity **7/14**; Thông báo có repository; cây thư mục có `application/`; `core` **15** chủ đề; câu *"Luật thông báo nằm trong `core`"*
(mục 9) xoá.

## 9. Test quét 25 và 27 sau đợt (vẫn hai số ấy — mở rộng, không mở số 28)

**Quét 25 `vi_tri_tep_theo_luat_test` — 5 chỗ:**
1. `tangMang` = `{data, domain, presentation, application}`; chữ lỗi luật 1 kể bốn thư mục.
2. `chuDeCore` bỏ `notification` (15 chủ đề) — dựng lại `core/notification/` là đỏ luật 4.
3. `diemGhep` += `lib/core/auth/phien_dieu_phoi_that.dart` — đúng câu `KIEN_TRUC` mục 4 (điểm ghép thứ tư); docstring tệp và `KIEN_TRUC` sửa vế *"không import
   `features/`"* thành *"chỉ biết bộ quét thông báo (`NotificationScanner`) qua tham số `boQuet`"*. Quét 4 (`sync_engine_start_owner_test`) đọc tệp ấy theo
   đường dẫn `lib/core/auth/…` — không đổi.
4. `conChoCoreImport` rút 7 mục thông báo → **18** dòng còn lại (mục 2); chú thích *"về 0 ở gạch 5"* ở ba mục `sync` / `lich_nen` sửa cho khớp (chúng không
   về 0 — không phải thông báo).
5. **Luật 7 mới** (ca test riêng, khuôn luật 5): tệp `.dart` dưới `lib/features/*/data/**` và `lib/features/*/domain/**` không có dòng `import` chứa
   `/application/`; không danh sách chờ (đo sau mục 7 = 0); **sàn đếm** tệp data + domain > 150 (đo 105 + 163 = 268); bản sai thử đỏ.
   Luật 6 (soi gương) tự phủ `test/features/*/application/`.

**Quét 27 `presentation_domain_khong_kieu_drift_test` — 4 chỗ:**
1. `kieuDrift` += `'AppNotificationEvent'`, `companionCua` += `'AppNotificationEventsCompanion'`. Bước 1 điền `conChoKieu['AppNotificationEvent']` =
   `{core/notification/hoc_gio_thong_bao.dart, core/notification/nhat_ky_thong_bao.dart}` (đo mục 2); rút ở bước 4 (record) và 6 (dời về `data/`).
   Cuối đợt **`conChoKieu` rỗng** — giữ hằng rỗng (khuôn `conChoDomain`): mọi kiểu trong `kieuDrift` nhắc ở presentation / shared / core / domain là đỏ ngay.
2. Luật 3 (`<dynamic>` trần) quét `features/*/data/` **và** `features/*/application/`; sàn đếm > 50 giữ (đo sau đợt ~110); `conChoDynamic` vẫn rỗng (đo mục 2).
3. **Luật 4 mới** (đề xuất hoãn của review đợt 3): tệp `lib/features/*/data/repositories/*_repository.dart` (**không** `_impl.dart`) không có dòng import
   `core/database` / `package:drift` (dùng lại `importCam`). Lý do ghi ở docstring: lối chuyển tiếp **không nêu tên kiểu** (`final hang = await dao.getAll(id)`
   — `badge_updater` :82, `de_xuat_thong_bao_nguon` :67) là thứ luật 1 mù; chốt ở chữ ký interface là chốt được. Không danh sách chờ (đo 0 / 10); **sàn
   đếm** ≥ 10 tệp interface (sau đợt 11); bản sai thử đỏ (thêm `import 'package:drift/drift.dart';` vào một interface).
4. `mauKieu(ten)` → `RegExp('\\b$ten(\\?|>| [a-z_][A-Za-z0-9_]*\\b|,|\\)|;|\\.fromJson| &&| \\|\\|)')` — bắt `x is Category && …` / `is Bill ||`
   (đề xuất hoãn thứ hai); ca tiền đề thêm `expect(m.hasMatch('if (x is Bill && x.isPaid)'), isTrue)` và `isFalse` cho `BillEntity &&`. Đo HEAD: 0 chỗ mới.

Docstring hai tệp cập nhật ngày và spec này. Bảng *Test quét `lib/`* ở `CLAUDE.md` (hàng 25, 27) và `KIEN_TRUC` mục 6 sửa chữ. Số kế tiếp cho test quét mới
**vẫn 28**.

## 10. Đối chiếu luật kiến trúc và lộ trình G88

- **`KIEN_TRUC` mục 4 (ba tầng → bốn):** `domain/` Dart thuần → 10 tệp `domain/` mới của Thông báo không import Flutter / Drift / `sl` / `application`
  (kiểm bằng máy — `notification_rules` sau mục 5 + 7; `hoc_gio` sau 4.4; `notification_prefs` chỉ import rules; `nhom_tu_khoa` chỉ rules + prefs);
  `data/` được `core/database` → 10 datasource, 3 tệp rời, impl repository giữ import là đúng vai; interface repository **không** import Drift (luật 4);
  `presentation/` đọc qua repository → hai trang đổi kiểu qua cửa có sẵn; `application/` hàng mới (mục 8). **Domain import hàm thuần ở `core`**
  (`notification_rules` → `core/utils/tuan_iso`; engine → `core/category/category_name`): hàng mục 4 chỉ ghi *"Dart thuần, domain khác, Entity"* nhưng
  **tiền lệ đã có** — `analytics/domain/pham_vi_ky`, `uoc_tinh_chi_tuy_y`, `ai_edge/domain/ma_ky` import `tuan_iso` từ `core`; hàng mục 8 *"kiểu / hàm Dart
  thuần hạ tầng `core` cần"* ngầm cho phép. Ghi rõ vào hàng `domain/` mục 4 khi cập nhật (mục 13), không phải lệch mới.
- **Mục 8 (vị trí tệp):** Entity ở `data/models/` ✓; repository tách interface / impl ở `data/repositories/` ✓ (luật 3 quét 25 tự canh vì tên `_repository`);
  datasource ở `data/datasources/` ✓; `*_nguon` / `*_store` tệp rời `data/` ✓ (tiền lệ); bộ điều phối ở `application/` ✓ (hàng đổi); hàm thuần hạ tầng
  cần ở `core/<chủ đề>/` ✓ (`tuan_iso`, `ten_tep_bien_lai`, watcher); test soi gương theo thư mục ✓ (phụ lục C).
- **Quét 22:** không đụng — không trang nào mở DAO; chữ nhắc `ThongBaoNguon` sửa. **Quét 23:** không tệp `presentation` thêm dòng. **Quét 2:** chữ
  nhắc tên cổng sửa; `sl<WalletRepository>().getActive(` trên một dòng không đụng. **Quét 4:** không đổi (đường dẫn `phien_dieu_phoi_that` giữ).
  **Quét 5** (`bill_conflict_resolver_wiring_test`): đọc **đường dẫn chuỗi** `features/bill/data/services/bill_payment_conflict_resolver.dart` ở :79 và :107
  → đổi sang `features/bill/application/…` ở bước 7 (quên là quét 5 đỏ, không im lặng). **Quét 6:** `SoDuViService` theo tên lớp ✓. **Quét 14 / 15:** không
  phép tính mới; bảng v26 vẫn ngoài `SyncEntityType`. **Quét 16 / 17 / 18 / 20 / 26:** canh gói khác, không liên quan; **không** test quét nào canh
  `flutter_local_notifications` theo đường dẫn — đo 2026-10-15: 5 tệp `test/` nhắc gói ấy đều là test của chính các tệp dời (bẫy 7.7 là luật đọc).
  **Quét 21:** không đụng quyền. **Quét 25 / 27:** mục 9. Ba `*_noi_day_test` đọc Kotlin / manifest từ cwd ✓ — nhưng **hai** trong ba còn đọc tệp Dart bằng
  chuỗi: `bien_lai_noi_day_test` :51 (`lib/core/notification/kenh_bien_dong.dart`) và `phien_ngan_hang_noi_day_test` :105 (`lib/core/notification/kenh_phien_ngan_hang.dart`)
  → đổi chuỗi ở bước 6 (ngoại lệ có tên của câu *"chỉ đổi import"*).
- **Quy tắc `CLAUDE.md`:** 9 (bảng thông báo cục bộ, không `SyncEntityType`) ✓ — Entity không đổi điều đó; bất biến ⑥ ví (`SoDuViService` một nơi ghi) ✓;
  `NOTIFICATION_FEATURE` mục 7 (mười ba bẫy) — không bước nào chạm phần hệ điều hành / lịch; `nhanhThanhTab` giữ.
- **Lộ trình G88:**

| Gạch | Sau đợt |
|---|---|
| 1 · 2 · 7 | đã đóng (2026-10-11 · 10-13 · 10-10) |
| 3 — UI cầm hàng Drift | **đóng**: `conChoKieu` rỗng, Entity 7/14 (ví, giao dịch, mục tiêu, ngân sách, hoá đơn, danh mục, **thông báo**) — bảy kiểu hàng chính trong `kieuDrift` không còn chỗ chờ; bảng phụ v24–v30 (phản hồi gợi ý, nhật ký xem, khoá chạy nền…) chỉ dùng trong `data/` nên không cần Entity (câu G88.3 có sẵn) — riêng `AppNotificationEvent` vào `kieuDrift` vì nó từng lên tới một hàm luật |
| 4 — `core` import `features/` | **43 → 18** dòng hạ tầng (còn `sync_engine` 7 · `lich_nen` 4 · hai tệp sync 2 + 2 · `kho_anh_quet` 1 · hai DAO 1 + 1) — **vẫn mở**, không thuộc Thông báo; ghi số mới |
| 5 — `core/notification` là mảng trong `core` | **đóng**: thư mục không còn; 35 tệp về `features/notification/` + 3 về `core/utils` · `nen` · `ocr` |
| 6 — `data/services/` tầng application chưa tên | **đóng**: `features/<x>/application/`, luật mục 4 / 8, quét 25 luật 7 |

## 11. Kiểm thử và nghiệm thu

**Thứ tự thi công** (mỗi bước một commit, toàn bộ test xanh ở mỗi commit):

1. **Quét 27 mở rộng** với danh sách chờ **hiện trạng**: `kieuDrift` + `AppNotificationEvent` (`conChoKieu` tạm 2 tệp), luật 3 quét thêm `application/`
   (chưa có thư mục — 0 tệp, sàn vẫn > 50 nhờ `data/`), luật 4 interface, `mauKieu` ` &&` / ` ||`. Bản sai thử đỏ cho từng luật.
2. **`notification_entity.dart`** + `notification_entity_companion.dart` + test (4.1, 4.3).
3. **Một commit đổi kiểu "trục Thông báo"**: `thong_bao_repository.dart` + `_impl` (4.2) · xoá `thong_bao_nguon.dart` · DI · 10 tệp lib + 7 test đổi tên
   (phụ lục B) · helper `nguon_doc_gia` · hai trang nhận `NotificationEntity`, `_xoaCoHoanTac` gọi `chenLai(item)` · `notification_panel_test` fixture ·
   `thong_bao_nguon_test` → `thong_bao_repository_test` (+ ca `chenLai`). Rút 3 tệp khỏi `conChoKieu['AppNotification']` (2 trang + cổng).
4. **Hai tệp luật** (mục 5, 4.4): `hang*` + `deXuatThongBao` + `SuKienNhatKy`; `DeXuatThongBaoNguon.tai` map; `notification_scanner` :670 map tại chỗ;
   fixture 2 tệp test. Rút `notification_rules`, `hoc_gio_thong_bao` khỏi `conChoKieu['AppNotification']`; rút `hoc_gio` khỏi `conChoKieu['AppNotificationEvent']`.
5. **Bốn chỗ dời ngoài mảng** (mục 7) + test soi gương (`test/features/category/data/category_suggestion_engine_test.dart` → `…/category/domain/`;
   `test/features/budget/presentation/widgets/budget_health_test.dart` → `…/budget/domain/`; `test/features/wallet/so_du_vi_service_test.dart` ở gốc mảng —
   giữ) + 14 chỗ import. Kiểm `grep import.*data/services/` ở `domain` / `data/repositories` = 0.
6. **Dời `core/notification`** (mục 6): `git mv` 35 tệp + 40 test; 26 lib + 22 test đổi import; **hai chuỗi đường dẫn** trong `bien_lai_noi_day_test` :51 và
   `phien_ngan_hang_noi_day_test` :105 đổi theo; quét 25 (`tangMang` + `application` vì bước này tạo `features/notification/application/`, `chuDeCore` −1,
   `diemGhep` +1, `conChoCoreImport` 43 → 18); quét 27 `conChoKieu` → rỗng (4 tệp vai data về `application/`, `nhat_ky` về `data/`); chú thích đường dẫn ở
   `notification_event_dao.dart` :11, `app_router.dart` :177. **Một commit.**
7. **Gạch 6** (mục 8): `git mv` 10 tệp + 3 test; 48 import; hai chuỗi đường dẫn ở quét 5 (`bill_conflict_resolver_wiring_test` :79, :107); quét 25 luật 7;
   `KIEN_TRUC` mục 4 / 8 (có thể gộp vào bước 8). **Một commit.**
8. **Tài liệu** (mục 13) + số đo + nghiệm thu máy ảo.

**Phép đo của người soát** (kế hoạch viết script ở scratchpad, không vào repo):
- Bước 3: `git diff -U0` của commit, chuẩn hoá các thay thế được phép trên dòng `-` (`\bThongBaoNguon\b → ThongBaoRepository`; `\bThongBaoNguonDrift\b →
  ThongBaoRepositoryImpl`; `\bAppNotification\b` **không** theo sau bởi `s|Event` → `NotificationEntity`; `insertIfAbsent\(item\.toCompanion\(true\)\) →
  chenLai(item)`; dòng `import … core/database/app_database.dart` ↔ `… notification_entity.dart` / `thong_bao_repository.dart`; `thong_bao_nguon.dart`
  ↔ `thong_bao_repository.dart`) rồi so tập dòng `-` đã chuẩn hoá với tập dòng `+` — **phải rỗng** ngoài fixture test, docstring, và hai tệp mới.
- Bước 4: cùng khuôn, thêm `List<AppNotificationEvent> → List<SuKienNhatKy>` và dòng map tại chỗ :670 là dòng `+` được phép duy nhất ở scanner.
- Bước 6, 7: `git diff -M --stat` chỉ gồm rename (`=>`) và các tệp sửa import; `git diff -M -U0 | grep '^[-+]' | grep -v '^[-+][-+]' | grep -vE
  "^[-+]\s*(import|export|part) |^[-+]\s*///"` **rỗng** ngoài hai test quét và hằng `conChoCoreImport` / `chuDeCore` / `diemGhep` / `tangMang`.
  Lệch một dòng là một chỗ "tiện tay sửa" cần giải thích.

**Kiểm thử:** **không đổi kỳ vọng ca nào**; `flutter test` tăng đúng số ca mới (Entity 3 · companion 1 · `chenLai` 1–2 · quét 27 luật 4 + tiền đề ·
quét 25 luật 7 — đếm khi xong); `flutter analyze` **20** (không phép ép nào bỏ thêm — Entity cùng tên trường). Kế hoạch grep `flutter_local_notifications`
trong `test/` để chắc không test quét nào canh đường dẫn `os/` cũ.

**Nghiệm thu máy ảo `FlowMoney_16G`** (`-gpu host`, đang chạy `emulator-5554`, phiên Đạt, backend dev tắt; bản debug; cuộn giữ-rồi-thả; cắt 100 px thanh
trạng thái). **Chụp bộ "trước" ở bước 0 của kế hoạch** từ APK đang cài `d3b7b908…` (dựng ở `811e1ea8`; `lib/` chỉ đổi một chú thích tới `a4daec33` —
hợp lệ); "sau" xác nhận bằng `dumpsys package com.flowmoney.flowmoney | grep lastUpdateTime` **và** SHA-1 APK. Màn: trung tâm thông báo (ba bộ lọc, nhấn
giữ đánh dấu đọc / chưa đọc, vuốt xoá + *Hoàn tác* hàng thường, *Đọc tất cả*), bảng thông báo và chuông Trang chủ, Cài đặt thông báo (cuộn hết trang),
hai màn đồng ý D1 / nhắc sau ngân hàng, Sổ giao dịch, Mục tiêu, Cá nhân, Ngân sách (thẻ sức khoẻ — `budget_health` dời), Thêm giao dịch có thẻ gợi ý
(engine dời; gõ `caffe`, không Lưu). Logcat: `[NotificationScanner]` chạy sau mở app, `[BadgeUpdater] badge=` in, **0** dòng lỗi. Mục tiêu **0 px khác**
ngoài lệch thời gian đã biết, vàng thuần `#FFFF00` **0**. **Lỗ ghi sẵn vào biên bản:** *Hoàn tác* xoá cứng hàng D1 (`chenLai`), mọi đường biến động / biên lai /
phiên ngân hàng (cần Kotlin + máy thật — chưa cắm), chạy nền WorkManager — do test phủ (`thong_bao_repository_test`, `nhap_*_test` 3 tệp, `notification_scanner_lich_nen_test`;
đếm ca khi xong). **Không ghi dữ liệu thử** (tiền lệ chốt 3 đợt 3).

**Phép đo kết luận** (chạy từ `src/Client-app`, trên dòng mã — thước đo thẩm quyền là quét 27 / `boChuThich`):
- `grep -rlE "\bAppNotification(Event)?(\?|>| [a-z_]+\b|,|\)|;)" lib/features/*/presentation lib/features/*/domain lib/shared lib/core --include=*.dart`
  = 0 ngoài `core/database`, `core/sync`.
- `test -e lib/core/notification` sai; `find lib/features -path "*/data/services/*"` = 0; `grep -rn "ThongBaoNguon" lib test` = 0.
- `grep -rlE "import .*/application/" lib/features/*/data lib/features/*/domain` = 0.
- `grep -rlE "core/database|package:drift" lib/features/*/data/repositories/*_repository.dart` (không `_impl`) = 0 trên 11 tệp.
- `grep -rcE "^(import|export) .*features/" lib/core` — tổng và phần hạ tầng (dự kiến **18**; điểm ghép đổi vì DI / router / `chay_nen` / `phien_dieu_phoi_that`
  import đường mới — **đếm, không đoán**).
- `ls lib/core | wc -l` = 15 thư mục.

## 12. Ngoài phạm vi — quan sát, không sửa

- Cột `AppNotifications.osScheduledId` **chết** (0 đọc, 0 ghi từ v13): id hệ điều hành tính lại từ `dedupeKey` qua `osScheduledId()`. Bỏ cột cần bước di trú
  (schema v31) — việc riêng; Entity bỏ trường là đủ cho đợt này.
- Ba lệch `domain → data/repositories` sẵn có: `ai_edge/domain/goi_so_phan_tich` · `hang_tong_quan` → `analytics_repository`; `transaction/domain/tim_giao_dich`
  → `bao_cao_repository`. Không canh bởi luật 2 quét 27 (chỉ cấm `core/database` / Drift). Ghi vào `KIEN_TRUC` mục 9 là nợ đọc; không đổi ở đợt này.
- Gạch 4 còn **18** dòng ở 7 tệp `core` không thuộc Thông báo (`sync_engine` 7 …) — hướng xử lý giữ như G88.4.
- `notification_rules.dart` 1.065 dòng ở `domain/` — quét 23 chỉ trần `presentation/`; không tách ở đợt này (đổi thân là ngoài phạm vi).
- Hai tệp `docs/superpowers/plans/2026-09-19-*` **được theo dõi** dù `plans/` gitignore — lịch sử, không đụng.
- `features/notification/presentation/` **không đổi tệp nào ngoài hai tệp đổi kiểu** — 6 widget `cai_dat_thong_bao/` và 3 trang đồng ý chỉ đổi import.

## 13. Tài liệu cập nhật khi xong (bước 8; đếm bằng máy, ghi ngày)

- `CLAUDE.md`: dòng ⭐ bàn giao; hàng *Đụng vào presentation* (Entity 7/14, lối chuyển tiếp 0, quét 27 bốn luật, quét 25 bảy luật, `conChoKieu` rỗng, số tệp
  quét); hàng *Thông báo* và *đọc biến động số dư* (đường dẫn `core/notification/…` → `features/notification/…`, `ThongBaoNguon` → `ThongBaoRepository`);
  hàng *quản lý ví* (`so_du_vi_service` đường mới), *hoá đơn* / *mục tiêu* (runner ở `application/`); bảng *Test quét `lib/`* hàng 25 / 27; mốc `flutter test`;
  G88 câu *"Nợ còn lại có tên"*.
- `docs/KIEN_TRUC_CLIENT_APP.md`: mục 1 (Entity 7/14, lộ trình gạch 3 xong), 3 (cây có `application/`, không `core/notification`), 4 (hàng `application/`;
  hàng `domain/` ghi rõ được import hàm thuần ở `core/utils` · `core/category` — tiền lệ `tuan_iso`; điểm ghép thứ tư biết bộ quét; số dòng `features/` trong
  `core` đo lại), 6 (quét 25 / 27 chữ), 8 (hàng *Bộ điều phối* → `application/`; test soi gương),
  9 (nhược điểm còn lại: bỏ *"UI cầm kiểu Drift ở AppNotification"* và *"Luật thông báo nằm trong core"*; thêm ba lệch domain → repository), 10.
- `docs/CLIENT_APP_KNOWN_GAPS.md`: G88 gạch 3 ✅ đóng (đợt 4/4), gạch 5 ✅, gạch 6 ✅ (tên `application/`), gạch 4 số mới 18; dòng *Cập nhật* đầu tệp.
- `docs/NOTIFICATION_FEATURE.md`: mục 4 cây tệp (27 đường dẫn `core/notification` → mới; mục 4.4 bộ luật ở `domain/`; cổng); bảng test mục cuối (đường
  `test/core/notification` → `test/features/notification/...`).
- `docs/BIEN_DONG_SO_DU_FEATURE.md` (12 đường dẫn), `docs/GOAL_FEATURE.md` / `docs/bill/BILL_DOCUMENTATION.md` (runner, resolver → `application/`;
  `BILL_DOCUMENTATION` 5 dòng `data/services`), `docs/CATEGORY_RATIONALE.md` (engine → `domain/`, seeder → `application/`).
- `docs/PROJECT_CONTEXT.md`: mục 9 (cấu trúc app) và khối mới đầu mục 14 (số đo, nghiệm thu, commit); mục 14 các khối cũ **giữ nguyên** (ảnh chụp có ngày).
- Spec cũ (`2026-10-10-bit-diem-ro…` 11 dòng `ThongBaoNguon`, ba spec Entity) **giữ nguyên** — lịch sử; spec này thêm khối ✅ *"Số đo sau thi công"* đầu tệp.
- Lệnh soát: `git ls-files docs CLAUDE.md | xargs grep -n "core/notification\|data/services\|ThongBaoNguon\|test/core/notification"` — mỗi dòng còn lại phải
  nằm trong khối lịch sử có ngày hoặc spec cũ.

## Phụ lục A — 9 tệp `conChoKieu['AppNotification']` · 26 tệp lib · 22 tệp test import `core/notification` (đo 2026-10-15)

**9 tệp chờ:** `features/notification/presentation/pages/notification_center_page.dart` · `…/widgets/notification_panel.dart` ·
`core/notification/hoc_gio_thong_bao.dart` · `nhap_bien_dong.dart` · `nhap_bien_lai.dart` · `nhap_phien_ngan_hang.dart` · `notification_rules.dart` ·
`notification_scanner.dart` · `thong_bao_nguon.dart`.

**26 tệp lib** (bỏ tiền tố `lib/`): `main.dart` (9 dòng) · `core/di/injection_container.dart` (18) · `core/router/app_router.dart` (3) · `core/nen/chay_nen.dart` (2) ·
`core/auth/phien_dieu_phoi_that.dart` · `core/ocr/kho_anh_quet.dart` · `core/database/daos/notification_event_dao.dart` (chỉ docstring) ·
`features/ai_edge/domain/ma_ky.dart` · `features/analytics/domain/pham_vi_ky.dart` · `features/analytics/domain/uoc_tinh_chi_tuy_y.dart` (ba tệp → `tuan_iso`) ·
`features/bill/data/services/bill_payment_conflict_resolver.dart` · `features/bill/domain/bill_status.dart` · `features/goal/presentation/pages/goal_page.dart` ·
`features/home/presentation/pages/home_page.dart` · `features/profile/presentation/pages/profile_page.dart` ·
`features/notification/presentation/pages/notification_center_page.dart` · `notification_settings_page.dart` · `widgets/notification_panel.dart` ·
`widgets/cai_dat_thong_bao/hang_nguong.dart` · `khoi_nhac_sau_ngan_hang.dart` · `ten_nhom_thong_bao.dart` · `the_bien_dong.dart` ·
`features/transaction/data/them_giao_dich_nguon.dart` · `features/transaction/domain/dien_san_bien_dong.dart` ·
`features/transaction/presentation/pages/add_transaction_page.dart` · `transaction_page.dart`.

**22 tệp test** (bỏ tiền tố `test/`): `helpers/nguon_doc_gia.dart` · `shared/widgets/main_shell_tab_so_giao_dich_test.dart` · `core/auth/phien_dieu_phoi_that_test.dart` ·
`core/database/notification_dao_test.dart` · `core/ui/vi_tri_tep_theo_luat_test.dart` · `core/ui/presentation_domain_khong_kieu_drift_test.dart` (hai test quét —
sửa hằng, không phải import) · `features/wallet/gop_vi_service_test.dart` · `features/notification/notification_settings_page_test.dart` · `notification_settings_de_xuat_test.dart` ·
`nhac_sau_ngan_hang_cai_dat_test.dart` · `dong_y_bien_dong_test.dart` · `notification_center_page_test.dart` · `notification_center_nhat_ky_test.dart` ·
`notification_center_de_xuat_test.dart` · `features/auth/session_validation_test.dart` · `features/auth/auth_bloc_buoc_dang_xuat_test.dart` ·
`features/home/drawer_trang_chu_test.dart` · `features/transaction/presentation/add_transaction_goi_y_so_tien_test.dart` · `form_bien_lai_test.dart` ·
`dien_tu_phien_test.dart` · `dien_tu_bien_dong_test.dart` · `features/transaction/domain/dien_san_bien_dong_test.dart`.

## Phụ lục B — Tệp nhắc `ThongBaoNguon` / `ThongBaoNguonDrift` theo từ trọn (đo 2026-10-15, `grep -rlw`): 10 lib + 7 test

**lib (10):** `core/di/injection_container.dart` (cả hai tên) · `core/notification/thong_bao_nguon.dart` (xoá) · `features/goal/presentation/pages/goal_page.dart` ·
`features/home/presentation/pages/home_page.dart` · `features/notification/presentation/pages/notification_center_page.dart` ·
`features/notification/presentation/widgets/notification_panel.dart` · `features/profile/presentation/pages/profile_page.dart` ·
`features/transaction/data/them_giao_dich_nguon.dart` · `features/transaction/presentation/pages/add_transaction_page.dart` · `transaction_page.dart`.
**Không đổi** (chỉ nhắc `DeXuatThongBaoNguon`): `notification_settings_page.dart`, `de_xuat_thong_bao_nguon.dart` và test của chúng.

**test (7):** `core/notification/thong_bao_nguon_test.dart` (đổi tên, cả hai tên) · `helpers/nguon_doc_gia.dart` (cả hai tên) ·
`core/ui/presentation_khong_cham_csdl_test.dart` (chữ) · `features/wallet/wallet_picker_sources_test.dart` (chữ) · ba tệp chỉ nhắc `ThongBaoNguonDrift`:
`features/notification/notification_center_de_xuat_test.dart` · `notification_center_nhat_ky_test.dart` · `notification_center_page_test.dart`.

## Phụ lục C — 40 tệp `test/core/notification/` → đích soi gương (đo 2026-10-15; bỏ tiền tố `test/`)

| Đích | Tệp |
|---|---|
| `features/notification/domain/` (14) | `notification_rules_test` · `notification_rules_bill_auto_pay_test` · `notification_rules_goal_wallet_test` · `notification_rules_large_expense_test` · `notification_rules_rebalance_test` · `notification_rules_weekly_test` · `hoc_gio_thong_bao_test` · `notification_deeplink_test` · `notification_actions_test` · `cham_hdh_test` · `nhom_tu_khoa_test` · `phien_ngan_hang_test` · `prefs/notification_prefs_test` · `os/os_scheduled_id_test` |
| `features/notification/data/datasources/` (8) | `nhat_ky_thong_bao_test` · `hang_cho_su_kien_test` · `kho_bien_lai_test` · `os/os_notifier_native_test` · `os/android_manifest_receivers_test` · `bien_dong_noi_day_test` · `bien_lai_noi_day_test` · `phien_ngan_hang_noi_day_test` (ba test soi Kotlin đặt cạnh `kenh_*` mà chúng import; đọc tệp theo cwd) |
| `features/notification/data/` (3) | `de_xuat_thong_bao_nguon_test` · `prefs/notification_prefs_store_test` · `moc_phien_store_test` |
| `features/notification/data/repositories/` (1) | `thong_bao_nguon_test` → `thong_bao_repository_test` |
| `features/notification/application/` (12) | `notification_scanner_test` · `notification_scanner_auto_pay_test` · `notification_scanner_khoa_test` · `notification_scanner_lich_nen_test` · `reminder_scheduler_test` · `reminder_scheduler_auto_pay_test` · `badge_updater_test` · `notification_tap_router_test` · `nhap_bien_dong_test` · `nhap_bien_lai_test` · `nhap_phien_ngan_hang_test` · `mo_tu_tom_tat_bien_dong_test` |
| `core/utils/` (1) · `core/nen/` (1) | `tuan_iso_test` · `app_lifecycle_watcher_test` |

Đếm: 14 + 8 + 3 + 1 + 12 + 2 = **40** ✓. Thư mục `test/core/notification/` không còn. Cộng 3 test `data/services` (mục 8) → `features/{bill,category,goal}/application/`,
và hai test của mục 7 dời soi gương: `features/category/data/category_suggestion_engine_test` → `features/category/domain/`;
`features/budget/presentation/widgets/budget_health_test` → `features/budget/domain/` (`features/wallet/so_du_vi_service_test` ở gốc mảng — giữ). Tổng tệp test
dời: 40 + 3 + 2 = **45**.
