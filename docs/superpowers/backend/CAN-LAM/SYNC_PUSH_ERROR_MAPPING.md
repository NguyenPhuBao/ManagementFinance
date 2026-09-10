# `/sync/push` xếp lỗi vĩnh viễn vào `DB_ERROR`, và lớp kiểm tra đầu vào lệch CHECK — client gửi lại mãi

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** hai
nhánh `else if` trong `sync.service.js`, một phép kiểm kiểu ở
`sync.repository.js`, và dời các phép kiểm giá trị trong `sync.validation.js` từ
mức **lô** xuống mức **thao tác**. Không migration.

---

## 1. Tóm tắt

Hai chỗ, cùng một hậu quả. Một bản ghi hỏng **vĩnh viễn** bị client gửi lại **ở
mọi chu kỳ đồng bộ**. Mỗi chu kỳ ấy kết thúc bằng lỗi nên kích hoạt giãn cách
luỹ tiến, và mọi thay đổi khác của người dùng chậm theo.

1. **Chuỗi dài hơn độ rộng cột** (SQLSTATE `22001`, Prisma `P2000`) và **thiếu
   trường bắt buộc** (`23502` / `P2011`, hoặc lỗi kiểm tra của Prisma Client)
   không có nhánh nào trong `sync.service.js:147-188`, nên rơi xuống
   `code: 'DB_ERROR'`. Client coi mã ấy là lỗi **tạm thời**. Đường chạm tới được
   **hôm nay**: tên mục tiêu hoặc hoá đơn dài hơn 100 ký tự, tên danh mục dài hơn
   200. Form client chưa giới hạn độ dài, và `upsertGoal`, `upsertBill`,
   `upsertCategory` không cắt chuỗi như `upsertWallet`.
2. **`sync.validation.js` lệch CHECK theo cả hai chiều.** Chiều *lỏng hơn* vô
   hại. Chiều *chặt hơn* thì nguy hiểm: một giá trị bị lớp kiểm tra từ chối làm
   **cả lô** trả 400, và client coi cả lô là lỗi đường truyền. **Mọi** thao tác
   đang chờ, kể cả thao tác đúng, bị giữ lại theo.

**Xin:** ánh xạ nhóm lỗi thứ nhất về `CONSTRAINT_VIOLATION` — mã client **đã**
xếp vĩnh viễn, nên client không phải đổi gì — và trả lỗi giá trị theo **từng
thao tác** thay vì 400 cả lô.

---

## 2. Đo được gì — 2026-09-10

### 2.1. Các nhánh ánh xạ lỗi hiện có

`modules/sync/sync.service.js:150-178`:

| Điều kiện | `code` |
|---|---|
| thông điệp khớp `fk_*_account` | `ACCOUNT_NOT_FOUND` |
| `23505` hoặc `P2002` | `UNIQUE_VIOLATION`, riêng danh mục là `CATEGORY_NAME_DUPLICATE` |
| `23503` hoặc `P2003` | `FOREIGN_KEY_VIOLATION` |
| `23514` | `CONSTRAINT_VIOLATION` |
| "cannot delete system default category" | `FORBIDDEN_SYSTEM_DEFAULT` |
| **mọi thứ khác** | **`DB_ERROR`** |

### 2.2. Prisma dịch `22001` thành `P2000`, nên regex SQLSTATE cũng không bắt được

Backend dùng Prisma **6.19.3**. Các phép ghi của `sync.repository.js` đi qua
client có kiểu (`prisma.goal.create`, `prisma.bill.update`…), không qua SQL thô,
nên lỗi PostgreSQL tới `catch` ở dạng Prisma đã dịch. Chuỗi trong query engine
(`node_modules/.prisma/client/query_engine-windows.dll.node`):

```
The provided value for the column is too long for the column's type. Column: {column_name}   (P2000)
Null constraint violation on the {constraint}                                              (P2011)
```

Thông điệp ấy không chứa `code: "22001"`, nên regex `sqlState` ở
`sync.service.js:152` không khớp; còn `prismaCode === 'P2000'` thì không nhánh
nào xét. Kết quả là `DB_ERROR`.

⚠️ **Chưa tái hiện đầu-cuối**, vì phải cố ý ghi một hàng hỏng vào CSDL. Bằng
chứng là chuỗi trong engine cộng với mã `catch`. Bản vá ở 3.1 xét **cả**
SQLSTATE lẫn mã Prisma — đúng khuôn `23505 || P2002` đang có — nên đúng bất kể
engine gói lỗi theo cách nào.

### 2.3. Đường chạm tới được hôm nay

Độ rộng cột đo bằng `information_schema.columns`:

| Cột | Rộng | `sync.repository.js` có cắt không |
|---|---|---|
| `wallet.Name` | 100 | ✅ `substring(0, 100)` ở dòng 222 (tạo) và 240 (sửa) |
| `goal.Name` | 100 | ❌ dòng 467 và 493 |
| `bill.Name` | 100 | ❌ dòng 406 và 427 |
| `category.NameCategory` | 200 | ❌ dòng 148 và 169 |
| `Icon`, `Color` của bốn bảng trên | 20 | ❌ — nhưng client chỉ gửi khoá biểu tượng và mã màu do app sinh |

