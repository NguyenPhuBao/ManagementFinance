# Client-app — Việc còn dang dở & rủi ro đã biết

**Cập nhật:** 2026-09-10
**Mục đích:** ghi lại những hạng mục đã được **cân nhắc và cố ý hoãn**, kèm lý do và bán kính ảnh hưởng. Không có tài liệu này thì người tiếp theo sẽ hoặc bỏ sót, hoặc làm lại từ đầu việc phân tích rủi ro.

Mỗi mục đều ghi rõ **vì sao hoãn** — đó là phần dễ mất nhất.

---
> **Phiên 2026-09-03 đã đóng 9/10 mục có lúc đó.** Mô tả gốc bên dưới được giữ
> nguyên (kể cả phần *vì sao hoãn*) vì nó ghi lại bối cảnh và bán kính ảnh
> hưởng — thứ vẫn cần khi ai đó đọc lại đoạn mã tương ứng.
>
> **Đang mở tính tới 2026-09-10.** Mục đã đóng vẫn nằm lại trong bảng, gạch
> ngang tên — xoá đi thì người sau lại mở ra làm lần nữa.
>
> ⚠️ **Bảng này trôi khỏi thân tài liệu năm lần rồi** (G16, G17, G21, G18, G15 — cả năm đều
> ghi *còn mở* trong khi mục tương ứng bên dưới ghi *đã đóng*). Sửa một mục ở
> thân thì **phải sửa dòng của nó ở đây cùng lúc**; đây là bảng người đọc nhìn
> trước tiên nên nó sai là cả tài liệu sai.
>
> | Mục | Vì sao còn mở |
> |---|---|
> | ~~**G10**~~ | ✅ **Đóng 2026-09-07** — mỗi tài khoản nay có bản sao riêng, việc gán nhóm nằm trong `Idgroup` của chính hàng ấy |
> | ~~**G15**~~ | ✅ **Đóng 2026-09-07** — tab "Đã hết hạn" nay phân biệt "đã chốt sổ" với "hỏng, chưa bao giờ lên tới server". ⚠️ Dòng cũ ở đây ghi *hoãn có chủ ý*, mâu thuẫn với chính mục G15 bên dưới — **lần trôi thứ năm**; sửa 2026-09-10 |
> | ~~**G16**~~ | ✅ **Đóng trọn 2026-09-07.** Nguồn tự sinh đóng 2026-09-05; **vế lệch ràng buộc với CSDL cũng đã đóng** — hai partial unique index mới đều có `WHERE "Delete_at" IS NULL`. ⚠️ Dòng cũ ở đây ghi vế ấy *vẫn còn*, mâu thuẫn với chính mục G16 bên dưới; sửa 2026-09-08. Lớp cầm máu `_uniqueConstraintPattern` **vẫn giữ, đừng gỡ** |
> | ~~**G17**~~ | ✅ **Đóng 2026-09-07** — `context.watch<AuthBloc>()` + `key: ValueKey(idaccount)` trên `GoalPage`, có test canh. ⚠️ Dòng cũ ở đây ghi mục này còn mở, mâu thuẫn với chính mục G17 bên dưới; sửa 2026-09-08 |
> | **G18** | ⏸️ **THU HẸP DẦN, không còn chặn ở backend.** Cột `transaction.Idgoal` đã có từ 2026-09-07 và client đẩy/đọc nó; thứ còn lại chỉ là **hàng cũ trên server mang `Idgoal = NULL`**, chúng nhận ID khi được đẩy lại. ⚠️ Dòng cũ ở đây ghi *chặn ở backend*, mâu thuẫn với chính mục G18 bên dưới — **lần trôi thứ tư**; sửa 2026-09-08 |
> | **G19** | **Không phải lỗi** — ghi lại để người sau không "sửa" nhầm |
> | **G23** | Bản sao danh mục chỉ đầy đủ khi bộ mặc định **cục bộ** đầy đủ — pull tăng dần, tự khỏi ở lượt sau |
> | **G24** | Màu danh mục **không có cột** trên server — chặn ở backend |
> | ~~**G21**~~ | ✅ **Đóng 2026-09-07** — backend đã có ba cột `auto_deposit_*`, client đẩy và kéo cả ba. ⚠️ Dòng cũ ở đây ghi *chặn ở backend*, mâu thuẫn với chính mục G21 bên dưới; sửa 2026-09-08. Còn đúng một khe hở hẹp: hai máy cùng mở đúng lúc tới kỳ |
> | **G22** | **Không phải lỗi** — giờ trong mốc neo chỉ giữ được một chiều |
> | **G25** | **Không phải lỗi** — hai máy cùng sắp lại thứ tự ưu tiên khi ngoại tuyến thì được một thứ tự trộn (2026-09-08) |
> | **G26** | Hoãn có chủ ý — chưa có màn **duyệt giao dịch ngân hàng** cho sự kiện realtime trỏ tới; đây là một tính năng riêng, không phải phần còn thiếu của việc nối socket (2026-09-09) |
> | **G27** | Hoãn có chủ ý — không còn cách nói "ví này **được phép âm**" sau khi loại `debt` bị bỏ; cần một cột mới ở cả hai đầu cho một tình huống CSDL hiện không có hàng nào (2026-09-09) |
> | **G28** | ⛔ **Chặn ở backend** — cột `wallet."Status"` là `varchar(7)` trong khi chính `chk_wallet_status` cho phép `'Inactive'` (8 ký tự), nên **lưu trữ ví chỉ sống trên máy đã bấm** (2026-09-10) |
>
> **G20 đã đóng ngày 2026-09-05** — `depositToGoal` nhận `occurredAt` chặn hai
> đầu; đã kiểm cả bằng test lẫn trên máy ảo Android.

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
| ~~**G10**~~ | ✅ **ĐÓNG 2026-09-07 — không cần backend làm gì.** Bảng ấy tồn tại chỉ vì danh mục mặc định là hàng toàn cục nên không ghi `Idgroup` riêng cho từng tài khoản được. Nay **mỗi tài khoản có bản sao riêng** của bộ mặc định, nên việc gán nhóm nằm gọn trong `Idgroup` của chính hàng họ sở hữu — cột đã có và đã đồng bộ. Client đã gỡ mọi lời gọi tới bảng phụ; bảng còn trong lược đồ cục bộ nhưng không nơi nào ghi vào nữa. Xem `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`. | `default_category_seeder_test.dart` |


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

**Hiện trạng LÚC PHÁT HIỆN (2026-09-02):** `schemaVersion = 7`. Các bảng chỉ có `syncStatus` với đúng hai giá trị được ghi trong thực tế: `'pending'` và `'synced'`. Không có `syncRetryCount`, `syncError`, `syncBlockedUntil`. Một bản ghi lỗi vĩnh viễn vẫn nằm ở `pending` mãi mãi.

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

### ~~G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ~~ · ✅ ĐÓNG (2026-09-07)

Quan hệ "danh mục mặc định thuộc nhóm nào" lưu trong bảng `CategoryGroupMemberships`, và bảng ấy **không có `SyncEntityType` tương ứng** nên chỉ tồn tại trên một máy.

**Cách đóng không phải là thêm entity.** Bảng phụ ấy tồn tại chỉ vì danh mục mặc định là hàng **toàn cục** — không ghi `Idgroup` riêng cho từng tài khoản lên một hàng dùng chung được. Ngày 2026-09-07 client đổi hướng: mỗi tài khoản có **bản sao riêng** của bộ mặc định, còn hàng toàn cục lui về làm khuôn. Từ đó việc gán nhóm nằm gọn trong `Idgroup` của chính hàng người dùng sở hữu — một cột đã có sẵn, đã nằm trong payload đẩy và đã được `upsertCategory` ghi thật.

Client đã gỡ mọi lời gọi tới bảng phụ. Bảng vẫn còn trong lược đồ SQLite cục bộ vì bỏ một bảng Drift là một migration trên máy đang có dữ liệu, nhưng **không nơi nào ghi vào nó nữa**.

---

### ~~G11 — Không có migration đưa `isLocalOnly` của dữ liệu cũ về `false`~~ · ✅ ĐÃ SỬA (2026-09-03)

