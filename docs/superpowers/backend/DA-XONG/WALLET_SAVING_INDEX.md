# Bỏ `uq_wallet_saving_active` — luật "một ví Tiết kiệm mỗi tài khoản" chỉ tồn tại ở SQL

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** một
dòng `DROP INDEX`, không đụng mã ứng dụng. Kèm một việc **không tốn migration**:
thêm mã lỗi có cấu trúc cho 23505 trên `wallet`.

> ⚠️ **2026-09-11:** `main` @ `7675b35` đã viết lệnh bỏ index này (trong
> `database/12_Can_Lam_Align_Schema_Fixes.sql` — gộp về nhánh client 2026-09-11
> và ✅ áp lên CSDL dev của client cùng ngày — đo `pg_indexes` sau khi áp: index không còn) và đã trả `WALLET_NAME_DUPLICATE` / `WALLET_DEFAULT_DUPLICATE`
> như mục 4.2 xin. ✅ Client đã thêm hai mã ấy vào danh sách mã vĩnh viễn ngày
> 2026-09-11 (`sync_engine.dart:1631-1648`) — trước đó mã lạ rơi xuống `transient`
> và bị gửi lại mãi — nên câu *"cả ba vẫn là lỗi vĩnh viễn phía client"* ở 4.2 nay
> đúng với mã; mã thứ ba `WALLET_SAVING_LIMIT` không cần, vì backend chọn bỏ
> index thay vì giữ nó. Chốt tạm
> "một ví Tiết kiệm" ở mục 3 **vẫn còn trong mã** dù tệp 12 đã áp — gỡ là một hạng mục
> client riêng (G30). Xem
> [`FIX_BACKEND_3_REGRESSIONS.md`](../CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md) mục 4 và 5.
> Mã `WALLET_NAME_DUPLICATE` cần một phép thử khi chạy: `CAN-LAM/VERIFY_7675B35_REMAINING.md` §2.7.

---

## 1. Tóm tắt

PostgreSQL có partial unique index:

```sql
CREATE UNIQUE INDEX "uq_wallet_saving_active" ON "wallet" ("Idaccount")
  WHERE "Type" = 'Saving' AND "Delete_at" IS NULL;
```

(`prisma/migrations/20260901090000_align_new_database/migration.sql:80`, đã áp
— có trong `_prisma_migrations`.) Tức mỗi tài khoản chỉ được **một** ví loại
`Saving` đang sống.

Luật này **không có ở đâu ngoài SQL**: `docs/Rule_Project/Rule_project.md` mục 2
(Wallet rules) không nhắc; `New_Database.md` 3.2.8 chỉ ghi unique
`(Idaccount, Name)`. Nó đến từ bản `database/New_Database.sql` ngày 2026-08-26
(chú thích *"Tối đa 1 ví tiết kiệm cứng"*), khi thiết kế còn coi Tiết kiệm là một
ví đặc biệt. Nay mục tiêu tiết kiệm đã có bảng `goal` riêng, và Money Lover,
MISA, Spendee đều cho nhiều ví tiết kiệm — luật ấy có vẻ đã hết lý do tồn tại.

**Xin bỏ index.** Nếu đội backend thấy đây vẫn là ý đồ sản phẩm, xin ghi luật
vào `Rule_project.md` mục 2 và trả lời ở đây — client sẽ giữ chốt chặn vĩnh
viễn thay vì tạm.

---

## 2. Vì sao nó đang gây hại

Client tạo sẵn ví **"Tiết kiệm"** loại `saving` cho mọi tài khoản mới
(`default_account_data_initializer.dart`), rồi vẫn cho chọn "Tiết kiệm" khi
thêm ví. Người dùng tạo ví Tiết kiệm thứ hai thì:

1. SQLite ghi bình thường — không có index nào ở phía client.
2. `/sync/push` trả 23505 → `code: 'UNIQUE_VIOLATION'`.
3. Client xếp `UNIQUE_VIOLATION` là lỗi **vĩnh viễn** → ví không bao giờ lên
   server, không thử lại.
4. Mọi giao dịch ghi vào ví ấy đẩy lên vỡ `fk_transaction_wallet` → client coi
   là **tạm thời** → thử lại ở mọi chu kỳ, mãi mãi.

