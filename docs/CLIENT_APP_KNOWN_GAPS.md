# Client-app — Việc còn dang dở & rủi ro đã biết

**Cập nhật:** 2026-09-03
**Mục đích:** ghi lại những hạng mục đã được **cân nhắc và cố ý hoãn**, kèm lý do và bán kính ảnh hưởng. Không có tài liệu này thì người tiếp theo sẽ hoặc bỏ sót, hoặc làm lại từ đầu việc phân tích rủi ro.

Mỗi mục đều ghi rõ **vì sao hoãn** — đó là phần dễ mất nhất.

---
> **Phiên 2026-09-03 đã đóng 9/10 mục còn mở.** Mô tả gốc bên dưới được giữ nguyên
> (kể cả phần *vì sao hoãn*) vì nó ghi lại bối cảnh và bán kính ảnh hưởng — thứ vẫn
> cần khi ai đó đọc lại đoạn mã tương ứng. Chỉ có **G10** còn mở, và nó **chặn ở backend**.

| Mục | Đã làm gì | Test canh chừng |
|---|---|---|
| **G1** | Thêm `SyncStatus.authExpired`; `_runSync()` kết thúc ở `error` khi còn thao tác hỏng, `authExpired` khi phiên chết. Thêm `SyncStatusX.isTerminal` để test chờ trạng thái kết thúc bất kỳ (12 chỗ trong 6 file đã đổi theo). `scheduleSync()` nay quay lại `pending` được từ cả `error`. | `sync_failure_handling_test.dart` |
| **G2** | Giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p, kiểm ở đầu `_runSync`, reset khi có chu kỳ sạch và khi `start()`/`stop()`. Đồng hồ tiêm được qua tham số `now`. | nt (nhóm G2) |
| **G3** | `schemaVersion` 8 → 9: thêm `syncRetryCount` / `syncError` / `syncBlockedUntil` cho cả 6 bảng. Lỗi **vĩnh viễn** chặn bản ghi theo THỜI GIAN (không đổi `syncStatus` thành `'failed'`, đúng cảnh báo ở mục G3). `markSynced` xoá sạch dấu vết. | nt (nhóm G3) |
| **G4** | Gỡ mọi fallback về admin: `_getAccountId` (có `?? 1` và `return 1`) ở 4 trang bill/goal, **và 9 biểu thức `?? 1` nội tuyến** ở `goal_page.dart` / `goal_add_page.dart`. Thay bằng `core/auth/current_account.dart` trả `int?` — đường ĐỌC dùng `?? 0` (rỗng, không phải dữ liệu admin), đường GHI chặn hẳn kèm thông báo. Bỏ **mọi** nhánh `getAllNonDeleted()` không lọc tài khoản (4 trang + `goal_repository_impl.dart`); nay không còn nơi gọi nào. | `test/core/auth/current_account_test.dart` |
| **G5** | `isLocalDbEmpty` dùng `walletDao.getAll(accountId)`. | — |
| **G8** | Cả 6 chỗ dùng thẳng tham số `idaccount` của `_collectPendingOps`. | `sync_payload_contract_test.dart` |
| **G9** | `conflict` = LWW đã phân xử, server thắng → `markSynced` để thoát vòng đẩy lại vô hạn. | `sync_failure_handling_test.dart` |
| **G11** | `schemaVersion` 7 → 8 + migration `UPDATE categories SET is_local_only = 0, sync_status = 'pending' WHERE is_local_only = 1`. | `category_dao_test.dart` |
| **G12** | `AuthInterceptor` phát `sessionExpiredStream` khi xoá token (chỉ khi thật sự có token để mất, tránh dội sự kiện); AuthBloc nghe kênh này song song với `SyncEngine`. | `test/core/api/auth_interceptor_test.dart`, `session_validation_test.dart` |
| **G10** | ⛔ Không sửa được ở client — xem `docs/superpowers/backend/CATEGORY_GROUP_MEMBERSHIP_SYNC.md`. | — |


## 1. Việc đã cố ý hoãn