**Mô tả lúc phát hiện (2026-09-02):** `schemaVersion` khi ấy vẫn là 7. Người dùng đã có nhóm danh mục tạo **trước** phiên 2026-09-02 sẽ mang `isLocalOnly = true`, và bộ lọc trong `getSyncableCategories` sẽ loại chúng khỏi batch đẩy — tức **nhóm cũ không bao giờ lên backend**, chỉ nhóm tạo mới mới lên.

**Cách sửa:** bump `schemaVersion` lên 8 + migration `UPDATE categories SET is_local_only = 0, sync_status = 'pending' WHERE is_local_only = 1`.

---

### ~~G12 — `AuthInterceptor` xoá token khi refresh thất bại nhưng không báo cho ai~~ · ✅ ĐÃ SỬA (2026-09-03)

`auth_interceptor.dart` — `_clearTokens()` được gọi ở dòng 54 và 69, bản thân hàm nằm ở dòng 130-133. Không có mã nào trong `lib/` lắng nghe sự kiện này. App sẽ kẹt ở trạng thái `AuthSuccess` với token đã bị xoá: mọi request sau đó không có header → 401 → refresh (đã mất refresh token) → xoá lại → lặp cho tới khi khởi động lại app.

Kênh `sessionInvalidStream` thêm trong phiên 2026-09-02 mới chỉ nối từ **SyncEngine**, chưa nối từ interceptor.

---

### ~~G13 — Kích hoạt đồng bộ bị giãn cách từ chối thì không được hẹn lại~~ · ✅ ĐÃ SỬA (2026-09-03)

Phát hiện khi chạy app thật, không phải khi đọc mã: xoá một ngân sách trong lúc engine đang giãn cách thì thao tác đó **không lên tới backend**, kể cả sau khi giãn cách đã hết. Phải chờ tới lần mở app sau.

Đây là kiểu hỏng tệ nhất về mặt trải nghiệm: mục biến mất khỏi màn hình ngay lập tức nên người dùng tin là xong, trong khi máy khác vẫn thấy nó nguyên vẹn.

**Nguyên nhân:** nhánh giãn cách trong `_runSync` chỉ `debugPrint` rồi `return`. Ba nguồn kích hoạt còn lại đều thưa hoặc ngẫu nhiên — timer 15 phút, đổi trạng thái mạng, và `start()` lúc mở app — nên khoảng chờ thật dài hơn bậc giãn cách rất nhiều. Đã đo: chờ thêm 60 giây **sau** mốc hết giãn cách vẫn không có lệnh đẩy nào.

**Bản vá:** `_scheduleBackoffRetry()` — từ chối một yêu cầu đồng bộ nghĩa là **nợ người gọi một lần chạy**, nên hẹn giờ chạy lại đúng lúc hết giãn cách. Nhiều kích hoạt bị chặn liên tiếp dùng chung một hẹn giờ, nếu không thì mỗi lần ghi dữ liệu lại đẩy mốc chạy lại lùi về sau.

Bốn test canh vùng này ở `test/core/sync/sync_failure_handling_test.dart`, nhóm G2.

> ⚠️ Bản vá này chỉ rút ngắn **độ trễ**. Nguyên nhân khiến engine rơi vào giãn cách ngay từ đầu vẫn còn nguyên — xem G14.

---

### ~~G14 — 5 danh mục cá nhân đẩy hỏng vĩnh viễn, kéo theo mọi thứ khác chậm~~ · ✅ ĐÃ SỬA Ở CLIENT (2026-09-03)

> **Bản vá:** `PersonalDefaultCategories` tách làm hai giai đoạn. `convertLegacyRows()` chạy trước chu kỳ đồng bộ đầu tiên và **chỉ đụng tới máy còn hàng seed `cat_*`** — máy sạch thì không tạo gì. `ensureMissing()` chạy **sau** khi pull xong, lúc đã biết tài khoản thật sự đang có những gì. `auth_bloc` gọi hai giai đoạn đúng thứ tự ở cả đường đăng nhập lẫn khôi phục phiên, và chỉ gọi giai đoạn 2 khi `SyncEngine.hasCompletedPull` — pull hỏng thì hoãn tới lần mở app sau chứ không tạo mù.
>
> Cũng vá luôn một lỗ hổng có sẵn từ bản gốc: hàng seed `cat_*` **tự khớp tên với chính nó**, bị dùng làm đích trỏ tới rồi bị xoá mềm ngay sau — giao dịch kết thúc ở một danh mục đã xoá. Nay `_findOwned` loại chính hàng đó ra khỏi tập ứng viên.
>
> 6 test canh vùng này ở `test/features/category/data/personal_default_categories_test.dart` (còn 6 sau khi nhóm `foldIntoBackendDefaults` bị gỡ ngày 2026-09-07 — xem G16).
>
> **Máy đã lỡ tạo bản trùng cũng đã tự thoát được.** Bản vá trên ngăn phát sinh mới; bước khử trùng lặp sau pull dọn nốt hậu quả cũ — xem cuối mục này.

Đo được trên app thật ngày 2026-09-03 với tài khoản có sẵn dữ liệu, bằng cách đọc log của `SyncEngine` trong trình duyệt:

```
[SyncEngine] Push failed [transient]: entity=category, localId=6d16eab1-…, reason=
… (5 danh mục, lặp lại ở MỌI chu kỳ)
[SyncEngine] Real Sync Complete: 0/5 synced successfully.
[SyncEngine] Đang trong thời gian giãn cách sau 2 chu kỳ hỏng — hoãn tới 19:50:31
```

**Chuỗi nguyên nhân**, đã đối chiếu bằng truy vấn PostgreSQL:

1. Backend **đã có** 5 danh mục cá nhân của tài khoản (Chi khác, Thu khác, Làm thêm, Trả nợ, Thu nợ), mỗi cái một UUID — do một máy trước đó tạo ra và đẩy lên.
2. Trên một máy chưa từng chạy app, `PersonalDefaultCategories.ensureForAccount()` sinh lại đúng 5 danh mục đó với **UUID mới**.
3. Đẩy lên vi phạm quy tắc trùng tên → backend trả `status: failed` **kèm message rỗng**.
4. `reason` rỗng nên `_classifyFailure` không nhận ra được gì, xếp vào `transient` → **thử lại vĩnh viễn**.
5. Mọi chu kỳ đồng bộ vì thế kết thúc ở trạng thái hỏng → giãn cách luỹ tiến 30s → 1p → 5p → 15p → 60p.

**Bán kính ảnh hưởng rộng hơn tài liệu cũ ghi.** `CATEGORY_NAME_UNIQUENESS.md` mô tả hậu quả là "vi phạm trùng tên hỏng âm thầm". Thực tế nặng hơn: 5 thao tác hỏng vĩnh viễn này giữ engine trong giãn cách gần như liên tục, nên **mọi thay đổi khác** — ví, giao dịch, ngân sách — đều bị đẩy chậm theo. G13 chỉ rút ngắn độ trễ đó, không xoá được nó.

#### Nguyên nhân là THỨ TỰ chạy ở client, không phải ID không ổn định

> ⚠️ Bản ghi đầu tiên của mục này (commit `25915ec`) quy sai cho `CATEGORY_STABLE_IDS.md`. Đọc lại mã nguồn thì không phải vậy. Giữ lại đính chính này vì nó đúng kiểu sai mà mục 4 dưới đây cảnh báo: kết luận từ một tài liệu liên quan thay vì từ mã nguồn.

`ensureForAccount()` **có** kiểm trùng — nó gọi `getNamesInUse(idaccount)` rồi so bằng `normalizeCategoryName`, và chỉ tạo khi không thấy bản nào cùng tên ([`personal_default_categories.dart:55-66`](../src/Client-app/lib/features/category/data/services/personal_default_categories.dart)).

Vấn đề là nó chạy **trước** `SyncEngine.start()` trong `auth_bloc.dart` (cả hai đường: đăng nhập và khôi phục phiên). Đó là chủ ý, có ghi chú hẳn hoi: việc chuyển dữ liệu cũ trỏ vào hàng seed `cat_*` phải xong trước khi chu kỳ đồng bộ đầu tiên chạm vào. Nhưng trên máy mới, CSDL cục bộ **rỗng** nên phép kiểm trùng không thấy gì → tạo 5 UUID mới → pull sau đó mới kéo về 5 bản của backend → trùng tên.

Hai hướng sửa, đều thuần client:

- **Hoãn tới sau lần pull đầu tiên khi không có gì để chuyển đổi.** Nếu trong máy không tồn tại hàng `cat_*` nào thì lý do "phải chạy trước start()" không còn, và chờ pull xong mới tạo là an toàn.
- **Khử trùng lặp sau pull.** `removeDuplicateLocalSeedCategories()` đã làm việc tương tự nhưng chỉ cho `isDefault = true` và chỉ xoá bản có id không phải UUID — không xử lý được hai danh mục **người dùng** cùng tên mà cả hai đều là UUID. Cần mở rộng, kèm repoint tham chiếu trước khi xoá (repoint TRƯỚC, xoá SAU — đảo lại chính là lỗi 11.6).

**Phần thuộc backend là lớp phòng thủ thứ hai, không phải điều kiện tiên quyết:** cho `/sync/push` trả mã lỗi ổn định `CATEGORY_NAME_DUPLICATE` thay vì message rỗng, để client xếp được vào `permanent` bằng một dòng trong `_classifyFailure`. Đáng làm vì **mọi** vi phạm trùng tên khác cũng sẽ hỏng theo đúng kiểu này, không riêng 5 danh mục trên.

#### Dọn hậu quả trên máy đã lỡ tạo bản trùng · ✅ ĐÃ LÀM (2026-09-03)

Bản vá thứ tự chỉ ngăn phát sinh mới. Máy nào đã chạy bản client cũ và tạo ra 5 danh mục trùng thì chúng vẫn nằm ở `pending` và vẫn hỏng mỗi chu kỳ. `CategoryDao.mergeDuplicatePersonalCategories(idaccount)` dọn nốt phần đó, chạy **sau pull**, ngay sau `removeDuplicateLocalSeedCategories()` trong `SyncEngine`.

Cách nó chọn bản giữ lại:

- Gom các danh mục **không mặc định, chưa xoá** của tài khoản theo `normalizeCategoryName` — không tính `classify`, đúng quy tắc 7.
- Chỉ hành động khi nhóm có **đúng một** bản `synced` — đó là bản backend công nhận. Không bản nào hoặc nhiều hơn một thì bỏ qua, không đoán bừa.
- Chỉ hấp thụ các bản `pending`. Một hàng đã `synced` không bao giờ bị xoá — nó có thể đang được máy khác dùng.

`_absorbCategory()` **repoint TRƯỚC, xoá SAU** (đảo lại chính là lỗi 11.6):

1. `repointCategoryReferences()` — giao dịch, ngân sách, hoá đơn.
2. `parentId` của các danh mục con.
3. Từ khoá phân loại — bỏ qua những từ khoá bản giữ lại đã có, vì khoá duy nhất là `(idaccount, categoryId, normalizedKeyword)`.
4. Xoá thành viên nhóm của bản bị hấp thụ.
5. **Xoá vật lý** hàng đó.

Xoá vật lý là ngoại lệ có chủ ý của quy tắc 5: hàng `pending` này **chưa từng tồn tại trên server**, nên không có gì để đồng bộ; xoá mềm sẽ để lại đúng một thao tác đẩy vô nghĩa — thứ đang gây ra chính vấn đề này.

`removeDuplicateLocalSeedCategories()` vẫn giữ nguyên vai trò cũ: nó chỉ lo cho `isDefault = true` và chỉ xoá bản có id không phải UUID. Hai hàm bổ sung nhau chứ không chồng nhau.

9 test canh vùng này ở `test/core/database/category_dao_test.dart`, nhóm `mergeDuplicatePersonalCategories — dọn bản trùng do máy tự tạo`.

---

### G15 — Bản ghi vừa hết hạn vừa hỏng đồng bộ thì không sửa được · ✅ ĐÓNG (2026-09-07)

Tab **"Đã hết hạn"** của trang ngân sách khoá cả sửa lẫn xoá — đúng yêu cầu: số
liệu đã chốt sổ không được đổi về sau. Nhưng khoá đó không phân biệt "đã chốt
sổ" với "hỏng, chưa bao giờ lên tới server".

Một ngân sách rơi vào **cả hai** trạng thái kẹt không lối thoát: không đẩy lên
được (backend từ chối vĩnh viễn), mà cũng không mở ra sửa hay xoá được. **Đã
gặp thật** ngày 2026-09-04 với một ngân sách bị sửa thành `end = start`, vi phạm
`chk_budget_end_after_start`; lối thoát duy nhất khi ấy là xoá dữ liệu site của
trình duyệt rồi pull lại từ server.

**Đã sửa 2026-09-07** theo đúng hướng ghi sẵn ở đây: *khoá thao tác là để bảo
vệ số liệu đã chốt, không phải để nhốt dữ liệu hỏng.*

- Quy tắc gom về **một nơi**: `domain/budget_locking.dart`,
  `budgetActionsLocked({expired, budget})`. Trước đó phép kiểm nằm rải **ba**
  chỗ trong giao diện — chặn vuốt xoá, bỏ nút Sửa trên trang chi tiết, và (chỗ
  thật sự quyết định) danh sách hết hạn dựng thẻ mà **không truyền** `onEdit`/
  `onDelete`. Nới hai chỗ đầu mà quên chỗ thứ ba thì không có gì đổi cả.
- `BudgetEntity` nay mang `syncError` (cột đã có sẵn trong bảng từ G3, chỉ là
  chưa đưa lên tầng model) và `hasSyncError`.
- Thẻ hỏng có dấu hiệu riêng — biểu tượng `cloud_off` kèm chữ "Chưa đồng bộ
  được". **Không** nêu nguyên văn lỗi backend: nó là stack trace hoặc câu
  tiếng Việt của server, cả hai đều không giúp người dùng làm gì.
- Dòng thông báo đầu tab đổi theo: câu cũ "không sửa hay xoá" nay chỉ hiện khi
  **không có** thẻ hỏng. Để nguyên là giao diện nói sai về chính nó — người
  dùng thấy một thẻ sửa được ngay dưới dòng bảo không sửa được.

**Yêu cầu gốc KHÔNG bị nới.** Ngân sách hết hạn và đồng bộ sạch vẫn khoá y như
trước. Hai phép canh cho chiều ấy nằm cùng chỗ với phép canh cho ngoại lệ:
`budget_locking_test.dart` (ca *"hết hạn và đồng bộ sạch thì khoá"*) và
`budget_tabs_view_test.dart` (ca *"bản ghi SẠCH vẫn khoá, kể cả khi có thẻ
hỏng"* — mở cả danh sách vì có **một** thẻ hỏng là bỏ luôn yêu cầu gốc mà không
ai nhận ra).

⚠️ Chuỗi `syncError` **rỗng** không tính là hỏng. Vài đường ghi xoá cột ấy về
rỗng chứ không về `null`; coi rỗng là "đang hỏng" sẽ mở khoá cho **mọi** ngân
sách hết hạn. Có test canh riêng ca này.

---

### ~~G16 — Xoá một danh mục cá nhân mặc định thì nó mọc lại ở mỗi lần mở app~~ · ✅ ĐÃ ĐÓNG (2026-09-05)

Chuỗi năm bước, mỗi bước đều đúng theo ý đồ riêng của nó, nhưng ghép lại thì hỏng:

1. Người dùng xoá một trong 5 danh mục cá nhân mặc định. Xoá mềm, đẩy lên, server đặt `Delete_at`.
2. Lần mở app sau, `PersonalDefaultCategories.ensureMissing()` chạy (gọi ở `auth_bloc.dart:135` khi đăng nhập và `:176` khi khôi phục phiên).
3. Hàm đó hỏi `CategoryDao.getNamesInUse()` xem tài khoản còn thiếu gì. Nhưng `getNamesInUse` lọc `isDeleted = false` **và** `deletedAt IS NULL` — nên nó **không thấy hàng người dùng vừa xoá**, và kết luận là còn thiếu.
4. `_create()` tạo lại danh mục với **UUID mới**, `syncStatus = 'pending'`.
5. Đẩy lên đụng `uq_category_owner_name_classify` phía PostgreSQL. Index đó **không có mệnh đề `WHERE`** nên hàng đã xoá mềm vẫn giữ chỗ tên → PostgreSQL trả **23505**.

