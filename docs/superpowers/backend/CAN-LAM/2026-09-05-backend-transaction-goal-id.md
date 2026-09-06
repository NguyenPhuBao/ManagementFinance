# Yêu cầu Backend: đưa `goal_id` của giao dịch vào đường đồng bộ

**Ngày:** 2026-09-05
**Phạm vi:** Backend (PostgreSQL + Prisma + Sync API)
**Ưu tiên:** Thấp–Trung bình — **không có gì đang hỏng hôm nay**, đây là tài liệu *mở khoá*
**Từ:** Client-app

---

## 1. Tóm tắt trong ba câu

Client vừa thêm cột **cục bộ** `transactions.goal_id` (schema v14) để nối giao
dịch tích luỹ với đúng mục tiêu tiết kiệm bằng **ID** thay vì bằng **tên**. Cột
này cố ý chưa vào hợp đồng đồng bộ vì backend chưa có chỗ chứa, nên mọi hàng kéo
về từ máy chủ đều mang `goal_id` rỗng và phải rơi xuống nhánh dự phòng so tên —
nhánh vẫn còn đúng khuyết điểm mà cột này sinh ra để chữa.

Xin backend thêm một cột nullable. Không có nó, phần đối chiếu tiến độ mục tiêu
không bao giờ đáng tin trên máy thứ hai.

---

## 2. Bối cảnh

### Việc client đã làm

Lịch sử tích luỹ của một mục tiêu trước đây tra bằng ghi chú:

```sql
note LIKE '%Tích lũy mục tiêu: <tên mục tiêu>%'
```

Tên mục tiêu **không duy nhất** (khác với danh mục, mục tiêu không có quy tắc
trùng tên), và tệ hơn: một tên là **tiền tố** của tên khác thì nuốt luôn lịch sử
của mục tiêu kia. Mục tiêu tên `"Mua"` hiện ra mọi khoản đã nạp vào `"Mua xe"` —
người dùng thấy tiền mình không hề gửi.

Client đã thêm cột `goal_id` (schema v13 → v14) và nối theo ID. Truy vấn hiện
tại giữ **hai nhánh**:

```sql
goal_id = <id mục tiêu>
   OR (goal_id IS NULL AND note LIKE '%Tích lũy mục tiêu: <tên>%')
```

Nhánh thứ hai tồn tại vì hai loại hàng không bao giờ mang `goal_id`:

1. Hàng do bản app **trước v14** tạo ra.
2. **Mọi hàng kéo về từ `/sync/pull`** — vì cột là cục bộ.

Loại 1 tắt dần theo thời gian. **Loại 2 thì không**: cứ đăng nhập máy mới là lại
đầy hàng thiếu ID.

### Hệ quả cụ thể

| Tình huống | Hôm nay | Sau khi có cột |
|---|---|---|
| Nạp tiền trên máy A, xem lịch sử trên máy A | Nối bằng ID, chính xác | như cũ |
| Nạp trên máy A, xem trên máy B | Rơi xuống so tên — mục tiêu trùng tên hoặc tên là tiền tố sẽ hiện nhầm | Nối bằng ID, chính xác |
| Hai mục tiêu `"Mua"` và `"Mua xe"` trên máy B | `"Mua"` hiện luôn khoản của `"Mua xe"` | Tách đúng |

Lưu ý: lịch sử **không biến mất** trên máy B — nhánh ghi chú vẫn tìm ra hàng.
Vấn đề là nó tìm ra **thừa**, và thừa một cách im lặng.

### Việc nó đang chặn

Client muốn suy **tiến độ mục tiêu** (`current_amount`) từ tổng các giao dịch
mang `goal_id`, thay cho bộ đếm lưu riêng hiện nay. Không làm được, vì trên máy
mới mọi `goal_id` đều rỗng nên tiến độ suy ra sẽ bằng **0 cho mọi mục tiêu**.

Đây là lý do chính khiến tài liệu này tồn tại. Bản thân việc nối lịch sử thì
nhánh dự phòng đã gánh tạm được.