### ~~G1 — Trạng thái kết thúc của `_runSync()` luôn là `idle`, kể cả khi mọi thao tác đều thất bại~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** `sync_engine.dart` kết thúc chu kỳ bằng `_setStatus(SyncStatus.idle)` bất kể kết quả. `SyncStatus.error` gần như là mã chết đối với lỗi đẩy dữ liệu, vì `_sendBatch` không ném lỗi ra ngoài nên khối `catch` không bao giờ chạm tới.

**Vì sao hoãn:** đổi trạng thái kết thúc sẽ làm **treo 11 chỗ trong 6 file test** đang chờ đúng `SyncStatus.idle`:

```
test/core/sync/sync_checkpoint_test.dart
test/core/sync/sync_failure_handling_test.dart
test/core/sync/sync_payload_contract_test.dart
test/e2e_sqlite_to_backend_sync_test.dart
test/features/auth/session_validation_test.dart
test/features/category/category_create_test.dart
```

Chúng dùng `await statusStream.where((s) => s == SyncStatus.idle).first` kèm `.timeout(5s)` — đổi trạng thái mà không sửa đồng thời thì test sẽ fail dạng "timeout", rất khó đọc.

**Cách làm khi bắt tay vào:** thêm `SyncStatus.authExpired`, đổi 11 chỗ trên sang chờ **trạng thái kết thúc bất kỳ** (`idle | error | authExpired`) trong cùng một lần sửa. Lưu ý `scheduleSync()` chỉ chuyển sang `pending` khi status đang `idle`, nên nếu status kẹt ở `error` thì nhãn "chờ đồng bộ" sẽ không còn hiện.

**Giá trị thu được:** trung bình. Việc thoát khỏi vòng lặp lỗi đã được giải quyết bằng kênh `sessionInvalidStream` riêng; mục này chỉ làm trạng thái phản ánh đúng thực tế.

---

### ~~G2 — Không có exponential backoff~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** thao tác thất bại loại `transient` được thử lại ở chu kỳ kế tiếp, không giãn dần. Nguồn kích hoạt gồm: debounce 2 giây sau mỗi lần ghi dữ liệu (nhiều call-site `scheduleSync()` rải khắp các repository), đổi trạng thái kết nối, timer định kỳ 15 phút, và mỗi lần `start()`.

**Vì sao hoãn:** bản bền vững cần thêm cột vào schema (xem G3). Bản chỉ giữ trong RAM thì làm được ngay nhưng mất tác dụng sau mỗi lần mở lại app.

**Cách làm:** `_consecutiveFailures` + `_nextAllowedSyncAt` (30s → 1p → 5p → 15p → 60p), kiểm tra ở đầu `_runSync`. Reset khi có một chu kỳ thành công.

---

### ~~G3 — Lược đồ SQLite không có trạng thái thất bại~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** `schemaVersion = 7`. Các bảng chỉ có `syncStatus` với đúng hai giá trị được ghi trong thực tế: `'pending'` và `'synced'`. Không có `syncRetryCount`, `syncError`, `syncBlockedUntil`. Một bản ghi lỗi vĩnh viễn vẫn nằm ở `pending` mãi mãi.

**Vì sao hoãn:** cần bump `schemaVersion` + viết migration chạy trên máy người dùng thật — rủi ro cao hơn hẳn các thay đổi thuần logic.

> ⚠️ **Bẫy khi làm:** đừng chuyển `syncStatus` sang `'failed'` rồi loại khỏi `getPending`. Cơ chế thử lại hợp lệ (giao dịch tham chiếu ID danh mục mặc định cũ, phải Pull xong mới đẩy lại được) sẽ chết theo. Dùng `syncBlockedUntil` + backoff thay vì loại vĩnh viễn.

---

### ~~G4 — Nhiều truy vấn không lọc theo tài khoản~~ · ✅ ĐÃ SỬA (2026-09-03)

**Hiện trạng:** `WalletDao.getAllNonDeleted()` không nhận tham số `idaccount`. Còn **5 nơi** đang gọi bản không lọc:

| Nơi gọi | Ghi chú |
|---|---|
| `lib/core/sync/sync_engine.dart:234` | Dùng để tính `isLocalDbEmpty` — quyết định có full pull hay không |
| `lib/features/bill/presentation/pages/bill_add_page.dart:57` | Danh sách ví để chọn |
| `lib/features/bill/presentation/pages/bill_page.dart:45` | nt |
| `lib/features/goal/data/repositories/goal_repository_impl.dart:113` | nt |
| `lib/features/goal/presentation/pages/goal_detail_page.dart:58` | nt |