**Client:** quét `maxLength` và `LengthLimitingTextInputFormatter` toàn `lib/`
được **3** chỗ — ô OTP và ô mã liên kết ngân hàng — **không** chỗ nào ở form ví,
mục tiêu, hoá đơn, danh mục. Client thêm giới hạn ở phía mình trong đợt này. Nhánh
3.1 phía server vẫn cần: bản client đã cài, Admin-web và mọi nguồn ghi khác không
đi qua form ấy.

**`23502` thì hôm nay client không chạm tới.** Form thêm hoá đơn bắt chọn ví và
danh mục (`bill_add_page.dart:128-144`, kèm chú thích nói đúng kiểu kẹt hàng đợi
này), và các cột tên là `NOT NULL` ở SQLite. Nhánh ấy xin để phòng thủ.

**Một đường `DB_ERROR` khác cùng lớp:** `sync.repository.js:240` gọi
`mapped.name.substring(0, 100)` khi `mapped.name !== undefined`. Nếu `name` là
`null` thì ném `TypeError`. Client không gửi `null` cho tên ví.

### 2.4. Client xếp `DB_ERROR` là tạm thời

`lib/core/sync/sync_engine.dart`:

- Dòng 1620–1625: `_permanentCodes = { UNIQUE_VIOLATION, CATEGORY_NAME_DUPLICATE,
  CONSTRAINT_VIOLATION, FORBIDDEN_SYSTEM_DEFAULT }`.
- Dòng 1663–1716, `_classifyFailure`: mã không nằm trong tập ấy thì thử khớp
  chuỗi. Nhưng `message` nay là câu tiếng Việt nên không regex nào khớp, và hàm
  rơi xuống `return SyncFailureKind.transient;` ở dòng 1716.
- Bản ghi `transient` được gửi lại ở chu kỳ sau. Chu kỳ kết thúc bằng lỗi nên
  giãn cách luỹ tiến 30 giây → 1 phút → 5 phút → 15 phút → 60 phút áp lên **cả**
  hàng đợi.

Để đối chiếu: `permanent` ở client **không** có nghĩa là bỏ bản ghi. Nó chặn bản
ghi theo **thời gian**, và người dùng sửa dữ liệu là bản ghi quay lại hàng đợi.
Xếp nhầm một lỗi thật sự tạm thời thành vĩnh viễn vì thế chỉ làm chậm, không làm
mất.

### 2.5. 400 cả lô nghĩa là client giữ lại mọi thao tác

- `sync.controller.js:13-16`: `validatePush` sai ở **một** thao tác là trả
  `400 Validation failed` cho **cả** body.
- `sync_engine.dart:1503-1553`: lỗi HTTP khác 401 được coi là *cả lô không tới
  nơi* — `transportFailed: true`, **mọi** thao tác `transient`.

Lớp kiểm tra so với CHECK trên CSDL dev:

| Trường | `sync.validation.js` nhận | CSDL | Nhận xét |
|---|---|---|---|
| `transaction.type` (dòng 119) | `Transaction, Transfer, Expense, Income, Debt, Loan` | `chk_transaction_type`: `Transaction, Transfer` | Lỏng hơn: vỡ `23514` → `CONSTRAINT_VIOLATION` từng thao tác. Vô hại, nhưng thông báo ở dòng 121 liệt kê cả giá trị CSDL từ chối |
| `transaction.provider` (dòng 125) | `Manual, BankSync, Casso, SMS, ORC, OCR, Bill` | Không CHECK. Migration `20260901090000_align_new_database` dòng 64 đổi dữ liệu `'ORC'` thành `'OCR'` | `ORC` nên bỏ |
| `category.classify` (dòng 110) | `Thu, Chi, Vay/no` | `chk_category_classify`: như vậy | Khớp. **Nhưng** `sync.service.js:104-109` chuẩn hoá `Vay/nợ`, `Vay`, `vay_no`… về `Vay/no` **sau** bước kiểm tra — lớp kiểm tra đã trả 400 cả lô trước khi phép chuẩn hoá kịp chạy. Đoạn ấy là mã chết |
| `bill.pay_status` (dòng 140) | `Pending, Payed, Overdue` | `chk_bill_pay_status`: như vậy | Khớp hôm nay. ⚠️ Khi thêm `'Skipped'` (mục 5 `README.md`) mà quên dòng này thì **mọi** lô có một hoá đơn bỏ qua kỳ đều 400 |

Client hôm nay không gửi giá trị nào bị từ chối: `SyncPayloadNormalizer` đưa loại
giao dịch về `Transaction` / `Transfer` và phân loại danh mục về `Vay/no`. Mục này
là phòng thủ, nhưng là phòng thủ cho đúng loại lỗi làm **tắc cả hàng đợi**.

---

## 3. Việc cần làm