Không exception, không log, không gì trên màn hình. Cùng lớp lỗi với
`ewallet`/`debt` (đóng 2026-09-09).

Đo 2026-09-10 trên CSDL dev: 5 ví, 2 `Saving`, **chưa** tài khoản nào có hai —
lỗi đang chờ nổ, chưa gây thiệt hại.

⚠️ Phép đo 2026-09-09 ghi ở nhiều tài liệu client rằng *"không unique index nào
chặn ở cả hai đầu"* là **sai**: nó dùng `pg_constraint`, nơi partial unique
index không hiện. Đo `pg_indexes` thấy bảng `wallet` có **bốn**:
`uq_wallet_account_name_active`, `uq_wallet_saving_active`,
`uq_wallet_default_active`, `uq_wallet_bank_active`.

---

## 3. Client đã làm gì trong lúc chờ (2026-09-10)

`lib/features/wallet/domain/rang_buoc_vi.dart` + chốt ở
`WalletLocalDataSourceImpl._kiemRangBuocServer` (cả đường thêm lẫn đường sửa),
và màn Thêm ví khoá ô "Tiết kiệm" kèm một dòng giải thích. Có test ở ba tầng.

Chốt "một ví Tiết kiệm" là **tạm**, có chú thích trỏ về tệp này; khi backend
xác nhận đã bỏ index thì client gỡ `viTietKiemDaCo` và hai chỗ gọi. Chốt **trùng
tên** (`uq_wallet_account_name_active`) thì ở lại — luật ấy hợp lý và có trong
`New_Database.md`.

---

## 4. Việc cần làm

### 4.1. Bỏ index

Repo dùng **hai** quy ước migration cùng lúc (`prisma/migrations/` và
`database/N_*.sql` áp tay — xem `DEV_DB_MIGRATIONS_7_11.md` mục 4.2). Viết theo
quy ước đội backend chọn; nội dung SQL như nhau:

```sql
-- Xin từ client-app: docs/superpowers/backend/DA-XONG/WALLET_SAVING_INDEX.md
-- Luật "một ví Saving mỗi tài khoản" không có trong Rule_project.md và
-- chặn người dùng tạo ví tiết kiệm thứ hai (kẹt hàng đợi đẩy, im lặng).
DROP INDEX IF EXISTS "uq_wallet_saving_active";
```

Không cần sửa `schema.prisma`: Prisma không khai partial index, nên index này
vốn không có trong schema (đo: `grep uq_wallet schema.prisma` → 0 kết quả).

### 4.2. Mã lỗi có cấu trúc cho 23505 trên `wallet` (không migration)

`sync.service.js:161-168` đã tách `CATEGORY_NAME_DUPLICATE` khỏi
`UNIQUE_VIOLATION` chung. Xin cùng khuôn cho ví, theo tên constraint trong
thông báo lỗi:

| Constraint | `code` đề xuất | Client dùng để |
|---|---|---|
| `uq_wallet_account_name_active` | `WALLET_NAME_DUPLICATE` | báo "trùng tên" đúng chỗ thay vì "vi phạm ràng buộc" |
| `uq_wallet_default_active` | `WALLET_DEFAULT_DUPLICATE` | hai máy cùng đặt mặc định khi ngoại tuyến: máy đẩy sau tự gỡ cờ rồi đẩy lại |
| `uq_wallet_saving_active` (nếu giữ) | `WALLET_SAVING_LIMIT` | báo đúng lý do |

Cả ba vẫn là lỗi **vĩnh viễn** phía client; khác nhau chỉ ở thông điệp và ở
việc client tự chữa được ca nào.

---

## 5. Kiểm lại sau khi bỏ

```sql
SELECT indexname FROM pg_indexes
 WHERE tablename = 'wallet' AND indexname LIKE 'uq_wallet_%';
-- phải còn đúng 3: uq_wallet_account_name_active, uq_wallet_default_active,
-- uq_wallet_bank_active
```

Rồi báo lại ở đây; client gỡ chốt tạm và cập nhật `Rule_project.md` mục 2.