---

## 3. Việc backend cần làm

### 3.1 SQL migration

Đặt tên cột theo đúng quy ước đang dùng ở bảng `transaction` (`Idwallet`,
`Idcategory`, `Idwallet_transfer`):

```sql
ALTER TABLE "transaction"
  ADD COLUMN IF NOT EXISTS "Idgoal" VARCHAR(36) NULL;

ALTER TABLE "transaction"
  DROP CONSTRAINT IF EXISTS "fk_transaction_goal",
  ADD CONSTRAINT "fk_transaction_goal"
    FOREIGN KEY ("Idgoal") REFERENCES "goal"("Idgoal")
    ON DELETE SET NULL ON UPDATE NO ACTION;

CREATE INDEX IF NOT EXISTS "idx_transaction_goal"
  ON "transaction" ("Idgoal")
  WHERE "Idgoal" IS NOT NULL;

COMMENT ON COLUMN "transaction"."Idgoal" IS
  'Mục tiêu tiết kiệm mà giao dịch này thuộc về. NULL với mọi giao dịch thường.';
```

> **`ON DELETE SET NULL`, không phải CASCADE.** Xoá mục tiêu **không được** xoá
> giao dịch: tiền đã thật sự rời ví, dấu vết ấy phải ở lại sổ sách. Trên thực tế
> mục tiêu chỉ bị xoá **mềm** (`Delete_at`) nên nhánh này hiếm khi chạy, nhưng
> đặt sai thì lần duy nhất nó chạy sẽ xoá mất lịch sử tài chính.

### 3.2 Prisma schema

```prisma
model transaction {
  idtran             String    @id @db.VarChar(36) @map("Idtran")
  idaccount          Int       @map("Idaccount")
  idwallet           String    @db.VarChar(36) @map("Idwallet")
  idcategory         String?   @db.VarChar(36) @map("Idcategory")
  idwallet_transfer  String?   @db.VarChar(36) @map("Idwallet_transfer")
  idgoal             String?   @db.VarChar(36) @map("Idgoal")   // <- THÊM MỚI
  // ... các field hiện có giữ nguyên ...

  goal goal? @relation(fields: [idgoal], references: [idgoal], onDelete: SetNull, onUpdate: NoAction, map: "fk_transaction_goal")   // <- THÊM MỚI

  @@index([idgoal], map: "idx_transaction_goal")   // <- THÊM MỚI
  @@map("transaction")
}
```

Thêm quan hệ ngược vào model `goal`:

```prisma
model goal {
  // ... các field hiện có ...
  transaction transaction[]   // <- THÊM MỚI
}
```

### 3.3 `mapEntityFields` — `modules/sync/sync.repository.js`

Nhánh `case 'transaction'` hiện **không** đụng tới `idgoal`. Client sẽ gửi
thẳng tên `idgoal` (giống cách nó đang gửi `idwallet_transfer`), nên chỉ cần
nhận thêm biến thể camelCase cho chắc:

```js
case 'transaction':
  // ... các dòng hiện có ...
  if (m.goalId !== undefined) { m.idgoal = m.goalId; delete m.goalId; }
  break;
```

### 3.4 Upsert — cùng file, quanh dòng 262

Hàm dựng bản ghi `transaction` cần mang `idgoal` sang cả nhánh tạo mới lẫn nhánh
cập nhật:

```js
// tạo mới
idgoal: mapped.idgoal ?? null,

// cập nhật
idgoal: mapped.idgoal !== undefined ? mapped.idgoal : existing.idgoal,
```

> ⚠️ Nhánh cập nhật phải phân biệt **`undefined`** (client không gửi trường này)
> với **`null`** (client cố ý gỡ liên kết). Dùng `??` ở nhánh cập nhật sẽ biến
> mọi lần đẩy không kèm `idgoal` thành lệnh xoá liên kết.

### 3.5 `/sync/pull` — kiểm tra `select`