Và bản ghi đó không thoát ra được: `_classifyFailure` (`lib/core/sync/sync_engine.dart`) không có nhánh nào cho vi phạm UNIQUE — chỉ có `23514` cho ràng buộc CHECK — nên 23505 rơi vào `transient` và được **đẩy lại ở mọi chu kỳ**. `_markBlockedById` chỉ chạy với `permanent`, nên bản ghi giữ nguyên `pending` mãi mãi.

**Mỗi lần mở app lại thêm một bản ghi kẹt.**

**Vì sao trước đây không ai thấy.** `getNamesInUse` lọc hàng đã xoá là **cố ý và đúng** — quy tắc 7 nói "hàng đã xoá mềm không giữ chỗ", nên người dùng phải tạo lại được danh mục cùng tên. Lỗi nằm ở chỗ `ensureMissing` dùng nhầm hàm đó để trả lời một câu hỏi khác: *"tài khoản này có chủ ý không muốn danh mục đó không?"* — chứ không phải *"tên này còn trống không?"*.

**Đã làm ở phía client (2026-09-04):** `_classifyFailure` có thêm `_uniqueConstraintPattern` khớp `23505 | violates unique constraint | unique constraint failed` → xếp `permanent`. Bản ghi hỏng nay bị chặn **theo thời gian** thay vì đẩy lại ở mọi chu kỳ, nên nó không còn kích hoạt giãn cách luỹ tiến và không kéo chậm các thay đổi khác. Hai test canh chừng ở `test/core/sync/sync_failure_handling_test.dart` — một cho dạng câu chữ Prisma bọc, một cho mã SQLSTATE trần, vì Prisma đổi cách diễn đạt theo phiên bản.

> ⚠️ Đây là **lớp cầm máu, không phải bản vá gốc**. Bản ghi vẫn được tạo ra ở mỗi lần mở app, chỉ là không còn đẩy lại vô hạn.

~~**Còn chờ backend:** thêm `WHERE "Delete_at" IS NULL` vào unique index~~ — ✅ **backend làm xong 2026-09-07**, xem đoạn cuối mục này. Hồ sơ: `CATEGORY_NAME_UNIQUENESS.md` mục 4.1 và mục 10 của `2026-09-04-ocr-classify-review.md`. Khi có, bản ghi bị chặn tự quay lại hàng đợi mà người dùng không phải làm gì.

> ### ⚠️ Cập nhật 2026-09-07 — cách đóng đã đổi, nhưng G16 vẫn đóng
>
> `foldIntoBackendDefaults()` **đã bị gỡ**. Hướng đi đảo chiều: mỗi tài khoản nay
> có **bản sao riêng** của toàn bộ bộ mặc định (`DefaultCategorySeeder`), còn
> hàng toàn cục lui về làm khuôn và không hiện ra ở đâu. Để hàm gộp chạy song
> song với bước sao chép là một vòng lặp huỷ lẫn nhau.
>
> **Vì sao G16 vẫn không quay lại:** luật tạo bản sao đếm **cả hàng đã xoá mềm**.
> Người dùng xoá một danh mục thì hàng xoá mềm còn đó, và lượt seed sau nhìn thấy
> nó nên **không tạo lại**. Ba chữ ấy là khác biệt **duy nhất** với `ensureMissing()`
> — ai "dọn dẹp" chúng đi là tái hiện nguyên vẹn G16.
>
> Thiết kế: `docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`.
>
> Phần dưới giữ nguyên làm hồ sơ của chặng 2026-09-05.

**Đóng ngày 2026-09-05 — bằng cách bỏ hẳn nguồn kích hoạt.** Câu hỏi mà `ensureMissing` không trả lời được ("chưa từng có" hay "người dùng đã cố tình xoá") nay **không cần trả lời nữa**: backend đã nhận đúng 5 danh mục ấy vào bộ mặc định của nó (`Create_by = 1`, `Is_default = true`), nên không tài khoản nào phải giữ bản riêng.

`ensureMissing()` được thay bằng `foldIntoBackendDefaults()`: gộp bản riêng vào bản mặc định (dời tham chiếu ở cả `transactions`, `budgets`, `bills`) rồi **xoá mềm** bản riêng — và **không tạo mới gì cả**. Danh mục mặc định là toàn cục, không thuộc tài khoản nào, nên không còn gì để "mọc lại" ở mỗi lần mở app.


Ba điều kiện dừng, vì gộp là thao tác phá huỷ:

| Tình huống | Xử lý |
|---|---|
| Không thấy bản mặc định (backend cũ, hoặc pull hỏng) | Không đụng gì — không tạo, không xoá |
| Trùng tên nhưng **khác classify** | Không gộp. Quy tắc 7 không tính classify, nên một danh mục người dùng tự tạo có thể trùng tên mà khác loại; gộp nó là âm thầm đổi loại của mọi giao dịch bên trong |
| Hàng của tài khoản khác | Không đụng. `getNamesInUse` trả cả hàng mặc định của mọi tài khoản nên phép lọc phải nằm ở chính chỗ tìm bản riêng |

~~Test canh chừng: nhóm `foldIntoBackendDefaults` — chín ca.~~ **Nhóm ấy đã bị xoá cùng hàm, 2026-09-07.** Phép canh cho cơ chế hiện tại nằm ở `test/features/category/data/services/default_category_seeder_test.dart` — 13 ca, trong đó ca *"bản sao đã bị xoá mềm thì KHÔNG tạo lại"* chính là phép canh G16.

✅ **Phần lệch ràng buộc với CSDL cũng đã đóng — 2026-09-07.** Trước đó `uq_category_owner_name_classify` không có `WHERE "Delete_at" IS NULL`, nên hàng đã xoá mềm vẫn giữ chỗ tên ở PostgreSQL trong khi client cho tạo lại (quy tắc 7): xoá rồi tạo lại một danh mục **của chính mình** cùng tên vẫn nhận 23505. Đợt migration 2026-09-07 thay nó bằng hai partial unique index **có** mệnh đề ấy — và bỏ luôn `Classify` khỏi khoá, đúng quy tắc 7. Đo trên CSDL thật cùng ngày.

⚠️ Lớp cầm máu `_uniqueConstraintPattern` trong `_classifyFailure` **vẫn giữ, đừng gỡ.** Nó không còn phục vụ ca trên nữa, nhưng 23505 vẫn xảy ra được — hai người dùng khác nhau trùng tên danh mục mặc định, hay bất kỳ ràng buộc UNIQUE nào khác — và không có nó thì bản ghi hỏng quay lại bị đẩy ở mọi chu kỳ. Từ 2026-09-07 nhánh phân loại đi theo `code` của backend (`UNIQUE_VIOLATION`, `CATEGORY_NAME_DUPLICATE`), regex chỉ còn là đường dự phòng.

---

### G17 — Trang đọc theo tài khoản không đăng ký lại khi phiên tới muộn · ✅ ĐÓNG (2026-09-07)

Tái hiện nhiều lần trên máy ảo. Vào Mục tiêu **ngay sau khi mở app nguội** thì
danh sách rỗng dù CSDL có dữ liệu; thoát ra vào lại là thấy.

**Nguyên nhân gốc — ghi chép cũ nói sai.** Bản ghi 2026-09-05 đổ cho `?? 0`.
Nhưng `?? 0` chỉ làm lỗi **im lặng** thay vì nổ; bỏ nó đi thì trang hiện thông
báo lỗi thay vì danh sách rỗng — vẫn hỏng, chỉ ồn ào hơn.

Gốc thật: `GoalPage` đọc mã tài khoản **đúng một lần**, bên trong
`BlocProvider.create`. `currentAccountIdOrNull` dùng `context.read<AuthBloc>()`
— `read` **không đăng ký** gì cả — và `create` chỉ chạy một lần trong đời của
provider. Trang dựng trước khi phiên khôi phục xong sẽ đăng ký `watchGoals(0)`
rồi **giữ nguyên đăng ký ấy mãi**. Thoát ra vào lại thì provider mới được dựng,
lúc đó phiên đã sẵn sàng — đúng cách người dùng vô tình "chữa" nó.

`home_page` và `transaction_page` không mắc lỗi này vì chúng dùng
`context.watch<AuthBloc>()`.

