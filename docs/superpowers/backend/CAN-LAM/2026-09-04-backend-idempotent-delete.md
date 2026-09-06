# Yêu cầu Backend: `/sync/push` — ba lỗ hổng của đường đẩy dữ liệu

**Ngày:** 2026-09-04
**Phạm vi:** Backend (`modules/sync/sync.service.js`, `modules/sync/sync.repository.js`)
**Từ:** Frontend Team

| # | Việc | Ưu tiên | Trạng thái |
|---|---|---|---|
| **A** (mục 2–7) | Xoá một bản ghi không tồn tại phải là **thành công** | 🔴 Cao — đang làm **kẹt vĩnh viễn** hàng đợi đồng bộ | ⛔ Chưa |
| **B** (mục 8) | `message` trả về phải là **mã lỗi ổn định**, không phải stack trace Prisma | 🟡 Trung bình — kèm rò rỉ đường dẫn máy chủ và nội dung hàng dữ liệu | ⛔ Chưa |
| **C** (mục 9) | `budget.time_recurrence = null` phải được **giữ nguyên**, không ép về `'Month'` | 🔴 Cao — đang **chặn hẳn** tính năng ngân sách "Ngày cụ thể" | ⛔ Chưa |

Ba việc **độc lập**, làm riêng được.

- **A** và **B**: client đã tự vá tạm bằng cách khớp chuỗi (mục 6 và 8.3) — lớp
  phòng thủ dễ vỡ trong im lặng, nhưng ít ra người dùng không kẹt.
- **C**: client **không vá được**. Tính năng đã làm xong ở client nhưng dữ liệu
  bị backend sửa lại khi đồng bộ, nên nó chỉ đúng trên đúng một máy.

---

## 1. Tóm tắt một câu

**A.** Yêu cầu xoá một bản ghi mà server không có đang bị trả về là **lỗi**; nó
phải là **thành công**, vì mục tiêu của thao tác — "bản ghi này không còn trên
server" — đã đạt.

**B.** Khi truy vấn hỏng, client nhận về nguyên văn stack trace của Prisma kèm
đường dẫn tuyệt đối trên máy chủ; nó cần một `code` ngắn và ổn định để phân
loại lỗi thay vì dò chuỗi tiếng Anh.

**C.** `upsertBudget` ép `time_recurrence = null` thành `'Month'`, nên ngân
sách "Ngày cụ thể" không tồn tại được trên server — và sau khi pull về, nó tự
hết hạn sớm hơn ngày người dùng đặt.

---

## 2. Hiện trạng

`modules/sync/sync.service.js`, nhánh xử lý thao tác xoá:

```js
// Handle delete
if (operation === 'delete') {
  const deleted = await syncRepository.softDelete(entity, payload.id);
  results[idx] = {
    localId,
    status: deleted ? 'synced' : 'error',
    message: deleted ? undefined : 'Record not found',
  };
  if (deleted) synced++; else errors++;
  continue;
}
```

Và `syncRepository.softDelete` trả `null` khi không tìm thấy hàng:

```js
const existing = await def.model.findUnique({ where: { [def.pk]: id } });
if (!existing) return null;
```

Nghĩa là: **xoá một id server chưa từng thấy → `status: 'error'`,
`message: 'Record not found'`.**

Lưu ý sự bất đối xứng với đường tạo/cập nhật: `upsertBudget` (và các
`upsert*` khác) **tự tạo mới** nếu bản ghi chưa tồn tại. Đường ghi đã idempotent
rồi; chỉ đường xoá thì chưa.

---

## 3. Vì sao đây là lỗi nghiêm trọng

Client là ứng dụng **offline-first**: mọi thay đổi ghi vào SQLite trước, đẩy
lên sau. Một thao tác đẩy thất bại sẽ giữ bản ghi ở trạng thái `pending` và
được gửi lại ở chu kỳ sau. Với "Record not found", lần gửi lại nào cũng nhận
đúng câu trả lời đó — **vòng lặp không có lối ra**.

Hậu quả không dừng ở một bản ghi. Chu kỳ đồng bộ nào còn thao tác hỏng thì kết
thúc ở trạng thái `error`, kích hoạt giãn cách luỹ tiến 30s → 1p → 5p → 15p →
60p. **Mọi thay đổi khác** (ví, giao dịch, ngân sách) bị đẩy chậm theo. Đây
đúng là lớp sự cố đã được ghi ở mục 14 `docs/PROJECT_CONTEXT.md`.

