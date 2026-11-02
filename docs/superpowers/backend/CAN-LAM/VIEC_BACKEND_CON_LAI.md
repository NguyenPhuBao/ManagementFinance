# Việc backend còn phải làm

> **Người nhận:** backend (NPBao). Tệp này chỉ có việc còn phải làm. Đơn mới thêm vào đây, số kế tiếp **67**.

| Mã | Việc | Mức | Cách làm |
|---|---|---|---|
| 52.4 | So khoá mã hoá trên Render | **CAO** | Tay, cần quyền Render |
| 66.1 | Sửa nút Đồng ý / Từ chối đơn chuyển thừa ở Admin-web | VỪA | Bản vá |
| 66.2 | Sửa hai chỗ tài liệu | THẤP | Bản vá |
| 66.3 | Ca 7 `admin.payment.test.js` không được gọi PayOS thật | THẤP | Bản vá |

**Thứ tự:** áp một bản vá cho 66.1–66.3, kiểm lại, rồi làm 52.4 cùng lần deploy kế tiếp.

---

## 66.1, 66.2, 66.3 — Áp bản vá

Bản vá 7 tệp, +60 / −7 dòng, không cần migration, client-app không phải sửa gì.

**Bước 1. Áp bản vá, từ gốc repo:**

```bash
git apply docs/superpowers/backend/CAN-LAM/KIEM-THU/ban_sua_66.patch
```

`git apply` báo lỗi thì sửa tay theo bảng ở các mục dưới, rồi vẫn làm tiếp bước 2.

**Bước 2. Kiểm backend, không cần CSDL, không gọi PayOS:**

```bash
cd src/Backend
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_66.js . kq_66.txt   # dòng cuối: 9 đạt / 9 ca
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_61.js . kq_61.txt   # 6 đạt / 6 ca
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_62.js . kq_62.txt   # 14 đạt / 14 ca
```

**Bước 3. Kiểm Admin-web:**

```bash
cd src/Admin-web
npx vitest run src/tests/payment                                     # 23 passed
npx eslint src/pages/payments/PaymentHistoryPage.jsx src/api/payment.api.js   # 0 lỗi
```

**Bước 4. Chạy unit test và hai kịch bản gia đình trên CSDL thử.** Bắt buộc đặt `DATABASE_URL`: các ca 4, 11, 12 của `admin.payment.test.js` chạy hàm thật, dùng `.env` là chạy trên Supabase.

```bash
cd src/Backend
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu"
export DIRECT_URL="$DATABASE_URL" NODE_ENV=development LOG_LEVEL=error REDIS_PROVIDER=none REDIS_URL=
npx prisma db push --skip-generate --schema prisma/schema.prisma   # dòng Datasource phải ghi đúng tên CSDL thử, sai thì DỪNG

node --test --test-force-exit tests/unit/circuit.breaker.test.js tests/unit/payment.*.test.js tests/unit/admin.payment.test.js tests/unit/payos*.test.js   # 0 fail
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_pr174.js . kq_pr174.txt   # 24 đạt / 24 ca
npm run verify:household -- . kq_nha.txt                                                 # 50 đạt / 50 ca
```

**Bước 5. Bấm thử trên Admin-web, CSDL dev, tài khoản thử.** Không quét QR để chuyển: đó là tài khoản thật.

| # | Làm | Phải thấy |
|---|---|---|
| 1 | Tạo đơn bằng app hoặc `POST /api/payment/create-order`, rồi `node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/webhook_tu_ky.js <orderCode> 70000` | Đơn `WAITING_CONFIRMATION` |
| 2 | Admin-web → Thanh toán → mở đơn → **Đồng ý** | Đơn `PAID`, tài khoản thử thành Premium, số dư thừa không tạo thêm dòng `payment_transaction` |
| 3 | Tạo đơn mới, gửi webhook 70.000 như dòng 1, rồi bấm **Từ chối** | Đơn `REFUND_PENDING`, lý do *"Admin từ chối nâng cấp gói"*, đơn nằm trong hàng hoàn tiền |

**Bước 6.** Ghi kết quả vào bảng cuối tệp, commit, mở PR.