**Đã sửa cho trang Mục tiêu (2026-09-07):** `context.watch<AuthBloc>()` để
build chạy lại khi phiên tới, cộng `key: ValueKey(idaccount)` trên
`BlocProvider` để `create` chạy lần nữa với đúng tài khoản. Thiếu khoá thì
`watch` chỉ khiến build chạy lại mà cubit vẫn giữ đăng ký cũ — hai nửa phải đi
cùng nhau. Test canh: `goal_page_cold_start_test.dart`, đỏ đúng chỗ trước bản
vá (`Expected: contains <10>, Actual: [0]`).

**Đã kiểm và sửa cả bốn trang đọc theo tài khoản.** Mỗi trang có test riêng,
và mỗi test đều **đỏ trước** ở đúng assertion "phiên tới rồi mà trang chưa bao
giờ hỏi lại":

| Trang | Hỏng vì | Bằng chứng đỏ | Bản vá |
|---|---|---|---|
| `goal_page` | `currentAccountIdOrNull` + `BlocProvider.create` (chạy một lần) | `Actual: [0]` | `watch` + `ValueKey` |
| `budget_page` | y hệt | `Actual: []` ở assertion thứ hai | `watch` + `ValueKey` |
| `wallet_list_page` | y hệt, **cộng** bản chép tay `int.tryParse(user?.id ?? '') ?? 0` | `Actual: [0]` | `watch` + `ValueKey`, và gọi `currentAccountIdOrNull` thay bản chép tay |
| `bill_page` | **Khác:** nạp trong `addPostFrameCallback` của `initState` với `if (accountId == null) return;` | `Actual: []` | `watch` + `_thuNap()` gọi từ `build`, hoãn việc phát sự kiện sang `addPostFrameCallback` |

Ba trang đầu dùng chung bản vá `context.watch<AuthBloc>()` + `key:
ValueKey(idaccount)`. **Hai nửa phải đi cùng nhau:** thiếu `watch` thì build
không chạy lại, thiếu khoá thì build chạy lại mà cubit vẫn giữ đăng ký cũ.

`bill_page` không dùng được khoá vì nó **không có `BlocProvider`** — `BillBloc`
do router cung cấp. Ở đó bản vá là một hàm `_thuNap()` gọi từ `build`, có chốt
`_daNapCho` để chỉ nạp một lần cho mỗi mã tài khoản, và **hoãn việc phát sự
kiện** sang `addPostFrameCallback` — phát sự kiện bloc trong lúc dựng là lỗi
khung.

**Việc gỡ được kèm theo:** `wallet_list_page` là bản chép tay **cuối cùng** của
phép suy mã tài khoản mà G4 sinh ra để xoá bỏ. Nay cả bốn trang đều đi qua
`currentAccountIdOrNull`.

**Còn lại, cố ý chưa làm:** một trạng thái *"đang chờ phiên"* — khác hẳn *"không
có dữ liệu"* — dùng chung cho mọi trang. Bản vá hiện tại làm trang **tự khỏi**,
nhưng trong vài nhịp đầu người dùng vẫn thấy màn rỗng chứ không thấy "đang tải".
Đó là việc giao diện, tách riêng được, và không còn lỗi nào chờ nó.

⚠️ **`?? 0` giữ nguyên, có chủ ý.** Đây là bài học G4: đường ĐỌC không được
mặc định về `1` (tài khoản admin thật), và `0` là "rỗng, không phải dữ liệu
của ai". Nay nó chỉ còn là trạng thái **tạm** trong vài nhịp đầu, vì khoá
`ValueKey` kéo trang về đúng tài khoản ngay khi phiên tới.

---

### G18 — Nhánh dự phòng của lịch sử tích luỹ vẫn so bằng TÊN mục tiêu · ⏸️ THU HẸP DẦN (2026-09-07)

`TransactionDao.watchByGoal` có hai nhánh: nối bằng `goal_id` cho hàng có ID, và
`note LIKE '%Tích lũy mục tiêu: <tên>%'` cho hàng không có. Nhánh thứ hai mang
đúng khuyết điểm mà `goal_id` sinh ra để chữa — mục tiêu tên `"Mua"` vẫn nuốt
lịch sử của `"Mua xe"`.

**Đã đổi 2026-09-07:** backend có cột `transaction.Idgoal`, và client nay **đẩy**
`idgoal` trong payload giao dịch **lẫn đọc lại** ở nhánh pull. Nguồn sinh ra hàng
thiếu ID đã tắt: từ nay mọi hàng đi qua đồng bộ đều mang liên kết.

**Vì sao vẫn chưa gỡ được nhánh so tên:** hàng **đã nằm sẵn** trên server đều
mang `Idgoal = NULL`, vì chúng được đẩy lên trước khi client biết gửi trường này.
Chúng chỉ nhận ID khi được đẩy lại — tức khi người dùng sửa gì đó, hoặc không bao
giờ. Bỏ nhánh so tên bây giờ là lịch sử tích luỹ **đã có** biến mất khỏi màn hình.
Nhánh ấy nay **teo dần** thay vì đứng yên; gỡ được khi không còn hàng nào
`goal_id IS NULL` mà ghi chú khớp mẫu.

**Đã đo trên máy thật** (`emulator-5554`, tài khoản 10, 2026-09-07): trước bản vá,
cả **12** giao dịch tích luỹ trên server đều `Idgoal = NULL` — chính con số ấy là
thứ nhánh `Value.absent()` bảo vệ. Sau bản vá, gửi thêm 1.000 đ vào `MuaXe` sinh
ra hàng **đầu tiên** có `Idgoal`, và giá trị khớp chính xác `idgoal` của mục tiêu
(`dc2656fa-…`); `current_amount` đi từ 1.100.000 lên 1.101.000. Mười hai hàng cũ
vẫn `NULL` — đúng như mô tả ở trên, chúng chỉ nhận ID khi được đẩy lại.

⚠️ **Nhánh pull dùng `Value.absent()`, KHÔNG ghi đè null.** Server im lặng về
`idgoal` nghĩa là *chưa biết*, không phải *hãy xoá*. Ghi đè thẳng thì đúng ở chu
kỳ đồng bộ đầu tiên sau bản vá, mọi liên kết cục bộ đang có bị xoá sạch và toàn
bộ lịch sử rơi xuống nhánh so tên — tái hiện nguyên vẹn G18 mà không có lỗi nào
báo ra. Đã dựng bản ngây thơ để xem test có bắt được không: **có**, và đó là
`'hàng server KHÔNG có idgoal thì liên kết cục bộ phải còn nguyên'`.

⚠️ Điều kiện `goal_id IS NULL` ở nhánh dự phòng là thứ chặn không cho một hàng
đã có chủ bị mục tiêu khác nhận vơ. **Đừng bỏ nó khi dọn dẹp.**

---

### G19 — Tiến độ mục tiêu và số dư ví lệch nhau được, và app chỉ cảnh báo · ✅ CỐ Ý (2026-09-05)

Ghi ở đây để người sau **không "sửa"** nó.

Tiêu tiền từ ví tích luỹ bằng một giao dịch thường không hạ `current_amount` —
giao dịch ấy không mang `goal_id`. Mục tiêu có thể ghi "đã tích 2 triệu" trong
khi ví chỉ còn 300 nghìn.

**App không tự hoà giải, và đó là chủ ý.** Không đủ căn cứ để hoà giải đúng: một
ví phục vụ được nhiều mục tiêu, ví tích luỹ cũng chứa tiền không thuộc mục tiêu
nào, và tự hạ tiến độ là bất ngờ với người dùng. `canhBaoViKhongDu()` phơi ra sự
lệch để họ tự quyết. Lý do đầy đủ ở `docs/GOAL_FEATURE.md` mục 3.4.

Muốn tiến độ phản ánh thực tế thì phải **đánh dấu** khoản rút — luồng "Rút khỏi
mục tiêu" đã có, nhưng khoản chi tiêu thường thì theo định nghĩa không thuộc mục
tiêu nào.

---

### ~~G20 — Giao dịch trích bù mang dấu thời gian **lúc bù**, không phải mốc của kỳ~~ · ✅ ĐÃ SỬA (2026-09-05)

**Hiện trạng:** bộ trích tự động chạy trong vòng quét, tức khi app mở. Bỏ app ba
ngày với chu kỳ hàng ngày thì ba kỳ được trích bù cùng lúc — và cả ba hàng giao
dịch đều mang `date = DateTime.now()`, tức thời điểm bù. Đã đo trên máy ảo: ba
khoản của kỳ 06, 07, 08/09 đều ghi `2026-09-08 14:28`.

