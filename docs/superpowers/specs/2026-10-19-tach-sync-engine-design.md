# Tách `SyncEngine` thành lớp cộng tác

- **Ngày:** 2026-10-19 · nhánh `TranQuangDat` · HEAD lúc đo `4b896a8e` (`sync_engine.dart` không đổi từ `d10ea922`)
- **Trạng thái:** người dùng duyệt thiết kế trong hai phiên (Phần 1 phiên 2026-10-19 phiên 2, Phần 2 + điều chỉnh
  trần phiên 2026-10-19 phiên 3); spec này chờ duyệt bản viết.
- **Phạm vi:** chỉ `src/Client-app` và tài liệu client. **Tách mã thuần** — không đổi hành vi, giao diện, dữ liệu,
  payload đồng bộ, schema, constructor hay DI. Trên app không có gì nhìn thấy được thay đổi.

## 1. Bối cảnh

`lib/core/sync/sync_engine.dart` dài **2.153** dòng (đo 2026-10-19), một lớp làm bảy việc: vòng đời + giãn cách,
`_runSync`, kéo về sáu bảng, thu gom thao tác chờ đẩy, gửi lô, phân loại lỗi, tiện ích. `KIEN_TRUC_CLIENT_APP.md` mục 9
và điểm 5 mục 10 ghi nó là nhược điểm còn mở (*"`SyncEngine` một tệp 2.163 dòng"* — số cũ). Mỗi lần sửa một bảng ở
nhánh kéo về phải đọc qua cả nhánh đẩy và phân loại lỗi để biết trạng thái nào được chạm.

## 2. Quyết định đã chốt (người dùng, 2026-10-19)

1. **Hướng B — tách lớp cộng tác.** Không dùng `part` + extension (không tách được trạng thái), không tách kéo về
   thành mỗi bảng một tệp.
2. **Quét 34:** mọi tệp `.dart` dưới `lib/core/sync/` ≤ **800** dòng.
3. **Phần 1 (bốn lớp, ranh giới trạng thái, API giữ nguyên)** — duyệt phiên 2.
4. **Phần 2 (canh trước khi dời, quét 34 trần hạ dần, bốn bước dời thuần)** — duyệt phiên 3.
5. **Nhấc ba nhóm hàm thuần ra khỏi lớp kéo về** — phiên 3. Lý do: cộng đúng các khối Phần 1 giao cho lớp kéo về ra
   **~873** dòng (Phần 1 ước ~720 là đếm thiếu), vượt trần 800. Nhấc nhóm mốc, nhóm biểu tượng / màu mặc định và hàm
   gieo từ khoá ra còn **~744** dòng. Người dùng không chọn nâng trần.

## 3. Kiểm kê `sync_engine.dart` (đo trên `4b896a8e`)

| Dòng | Khối | Về đâu |
|---|---|---|
| 1–47 | import, docstring lớp, `_ngayCucBoUtcIso` (45–46) | import chia theo tệp; `_ngayCucBoUtcIso` → thu gom |
| 48–197 | trường, ba luồng phát, hẹn giờ, giãn cách, `_isSyncBlocked` (195–196) | engine; `_isSyncBlocked` → thu gom |
| 198–218 | `_markBlockedById` | gửi lô |
| 219–266 | `_resetBackoff`, `_hasCompletedPull` + `soLanKeoVeXong`, `_checkpointStore`, constructor | engine (getter chuyển tiếp); cờ / bộ đếm / checkpoint → kéo về |
| 267–532 | `start` · `stop` · `syncNow` · `syncMotLuot` · `scheduleSync` · `_lastPullTime` · `_noMotLanChay` · `_runSync` | engine; `_lastPullTime` → kéo về |
| 533–1150 | `_pullFromBackend` (616 dòng thân) | kéo về |
| 1152–1193 | `mocPullConDungKhong` · `_kepVeHienTai` · `_newestUpdateAt` (42) | `moc_keo_ve.dart` |
| 1195–1599 | `_collectPendingOps` (403) | thu gom |
| 1602–1653 | `_toValidUuid` · `_isValidUuidFormat` · `_resolveCategoryId` | `uuid_dong_bo.dart` |
| 1655–1874 | `_sendBatch` · `_markSyncedById` | gửi lô |
| 1876–1908 | `_idViMacDinhTrongLo` · `_deletedAtFrom` | kéo về |
| 1910–2043 | `accountNotFoundCode` · `_permanentCodes` · bốn regex · `_classifyFailure` | gửi lô (`accountNotFoundCode` chuyển tiếp ở engine) |
| 2044–2089 | `_gieoTuKhoaKhiTrong` (46) | `gieo_tu_khoa.dart` |
| 2091–2110 | `_setStatus` · `_disposed` · `dispose` | engine |
| 2112–2152 | `_defaultIconForCategoryName` · `_defaultColorForCategoryName` (41) | `bieu_tuong_danh_muc_mac_dinh.dart` |