### 66.1 — Nút Đồng ý / Từ chối của Admin-web

Nút gọi `POST /payment/confirm-upgrade`, route này so tài khoản đăng nhập với chủ đơn nên admin luôn nhận 404. Sửa bằng một route riêng cho admin. **Đừng nới phép so ở route của người dùng:** tài khoản thường sẽ xác nhận được đơn của người khác.

| Tệp | Sửa |
|---|---|
| `src/Backend/api/admin.routes.js` | Trước dòng `router.get('/payments/payos-qr', …)` thêm `router.post('/payments/orders/:orderCode/confirm-upgrade', paymentController.confirmUpgradeByAdmin);` |
| `src/Backend/modules/payment/payment.controller.js` | Thêm hàm dưới đây và thêm `confirmUpgradeByAdmin` vào `module.exports` |
| `src/Backend/modules/payment/payment.service.js` | Ba chỗ dưới đây |
| `src/Admin-web/src/api/payment.api.js` | Đổi `confirmUpgrade` thành như dưới đây. `handleConfirmUpgrade` và test giữ nguyên |

```js
// payment.controller.js, đặt trước processRefund
async function confirmUpgradeByAdmin(req, res, next) {
  try {
    const { orderCode } = req.params;
    const { accept } = req.body || {};
    if (!/^\d+$/.test(orderCode)) {
      return ResponseHandler.badRequest(res, 'Mã đơn hàng không hợp lệ');
    }
    if (typeof accept !== 'boolean') {
      return ResponseHandler.badRequest(res, 'Trường accept bắt buộc là kiểu boolean (true/false)');
    }
    req.auditActionName = accept ? 'Admin đồng ý nâng cấp đơn chuyển thừa' : 'Admin từ chối nâng cấp đơn chuyển thừa';
    // Quyền admin do authorize('admin') kiểm. Không truyền idaccount thì service bỏ phép so chủ đơn.
    const result = await paymentService.confirmUpgrade(undefined, {
      orderCode,
      accept,
      lyDoTuChoi: 'Admin từ chối nâng cấp gói',
    });
    return ResponseHandler.success(res, result, result.message);
  } catch (error) {
    if (error.statusCode === 400) return ResponseHandler.badRequest(res, error.message);
    if (error.statusCode === 404) return ResponseHandler.notFound(res, error.message);
    return next(error);
  }
}
```

```js
// payment.service.js, confirmUpgrade
// 1. Chữ ký
async function confirmUpgrade(idaccount, { orderCode, accept, lyDoTuChoi = 'Do người dùng từ chối nâng cấp gói' } = {}) {

// 2. Nhánh từ chối: cả updateOrderPaymentStatus (refundReason) lẫn payment.refund_pending (reason) dùng lyDoTuChoi

// 3. Nhánh từ chối: lấy thêm emitToAccount và báo màn của khách, ngay sau require core/socket
const { emitToAccount, getIO } = require('../../core/socket');
emitToAccount(order.idaccount, 'payment.order_cancelled', {
  orderId: order.id,
  orderCode: Number(order.order_code || orderCode),
  status: 'REFUND_PENDING',
  amountReceived: order.amount_received,
});
```

```js
// payment.api.js
confirmUpgrade: ({ orderCode, accept }) =>
  axiosClient.post(`/admin/payments/orders/${orderCode}/confirm-upgrade`, { accept }),
```

**Xong khi:** `chay_kiem_66.js` đạt 9 / 9 và bước 5 đúng cả ba dòng.

### 66.2 — Hai chỗ tài liệu

| Tệp | Sửa |
|---|---|
| `Project.md:93` | Lấy lại mục **(12) Theo Dõi Thiết Bị & IP Người Dùng** từ `git show ca95198a:Project.md` (dòng 93, từ `(12)` tới `(2-Tier Test Suite)`), đặt ngay trước `(13) Chuẩn Hóa Khả Năng`, nối bằng `; ` |
| `docs/Payment/PAYMENT_WORKFLOW_SPEC.md:173` | `MB Bank 2512070399999` đổi thành `tài khoản của kênh PayOS` |

**Xong khi:** hai lệnh sau đều đúng.