Thông báo thì **ngược lại** — nó lấy mốc kỳ làm `createdAt`, nên trung tâm thông
báo hiện đúng ngày từng kỳ. Hai nơi nói hai chuyện khác nhau về cùng một sự
việc.

**Bán kính ảnh hưởng:** không sai một đồng nào — số tiền, số dư ví và tiến độ
đều đúng. Chỉ phần thống kê **theo ngày** thấy ba khoản dồn vào một ngày.

**Vì sao hoãn (bối cảnh gốc):** `depositToGoal` cố tình không nhận tham số ngày;
nó luôn ghi "bây giờ", đúng như một khoản nạp tay. Thêm một tham số `date` tuỳ
chọn là mở đường cho nơi gọi khác truyền vào một ngày bịa — và đó là tầng ghi
tiền, chỗ ít đáng nới lỏng nhất. Muốn sửa thì phải làm cùng lúc: thêm tham số,
chặn nó ở mọi đường gọi khác, và viết test canh chừng.

**Đã sửa thế nào:** `depositToGoal` nhận `occurredAt`, chặn **hai đầu** (không ở
tương lai, không trước `startDate` của mục tiêu). Nơi gọi duy nhất là
`GoalAutoDepositRunner`; đường nạp tay không truyền, và `GoalCubit` cố ý không
phơi tham số ra. Chỉ cột `date` lùi lại — `updatedAt` vẫn là "bây giờ" vì nó là
sổ sách đồng bộ. Chi tiết và các phương án đã loại: mục **3.14** `GOAL_FEATURE.md`.

**Kiểm trên máy ảo 2026-09-05:** ba kỳ bù ghi lúc 17:30 mang `date` 06/07/08-09
lúc 08:00 với cùng một `updated_at` 17:30, và lịch sử tích luỹ (`orderBy: date
desc`) **xen kẽ đúng ngày** thay vì dồn lên đầu — đúng chỗ mà ghi chú cũ dặn phải
kiểm bằng mắt.

⚠️ **Bẫy để lại cho người sau:** runner nhận `now` tiêm vào, còn `depositToGoal`
đọc `DateTime.now()` — ở production hai thứ ấy là **một** đồng hồ. Bộ test cũ giả
lập kịch bản ở **tương lai** nên vỡ ngay khi phép chặn đầu trên ra đời; nay cả
`goal_auto_deposit_runner_test.dart` nằm trong quá khứ. Đừng "sửa" nó ngược lại.

---

### G21 — Cấu hình trích tự động không theo người dùng sang máy khác · ✅ ĐÓNG (2026-09-07)

**Đã đóng.** Backend thêm ba cột `auto_deposit_amount`,
`auto_deposit_wallet_id`, `auto_deposit_last_run` vào bảng `goal` trong đợt
2026-09-07; client đẩy và kéo **cả ba cùng một lúc**. Bật trích ở máy A rồi
đăng nhập máy B thì B nhận đủ cấu hình **lẫn mốc kỳ gần nhất**, nên nó không
trích lại kỳ mà A vừa trích xong.

**Đã đo trên máy thật, không chỉ bằng test** (`emulator-5554`, tài khoản 10,
2026-09-07): mục tiêu `MuaXe` vốn đã bật trích 100.000 đ/tháng từ ví `test`
nhưng ba cột trên server vẫn `null` — đúng vì trước bản vá chúng không bao giờ
được đẩy. Bấm Lưu một lần là cả ba lên tới PostgreSQL: `auto_deposit_amount`
= 100000, `auto_deposit_wallet_id` = ví **`test` (Cash)**, `auto_deposit_last_run`
có giá trị. Mục tiêu `MuaDT` (không bật trích) vẫn `null` cả ba, nên không phải
ghi bừa. Đáng chú ý nhất: ví nguồn khác hẳn `idwallet` = ví **`Tiết kiệm`
(Saving)** là ví NHẬN — gửi nhầm một trong hai thì app sẽ trích tiền từ đúng cái
ví lẽ ra phải nhận, và không có gì báo lỗi.

⚠️ **Ba cột vẫn phải đi cùng nhau.** `auto_deposit_last_run` là cột chặn trích
hai lần. Ai đó "dọn dẹp" payload và bỏ nó ra thì mỗi máy giữ một mốc riêng và
**cả hai cùng chuyển tiền** — tệ hơn hẳn hiện trạng cũ, nơi máy thứ hai đơn
giản là không trích gì. `sync_payload_contract_test.dart` khoá bộ khoá của
payload mục tiêu (21 trường) nên nó bắt được ngay.

**Khe hở còn lại, chấp nhận được:** hai máy cùng mở, cùng tới kỳ, cùng chưa kịp
kéo `last_run` của nhau thì vẫn trích hai lần. Hẹp vì trích chỉ chạy khi app mở,
và `Current_amount` là giá trị tuyệt đối nên LWW hội tụ chứ không cộng dồn sai.
Vá triệt để cần một khoá phía máy chủ trên `(Idgoal, kỳ trích)` — phụ thuộc
`transaction.Idgoal`, cột nay đã có nhưng client chưa đẩy (xem **G18**).

---

### G22 — Giờ trong mốc trích chỉ giữ được MỘT chiều · ✅ CỐ Ý (2026-09-05)

Ghi ở đây để người sau **không "sửa"** nó, và không hứa với người dùng nhiều hơn
những gì app làm được.

Người dùng chọn được "ngày 15 hàng tháng lúc 08:00". Giờ ấy được tôn trọng theo
chiều **không bao giờ sớm hơn** — nhưng bộ trích chạy khi app mở, nên nếu 21 giờ
mới mở app thì nó trích lúc 21 giờ.

Có một lời nhắc đặt trước qua AlarmManager nổ đúng 08:00 kể cả khi app đóng
(`ReminderScheduler`), nhưng nó chỉ **báo tin**; tiền vẫn chỉ chuyển khi mở app.

**Vì sao không làm WorkManager:** tác vụ nền phải mở một kết nối SQLite **thứ
hai** vào cùng tệp để chuyển tiền. Đây là chỗ duy nhất trong app tự chuyển tiền
khi người dùng vắng mặt; đổi vài giờ sớm hơn lấy rủi ro ấy là không đáng. Quyết
định này do người dùng chọn sau khi được nêu cả ba phương án.

**Nếu vẫn muốn làm:** `GoalAutoDepositRunner` viết độc lập với *khi nào* nó được
gọi, nên thêm một trigger nền chỉ là gọi `chay()` thêm một chỗ nữa. Phần khó nằm
ở kết nối CSDL trong isolate nền, không nằm ở logic trích.

---

### G23 — Bản sao danh mục chỉ đầy đủ khi bộ mặc định CỤC BỘ đầy đủ · ⏸️ CHẤP NHẬN ĐƯỢC (2026-09-07)

`DefaultCategorySeeder` sao chép từ những hàng mặc định **đã có trên máy này**
(`getBackendDefaults()` đọc SQLite, không gọi mạng). Mà pull là **tăng dần theo
`since`**: hàng nào không đổi kể từ mốc kiểm cuối thì không bao giờ được gửi lại.

Hệ quả: một máy có thể chỉ biết một phần bộ mặc định của server, và bản sao thiếu
theo. **Đo được 2026-09-07 trên `emulator-5554`:** server có **18** hàng mặc định,
máy ấy tạo được **13** bản sao (hai trong số còn lại bị chặn đúng luật vì tài
khoản từng có bản riêng cùng tên; ba cái còn lại đơn giản là chưa từng về máy).

**Vì sao không sửa ngay:** bước seed chạy sau **mọi** lần pull và luỹ đẳng, nên
khi một hàng mặc định thật sự về máy thì bản sao được tạo ở lượt kế tiếp. Người
dùng không mất gì — họ chỉ có ít danh mục dựng sẵn hơn, và tự thêm được.

**Nếu muốn dứt điểm:** cần một lần pull đầy đủ bộ mặc định (bỏ `since` cho riêng
nhánh `is_default = true`) ở lần đăng nhập đầu. Đó là thay đổi ở đường đồng bộ,
không phải ở bước seed — đừng vá bằng cách cho seeder gọi mạng.

---