Nếu hàm đọc giao dịch cho `/sync/pull` có `select` tường minh thì bổ sung
`idgoal`. Nếu nó trả cả bản ghi thì không cần làm gì.

---

## 4. Ánh xạ tên trường

| Client (Drift) | Payload đẩy | PostgreSQL |
|---|---|---|
| `goalId` | `idgoal` | `Idgoal` |

Payload giao dịch hiện có 11 khoá; sau thay đổi này là 12. Bộ khoá đầy đủ được
khoá trong `src/Client-app/test/core/sync/sync_payload_contract_test.dart` —
**đây là nơi duy nhất ghi hợp đồng tên trường giữa hai phía**, và client sẽ cập
nhật nó cùng lúc với việc thêm trường.

---

## 5. Hành vi mong đợi sau khi có cột

| Tình huống | Client gửi | Backend lưu |
|---|---|---|
| Giao dịch thường (chi/thu) | `idgoal: null` | `Idgoal = NULL` |
| Nạp tiền vào mục tiêu | `idgoal: "<uuid mục tiêu>"` | `Idgoal = "<uuid>"` |
| Kéo về máy khác | nhận `idgoal` | client ghi vào cột cục bộ, nối bằng ID |
| Mục tiêu bị xoá **cứng** | không gửi gì thêm | `Idgoal = NULL`, hàng giao dịch **ở lại** |

Khi cột đã có, client sẽ:

1. Thêm `'idgoal'` vào payload đẩy và cập nhật hợp đồng cùng lúc.
2. Đọc `idgoal` ở nhánh pull, ghi vào `transactions.goal_id`.
3. Bỏ dần nhánh dự phòng so tên trong `TransactionDao.watchByGoal` — giữ lại một
   thời gian cho hàng cũ, rồi gỡ.

---

## 6. Không ảnh hưởng tới

- Auth, người dùng, phân quyền.
- Các bảng khác (`wallet`, `budget`, `bill`, `category`).
- Ràng buộc `chk_transaction_type` và `uq_transaction_external` — cột mới không
  đụng tới cả hai.
- Cách tính số dư ví và chiều tiền (vẫn là dấu của `Amount`).
- Admin-web: cột nullable nên mọi truy vấn hiện có chạy nguyên như cũ.

---

## 7. Vì sao xếp ưu tiên thấp

Không có gì đang hỏng vì thiếu cột này. Trên máy tạo ra dữ liệu, việc nối bằng
ID đã chạy đúng ngay hôm nay; trên máy khác thì nhánh dự phòng gánh được phần
lớn trường hợp. Khuyết điểm chỉ lộ ra khi người dùng đặt hai mục tiêu có tên
trùng hoặc tên này là tiền tố của tên kia.

Nhưng nó **chặn hẳn** một hướng đi mà client muốn: bỏ bộ đếm `current_amount` để
suy tiến độ từ chính các giao dịch. Nếu backend định làm bước 9 ở
[README.md](./README.md) (nhóm C, cần migration), gộp cột này vào cùng đợt
migration ấy là rẻ nhất — nó chỉ là một `ALTER TABLE` một dòng cộng một khoá
ngoại.

---

## 8. Đối chiếu đã làm

Các khẳng định trong tài liệu này đối chiếu với mã nguồn thật ngày 2026-09-05:

- `src/Backend/prisma/schema.prisma` — model `transaction` và `goal`.
- `src/Backend/modules/sync/sync.repository.js` — `mapEntityFields` nhánh
  `'transaction'` **không** có `idgoal`; hàm upsert quanh dòng 262.
- `src/Client-app/lib/core/database/tables/transactions_table.dart` — cột
  `goalId`, kèm chú thích ghi rõ nó là cục bộ và vì sao.
- `src/Client-app/lib/core/database/app_database.dart` — migration v13 → v14.
- `src/Client-app/lib/core/database/daos/transaction_dao.dart` — `watchByGoal`
  với hai nhánh.
