# Việc backend còn phải làm

> **Người nhận:** backend (NPBao). Tệp này **chỉ có việc còn phải làm**, đo trên backend `1c8a77c8` (PR #178) ngày 2026-11-02. Việc xong thì client xoá khỏi tệp; lịch sử xem bằng git.
> Đơn mới thêm vào tệp này, số kế tiếp **67**.

## Tổng quan

| Mã | Lỗi | Mức | Cách xong |
|---|---|---|---|
| 52.4 | Chưa so khoá mã hoá trên Render. Khác khoá thì kéo toàn bộ trả 500 | **CAO** | Tay, cần quyền Render |
| 66.1 | Nút Đồng ý / Từ chối đơn chuyển thừa ở Admin-web luôn báo lỗi với đơn của khách | VỪA | PO chọn hướng, rồi sửa |
| 66.2 | Tài liệu: `Project.md` mất mục (12), `PAYMENT_WORKFLOW_SPEC.md:173` còn số tài khoản | THẤP | Tay |
| 66.3 | Ca 7 `admin.payment.test.js` gọi PayOS thật khi có khoá `.env` | THẤP | Sửa test |
| 60.3 | Ba ca test nói nhiều hơn điều chúng chứng minh | THẤP | Tay, tuỳ chọn |

---

## 52.4 (CAO) — So khoá mã hoá trên Render

⚠️ **Mới xong nửa đầu.** PR #178 đã thêm dòng `DATA_KEY_FP` vào `index.js:13`, nhưng chưa có kết quả từ Render. Điều chưa ai biết vẫn là **máy chủ Render có chạy cùng khoá `98e9e026` không**.

25 + 3 hàng trên Supabase mang khoá `.env`. Render khác khoá thì mọi lượt kéo toàn bộ của tài khoản có hàng còn sống trả 500 (`sync.controller.js:67-73`).

**Việc còn lại:** deploy, đọc log, rồi gỡ dòng `DATA_KEY_FP`.

**Xong khi có đủ hai điều:**

1. Log Render in `DATA_KEY_FP` bằng `98e9e026`.
2. `GET https://managementfinance.onrender.com/api/sync/pull?since=1970-01-01T00:00:00.000Z` của một tài khoản có hàng đã di trú trả 200.

Khác vân tay thì đừng đổi khoá trên Render khi chưa di trú dữ liệu: báo client và PO trước.

## 66.1 (VỪA) — Nút Đồng ý / Từ chối của Admin-web luôn báo lỗi

**Đo được** (2026-11-02, gọi `paymentService.confirmUpgrade` trên `1c8a77c8` với repository giả, đơn `WAITING_CONFIRMATION` của tài khoản 30):

| Người gọi | Kết quả |
|---|---|
| Chủ đơn, `idaccount` 30 | Được, cả Đồng ý lẫn Từ chối |
| Admin, `idaccount` 1 | **404** *"Đơn hàng không tồn tại hoặc không thuộc quyền sở hữu của bạn"*, cả hai nút |

**Gốc lỗi.** PR #178 định nghĩa `handleConfirmUpgrade` (`PaymentHistoryPage.jsx:411`), hai nút ở dòng 1343 và 1350 gọi `POST /payment/confirm-upgrade`. Route này lấy `req.user.idaccount`, và token admin mang `idaccount` của chính admin, nên `payment.service.js` so `order.idaccount !== idaccount` rồi từ chối. Trước PR, nút ném `ReferenceError`; nay ra câu báo lỗi. Ca `2.11` của `payment.page.test.jsx` giả `paymentApi.confirmUpgrade` nên không thấy.

**Hậu quả.** Khách chuyển thừa mà không tự bấm trên app thì admin không xử lý hộ được, đơn nằm `WAITING_CONFIRMATION` mãi. App của khách không bị ảnh hưởng.

**Cần PO chọn một trong hai, chưa có bản vá:**

- **A. Admin được xử lý hộ:** thêm route admin cạnh `/payments/orders/:id/refund` (`api/admin.routes.js:80`), gọi `paymentService.confirmUpgrade(undefined, { orderCode, accept })` (tham số đầu rỗng thì bỏ phép so chủ đơn), và cho `paymentApi` của Admin-web gọi route mới. **Đừng** nới phép so ở route của người dùng: tài khoản thường sẽ xác nhận được đơn của người khác.
- **B. Chỉ khách được quyết:** bỏ hai nút và `handleConfirmUpgrade`, hiện dòng *"Chờ khách xác nhận trên app"*.

**Xong khi:** hướng A có ca test đi qua route thật với token admin; hoặc hướng B không còn nút nào gọi `confirm-upgrade` ở Admin-web.

## 66.2 (THẤP) — Hai chỗ tài liệu

| Tệp | Sửa |
|---|---|
| `Project.md:93` | PR #178 viết đè mất mục **(12) Theo Dõi Thiết Bị & IP Người Dùng** khi thêm (13), (14). Lấy lại đoạn ấy từ `git show ca95198a:Project.md` |
| `docs/Payment/PAYMENT_WORKFLOW_SPEC.md:173` | Còn *"VietQR thật (MB Bank 2512070399999)"*. Đổi thành *"tài khoản của kênh PayOS"*. Lệnh `grep` của 62.1 chỉ quét `src/` nên không thấy |

## 66.3 (THẤP) — Ca 7 gọi PayOS thật

`tests/unit/admin.payment.test.js` ca 7 (`createSampleOrder`) không giả PayOS. Có khoá trong `.env` thì **mỗi lần chạy tạo một liên kết thật trên kênh**; không có khoá thì đỏ (đo 2026-11-02: code 214). Con số *78 pass* trong bảng trả lời PR #178 vì thế cần `.env` thật. Đây là thiếu sót của bản vá client giao, không phải lỗi của bạn.

**Sửa:** đặt trước `try` của ca 7, và trả lại ở `finally`:

```js
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
// finally:
payosClient.setPayOSClientMock(null);
```

⚠️ Ca 4, 11, 12 cùng tệp gọi `autoExpirePendingOrders` / `downgradeExpiredPremiumAccounts` thật, nên cũng cần CSDL: chạy với `.env` là các hàm ấy chạy trên CSDL trong `.env`. Chạy test trên `flowmoney_kiem_thu`, không chạy trên Supabase.

**Xong khi:** ca 7 xanh khi `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY` rỗng.

## 60.3 (THẤP, tuỳ chọn) — Ba ca test nói nhiều hơn điều chúng chứng minh

Ca 2 đã sửa ở PR #176. Bằng chứng đường thật của gia đình là `verify:household`, không phải các ca này. Chỉ cần làm khi có thời gian.

| Ca trong `tests/unit/household_and_aiops_v2.test.js` | Vì sao chưa canh được | Cách sửa |
|---|---|---|
| Ca 3 (58.1) | `operation: 'create'`, khoá `to_idwallet`: app không gửi | Chép payload từ `src/Client-app/test/core/sync/sync_payload_contract_test.dart` |
| Ca 4 (57.4 + 59.1) | Giả `enforceHouseholdPermission`, không kiểm *không ghi* | Giả ở tầng Prisma, kiểm số lần ghi |
| Ca 5 (58.5) | Đi qua `isAccountQuarantined`, 0 chỗ gọi ngoài test | Gọi `sweepExpiredQuarantines`, `_reconcileAutoLocks` |

## Giữ nguyên khi sửa backend

Các kịch bản ở `KIEM-THU/` đang đạt trọn và client chạy lại sau mỗi lần gộp. Chạy trước khi báo xong, hai kịch bản đầu trên CSDL riêng tên `flowmoney_kiem_thu`:

```bash
cd src/Backend
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu"
export DIRECT_URL="$DATABASE_URL" NODE_ENV=development LOG_LEVEL=error REDIS_PROVIDER=none REDIS_URL=
npx prisma db push --skip-generate --schema prisma/schema.prisma   # dòng Datasource phải ghi đúng tên CSDL thử, sai thì DỪNG

node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_pr174.js . kq_pr174.txt   # 24 đạt / 24 ca
npm run verify:household -- . kq_nha.txt                                                 # 50 đạt / 50 ca
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_61.js . kq_61.txt         # 6 đạt / 6 ca
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_62.js . kq_62.txt         # 14 đạt / 14 ca
```

---

## Trả lời (backend ghi vào đây)

| Mã | Đã làm | Kiểm lại ra gì |
|---|---|---|
| 52.4 | | *(vân tay trong log Render, mã trả về của `/sync/pull` trên Render)* |
| 66.1 | | *(hướng PO chọn; ca test)* |
| 66.2 | | |
| 66.3 | | *(kết quả ca 7 khi khoá PayOS rỗng)* |
| 60.3 | | *(hoặc "chưa")* |