**Chỗ hai lớp mới dùng chung, đo được:**

- `_resolveCategoryId` được **cả** kéo về (dòng 855, `repairPendingTransactionsCategoryId(_resolveCategoryId)`) **lẫn**
  thu gom gọi.
- `_toValidUuid` được thu gom và gửi lô gọi (dòng 1702).
- `_backoffSteps` + `_consecutiveFailures` được engine (`_registerFailedCycle`) và gửi lô dùng: dòng 1767 chọn bậc chặn
  cho lỗi vĩnh viễn.
- `_now()` được `_isSyncBlocked` (thu gom) và gửi lô dùng.

## 4. Thiết kế

### 4.1 Cây tệp sau khi tách

| Tệp (dưới `lib/core/sync/`) | Nội dung | Ước lượng |
|---|---|---|
| `sync_engine.dart` | `SyncEngine`: vòng đời, giãn cách, hẹn giờ, nghe mạng, `_runSync`, ba luồng phát, `_setStatus` / `dispose`, API chuyển tiếp | ~520 |
| `ap_du_lieu_keo_ve.dart` (mới) | `ApDuLieuKeoVe`: `pullFromBackend`, mốc kéo, checkpoint, `daKeoXong`, `soLanKeoVeXong`, `_idViMacDinhTrongLo`, `_deletedAtFrom` | ~744 |
| `thu_gom_day.dart` (mới) | `ThuGomThaoTacDay`: `collectPendingOps` (mục 0 · 1 · 2 · 1b · 3 · 4 · 5 · 6), `_isSyncBlocked`, `_ngayCucBoUtcIso` | ~465 |
| `gui_lo_dong_bo.dart` (mới) | `GuiLoDongBo`: `sendBatch`, `_markSyncedById`, `_markBlockedById`, phân loại lỗi, `accountNotFoundCode` | ~415 |
| `uuid_dong_bo.dart` (mới) | hàm top-level `toValidUuid`, `isValidUuidFormat`, `resolveCategoryId(AppDatabase db, String? categoryId)` | ~60 |
| `moc_keo_ve.dart` (đã có, 59) | thêm `mocPullConDungKhong`, `kepVeHienTai`, `newestUpdateAt` | ~101 |
| `bieu_tuong_danh_muc_mac_dinh.dart` (mới) | `defaultIconForCategoryName`, `defaultColorForCategoryName` | ~50 |
| `gieo_tu_khoa.dart` (mới) | `gieoTuKhoaKhiTrong(AppDatabase db, int accountId, Map<String, List<String>> tuKhoaTheoDanhMuc)` | ~55 |

`core/sync` từ 8 lên **14** tệp; `core` từ 100 lên **106**. Các con số này đếm lại bằng máy sau khi làm.

**Tên hàm.** Lớp và hàm mới phải công khai, vì `part` đã bị loại ở quyết định 1, mà tên riêng (có `_`) không đi qua
ranh giới tệp. Hàm giữ **tên gốc, chỉ bỏ dấu `_`** (`collectPendingOps`, `sendBatch`, `pullFromBackend`,
`resolveCategoryId`…), để `grep` theo tên cũ trong tài liệu và chú thích vẫn tìm ra chỗ. Hàm chỉ dùng trong một lớp
vẫn giữ `_`: `_classifyFailure`, `_permanentCodes`, `_markSyncedById`, `_markBlockedById`, `_isSyncBlocked`,
`_idViMacDinhTrongLo`, `_deletedAtFrom`.

### 4.2 Bốn lớp

**`SyncEngine`** giữ toàn bộ cam kết về **thứ tự** trong `_runSync`:
- đẩy → phát `pushResultStream` **trước** Pull → Pull → thử lại một lần → phát kết quả thử lại;
- dừng khi phiên chết (`hasSessionInvalid` → `authExpired`);
- nợ một lần chạy bù (`_noMotLanChay`);
- giãn cách (`_registerFailedCycle` / `_resetBackoff` / hẹn chạy lại).