`TransactionDao.watchAllNonDeleted()` và `GoalDao.watchAllNonDeleted()` cũng cùng dạng.

**Đã giảm nhẹ tới đâu:** đường nguy hiểm nhất — sync engine dùng nó để **suy ra danh tính người dùng** — đã bị gỡ bỏ. Việc đăng nhập cũng gọi `purgeDataForOtherAccounts()` nên dữ liệu tài khoản khác không còn tồn tại trong máy ở điều kiện bình thường.

**Vì sao hoãn:** lịch sử git có commit *"fix(goal): add watchAllNonDeleted fallback query in GoalDao to prevent goals from disappearing on wallet creation"* — tức việc **không lọc** từng được thêm **có chủ đích** để chữa một triệu chứng khác. Thêm bộ lọc mà không hiểu bug gốc đó rất có thể làm nó tái phát.

**Cách làm:** dựng lại kịch bản trong commit kia (tạo ví mới rồi xem danh sách mục tiêu) thành test trước, rồi mới thêm bộ lọc.

---

### ~~G5 — `isLocalDbEmpty` tính trên toàn bộ ví, không riêng tài khoản hiện tại~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart:234` — nếu máy còn ví của tài khoản khác, `isLocalDbEmpty` sẽ là `false` và bỏ qua full pull, dù tài khoản hiện tại chưa có dữ liệu gì. Sửa: dùng `walletDao.getAll(accountId)`. Nhỏ, nhưng nằm trong G4 nên gộp làm một lần.

---

### ~~G6 — `purgeDataForOtherAccounts()` chỉ chạy khi đăng nhập~~ · ✅ ĐÃ SỬA

Hàm dọn dữ liệu tài khoản khác trước đây chỉ được gọi trong `_onLoginSubmitted`. Nay được gọi cả trong `_onAuthCheckRequested` (khôi phục phiên lúc mở app), ngay trước `SyncEngine.start()`.

Test bao phủ: `session_validation_test.dart` — *"Khôi phục phiên cũng dọn dữ liệu tài khoản khác, không chỉ lúc đăng nhập"*.

---

### ~~G7 — Pull ghi cứng `isDeleted = false` cho mọi danh mục~~ · ✅ ĐÃ SỬA

`sync_engine.dart` nay đọc `isDeleted: Value(c['delete_at'] != null)` như các thực thể khác.

Đã kiểm chứng backend **không** lọc `delete_at` khi trả dữ liệu (`getCategoriesByAccount` chỉ lọc theo `is_default`/`create_by`/`update_at`), nên hàng đã xoá thật sự nằm trong response — đây là lỗi thật, không phải giả định.

Test bao phủ: `category_create_test.dart` — *"Pull đọc cờ xoá của danh mục thay vì hồi sinh nó"*.

---

### ~~G8 — Fallback `?? 1` vẫn còn trong khâu dựng payload đồng bộ~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart` dòng 671, 699, 781, 818, 859, 892 — cả 6 thực thể vẫn có `(_currentIdaccount ?? 1)`.

**Hiện KHÔNG gây hại:** `_runSync()` đã có chốt trả về sớm khi `_currentIdaccount == null`, nên nhánh `?? 1` không còn tới được. Nhưng nó vẫn là mìn: ai đó gọi `_collectPendingOps()` từ chỗ khác sẽ làm nó sống lại, và hậu quả là ghi dữ liệu dưới danh nghĩa **tài khoản admin**.

**Cách sửa:** đổi tham số của `_collectPendingOps` thành `int idaccount` bắt buộc và dùng thẳng nó thay cho `_currentIdaccount ?? 1`.

---

### ~~G9 — Trạng thái `conflict` bị bỏ lửng~~ · ✅ ĐÃ SỬA (2026-09-03)

`sync_engine.dart:1009-1014` — thao tác trả về `status == 'conflict'` chỉ được thêm vào `conflictIds` và `debugPrint`. Bản ghi **không** được `markSynced`, **không** tính vào `failed`, và không có bất kỳ mã giải quyết xung đột nào. Nó sẽ được đẩy lại ở mọi chu kỳ sau.