### G24 — Màu danh mục không có chỗ trên server · ⛔ CHẶN Ở BACKEND (2026-09-07)

Bảng `category` phía PostgreSQL có **đúng 12 cột** và không cột nào cho màu.
Client vẫn đẩy khoá `colour` lên ở mỗi lần đồng bộ, backend **bỏ qua im lặng** —
đúng kiểu hỏng mà quy tắc 4 của `CLAUDE.md` mô tả, lần này còn khó thấy hơn vì
tên trường không sai, chỉ là không có chỗ nào để ghi.

Hệ quả: màu người dùng chọn **chỉ sống trên máy đã chọn**. Đăng nhập máy khác
hoặc cài lại app là mất, không lỗi, không log.

Lỗi này **có sẵn từ trước**, không do thay đổi 2026-09-07 sinh ra — nhưng bán
kính vừa rộng ra hẳn: trước đây người dùng gần như không đổi màu được gì vì hàng
mặc định là toàn cục và bị chặn sửa; nay họ sở hữu cả bộ và sửa được từng cái.

**Client không sửa được** — không có cột thì không có chỗ ghi. Tài liệu xin:
`docs/superpowers/backend/CAN-LAM/CATEGORY_COLOUR_COLUMN.md`.

---

### G25 — Hai máy cùng sắp lại thứ tự ưu tiên khi ngoại tuyến thì được một thứ tự trộn · ✅ CỐ Ý (2026-09-08)

Thứ tự ưu tiên mục tiêu (schema v19) đồng bộ qua cột `Priority`, và phép phân
xử của dự án là **LWW theo từng hàng**. Sắp lại danh sách thì lại là một thao
tác trên **cả danh sách**. Hai thứ ấy không khớp nhau.

Máy A kéo `MuaXe` lên đầu, máy B kéo `MuaDT` lên đầu, cả hai đang ngoại tuyến.
Khi cùng đẩy lên, mỗi hàng thắng riêng theo `Update_at` của nó — kết quả có thể
là một thứ tự **không giống lần sắp nào**. Không hàng nào sai, không có lỗi,
không có gì trên màn hình nói ra điều đó.

**Vì sao không vá:**

- Vá triệt để cần khoá thứ tự kiểu **phân số hoặc chuỗi** (`"a0"`, `"a0V"`, lối
  của LexoRank) thay cho số nguyên. Đó là đổi cả kiểu dữ liệu ở hai đầu, cho
  một tình huống cần hai máy cùng hoạt động và cùng ngoại tuyến.
- Hậu quả tệ nhất là người dùng **kéo lại vài mục tiêu**. Không mất tiền, không
  mất bản ghi, không kẹt hàng đợi đẩy — khác hẳn G21, nơi cấu hình trích tự
  động không sang máy khác thì tiền không được chuyển mà cũng không ai biết.
- FlowMoney gần như luôn chỉ có một máy hoạt động cho mỗi tài khoản.

**Bán kính:** `uuTienSauKhiKeo`, `GoalRepositoryImpl.capNhatUuTien`, và nhánh
`priority` của `sync_engine.dart`. Ghi ở đây để người sau không tưởng chỗ này
bị bỏ sót — nó đã được cân nhắc, và lý lẽ nằm ở
`docs/superpowers/backend/DA-XONG/2026-09-05-backend-goal-priority.md` mục 5.

> ⚠️ Đừng nhầm với một lỗi **khác** cũng thuộc vùng mục tiêu, nay **đã sửa**
> (2026-09-08): `GoalDetailPage` không nghe dòng dữ liệu (bẫy 4.5
> `GOAL_FEATURE.md`), nên đồng bộ kéo về một thay đổi của mục tiêu **đang mở**
> thì màn hình vẫn hiện số cũ. Bán kính của nó vừa rộng ra vì `priority` nay
> cũng đi qua đường đồng bộ. Đó là lỗi **sửa được ở client**, không phải một
> đánh đổi — nên nó không có mục G nào và nằm trong danh sách việc phải làm.

---

### G26 — Không có màn "Giao dịch chờ duyệt" cho giao dịch ngân hàng về · ✅ CỐ Ý (2026-09-09)

Khi nối Socket.io, client bắt được sự kiện `bank_transaction.incoming` và hiện
một toast. Nhưng nó **không** có chỗ nào để người dùng *duyệt* giao dịch ấy —
gán danh mục, xác nhận hoặc từ chối.

Backend đã có sẵn cả ba endpoint (`api/bank.routes.js`):

- `GET  /api/bank/pending-transactions`
- `POST /api/bank/confirm-transaction`
- `POST /api/bank/reject-transaction`

**Vì sao hoãn:** đây là **một tính năng riêng**, không phải phần còn thiếu của
việc nối socket. Nó kéo theo cả một luồng liên kết ngân hàng (`register-account`,
`link-url`, WebView của SePay), một màn danh sách, và một khái niệm mới trong
giao diện — "giao dịch chưa được duyệt" — mà SQLite cục bộ hiện **không phân
biệt được**: cột `status` và `provider` có trong bảng nhưng **không nằm trong
hợp đồng đồng bộ theo chiều nào cả** (quy tắc 4 `CLAUDE.md`), nên một giao dịch
`Pending` kéo về qua `/sync/pull` trông y hệt một giao dịch bình thường.

**Bán kính nếu làm:** thêm `status`/`provider` vào hợp đồng đồng bộ (và do đó
vào `sync_payload_contract_test.dart`), một màn hình mới, và một badge đếm ở
tab Giao dịch. ⚠️ **Phải lên Stitch trước** — đây là màn hình mới, chưa có
thiết kế nào.

**Không chặn gì đang chạy.** Kênh realtime vẫn có ích mà không cần nó: mọi sự
kiện đều đánh thức đồng bộ, nên giao dịch ngân hàng vẫn hiện ra trong danh sách
sau vài giây thay vì sau 15 phút.

---

### G27 — Không còn cách nào nói "ví này được phép âm" · ⏸️ HOÃN CÓ CHỦ Ý (2026-09-09)

Từ 2026-09-07, ví loại `debt` mang số dư âm **không** sinh cảnh báo: âm là đúng
bản chất của nó, và trước đó nó bị nhắc mỗi ngày cho tới khi trả hết nợ — đúng
loại nhiễu khiến người dùng tắt cả nhóm thông báo.

Ngày 2026-09-09 loại ví thu về ba (`WalletType`: `cash | bank | saving`) vì
`ewallet` và `debt` vỡ `chk_wallet_type` của PostgreSQL và làm ví **kẹt hàng
đợi đẩy vĩnh viễn**. Ví cũ chuyển thành `bank`, và chốt kia mất chỗ bám: không
còn tín hiệu nào để phân biệt "âm vì đang nợ" với "âm vì ghi nhầm".

**Hệ quả:** ai từng theo dõi thẻ tín dụng bằng ví `debt` nay được nhắc "ví âm"
mỗi ngày trở lại.

**Vì sao hoãn:** chữa đúng cần một khái niệm **mới** — một cờ "ví được phép âm"
trên bảng `wallets` — chứ không phải khôi phục chuỗi `'debt'` đã chết. Cờ ấy là
cột mới ở **cả hai đầu** (client + PostgreSQL, tức một tài liệu `CAN-LAM` nữa),
cho một tình huống mà CSDL hiện **không có hàng nào**: đo 2026-09-09, server chỉ
có ví `Cash` (3) và `Saving` (2).

**Bán kính nếu làm:** cột mới trên `wallets` + hợp đồng đồng bộ
(`sync_payload_contract_test.dart`), một công tắc ở trang sửa ví, và khôi phục
hai nhánh loại trừ trong `_walletCandidates`. Hai test ở
`notification_rules_goal_wallet_test.dart` đã ghi lại chiều cũ lẫn chiều mới —
đọc chúng trước khi làm.

---

### G28 — Lưu trữ ví chỉ sống trên máy đã bấm · ⛔ CHẶN Ở BACKEND (2026-09-10)

Tính năng **lưu trữ ví** (2026-09-10) ghi trạng thái vào cột `wallets.status`
của SQLite. Cột cùng tên đã có sẵn ở PostgreSQL và `upsertWallet` phía backend
đã xử lý nó ở cả nhánh tạo lẫn nhánh cập nhật — nên nhìn qua thì đây là thứ đẩy
lên được ngay. Nó không.