Engine **không** còn giữ `_db`, `_dioClient`, `_soDuVi`, `_viBiGiu`, `_checkpointStore`. Constructor vẫn nhận đủ các
tham số ấy và chuyển thẳng cho ba lớp, nên dòng `// ignore: unused_field` của `_dioClient` mất theo trường. Ba lớp được
dựng **trong thân constructor** rồi gán vào `late final`. Không đặt ở danh sách khởi tạo, vì hai trong ba lớp cần bao
đóng đọc `this`.

**`ApDuLieuKeoVe`** nhận `dioClient`, `db`, `soDuVi`, `checkpointStore` và giữ:
- trạng thái kéo: `_lastPullTime`, `_hasCompletedPull`, `_soLanKeoVeXong`;
- getter `daKeoXong`, `soLanKeoVeXong`.

Bốn lối vào, mỗi lối thay đúng một chỗ engine đang đụng trạng thái kéo:

| Lối vào | Thay cho | Thân |
|---|---|---|
| `pullFromBackend(int accountId)` | `_pullFromBackend` | nguyên văn |
| `napMoc(int idaccount)` | `start()` dòng 283–286 | `_lastPullTime = mocPullConDungKhong(await _checkpointStore?.read(idaccount), DateTime.now().toUtc());` |
| `napMocNeuChuaCo(int idaccount)` | `syncMotLuot()` dòng 345–348 | giữ nguyên biểu thức `_lastPullTime ??= …`: mốc đã có thì **không** đọc checkpoint |
| `datLaiPhien()` | `stop()` dòng 318 + 323 | `_hasCompletedPull = false; _lastPullTime = null;` — **không** đặt lại `_soLanKeoVeXong` (đếm theo đời engine) |

Trong `stop()`, đặt `datLaiPhien()` ở chỗ nào trước `_setStatus(idle)` cũng tương đương: đoạn ấy chạy đồng bộ, không có
người nghe nào chen giữa. Không cần soát thứ tự ở đây.

⚠️ Quên lối `datLaiPhien` là lỗi **im lặng**: tài khoản đăng nhập sau thừa hưởng cờ *"đã kéo xong"* của phiên trước, và
`PersonalDefaultCategories` tin vào CSDL chưa kéo (G14).

**`ThuGomThaoTacDay`** nhận:
- `db`, `viBiGiu`;
- `DateTime Function() now` — chính trường `_now` của engine;
- `int? Function() taiKhoanPhien` — bao đóng `() => _currentIdaccount`.

Lối vào duy nhất: `collectPendingOps(int idaccount)`. Dòng 1317 `_currentIdaccount ?? idaccount` thành
`_taiKhoanPhien() ?? idaccount`.

**`GuiLoDongBo`** nhận:
- `dioClient`, `db`, `now`;
- `Duration Function() bacChan`.

Engine cấp `bacChan` bằng một phương thức riêng:

```dart
Duration _bacChanHienTai() =>
    _backoffSteps[_consecutiveFailures.clamp(0, _backoffSteps.length - 1)];
```

Biểu thức ấy chép nguyên văn từ dòng 1767–1768 — **không** có `- 1`, khác `_registerFailedCycle`. Dòng 1767–1772 của
gửi lô thành `final step = _bacChan();` rồi `_now().add(step)`. Nhờ vậy `_backoffSteps` và `_consecutiveFailures` ở lại
engine, gửi lô không biết gì về giãn cách. Lối vào: `sendBatch(List<SyncOperation> ops)`; hằng
`static const String accountNotFoundCode`.

### 4.3 Ba chỗ đọc trạng thái engine — qua hàm, không chụp giá trị

| Chỗ | Đọc | Vì sao phải là hàm |
|---|---|---|
| thu gom, gửi lô | `now` | đồng hồ tiêm được (test giãn cách dùng đồng hồ giả, tiến giờ giữa các lượt) |
| thu gom mục 1b | `taiKhoanPhien()` | `syncMotLuot` đặt rồi trả lại `_currentIdaccount` quanh một lượt; chụp lúc dựng là đọc `null` |
| gửi lô, lỗi vĩnh viễn | `bacChan()` | đọc **sau** một `await` trong vòng lặp kết quả; `start()` có thể `_resetBackoff()` giữa chừng — đọc lúc gọi là đúng hành vi cũ |