---

### G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ · ⛔ CHẶN Ở BACKEND

Quan hệ "danh mục mặc định thuộc nhóm nào" lưu trong bảng `CategoryGroupMemberships` nhưng **không có `SyncEntityType` tương ứng** (`sync_models.dart:11` chỉ có wallet/transaction/category/budget/bill/goal). Nghĩa là: nhóm và danh mục cá nhân giờ đã đồng bộ được, nhưng việc **gán danh mục mặc định vào nhóm** vẫn chỉ tồn tại trên một máy.

---

### ~~G11 — Không có migration đưa `isLocalOnly` của dữ liệu cũ về `false`~~ · ✅ ĐÃ SỬA (2026-09-03)

`schemaVersion` vẫn là 7. Người dùng đã có nhóm danh mục tạo **trước** phiên 2026-09-02 sẽ mang `isLocalOnly = true`, và bộ lọc trong `getSyncableCategories` sẽ loại chúng khỏi batch đẩy — tức **nhóm cũ không bao giờ lên backend**, chỉ nhóm tạo mới mới lên.

**Cách sửa:** bump `schemaVersion` lên 8 + migration `UPDATE categories SET is_local_only = 0, sync_status = 'pending' WHERE is_local_only = 1`.

---

### ~~G12 — `AuthInterceptor` xoá token khi refresh thất bại nhưng không báo cho ai~~ · ✅ ĐÃ SỬA (2026-09-03)

`auth_interceptor.dart` — `_clearTokens()` được gọi ở dòng 54 và 69, bản thân hàm nằm ở dòng 130-133. Không có mã nào trong `lib/` lắng nghe sự kiện này. App sẽ kẹt ở trạng thái `AuthSuccess` với token đã bị xoá: mọi request sau đó không có header → 401 → refresh (đã mất refresh token) → xoá lại → lặp cho tới khi khởi động lại app.

Kênh `sessionInvalidStream` thêm trong phiên 2026-09-02 mới chỉ nối từ **SyncEngine**, chưa nối từ interceptor.

---

### ~~G13 — Kích hoạt đồng bộ bị giãn cách từ chối thì không được hẹn lại~~ · ✅ ĐÃ SỬA (2026-09-04)

Phát hiện khi chạy app thật, không phải khi đọc mã: xoá một ngân sách trong lúc engine đang giãn cách thì thao tác đó **không lên tới backend**, kể cả sau khi giãn cách đã hết. Phải chờ tới lần mở app sau.

Đây là kiểu hỏng tệ nhất về mặt trải nghiệm: mục biến mất khỏi màn hình ngay lập tức nên người dùng tin là xong, trong khi máy khác vẫn thấy nó nguyên vẹn.

**Nguyên nhân:** nhánh giãn cách trong `_runSync` chỉ `debugPrint` rồi `return`. Ba nguồn kích hoạt còn lại đều thưa hoặc ngẫu nhiên — timer 15 phút, đổi trạng thái mạng, và `start()` lúc mở app — nên khoảng chờ thật dài hơn bậc giãn cách rất nhiều. Đã đo: chờ thêm 60 giây **sau** mốc hết giãn cách vẫn không có lệnh đẩy nào.

**Bản vá:** `_scheduleBackoffRetry()` — từ chối một yêu cầu đồng bộ nghĩa là **nợ người gọi một lần chạy**, nên hẹn giờ chạy lại đúng lúc hết giãn cách. Nhiều kích hoạt bị chặn liên tiếp dùng chung một hẹn giờ, nếu không thì mỗi lần ghi dữ liệu lại đẩy mốc chạy lại lùi về sau.

Bốn test canh vùng này ở `test/core/sync/sync_failure_handling_test.dart`, nhóm G2.

> ⚠️ Bản vá này chỉ rút ngắn **độ trễ**. Nguyên nhân khiến engine rơi vào giãn cách ngay từ đầu vẫn còn nguyên — xem G14.

---

### G14 — 5 danh mục cá nhân đẩy hỏng vĩnh viễn, kéo theo mọi thứ khác chậm · ⛔ CHẶN Ở BACKEND