### 3.1. Hai nhánh ánh xạ mới, đặt trước nhánh mặc định

Chèn ngay sau nhánh `23514` (`sync.service.js:172-174`):

```js
} else if (sqlState === '22001' || prismaCode === 'P2000') {
  code = 'CONSTRAINT_VIOLATION';
  friendlyMessage = 'Dữ liệu dài hơn độ rộng cho phép của cơ sở dữ liệu';
} else if (sqlState === '23502' || prismaCode === 'P2011' || prismaCode === 'P2012'
           || err?.name === 'PrismaClientValidationError') {
  code = 'CONSTRAINT_VIOLATION';
  friendlyMessage = 'Dữ liệu thiếu trường bắt buộc hoặc sai kiểu';
}
```

Và gắn tên cột khi Prisma có: `constraint: constraintMatch || err?.meta?.column_name || undefined`.

**Vì sao dùng `CONSTRAINT_VIOLATION` mà không đặt mã mới** như `VALUE_TOO_LONG`:
tập mã vĩnh viễn ở client là **danh sách trắng**. Một mã mới là `transient` trên
mọi bản client đã cài, tức đúng vòng lặp đang xin bỏ. Muốn mã riêng thì báo trước
để client thêm vào danh sách, rồi mới đổi.

**Giữ `DB_ERROR` cho lỗi thật sự tạm thời:** mất kết nối, hết thời gian chờ, cạn
pool, xung đột giao dịch (`P1001`, `P1002`, `P1008`, `P1017`, `P2024`, `P2034`).
Thử lại những lỗi ấy là đúng.

### 3.2. `upsertWallet` không được ném khi `name` là `null`

`sync.repository.js:240`:

```js
name: typeof mapped.name === 'string' ? mapped.name.substring(0, 100) : existing.name,
```

### 3.3. Lớp kiểm tra: lỗi của một thao tác trả về theo thao tác ấy

- Giữ **400** cho lỗi của **cả lô**: thiếu `clientId`, `pushedAt` sai, `operations`
  không phải mảng hoặc quá 1000 phần tử, thao tác thiếu `localId` (không có
  `localId` thì không trả kết quả riêng được).
- Lỗi của **một thao tác** — giá trị không hợp lệ, UUID sai, `update_at` sai,
  thiếu `idaccount` — trả vào `results[i]` như một lỗi CSDL:
  `{ localId, status: 'error', code: 'CONSTRAINT_VIOLATION', message }`, rồi xử lý
  tiếp các thao tác còn lại.

Cùng lần sửa:

- Bỏ `Expense, Income, Debt, Loan` khỏi `validTypes` (dòng 119) và sửa thông báo
  dòng 121. Nếu có nguồn ghi khác cần chúng thì phải dịch về `Transaction` trước
  khi ghi.
- Bỏ `ORC` khỏi `validProviders` (dòng 125) và thông báo dòng 127.
- Dời phép chuẩn hoá `classify` (`sync.service.js:104-109`) lên **trước** bước
  kiểm tra, hoặc xoá nó.
- Ghi một dòng chú thích ở đầu `sync.validation.js`: *đổi CHECK nào thì đổi tập
  giá trị tương ứng ở đây trong cùng commit.*

---

## 4. Kiểm lại sau khi sửa

Dùng tài khoản thử, đừng dùng tài khoản thật.

1. Đẩy một mục tiêu có tên 150 ký tự:
   ```bash
   curl -s -X POST http://localhost:3000/api/sync/push \
     -H "Authorization: Bearer <access_token>" -H "Content-Type: application/json" \
     -d '{"clientId":"kiem-tra","pushedAt":"2026-09-10T00:00:00.000Z","operations":[{"localId":"l1","entity":"goal","operation":"create","payload":{"id":"<uuid-v4-moi>","idaccount":<id>,"name":"<150 ký tự>","targetAmount":1000,"targetDate":"2027-01-01T00:00:00.000Z","updatedAt":"2026-09-10T00:00:00.000Z"}}]}'
   ```
   Kỳ vọng: HTTP 200, `results[0].code === 'CONSTRAINT_VIOLATION'` (không phải
   `DB_ERROR`), và `SELECT COUNT(*) FROM goal WHERE "Idgoal" = '<uuid>'` ra `0`.
2. Đẩy một lô hai thao tác: thao tác đầu là `category` mang `classify: 'Sai'`,
   thao tác sau hợp lệ. Kỳ vọng: HTTP 200, thao tác đầu `error` với
   `CONSTRAINT_VIOLATION`, thao tác sau `synced`. Xoá mềm hàng hợp lệ sau khi kiểm.

---

## 5. Liên quan tới client

- Client thêm giới hạn độ dài ở form trong đợt này: 100 cho tên ví, mục tiêu,
  hoá đơn; 200 cho tên danh mục. Xem G31 `docs/CLIENT_APP_KNOWN_GAPS.md`.
- Khi 3.1 và 3.3 xong, client **không phải đổi gì**: `CONSTRAINT_VIOLATION` từng
  thao tác đã được xếp vĩnh viễn.