### 4.4 API công khai giữ nguyên từng chữ

- **Constructor:** cùng tham số, cùng tên, cùng mặc định. 28 tệp test dựng / kế thừa `SyncEngine` và DI
  (`injection_container.dart`) không đổi.
- **Thành viên:** `status`, `statusStream`, `pushResultStream`, `sessionInvalidStream`, `start`, `stop`, `syncNow`,
  `syncMotLuot`, `scheduleSync`, `dispose`, `hasCompletedPull`, `soLanKeoVeXong`, ba getter `@visibleForTesting`
  (`backoffRetryAt`, `consecutiveFailures`, `nextAllowedSyncAt`).
- **Hai thành viên tĩnh:**
  - `accountNotFoundCode` = `GuiLoDongBo.accountNotFoundCode` (hằng chuyển tiếp);
  - `mocPullConDungKhong(daLuu, bayGio)` chuyển tiếp sang hàm cùng tên ở `moc_keo_ve.dart`. Engine import tệp ấy
    **có tiền tố** (`as moc`), vì một phương thức tĩnh gọi hàm top-level cùng tên mà không tiền tố là tự gọi chính nó.
- **Không thêm thành viên công khai nào vào `SyncEngine`.** 7 tệp test `implements SyncEngine` (lớp giả có
  `noSuchMethod`) và 4 lớp `extends SyncEngine` (`_SpySyncEngine`) dựa vào bề mặt này.

Đo 2026-10-19:
- `grep -rlE 'SyncEngine\(|taoSyncEngineThu\(|extends SyncEngine' test` → **28**;
- `implements SyncEngine` → **7**;
- tệp test nhắc chữ `SyncEngine` → **46**;
- tệp import `sync_engine.dart` → **32**.

### 4.5 Luật "dời nguyên văn"

**Được đổi:**
- bỏ `_` ở tên hàm chuyển sang công khai (mục 4.1);
- `_db` → `db` trong ba hàm top-level nhận `AppDatabase`;
- gọi hàm qua tên mới, kể cả `repairPendingTransactionsCategoryId((id) => resolveCategoryId(_db, id))`;
- `_currentIdaccount` → `_taiKhoanPhien()` và dòng chọn bậc chặn (mục 4.2);
- tham chiếu dartdoc `[x]` trỏ tới ký hiệu đã sang tệp khác thì ghi đủ (`[SyncEngine.start]`), chữ giữ nguyên;
- **docstring đặt nhầm** ở dòng 1878–1890: nó tả `_deletedAtFrom` nhưng đứng trên `_idViMacDinhTrongLo`. Khi dời, gắn
  nó vào đúng hàm. Đây là sửa chỗ đặt chú thích, không phải sửa mã.
- **docstring đặt nhầm thứ hai**, ở đầu tệp: dòng 21–44 là **một** khối `///` liền mạch (không dòng trống giữa 39 và
  40), đứng ngay trên `_ngayCucBoUtcIso` (dòng 45). Vì dartdoc gắn khối vào khai báo kế tiếp, nên hôm nay đoạn tả
  *"SyncEngine — bộ máy đồng bộ offline-first"* là doc của `_ngayCucBoUtcIso`, còn `class SyncEngine` không có doc.
  Khi dời ở bước 3: tách khối — dòng 21–39 ở lại trên `class SyncEngine`, dòng 40–44 đi theo hàm sang `thu_gom_day.dart`.

**Không được đổi:**
- thứ tự câu lệnh, chú thích, chữ log;
- tiền tố `debugPrint` **`[SyncEngine]`** — ai lọc logcat theo chữ ấy vẫn thấy;
- **mọi lời gọi `DateTime.now()` trần**. Khoảng 15 chỗ ở thân kéo về / thu gom / gửi lô / gieo từ khoá:
  634, 732, 738, 829, 919, 936, 973, 1024, 1057, 1096, 1171, 1199, 1661, 1907, 2066. Đổi chúng sang `now()` là **đổi
  hành vi** (giờ ghi trong test dùng đồng hồ giả sẽ khác) — ngoài phạm vi;
- năm issue `curly_braces_in_flow_control_structures` ở hai hàm biểu tượng / màu đi nguyên sang tệp mới.

## 5. Phép canh — làm TRƯỚC khi dời mã