### Log thật, thu ngày 2026-09-04

```
[SyncEngine] Push failed [transient]: entity=budget,
localId=de4775ef-c9e1-44a5-bf9f-7aec370c4ecc, reason=Record not found
[SyncEngine] Real Sync Complete: 0/1 synced successfully.
...lặp lại ở mọi chu kỳ sau...
```

---

## 4. Hai đường vào lỗi, cả hai đều xảy ra trong thực tế

### 4.1. Bản ghi chưa từng lên tới server (thường gặp nhất)

Người dùng tạo một ngân sách **khi đang offline**, đổi ý và xoá nó **trước khi**
lần đồng bộ đầu tiên kịp chạy. Client gửi `operation: 'delete'` cho một id
server chưa từng thấy. Không có hành động nào của quản trị viên, không có lỗi
dữ liệu — chỉ là một thao tác người dùng hoàn toàn bình thường.

### 4.2. Bản ghi bị xoá cứng ở phía server

Dọn dữ liệu bằng SQL trực tiếp, hoặc script bảo trì gọi `DELETE` thay vì đặt
`delete_at`. Máy nào đã từng đồng bộ bản ghi đó sẽ kẹt.

> Đường 4.2 chính là cách sự cố ngày 2026-09-04 phát sinh: một bản ghi thử
> nghiệm bị xoá cứng khỏi PostgreSQL trong khi client vẫn giữ nó.

### Trường hợp KHÔNG bị lỗi

Hai máy cùng xoá một bản ghi thì **không** kẹt: `softDelete` dùng `findUnique`
không lọc theo `delete_at`, nên hàng đã xoá mềm vẫn tìm thấy và được cập nhật
lại. Chỉ hàng **thật sự không tồn tại** mới gây lỗi.

---

## 5. Đề xuất sửa

Xoá là thao tác **idempotent** theo định nghĩa: gọi một lần hay mười lần thì
trạng thái cuối vẫn là "không còn". Không tìm thấy bản ghi nghĩa là trạng thái
mong muốn đã sẵn có.

```js
// Handle delete — idempotent: không tìm thấy nghĩa là ĐÃ ở trạng thái mong muốn
if (operation === 'delete') {
  const deleted = await syncRepository.softDelete(entity, payload.id);
  results[idx] = {
    localId,
    status: 'synced',
    // Giữ lại thông tin để quan sát, nhưng KHÔNG đổi status thành 'error'.
    message: deleted ? undefined : 'Already absent',
  };
  synced++;
  continue;
}
```

### Ngoại lệ cần giữ nguyên

`softDelete` với danh mục mặc định vẫn **ném lỗi**
(`Cannot delete system default category`) và phải tiếp tục như vậy — đó là từ
chối có chủ ý, không phải "không tìm thấy". Thay đổi đề xuất ở trên chỉ đụng
nhánh `null` trả về từ `findUnique`.

### Không cần đổi lược đồ

Đây là thay đổi thuần logic, không thêm/sửa cột nào, không cần migration.

---

## 6. Phần client đã làm (để backend biết bối cảnh)

Ngày 2026-09-04, `SyncEngine` được vá để tự thoát khỏi vòng lặp: khi thao tác
là `delete` **và** thông báo khớp `record not found`, client đánh dấu bản ghi
là đã đồng bộ thay vì báo lỗi. Có ba test canh ở
`src/Client-app/test/core/sync/sync_failure_handling_test.dart`, nhóm
**"Xoá một bản ghi server không có"**.

**Bản vá này không thay thế việc sửa backend:**

- Nó dựa vào **khớp chuỗi** `'record not found'`. Đổi câu chữ trong
  `sync.service.js` là mất tác dụng — và mất **trong im lặng**, đúng lớp lỗi mà
  dự án này luôn phải đề phòng.
- Mọi client đã phát hành trước ngày đó vẫn kẹt.
- Sửa ở backend chặn lỗi cho tất cả, một lần.

Nếu backend chuyển sang trả `status: 'synced'` thì bản vá client trở thành
nhánh chết vô hại — client nhận `synced` và đi tiếp bình thường. **Không cần
phối hợp thời điểm phát hành.**

---

## 7. Cách kiểm chứng sau khi sửa