Đo được trên app thật ngày 2026-09-04 với tài khoản có sẵn dữ liệu, bằng cách đọc log của `SyncEngine` trong trình duyệt:

```
[SyncEngine] Push failed [transient]: entity=category, localId=6d16eab1-…, reason=
… (5 danh mục, lặp lại ở MỌI chu kỳ)
[SyncEngine] Real Sync Complete: 0/5 synced successfully.
[SyncEngine] Đang trong thời gian giãn cách sau 2 chu kỳ hỏng — hoãn tới 19:50:31
```

**Chuỗi nguyên nhân**, đã đối chiếu bằng truy vấn PostgreSQL:

1. Backend **đã có** 5 danh mục cá nhân của tài khoản (Chi khác, Thu khác, Làm thêm, Trả nợ, Thu nợ), mỗi cái một UUID.
2. Trên một máy chưa từng chạy app, `PersonalDefaultCategories.ensureForAccount()` sinh lại đúng 5 danh mục đó với **UUID mới** — vì ID không ổn định giữa các máy (xem `CATEGORY_STABLE_IDS.md`).
3. Đẩy lên vi phạm quy tắc trùng tên → backend trả `status: failed` **kèm message rỗng**.
4. `reason` rỗng nên `_classifyFailure` không nhận ra được gì, xếp vào `transient` → **thử lại vĩnh viễn**.
5. Mọi chu kỳ đồng bộ vì thế kết thúc ở trạng thái hỏng → giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p.

**Bán kính ảnh hưởng rộng hơn tài liệu cũ ghi.** `CATEGORY_NAME_UNIQUENESS.md` mô tả hậu quả là "vi phạm trùng tên hỏng âm thầm". Thực tế nặng hơn: 5 thao tác hỏng vĩnh viễn này giữ engine trong giãn cách gần như liên tục, nên **mọi thay đổi khác** — ví, giao dịch, ngân sách — đều bị đẩy chậm theo. G13 chỉ rút ngắn độ trễ đó, không xoá được nó.

**Client sửa được một phần** khi backend gửi mã lỗi ổn định: thêm `if (code == 'CATEGORY_NAME_DUPLICATE') return SyncFailureKind.permanent;` vào `_classifyFailure` (`lib/core/sync/sync_engine.dart`). Khi đó 5 thao tác kia bị chặn theo thời gian như mọi lỗi vĩnh viễn khác thay vì kéo cả chu kỳ xuống. **Hiện chưa làm được** vì backend trả message rỗng, client không có gì để nhận diện.

**Sửa tận gốc thuộc backend**, theo thứ tự: `CATEGORY_STABLE_IDS.md` (ID ổn định, để máy mới không sinh lại danh mục trùng) → `CATEGORY_NAME_UNIQUENESS.md` (trả mã lỗi ổn định thay vì message rỗng).

---

## 2. Vấn đề đã biết nhưng thuộc về Backend

Xem hai tài liệu riêng trong `docs/superpowers/backend/`:

- **`SESSION_VALIDITY_FINDINGS.md`** — token của tài khoản đã xoá vẫn dùng được; `/auth/me` không chạm CSDL; `/sync/push` luôn trả HTTP 200.
- **`CATEGORY_CLASSIFY_ALIGNMENT.md`** — giá trị `Vay/nợ` (tài liệu) lệch với `Vay/no` (CSDL, seed, client).
- **`CATEGORY_GROUP_MEMBERSHIP_SYNC.md`** — G10: backend chưa có bảng/entity cho việc gán danh mục **mặc định** vào nhóm, nên quan hệ đó chỉ tồn tại trên một máy.
- **`CATEGORY_KEYWORD_SYNC.md`** — từ khoá phân loại tồn tại ở hai kho độc lập, không có đường nối; kèm một lỗ hổng phân quyền trong `POST /api/ai/classify/feedback`.
- **`CATEGORY_NAME_UNIQUENESS.md`** — hai unique index của `category` đang khác quy tắc nghiệp vụ theo cả hai chiều; client đã thi hành đúng quy tắc, CSDL thì chưa.
- **`CATEGORY_STABLE_IDS.md`** — ID danh mục mặc định sinh ngẫu nhiên mỗi lần seed, nên tên bị dùng làm khoá nối giữa hai phía; đây là nguyên nhân gốc của các lỗi 11.3–11.6.

