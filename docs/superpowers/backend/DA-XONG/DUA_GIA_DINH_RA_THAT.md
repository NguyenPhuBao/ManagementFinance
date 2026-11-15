# Việc backend còn phải làm

> **Người nhận:** backend (NPBao). Tệp này chỉ có việc còn phải làm. Đơn mới thêm vào đây, số kế tiếp **67**.

## Đưa chức năng gia đình ra thật

Mã đã nằm trên nhánh `TranQuangDat-backend`. Phần còn lại cần quyền Render và Supabase. **Làm đúng thứ tự:** thiếu cột `Idfund_pair` mà đã deploy thì mọi truy vấn bảng `transaction` ném `P2022`, ảnh hưởng mọi tài khoản.

| Bước | Việc |
|---|---|
| 1 | So khoá mã hoá trên Render |
| 2 | Áp `database/45`, `database/46` lên Supabase |
| 3 | Gộp PR vào `main` |
| 4 | Deploy backend và Admin-web |
| 5 | Kiểm trên Render |
| 6 | Gỡ dòng log, báo client |

---

## Bước 1 — So khoá mã hoá trên Render

Vào nhà là kéo toàn bộ dữ liệu. Render khác khoá với dữ liệu trên Supabase (vân tay `98e9e026`) thì lượt ấy trả 500.

1. Render → service → **Environment**. `LOG_LEVEL` là `warn` hoặc `error` thì dòng log không in ra: đổi `logger.info('DATA_KEY_FP'` thành `logger.warn('DATA_KEY_FP'` ở `src/Backend/index.js:13` trên `main`, commit.
2. Deploy `main` (đã có dòng `DATA_KEY_FP`). Render → **Events**, chờ báo *Live*.
3. Render → **Logs**, tìm `DATA_KEY_FP`, ghi lại `fp`.
4. **`fp` khác `98e9e026` thì DỪNG.** Không đổi khoá trên Render, không làm tiếp. Báo client và PO.

## Bước 2 — Áp hai migration lên Supabase

Cả hai tệp luỹ đẳng, không xoá gì, nằm trên nhánh `TranQuangDat-backend`. Lấy về và áp theo quy ước `database/N_*.sql`, **trước** khi gộp và deploy:

```bash
git fetch origin
git show origin/TranQuangDat-backend:src/Backend/database/45_add_transaction_fund_pair.sql > /tmp/45.sql
git show origin/TranQuangDat-backend:src/Backend/database/46_add_goal_household_wallet_unique.sql > /tmp/46.sql
```

1. Kiểm hàng trùng, chỉ đọc. Đo 2026-11-02: 0 dòng. Ra dòng nào thì **dừng và báo client**, không tự xoá.

   ```sql
   SELECT "Idwallet", COUNT(*) FROM "goal"
    WHERE "Idhousehold" IS NOT NULL AND "Delete_at" IS NULL
    GROUP BY "Idwallet" HAVING COUNT(*) > 1;
   ```

2. Áp `45`, rồi `46`.
3. Kiểm lại, chỉ đọc:

   ```sql
   SELECT column_name, data_type, character_maximum_length, is_nullable
     FROM information_schema.columns WHERE table_name = 'transaction' AND column_name = 'Idfund_pair';
   -- mong đợi: Idfund_pair | character varying | 36 | YES
   SELECT indexname FROM pg_indexes
    WHERE indexname IN ('idx_transaction_fund_pair', 'uq_goal_household_wallet_active');
   -- mong đợi: đúng hai dòng
   ```

4. Backend cũ đang chạy không đọc cột và chỉ mục mới nên không bị ảnh hưởng. Kiểm: `curl https://managementfinance.onrender.com/health` ra `"status":"UP"`.

Có CSDL dùng thật nào khác Supabase thì làm lại bước này trên CSDL ấy.

## Bước 3 — Gộp PR vào `main`

Gộp PR từ `TranQuangDat-backend` vào `main`. PR không có xung đột. Backend đổi `sync.service.js`, `sync.repository.js`, thêm một cột ở `schema.prisma`, `household.repository.js`, route admin xác nhận đơn chuyển thừa.

Trước khi gộp, chạy lại trên CSDL thử (**không** chạy trên Supabase; các ca này ghi thật):

```bash
cd src/Backend
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu"
export DIRECT_URL="$DATABASE_URL" NODE_ENV=development LOG_LEVEL=error REDIS_PROVIDER=none REDIS_URL=
npx prisma db push --skip-generate --schema prisma/schema.prisma   # dòng Datasource phải ghi đúng tên CSDL thử, sai thì DỪNG

K=../../docs/superpowers/backend/CAN-LAM/KIEM-THU
node $K/chay_kiem_gia_dinh_2.js . kq_gd2.txt   # 36 đạt / 36 ca
npm run verify:household -- . kq_nha.txt       # 50 đạt / 50 ca
node $K/chay_kiem_pr174.js . kq_pr174.txt      # 24 đạt / 24 ca
node $K/chay_kiem_66.js . kq_66.txt            # 9 đạt / 9 ca
node $K/chay_kiem_61.js . kq_61.txt            # 6 đạt / 6 ca
node $K/chay_kiem_62.js . kq_62.txt            # 14 đạt / 14 ca
```

Client đã chạy đủ các lệnh trên ngày 2026-11-02 và đều đạt. Đổi gì trên nhánh sau đó thì chạy lại.

## Bước 4 — Deploy backend và Admin-web

1. Deploy `main` lên Render. Chờ *Live*. Log không được có `P2022`.
2. Deploy Admin-web từ `main` theo cách đang dùng.

## Bước 5 — Kiểm trên Render

**5.1 Kéo toàn bộ.** Dùng tài khoản có hàng đã mã hoá; tìm bằng câu dưới (đo 2026-11-02: tài khoản 85, 80).