```bash
# Gửi lệnh xoá cho một id không tồn tại
curl -X POST http://localhost:3000/api/sync/push \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "kiem-thu",
    "pushedAt": "2026-09-04T00:00:00.000Z",
    "operations": [{
      "localId": "00000000-0000-4000-8000-000000000000",
      "entity": "budget",
      "operation": "delete",
      "payload": { "id": "00000000-0000-4000-8000-000000000000" },
      "createdAt": "2026-09-04T00:00:00.000Z"
    }]
  }'
```

**Mong đợi sau khi sửa:** `results[0].status === 'synced'`, và `summary.errors`
bằng 0.

**Hiện tại (chưa sửa):** `status: 'error'`, `message: 'Record not found'`.

Nên bổ sung một test tự động cho nhánh này — hiện `sync.service.js` chưa có
test nào phủ đường xoá.

---

## 8. Việc thứ hai: `message` phải là mã lỗi ổn định, không phải stack trace

**Ưu tiên:** Trung bình. Độc lập với mục 5, làm riêng được.

### 8.1. Hiện trạng: nguyên văn lỗi Prisma bị gửi thẳng về client

Khi một truy vấn Prisma ném lỗi, `message` trả về client là toàn bộ chuỗi lỗi
của Prisma. Đây là bản thu ngày 2026-09-04, cắt bớt:

```
Invalid `prisma.budget.update()` invocation in
D:\test_kltn\ManagementFinance\src\Backend\modules\sync\sync.repository.js:333:28
  332 if (new Date(mapped.update_at) > new Date(existing.update_at)) {
→ 333   return prisma.budget.update(
Error occurred during query execution:
ConnectorError(ConnectorError { user_facing_error: None, kind:
QueryError(PostgresError { code: "23514", message: "new row for relation
\"budget\" violates check constraint \"chk_budget_end_after_start\"", ...
detail: Some("Failing row contains (3d810935-..., 10, 08639bd7-..., 200000.00,
0.00, null, 100.00, Over, null, 2026-09-03 17:00:00, ...)") ...
```

Ba vấn đề trong một chuỗi:

1. **Rò rỉ thông tin.** Đường dẫn tuyệt đối trên máy chạy server
   (`D:\test_kltn\ManagementFinance\src\Backend\...`), số dòng mã nguồn, và
   **toàn bộ nội dung hàng dữ liệu** đều đi ra ngoài. Client chỉ cần biết
   "ngày kết thúc phải sau ngày bắt đầu".
2. **Client buộc phải khớp chuỗi.** Không có trường nào cho biết đây là lỗi
   loại gì, nên client phải dò mã `23514` và cụm `violates check constraint`
   trong đống chữ đó. Nâng phiên bản Prisma hay đổi ngôn ngữ thông báo là mất
   khả năng phân loại — **mất trong im lặng**.
3. **Không dùng được cho người dùng cuối.** Chuỗi này không thể hiện lên màn
   hình cho người dùng đọc, nên client phải tự nghĩ ra lời nhắn thay thế và tự
   đoán xem lỗi thật là gì.

### 8.2. Đề xuất

Bắt lỗi Prisma ở tầng service và quy về mã ổn định. Tối thiểu:

```js
// Trong khối catch bao quanh lời gọi upsert/softDelete.
// Prisma đặt mã của nó ở `err.code` ('P2002', 'P2003'…) nhưng KHÔNG bóc
// SQLSTATE của PostgreSQL ra trường riêng — nó nằm trong chuỗi `err.message`.
const prismaCode = err?.code ?? null;
const sqlState = String(err?.message || '').match(/code: "(\d{5})"/)?.[1];

const MA_LOI = {
  '23514': 'CONSTRAINT_VIOLATION',
  '23503': 'FOREIGN_KEY_VIOLATION',
  '23505': 'UNIQUE_VIOLATION',
};
const code = MA_LOI[sqlState]
  ?? (prismaCode === 'P2002' ? 'UNIQUE_VIOLATION'
    : prismaCode === 'P2003' ? 'FOREIGN_KEY_VIOLATION'
    : 'DB_ERROR');

if (code !== 'DB_ERROR') {
  // Tên ràng buộc giúp client nói đúng ô nào sai, ví dụ
  // 'chk_budget_end_after_start' → "Ngày kết thúc phải sau ngày bắt đầu".
  const constraint =
    String(err.message).match(/constraint \\?"([\w.]+)\\?"/)?.[1] ?? null;
  results[idx] = {
    localId,
    status: 'error',
    code,          // ← mã ổn định để client phân loại
    constraint,    // ← ví dụ 'chk_budget_end_after_start'
    message: 'Dữ liệu vi phạm ràng buộc của cơ sở dữ liệu',
  };
  errors++;
  continue;
}
```