### 5.1 Ba test quét cột cục bộ quét cả thư mục

Ba test đang đọc **danh sách cứng** gọi đích danh `sync_engine.dart`:

| Test | Danh sách hiện tại |
|---|---|
| `test/features/wallet/vi_trung_ten_cuc_bo_test.dart` (G63) | `sync_engine` · `cong_vi_bi_giu` · `sync_payload_normalizer` |
| `test/features/wallet/wallet_cho_phep_am_test.dart` (quét 7) | `sync_engine` · `sync_payload_normalizer` |
| `test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart` (quét 15) | `sync_engine` · `sync_payload_normalizer` · `sync_models` |

Mã dời sang tệp mới mà danh sách giữ nguyên thì cột cục bộ có thể lọt vào đường đẩy ở `thu_gom_day.dart` mà không ca nào
đỏ. Sửa cả ba thành **mọi `.dart` dưới `lib/core/sync/` trừ `.g.dart`**, giữ dạng đường dẫn `'lib/core/sync/…'`. Mỗi
test thêm một ca chặn: danh sách quét **không rỗng** và **chứa** `lib/core/sync/sync_engine.dart` cùng
`lib/core/sync/sync_payload_normalizer.dart`. Ca này canh trường hợp liệt kê thư mục hỏng (chạy sai thư mục làm việc,
đổi dấu `\`) làm test xanh vì không đọc gì.

Đo 2026-10-19: không tệp nào dưới `lib/core/sync/` ngoài `sync_engine.dart` nhắc **36** chữ cấm của quét 15 hay bốn
chữ cấm của hai test ví. Nới phạm vi vì thế **không** làm đỏ trước khi dời. Mỗi ca chặn phải được thử bằng một bản sai
có chủ ý (danh sách rỗng) và thấy đỏ.

### 5.2 Quét 34 — `test/core/sync/sync_tep_khong_qua_dai_test.dart`

Đặt ở `test/core/sync/` vì luật soi gương của quét 25: quét đọc `lib/core/sync/` thì test nằm ở `test/core/sync/`.
Khuôn giống quét 23 (`tep_presentation_khong_qua_dai_test.dart`):
- `tran = 800`;
- `mienTru = {'core/sync/sync_engine.dart': 2153}`;
- trần riêng chỉ được giảm;
- tệp miễn trừ xuống ≤ 800 mà chưa rút khỏi danh sách thì đỏ;
- tệp trong danh sách không còn tồn tại thì đỏ.

⚠️ Số **2153** là của `wc -l`. Còn test đếm bằng `readAsLinesSync().length`, và hai cách lệch nhau một dòng khi tệp
không có ký tự xuống dòng ở cuối. Bàn giao 2026-10-19 đã gặp đúng kiểu lệch ấy (*"số dòng lệch một"*). Vì vậy trần riêng
**lấy từ số chính test báo** ở lượt chạy đầu, không chép từ spec này. Mọi lần hạ trần cũng theo luật ấy.

Mỗi bước dời **hạ trần riêng** về đúng số đo sau bước ấy. Bước 4 rút mục cuối, `mienTru` rỗng; cơ chế miễn trừ giữ lại
cho tệp dài sau này, như quét 23. Docstring ghi số **34**. Bảng test quét ở `CLAUDE.md` và `KIEN_TRUC` thêm một hàng;
*"số tiếp theo"* thành **35**.

### 5.3 `wallet_picker_sources_test` — đổi ở bước 4, không phải bước canh

Quét 2 nhận diện tệp đọc **mọi** ví bằng chuỗi `walletDao.getAll(`. Trong `sync_engine.dart` chỉ thân kéo về có chuỗi
ấy (dòng 536, 568). Thu gom đọc `getPending`, gửi lô đọc `markSynced` / `markSyncBlocked`, nên không vướng. Bước 4 đổi
khoá `'core/sync/sync_engine.dart'` thành **`'core/sync/ap_du_lieu_keo_ve.dart'`**, giữ nguyên lý do *"Đồng bộ phải
đẩy và kéo cả ví lưu trữ…"*. Chỉ một tệp, không phải hai như bản trình miệng.

### 5.4 Không cần đổi (đã soát)

- **Quét 27:** `presentation_domain_khong_kieu_drift_test.dart:189` miễn `core/sync/` theo **tiền tố**, nên tệp mới tự
  được miễn. Đừng thêm ngoại lệ.
- **Quét 4:** `.start(idaccount:)` chỉ ở `phien_dieu_phoi_that.dart`. Không đụng.
- **Quét 25 luật 5:** tệp mới chỉ được import `features/` trong `domainThuanChoCore`. Mọi import `features/` của engine
  hôm nay (`bill_recurrence`, `wallet_status`, `bill_pay_status`, `uu_tien_hop_le`) đã nằm trong danh sách. Tệp nào dùng
  hằng nào thì mang import ấy theo.
- **Quét 32:** `core/sync` không dùng `DateFormat`.
- **`sync_payload_contract_test`** không đọc mã nguồn dạng chữ (đo: không `File(` / `readAsString` nào trong tệp). Nó
  chạy engine thật, nên đi trong lưới hồi quy.

## 6. Bốn bước dời

Mỗi bước: một lượt thi công, một lượt soát, test xanh rồi mới commit. **Không sửa kỳ vọng của test cũ**: đỏ là dời sai.

1. **Canh + hàm thuần** (hai commit).
   - (a) Mục 5.1 và quét 34 (`mienTru` 2153). Suite liên quan xanh trên mã cũ.
   - (b) Tách `uuid_dong_bo.dart`, `bieu_tuong_danh_muc_mac_dinh.dart`, `gieo_tu_khoa.dart`, và ba hàm mốc sang
     `moc_keo_ve.dart`; `SyncEngine.mocPullConDungKhong` chuyển tiếp. Hạ trần.
2. **`GuiLoDongBo`** — `sendBatch`, `_markSyncedById`, `_markBlockedById`, khối phân loại lỗi; engine thêm
   `_bacChanHienTai`; `accountNotFoundCode` chuyển tiếp. Hạ trần.
3. **`ThuGomThaoTacDay`** — `collectPendingOps`, `_isSyncBlocked`, `_ngayCucBoUtcIso`. Hạ trần.
4. **`ApDuLieuKeoVe`** — `pullFromBackend`, trạng thái kéo, `napMoc` / `napMocNeuChuaCo` / `datLaiPhien`, hai hàm
   tĩnh riêng; đổi khoá quét 2 (mục 5.3); rút miễn trừ quét 34.

Thứ tự đi từ lớp ít dính trạng thái nhất tới lớp nhiều nhất. Gửi lô chỉ đọc ba hàm. Thu gom thêm cổng ví bị giữ. Kéo
về **sở hữu** trạng thái và cần ba chỗ trong `start` / `syncMotLuot` / `stop` đổi theo.

**Test sau mỗi bước:** `test/core/` + mọi tệp test nhắc chữ `SyncEngine` (46 tệp, đo 2026-10-19) + bốn test quét ở
mục 5. Trong đó, lưới chính là:
- 25 tệp `test/core/sync/`;
- `sync_payload_contract_test` — tên trường payload;
- `sync_push_result_truoc_pull_test` — thứ tự phát trước Pull;
- `sync_mot_luot_test` — trả lại `_currentIdaccount`;
- `sync_checkpoint_test` — mốc, `napMoc` / `datLaiPhien`;
- `sync_failure_handling_test` — bậc chặn, giãn cách.

**Cuối đợt:**
- toàn bộ `flutter test` = mốc **7.494** cộng đúng số ca mới, 0 fail, 10 skip;
- `flutter analyze` **20** issue, cùng tập mã lỗi; năm issue `curly_braces` đổi tệp;
- review toàn nhánh (giao rõ: soát **xuyên bước**);
- dựng `--release` **không** cần — không đụng mã Android gốc.

## 7. Tài liệu và chú thích mã

Làm ở **bước 5**, sau khi mã xong, là commit riêng.

- **Chú thích trong `lib/` và `test/`** nhắc tên cũ (`_collectPendingOps`, `_sendBatch`, `_pullFromBackend`,
  `_resolveCategoryId`, `_classifyFailure`, `_permanentCodes`, `sync_engine.dart` theo nghĩa *nơi đặt mã*) → đổi sang
  tệp / lớp / tên mới. Đo 2026-10-19: ~10 tệp `lib/`, ~9 tệp `test/` nhắc các tên riêng.
- ⚠️ `core/database/tables/transactions_table.dart` có hai docstring cột nhắc `_collectPendingOps`, và docstring cột
  chảy vào `app_database.g.dart`. Sửa chúng thì chạy `build_runner` (`clean` trước, vì bộ nhớ đệm không ghi lại tệp đã
  hoàn bằng git), commit **riêng** `.g.dart`. Lượt sinh ấy kéo theo chỗ lệch có sẵn (chú thích `Transaction.billId`,
  +5 −2) — đúng việc bàn giao 2026-10-19 hẹn *"lần `build_runner` kế commit riêng"*. **Chốt:** diff `.g.dart` chỉ
  được gồm chú thích (hai docstring vừa sửa + phần `billId`). Lớn hơn thế (bộ sinh / phiên bản trôi) thì **dừng, hỏi
  người dùng**, không commit.
- **Tài liệu sống** — sửa câu ở **thì hiện tại** nói *mã nằm đâu*; câu lịch sử có ngày giữ nguyên. Danh sách:
  - `CLAUDE.md` — hàng *Đụng vào đồng bộ*, bảng test quét, *số tiếp theo*;
  - `docs/PROJECT_CONTEXT.md` — mục 6, 7 và khối mới mục 14;
  - `docs/KIEN_TRUC_CLIENT_APP.md` — bảng mục 2 (`2.166 dòng`), cây `core/sync` 8 → 14, `core` 100 → 106, phép đo
    `core → features` mục 4, mục 9 và điểm 5 mục 10 gỡ nhược điểm *"SyncEngine một tệp"*, bảng quét;
  - `docs/superpowers/sync/SYNC_DOCUMENTATION.md`;
  - `docs/bill/BILL_DOCUMENTATION.md`;
  - `docs/GOAL_FEATURE.md`;
  - `docs/CLIENT_APP_KNOWN_GAPS.md`;
  - `docs/CATEGORY_RATIONALE.md`;
  - `docs/NOTIFICATION_FEATURE.md`;
  - `docs/AI_EDGE_FEATURE.md`.

  Cùng soát `CAN-LAM/`: đơn trong hàng đợi cũng là tài liệu. Tài liệu do backend tạo vẫn chỉ đọc
  (`git log --follow --format='%an'` trước khi sửa).
- **Không sửa:** `DA-XONG/`, `plans/`, spec cũ, tệp bàn giao — chúng là ảnh chụp có ngày.

**Chú thích sai phát hiện khi đo** — sửa ở bước 5, chỉ đổi chữ. Docstring `mocPullConDungKhong` viết *"Công khai để test
gọi thẳng"*, nhưng **0** test gọi nó (đo 2026-10-19). Viết lại theo sự thật: công khai vì là API của engine, đường chạy
thật dùng nó ở `napMoc`.

## 8. Ngoài phạm vi

- Đổi hành vi dưới mọi hình thức, kể cả đổi `DateTime.now()` trần sang đồng hồ tiêm (mục 4.5).
- Sửa lỗi tìm thấy khi dời: ghi vào báo cáo, làm riêng.
- Tách tiếp `pullFromBackend` (616 dòng một phương thức) hay mỗi bảng một tệp.
- Đổi constructor, DI, tên luồng, tiền tố log.
- Sửa năm issue `curly_braces` (đổi kiểu mã, không đổi hành vi — để lượt dọn lint riêng nếu muốn).
- Unit test riêng cho ba lớp mới: chúng được chạy qua `SyncEngine` thật trong lưới hồi quy, và dời nguyên văn không thêm
  nhánh nào.

## 9. Rủi ro và cách chặn

| Rủi ro | Chặn |
|---|---|
| Quên một chỗ engine chạm trạng thái kéo | mục 4.2 liệt kê đủ ba chỗ đo được; `sync_checkpoint_test` + `sync_mot_luot_test` |
| Chụp giá trị thay vì đọc qua hàm | mục 4.3; ca giãn cách dùng đồng hồ giả ở `sync_failure_handling_test` |
| Dời lệch thứ tự đẩy / phát / kéo | `_runSync` **không** dời; `sync_push_result_truoc_pull_test` |
| Cột cục bộ lọt vào tệp mới | mục 5.1 — quét cả thư mục, có ca chặn |
| Tệp mới vượt 800 | quét 34; số đo từng bước ghi ở trần riêng |
| Phương thức tĩnh chuyển tiếp tự gọi đệ quy | import `moc_keo_ve.dart` có tiền tố (mục 4.4) |
| Lớp giả `implements SyncEngine` vỡ | không thêm thành viên công khai (mục 4.4) |