Lược đồ **tự mâu thuẫn ở đúng cột ấy**, hai phép đo trên cùng một cột:

```
chk_wallet_status => CHECK (("Status")::text = ANY (ARRAY['Active','Inactive']))
Status            => character varying(7)
```

CHECK tuyên bố `'Inactive'` hợp lệ; kiểu cột không chứa nổi nó — chuỗi ấy dài
**8 ký tự**. Không giá trị nào vừa **cả hai** ngoài `'Active'`, nên trên thực tế
cột này là một **hằng số** chứ không phải một trạng thái.

Bản đầu của client có đẩy `status` lên, và trên máy ảo nó **kẹt hàng đợi đẩy**:
backend trả lỗi ràng buộc, bản ghi quay lại hàng đợi và thử lại ở mọi chu kỳ,
kéo chậm cả hàng đợi. Đây là điều `flutter test` **không** bắt được — hợp đồng
đồng bộ được canh bằng adapter giả, không bằng CSDL thật.

**Vì sao không vá ở client:** không có chỗ ghi thì không có cách ghi. Cột được
gỡ khỏi **cả hai** chiều của đồng bộ, cùng diện với `bills.autoPayEnabled` và
`bills.anchorDay`. Chiều **kéo về** phải im lặng cùng lúc chứ không chỉ chiều
đẩy: server luôn trả `'Active'` cho mọi ví — nó chưa bao giờ nhận được giá trị
nào khác — nên một bản chỉ gỡ chiều đẩy sẽ khiến ví vừa lưu trữ **tự bỏ lưu
trữ** sau đúng một chu kỳ đồng bộ, im lặng. Có test riêng canh ca ấy, và nó gửi
`'status': 'Active'` chứ không gửi payload thiếu khoá, vì dạng thiếu khoá không
phân biệt được hai cách cài đặt.

**Hệ quả:** hai máy cùng một tài khoản thấy khác nhau, và người dùng không được
báo gì. Cùng hạng với `bill.Auto_pay` nhưng **nhẹ hơn**: lưu trữ ví không tự
tiêu tiền của ai, chỉ làm một ví hiện lại ở máy chưa bấm.

**Bán kính khi backend nới cột:** một dòng `ALTER TABLE` (không cần đụng CHECK —
nó đã cho phép đúng hai giá trị cần thiết), rồi client mở lại **ba chỗ** — nhánh
đẩy và nhánh kéo về của `sync_engine.dart`, cộng `walletForPush` trong
`sync_payload_normalizer.dart` — và cập nhật `sync_payload_contract_test.dart`
cùng lúc (payload đẩy ví **12 → 13** trường). Cả ba chỗ đều còn nguyên chú thích
chỉ ngược về tài liệu xin:
`docs/superpowers/backend/CAN-LAM/WALLET_STATUS_COLUMN_WIDTH.md`.

`WalletStatus.khoaGuiLen` (`'Active'`/`'Inactive'`) vẫn ở lại và vẫn được
`wallet_status_test.dart` canh, đúng để ngày nối lại chỉ tốn một dòng — **đừng
đọc nó là mã chết bỏ quên**.

✅ **CSDL dev trên máy người dùng đã trở về lược đồ chuẩn** (2026-09-10). Cùng
ngày cột ấy từng bị đổi sang `varchar(16)` **ngoài quy trình**, rồi được hoàn
tác theo yêu cầu **đích danh** của người dùng — đo lại: `varchar(7)`, lịch sử
migration 3 dòng, bốn CHECK đủ, số hàng không đổi. Nên trên máy ấy đẩy
`'Inactive'` lên **lại vỡ như mọi môi trường khác** — G28 vẫn đúng. Diễn biến
đầy đủ ở mục **3b** của `CAN-LAM/WALLET_STATUS_COLUMN_WIDTH.md`.

---

## 2. Vấn đề đã biết nhưng thuộc về Backend

Xem hai tài liệu riêng trong `docs/superpowers/backend/`:

- **`SESSION_VALIDITY_FINDINGS.md`** — token của tài khoản đã xoá vẫn dùng được; `/auth/me` không chạm CSDL; `/sync/push` luôn trả HTTP 200.
- **`CATEGORY_CLASSIFY_ALIGNMENT.md`** — giá trị `Vay/nợ` (tài liệu) lệch với `Vay/no` (CSDL, seed, client).
- ~~**`CATEGORY_GROUP_MEMBERSHIP_SYNC.md`**~~ — G10 đã **đóng 2026-09-07**; backend không phải làm gì.
- **`2026-09-05-backend-goal-auto-deposit.md`** — G21: ba cột cấu hình trích tiền tự động chưa có chỗ chứa ở backend. **Ba cột phải lên cùng lúc**, đẩy một phần là hai máy cùng trích một kỳ.
- **`CATEGORY_KEYWORD_SYNC.md`** — từ khoá phân loại tồn tại ở hai kho độc lập, không có đường nối; kèm một lỗ hổng phân quyền trong `POST /api/ai/classify/feedback`.
- **`CATEGORY_NAME_UNIQUENESS.md`** — hai unique index của `category` đang khác quy tắc nghiệp vụ theo cả hai chiều; client đã thi hành đúng quy tắc, CSDL thì chưa.
- **`CATEGORY_STABLE_IDS.md`** — ID danh mục mặc định sinh ngẫu nhiên mỗi lần seed, nên tên bị dùng làm khoá nối giữa hai phía; đây là nguyên nhân gốc của các lỗi 11.3–11.6.
- **`2026-09-04-backend-idempotent-delete.md`** — ba lỗ hổng của `/sync/push`: xoá một bản ghi không tồn tại bị trả về là lỗi (làm client đẩy lại vĩnh viễn); `message` là nguyên văn stack trace Prisma kèm đường dẫn máy chủ; và `budget.time_recurrence = null` bị ép về `'Month'`, **chặn hẳn** lựa chọn ngân sách "Ngày cụ thể".

Client **không** phụ thuộc vào việc backend có sửa hay không.

---

## 3. Lưu ý về kiểm thử

Trạng thái hiện tại (đã chạy thật, không phải đếm tay, đo 2026-09-08): `flutter test` toàn bộ **1529/1529 pass** trong ~75 giây, trên **144 file test / 33.892 dòng**. Trước phiên 2026-09-02 là 56 pass / 9 fail và mất hơn 10 phút (một test treo tới timeout); mốc 180 pass / 27 file ghi ở đây trước đó là con số **cuối phiên 2026-09-03** và đã lạc hậu năm ngày.

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
- ~~3 feature không có test~~ → nay còn **hai**: **profile**, **ai_chat** (đo lại 2026-09-08 bằng `find`/`flutter test`, con số cũ ở đây đã lạc hậu nhiều đợt). **analytics** có 4 tệp / **61** test từ 2026-09-08 (lát 2a **và 2b** — `docs/ANALYTICS_FEATURE.md`); **budget** 24 tệp; **home** 2 tệp; **notification** 20 tệp trong `test/core/notification/` + `test/features/notification/` (cộng 3 tệp liên quan nằm chỗ khác).

---

## 4. Nguyên tắc rút ra từ phiên 2026-09-02

Ghi lại vì chúng đã lặp đi lặp lại trong dự án này:

1. **Tên trường sai không gây lỗi — nó im lặng.** Payload đi qua ba nơi định nghĩa tên trường độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend). Một tên sai chỉ đơn giản bị bỏ qua. `test/core/sync/sync_payload_contract_test.dart` khoá lại toàn bộ ánh xạ này — **cập nhật nó mỗi khi thêm trường mới cho sync**.

2. **`InsertMode.insertOrReplace` thay CẢ HÀNG.** Cột nào không gán trong companion sẽ bị đưa về giá trị mặc định. Đây từng xoá sạch cấu trúc nhóm danh mục sau mỗi lần pull. Toàn bộ 6 DAO nay dùng `insertAllOnConflictUpdate`. **Đừng đổi ngược lại.**

3. **Đừng bao giờ suy ra danh tính người dùng từ dữ liệu cục bộ.** `idaccount` chỉ được đến từ phiên đăng nhập.

4. **`idaccount = 1` là tài khoản admin THẬT**, không phải giá trị "chưa biết". Mọi fallback `?? 1` đều đã bị gỡ bỏ.