Điểm mấu chốt là **đừng để `err.message` của Prisma đi ra ngoài**. Ghi nó vào
log phía server để còn gỡ rối, nhưng thứ gửi cho client chỉ nên là `code`,
`constraint` và một câu ngắn.

Cùng cách đó cho các mã còn lại:

| Tình huống | SQLSTATE / Prisma | `code` đề xuất |
|---|---|---|
| Vi phạm ràng buộc `CHECK` | `23514` | `CONSTRAINT_VIOLATION` |
| Vỡ khoá ngoại | `23503` / `P2003` | `FOREIGN_KEY_VIOLATION` |
| Trùng khoá duy nhất | `23505` / `P2002` | `UNIQUE_VIOLATION` |
| Entity không hợp lệ | — | `UNKNOWN_ENTITY` |
| Tài khoản không tồn tại | — | `ACCOUNT_NOT_FOUND` *(đã có, client đang dùng)* |

`ACCOUNT_NOT_FOUND` là tiền lệ có sẵn: client đọc nó ở
`SyncEngine.accountNotFoundCode` và **ưu tiên hơn** việc khớp chuỗi, đúng như
ghi chú trong `_classifyFailure`. Chỉ cần mở rộng cùng khuôn mẫu.

### 8.3. Vì sao đáng làm, dù client đã tự vá

`SyncEngine._classifyFailure` hiện có **ba** phép khớp chuỗi dựng tạm:

| Khớp | Dùng để | Vỡ khi |
|---|---|---|
| `record not found` | nhận ra xoá thứ đã không còn (mục 6) | đổi câu chữ trong `sync.service.js` |
| `23514` hoặc `violates check constraint` | xếp lỗi ràng buộc CHECK thành **vĩnh viễn** thay vì thử lại mãi | Prisma đổi định dạng thông báo |
| `23505`, `violates unique constraint`, hoặc `unique constraint failed` | *(thêm 2026-09-04)* xếp vi phạm khoá duy nhất thành **vĩnh viễn** | Prisma đổi định dạng thông báo |

Cả ba đều hỏng **âm thầm**: không exception, không log, chỉ là một bản ghi lặng
lẽ quay lại vòng lặp đẩy vô hạn. Có `code` ổn định thì client bỏ được cả ba.

> **Phép khớp thứ ba vừa phải thêm vào, và đó là bằng chứng cho luận điểm này.**
> Ngày 2026-09-04 phát hiện một đường sinh vi phạm khoá duy nhất **tự lặp**:
> người dùng xoá một danh mục cá nhân mặc định, `PersonalDefaultCategories
> .ensureMissing()` tạo lại nó với UUID mới ở **mỗi lần mở app**, và mỗi bản
> mới đụng `uq_category_owner_name_classify` → `23505`. Trước bản vá, mỗi lần
> mở app thêm một bản ghi kẹt vĩnh viễn ở hàng đợi đẩy.
>
> Client đã phải đoán **ba biến thể câu chữ** cho cùng một lỗi, vì không biết
> Prisma phiên bản nào đang chạy trên server. Đó chính xác là chi phí mà mục
> này đề nghị xoá bỏ. Chi tiết đường kích hoạt ở G16 trong
> `docs/CLIENT_APP_KNOWN_GAPS.md`.

### 8.4. Gợi ý còn lại (không bắt buộc)

- Xoá một bản ghi **đã xoá mềm** rồi: hiện đã đúng (cập nhật lại `delete_at`),
  nhưng đáng có test để không bị vô tình siết thành lọc `delete_at: null`.
- Chuẩn hoá nơi phát sinh: gói toàn bộ vòng lặp thao tác trong một hàm dịch lỗi
  duy nhất, thay vì để mỗi nhánh tự quyết định `message` — hiện `Record not
  found`, `Unknown entity` và lỗi Prisma đi ra theo ba đường khác nhau.

> Xem thêm phần "mã lỗi ổn định" trong `CATEGORY_NAME_UNIQUENESS.md` — cùng một
> vấn đề, phát hiện từ một hướng khác: client đang phải đoán ý backend qua câu
> chữ tiếng Anh trong `message`.


---

## 9. Việc thứ ba: `budget.time_recurrence = null` bị ép về `'Month'`

**Ưu tiên:** Cao. Đang chặn hẳn một tính năng đã làm xong ở client.

### 9.1. Bối cảnh