Client **không** phụ thuộc vào việc backend có sửa hay không.

---

## 3. Lưu ý về kiểm thử

Trạng thái hiện tại (đã chạy thật, không phải đếm tay): `flutter test` toàn bộ **180/180 pass** trong ~10 giây, trên **27 file test / 6859 dòng**. Trước phiên 2026-09-02 là 56 pass / 9 fail và mất hơn 10 phút (một test treo tới timeout).

> ⚠️ **`.gitignore` dòng 77 có `test/`** — luật này khớp mọi thư mục tên `test` ở mọi cấp, và **đã tồn tại từ trước** phiên 2026-09-02 (kiểm chứng: `git diff .gitignore` chỉ thêm đúng một dòng `src/Backend/scripts/seed_roles.js`).
>
> Hệ quả đã đo được **tại thời điểm phát hiện** (2026-09-02): 16/23 file test đang được git theo dõi (commit trước khi luật có hiệu lực), 7/23 file thì không. Bảy file đó chứa 45 test:
>
> ```
> test/core/sync/sync_checkpoint_test.dart          (5 test)
> test/core/sync/sync_failure_handling_test.dart    (3 test)
> test/core/sync/sync_payload_contract_test.dart    (8 test)
> test/core/database/category_dao_test.dart         (9 test)
> test/features/auth/session_validation_test.dart   (9 test)
> test/features/category/category_create_test.dart  (8 test)
> test/features/wallet/default_account_data_initializer_test.dart (3 test)
> ```
>
> **✅ Đã xử lý (2026-09-02):** 7 file test bị chặn đã được đưa vào git bằng `git add -f`, cùng với `lib/core/sync/sync_checkpoint_store.dart`, và đã đi vào commit `ea0941b`. **Luật ignore lại cắn đúng như dự đoán:** hai file test tạo mới ngày 2026-09-03 (`test/core/api/auth_interceptor_test.dart`, `test/core/auth/current_account_test.dart`) cũng bị chặn âm thầm và phải `git add -f` lần nữa. Sau đó: **25/25 file test đều được git theo dõi**.
>
> **Nhưng luật ignore vẫn còn nguyên.** Mọi file test tạo MỚI từ nay vẫn sẽ bị chặn âm thầm. Cần quyết định: đây là quy ước có chủ đích (thì phải nhớ `git add -f` mỗi lần), hay luật đặt quá rộng (thì nên đổi `test/` thành đường dẫn cụ thể hơn, ví dụ `/Test/` cho thư mục script test cục bộ ở gốc repo).

### Vùng chưa có test nào

- ~~`lib/core/api/interceptors/auth_interceptor.dart`~~ — nay đã có `test/core/api/auth_interceptor_test.dart` (3 test, phiên 2026-09-03).
- 4 feature không có test và cũng không được import từ test: **analytics**, **home**, **profile**, **ai_chat**. (**budget** đã có 34 test từ 2026-09-04.)

---

## 4. Nguyên tắc rút ra từ phiên 2026-09-02

Ghi lại vì chúng đã lặp đi lặp lại trong dự án này:

1. **Tên trường sai không gây lỗi — nó im lặng.** Payload đi qua ba nơi định nghĩa tên trường độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend). Một tên sai chỉ đơn giản bị bỏ qua. `test/core/sync/sync_payload_contract_test.dart` khoá lại toàn bộ ánh xạ này — **cập nhật nó mỗi khi thêm trường mới cho sync**.

2. **`InsertMode.insertOrReplace` thay CẢ HÀNG.** Cột nào không gán trong companion sẽ bị đưa về giá trị mặc định. Đây từng xoá sạch cấu trúc nhóm danh mục sau mỗi lần pull. Toàn bộ 6 DAO nay dùng `insertAllOnConflictUpdate`. **Đừng đổi ngược lại.**

3. **Đừng bao giờ suy ra danh tính người dùng từ dữ liệu cục bộ.** `idaccount` chỉ được đến từ phiên đăng nhập.

4. **`idaccount = 1` là tài khoản admin THẬT**, không phải giá trị "chưa biết". Mọi fallback `?? 1` đều đã bị gỡ bỏ.