```bash
grep -c "(12) Theo Dõi Thiết Bị" Project.md        # 1
grep -c "2512070399999" docs/Payment/PAYMENT_WORKFLOW_SPEC.md   # 0
```

### 66.3 — Ca 7 không gọi PayOS thật

Trong `src/Backend/tests/unit/admin.payment.test.js`, ca `7. Tầng 2: paymentRepository.createSampleOrder…`:

```js
// Đặt ngay trước `try {` của ca 7
const payosClient = require('../../modules/payment/payos.client');
payosClient.setPayOSClientMock({
  paymentRequests: {
    create: async () => ({
      bin: '970422',
      accountNumber: '1234567890',
      accountName: 'KENH THU',
      description: 'CSTHU ABC123',
      checkoutUrl: 'https://pay.payos.vn/web/thu',
      paymentLinkId: 'link-thu',
    }),
  },
});

// Đặt cuối khối `finally` của ca 7
payosClient.setPayOSClientMock(null);
```

**Xong khi:** ca 7 xanh khi `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY` để rỗng.

---

## 52.4 (CAO) — So khoá mã hoá trên Render

Phải biết máy chủ Render có chạy cùng khoá với dữ liệu trên Supabase (vân tay `98e9e026`) không. Khác khoá thì mọi lượt kéo toàn bộ của tài khoản có hàng đã mã hoá trả 500.

1. **Kiểm mức log.** Render → service → **Environment**. `LOG_LEVEL` là `warn` hoặc `error` thì dòng `DATA_KEY_FP` (mức info) không in ra: đổi `logger.info` thành `logger.warn` ở `src/Backend/index.js:13` trước khi deploy.
2. **Deploy** commit có dòng `DATA_KEY_FP`. Render → **Events**, chờ deploy đúng commit ấy báo *Live*.
3. **Đọc vân tay.** Render → **Logs**, tìm `DATA_KEY_FP`. Ghi lại giá trị `fp`.
4. **Khác `98e9e026` thì DỪNG.** Không đổi khoá trên Render, không làm bước 5, 6. Báo client và PO: đổi khoá khi chưa di trú dữ liệu là làm hỏng dữ liệu đang đọc được.
5. **Thử kéo toàn bộ trên Render.** Dùng tài khoản có hàng đã mã hoá. Tìm bằng câu truy vấn chỉ đọc trên Supabase (đo 2026-11-02: tài khoản 85, 80):

   ```sql
   SELECT "Idaccount", count(*)::int AS so_hang
   FROM "transaction"
   WHERE "Note" LIKE 'enc:%' AND "Deleted_at" IS NULL
   GROUP BY 1 ORDER BY 2 DESC LIMIT 5;
   ```

   ```bash
   B=https://managementfinance.onrender.com/api
   curl -s -X POST "$B/auth/login" -H 'content-type: application/json' \
     -d '{"username":"<tên đăng nhập>","password":"<mật khẩu>"}'     # chép accessToken trong phản hồi
   curl -s -o /dev/null -w '%{http_code}\n' "$B/sync/pull?since=1970-01-01T00:00:00.000Z" \
     -H 'authorization: Bearer <accessToken>'                         # phải 200
   ```

   Ra 500 kèm `DECRYPT_FAILED` thì xử lý như bước 4. Lần gọi đầu có thể chậm vì Render vừa thức dậy.

6. **Gỡ log.** Xoá dòng `DATA_KEY_FP` ở `src/Backend/index.js`, commit, deploy.

**Xong khi:** vân tay Render bằng `98e9e026`, `/sync/pull` trả 200, dòng log đã gỡ.

---

## Trả lời (backend ghi vào đây)

| Mã | Đã làm | Kiểm lại ra gì |
|---|---|---|
| 66.1 | | *(dòng cuối `kq_66.txt`, vitest, ESLint, kết quả ba dòng ở bước 5)* |
| 66.2 | | *(kết quả hai lệnh `grep`)* |
| 66.3 | | *(số pass / fail của unit test trên `flowmoney_kiem_thu`; `kq_pr174.txt`, `kq_nha.txt`)* |
| 52.4 | | *(vân tay trên Render, mã trả về của `/sync/pull`, commit gỡ log)* |