Ngân sách ở client có thêm lựa chọn **"Ngày cụ thể"** (2026-09-04): người dùng
không chọn chu kỳ nào mà tự đặt ngày kết thúc. Trạng thái đó biểu diễn bằng
`time_recurrence = NULL`, và lược đồ backend **đã cho phép** — ràng buộc
`chk_budget_time_recurrence` là:

```sql
CHECK ("Time_recurrence" IS NULL OR "Time_recurrence" IN ('Week','Month','Quarter','Year'))
```

Client đã làm phần của mình: cột SQLite đổi sang nullable ở migration v12.

### 9.2. Hiện trạng: hai chỗ nuốt mất `null`

Trong `sync.repository.js`, hàm `upsertBudget`:

```js
// Nhánh TẠO MỚI — dòng ~325
time_recurrence: mapped.time_recurrence || 'Month',
//                                       ^^ null, '' và 0 đều thành 'Month'

// Nhánh CẬP NHẬT — dòng ~346
time_recurrence: mapped.time_recurrence ?? existing.time_recurrence,
//                                      ^^ null thì giữ nguyên giá trị cũ
```

Kết quả: client gửi `null`, PostgreSQL nhận `'Month'` (hoặc giá trị cũ). Ngân
sách "Ngày cụ thể" **không bao giờ tồn tại được trên server**.

### 9.3. Vì sao hỏng trong im lặng, và hỏng tới mức nào

`/sync/push` trả về `status: 'synced'` — không có lỗi nào để lần ra. Người dùng
thấy ngân sách của mình đúng trên máy vừa tạo, cho tới khi máy đó pull về hoặc
họ mở app ở máy khác:

1. Chu kỳ hiện thành **"Hàng tháng"** thay vì "Ngày cụ thể".
2. Tệ hơn con số: hạn dùng bị tính lại. Với `recurrence = false`, client lấy
   mốc **đến sớm hơn** giữa ngày kết thúc và cuối chu kỳ. Một ngân sách "Ngày
   cụ thể" dài **ba tháng** sau khi pull về sẽ hết hạn sau **một tháng** — đúng
   một chu kỳ 'Month' mà backend vừa bịa ra.

Nói cách khác: ngân sách tự hết hạn sớm hai tháng, và không có gì báo.

### 9.4. Đề xuất sửa

```js
// TẠO MỚI: phân biệt "không gửi trường này" với "gửi null".
time_recurrence: mapped.time_recurrence === undefined
  ? 'Month'                       // client cũ không gửi trường → giữ mặc định
  : mapped.time_recurrence,       // gửi null → LƯU null

// CẬP NHẬT: cùng một phép phân biệt.
time_recurrence: mapped.time_recurrence !== undefined
  ? mapped.time_recurrence
  : existing.time_recurrence,
```

Mấu chốt là dùng `=== undefined` chứ không phải `||` hay `??`: `undefined`
nghĩa là "client không nói gì về trường này", còn `null` là "client cố ý nói
không có chu kỳ". Gộp hai thứ đó lại thì không cách nào lưu được `null`.

Khuôn mẫu đúng đã có sẵn ngay trong cùng tệp — `upsertGoal` dùng
`time_recurrence: mapped.time_recurrence || null` ở nhánh tạo mới và
`!== undefined` ở nhánh cập nhật. Chỉ cần `budget` làm giống vậy.

### 9.5. Cách kiểm chứng

```bash
# Đẩy một ngân sách "Ngày cụ thể": không chu kỳ, có ngày kết thúc.
curl -X POST http://localhost:3000/api/sync/push   -H "Authorization: Bearer <token>" -H "Content-Type: application/json"   -d '{"clientId":"kiem-thu","pushedAt":"2026-09-04T00:00:00.000Z",
       "operations":[{"localId":"<uuid>","entity":"budget","operation":"create",
       "createdAt":"2026-09-04T00:00:00.000Z","payload":{
         "id":"<uuid>","idaccount":<id>,"idcategory":"<uuid>",
         "total_amount":1000000,"start":"2026-09-04T00:00:00.000Z",
         "end":"2026-12-04T00:00:00.000Z","recurrence":false,
         "time_recurrence":null,"is_deleted":false,
         "update_at":"2026-09-04T00:00:00.000Z"}}]}'
```

Rồi đọc lại hàng vừa tạo.

**Mong đợi sau khi sửa:** `Time_recurrence` là `NULL`.
**Hiện tại:** `'Month'`.