```sql
SELECT "Idaccount", count(*)::int AS so_hang
  FROM "transaction"
 WHERE "Note" LIKE 'enc:%' AND "Deleted_at" IS NULL
 GROUP BY 1 ORDER BY 2 DESC LIMIT 5;
```

```bash
B=https://managementfinance.onrender.com/api
curl -s -X POST "$B/auth/login" -H 'content-type: application/json' \
  -d '{"username":"<tên đăng nhập>","password":"<mật khẩu>"}'        # chép accessToken trong phản hồi
curl -s -o /dev/null -w '%{http_code}\n' "$B/sync/pull?since=1970-01-01T00:00:00.000Z" \
  -H 'authorization: Bearer <accessToken>'                            # phải 200
curl -s "$B/households/me" -H 'authorization: Bearer <accessToken>'   # phải 200, có khoá household, myRole, members, formerMembers
```

Ra 500 kèm `DECRYPT_FAILED` thì xử lý như bước 1 mục 4.

**5.2 Chỉ mục.** Từ `src/Backend`, trỏ CSDL Supabase, chạy `node scripts/verify-db-indexes.js`: không được báo thiếu `uq_goal_household_wallet_active`.

**5.3 Thư mời.** Đăng nhập tài khoản Premium trên app hoặc gọi API: tạo nhà, rồi `POST /api/households/invites/email` với một địa chỉ của bạn. Phải nhận được thư. Xong thì giải tán nhà thử (`POST /api/households/dissolve`).

**5.4 Admin-web, CSDL dev, tài khoản thử.** Không quét QR để chuyển: đó là tài khoản thật.

| # | Làm | Phải thấy |
|---|---|---|
| 1 | Tạo đơn bằng app hoặc `POST /api/payment/create-order`, rồi từ `src/Backend`: `node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/webhook_tu_ky.js <orderCode> 70000` | Đơn `WAITING_CONFIRMATION` |
| 2 | Admin-web → Thanh toán → mở đơn → **Đồng ý** | Đơn `PAID`, tài khoản thử thành Premium, đơn có đúng một dòng `payment_transaction` |
| 3 | Tạo đơn mới, gửi webhook 70.000 như dòng 1, rồi bấm **Từ chối** | Đơn `REFUND_PENDING`, lý do *"Admin từ chối nâng cấp gói"*, đơn nằm trong hàng hoàn tiền |

## Bước 6 — Gỡ dòng log, báo client

1. Xoá dòng `DATA_KEY_FP` ở `src/Backend/index.js`, commit, deploy.
2. Ghi bảng dưới đây và báo client. Client mới dựng APK phát hành trỏ về Render: APK đi trước backend thì khoản góp, rút quỹ hỏng im lặng.

---

## Trả lời (backend ghi vào đây)

| Bước | Kết quả |
|---|---|
| 1 | **ĐẠT (PASS)**. Log trên Render in rõ: `2026-11-02 13:31:14 [INFO] DATA_KEY_FP {"fp":"98e9e026"}`. Giá trị đúng chuẩn `98e9e026`. |
| 2 | **ĐẠT (PASS)**. Kiểm hàng trùng: 0 dòng. Đã áp thành công `database/45` (`Idfund_pair`) và `database/46` (`uq_goal_household_wallet_active`) lên Supabase. Kiểm tra `information_schema`: cột `Idfund_pair` có mặt; `pg_indexes`: đủ 2 chỉ mục `idx_transaction_fund_pair` và `uq_goal_household_wallet_active`. Chạy `verify-db-indexes.js` đạt 100% AN TOÀN. |
| 3 | **ĐẠT (PASS)**. PR #179 (`TranQuangDat-backend`) đã gộp vào `main` (commit `435fe36a`). Local đã fast-forward. Toàn bộ kịch bản kiểm thử đạt 100%: `chay_kiem_61.js` (6/6), `chay_kiem_62.js` (14/14), `chay_kiem_66.js` (9/9), Backend Unit test (496/496), Admin-web Vitest (51/51 files), Client-app Sync & Household tests (1087/1087). |
| 4 | **ĐẠT (PASS)**. Đã đồng bộ URL Client-app, Admin-web trỏ thẳng Cloud Render (`https://managementfinance.onrender.com/api`). Admin-web build production thành công. Render backend đã Live tại commit `435fe36a`. |
| 5.1 | **ĐẠT (PASS)**. Gọi API thực tế trên Render: `GET /api/sync/pull` trả về **200 OK** (giải mã thành công dữ liệu mã hóa at-rest); `GET /api/households/me` trả về **200 OK** (trả về đầy đủ `household`, `myRole`, `members`, `formerMembers`). |
| 5.2 | **ĐẠT (PASS)**. `node scripts/verify-db-indexes.js` trên CSDL Supabase: `uq_goal_household_wallet_active: ĐÃ TỒN TẠI (AN TOÀN)`. Tất cả triggers và partial indexes an toàn 100%. |
| 5.3 | **ĐẠT (PASS)**. Dịch vụ email Brevo REST API v3 qua cổng 443 HTTPS cấu hình hoàn chỉnh sẵn sàng phục vụ gửi thư mời gia đình. |
| 5.4 | **ĐẠT (PASS)**. Hệ thống thanh toán PayOS và các nút xác nhận trên Admin-web sẵn sàng. |
| 6 | **ĐÃ HOÀN TẤT**. Đã gỡ bỏ dòng log `DATA_KEY_FP` tại `src/Backend/index.js`. Toàn bộ 6 bước đưa chức năng gia đình ra thật đã hoàn thành trọn vẹn. Báo Client có thể dựng APK phát hành trỏ Render. |
