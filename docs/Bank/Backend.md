# Đặc Tả Kỹ Thuật Tích Hợp SePay Cá Nhân — Module Backend

Tài liệu này quy định chi tiết toàn bộ các hạng mục công việc, kiến trúc mã nguồn, quy chuẩn API và các lưu ý vận hành trên môi trường **Cloud (Render)** để tích hợp thành công nền tảng **SePay Cá Nhân (`my.sepay.vn`)** tại Module Backend cho hệ thống **FlowMoney**.

---

## 1. Tổng Quan Kiến Trúc & Luồng Vận Hành

### 1.1. Mô Hình Tích Hợp SePay Cá Nhân
* **Chủ hệ thống (Admin / Sinh viên):**
  * Sở hữu tài khoản cá nhân trên [my.sepay.vn](https://my.sepay.vn).
  * Liên kết các tài khoản ngân hàng thực tế (MBBank, Vietcombank, ACB...) trên giao diện SePay.
  * Cài đặt **1 URL Webhook duy nhất** trên SePay trỏ về Backend Render:
    `https://managementfinance.onrender.com/api/bank/webhook`
  * Thiết lập phương thức xác thực: `API Key` (Header `Authorization: ApiKey <SEPAY_WEBHOOK_API_KEY>`).
* **Người dùng cuối (End-users trên Client-app):**
  * Không cần có tài khoản SePay.
  * Tự do khai báo các tài khoản ngân hàng của họ trên ứng dụng (Số tài khoản, Tên ngân hàng, Tên chủ thẻ).
  * Backend tự động ánh xạ (Mapping) biến động số dư từ Webhook SePay tới đúng tài khoản người dùng dựa trên trường `accountNumber`.

---

## 2. Các Hạng Mục Cần Thực Hiện Tại Source Code Backend

### 2.1. Cấu Hình Biến Môi Trường (`.env` & `src/Backend/config/index.js`)

Chỉ cần cấu hình khóa bí mật của Webhook (và tùy chọn API Token nếu cần gọi API tra cứu của SePay cá nhân):

```env
# ==============================================================================
# SEPAY PERSONAL CONFIGURATION (my.sepay.vn)
# ==============================================================================
SEPAY_WEBHOOK_API_KEY=your_secure_webhook_api_key_here
SEPAY_API_TOKEN=your_personal_api_token_here
```

Cập nhật `src/Backend/config/index.js`:
```javascript
sepay: {
  webhookApiKey: process.env.SEPAY_WEBHOOK_API_KEY,
  apiToken: process.env.SEPAY_API_TOKEN,
  apiUrl: process.env.SEPAY_API_URL || 'https://my.sepay.vn/userapi',
}
```

---

### 2.2. Module Xác Thực & Chuẩn Hóa Webhook (`src/Backend/modules/bank/sepay/sepay.webhook.js`)

Module chịu trách nhiệm bảo vệ an toàn cho Server và chuẩn hóa dữ liệu từ SePay Cá Nhân:

1. **Xác thực ApiKey Timing-Safe (`verifySignature`):**
   * Lấy Header `Authorization` (hoặc `x-api-key`).
   * Kiểm tra định dạng `ApiKey <KEY>`.
   * Dùng hàm `crypto.timingSafeEqual(bufferReceived, bufferExpected)` để so khớp, loại bỏ hoàn toàn nguy cơ bị tấn công Timing Attack.

2. **Chuẩn hóa Payload SePay Cá Nhân (`normalizeTransactionPayload`):**
   * Tương thích hoàn toàn với cấu trúc JSON `camelCase` của SePay:
     * `account_number`: Bóc tách từ `rawPayload.accountNumber` hoặc `subAccount`.
     * `bank_tran_id`: Bóc tách từ `rawPayload.referenceCode` (mã FT ngân hàng) hoặc `rawPayload.id`.
     * `transfer_type`: Chuyển đổi `"in"` $\rightarrow$ `'credit'` (Thu), `"out"` $\rightarrow$ `'debit'` (Chi).
     * `amount`: Bóc tách từ `rawPayload.transferAmount` hoặc `amount`.
     * `accumulated`: Bóc tách số dư lũy kế thực tế từ ngân hàng.
     * `note`: Bóc tách từ `rawPayload.content` hoặc `description`.
     * `date_transaction`: Parse từ chuỗi `rawPayload.transactionDate`.

---

### 2.3. Danh Sách Endpoint REST API (`src/Backend/api/bank.routes.js`)

| Phương Thức | Endpoint | Xác Thực | Chức Năng |
|---|---|---|---|
| `POST` | `/api/bank/register-account` | `authenticate` (JWT) | Người dùng tự khai báo tài khoản ngân hàng trên App |
| `GET` | `/api/bank/accounts` | `authenticate` (JWT) | Lấy danh sách tài khoản ngân hàng đã khai báo của User |
| `POST` | `/api/bank/webhook` | `ApiKey` (Public) | Nhận thông báo biến động số dư tức thì từ SePay |
| `GET` | `/api/bank/pending-transactions`| `authenticate` (JWT) | Lấy danh sách giao dịch ngân hàng đang chờ duyệt |
| `POST` | `/api/bank/confirm-transaction` | `authenticate` (JWT) | Xác nhận duyệt giao dịch và chốt danh mục chi tiêu |
| `POST` | `/api/bank/reject-transaction`  | `authenticate` (JWT) | Từ chối giao dịch ngân hàng |

---

### 2.4. Xử Lý Tại Controller (`src/Backend/modules/bank/bank.controller.js`)

#### A. Khai Báo Tài Khoản Ngân Hàng (`registerAccount`)
```javascript
async registerAccount(req, res, next) {
  try {
    const idaccount = req.user.idaccount;
    const { account_number, bank_name, account_name, balance } = req.body;
    const result = await bankService.registerAccount(idaccount, {
      account_number,
      bank_name,
      account_name,
      balance,
    });
    return ResponseHandler.success(res, result, 'Đăng ký tài khoản ngân hàng thành công', 201);
  } catch (error) {
    next(error);
  }
}
```

#### B. Tiếp Nhận Webhook Siêu Tốc (`handleWebhook`)
```javascript
async handleWebhook(req, res, next) {
  try {
    // 1. Verify ApiKey qua crypto.timingSafeEqual
    const isValid = sepayWebhook.verifySignature(req);
    if (!isValid) {
      return res.status(401).json({ success: false, message: 'Invalid ApiKey' });
    }

    // 2. Đẩy ngay vào hàng đợi BullMQ (xử lý bất đồng bộ)
    await bankService.enqueueWebhookJob(req.body);

    // 3. Phản hồi HTTP 200 OK ngay lập tức (< 500ms)
    return res.status(200).json({ success: true, message: 'Webhook received successfully' });
  } catch (error) {
    return res.status(200).json({ success: false, message: 'Queue error' });
  }
}
```

---

### 2.5. Xử Lý Bất Đồng Bộ & Chống Trùng Tại Worker (`src/Backend/workers/bank.worker.js`)

Tiến trình worker độc lập xử lý hàng đợi BullMQ `bank-webhook` qua hàm `processSepayTransaction`:

1. **Mapping Người Dùng:**
   * Tìm `bank_account` trong CSDL theo `account_number = payload.accountNumber`.
   * Lấy ra `idaccount` của User sở hữu tài khoản.
2. **Khử Trùng Lặp Tuyệt Đối (Idempotency):**
   * Kiểm tra giao dịch đã tồn tại theo `(provider = 'BankSync', bank_tran_id = referenceCode)` hay chưa.
   * Nếu đã có $\rightarrow$ Bỏ qua (ngăn chặn rủi ro ghi đúp khi SePay retry gửi lại).
3. **Cập Nhật Số Dư Thực Tế:**
   * Lấy số dư lũy kế `accumulated` từ SePay gán trực tiếp cho `bank_account.balance` và `wallet.balance`.
4. **AI Classify Phân Loại Chi Tiêu (3-Tier):**
   * Tự động gọi phân loại AI dựa trên nội dung chuyển khoản `content` để gợi ý danh mục chi tiêu (Ăn uống, Hóa đơn...).
5. **Tạo Giao Dịch & Bắn Realtime Socket.io:**
   * Lưu giao dịch với `status = 'Pending'`.
   * Bắn sự kiện Socket.io:
     * Tới người dùng: `socket.emitToUser(idaccount, 'bank_transaction.incoming', transactionData)` $\rightarrow$ Điện thoại rung, chuông báo tiền vào/ra.
     * Tới quản trị viên: `socket.emitToAdmin('admin.bank_transaction_created', transactionData)`.

---

## 3. Quy Tắc Nghiệp Vụ Bất Di Bất Dịch Cho Ví `Banking`

1. **Khóa sửa số dư thủ công:** Nghiêm cấm API cập nhật số dư bằng tay cho ví `type = 'Banking'`.
2. **Khóa tạo giao dịch thủ công:** Chặn tạo giao dịch có `Provider = 'Manual'` vào ví Banking.
3. **Chỉ biến động qua 3 nguồn dữ liệu:**
   * `SePay Webhook IPN` (Giao dịch ngân hàng thực tế $\rightarrow$ Người dùng duyệt).
   * `ORC AI` (Quét hóa đơn chọn nguồn thanh toán từ ngân hàng).
   * `SMS Parser` (Đọc tin nhắn SMS ngân hàng).

---

## 4. Hướng Dẫn Kết Nối SePay Cá Nhân Với Backend Render Cloud

### Bước 1: Cấu hình biến môi trường trên Render
1. Truy cập **Render Dashboard** $\rightarrow$ Web Service **`managementfinance`**.
2. Vào mục **Environment** $\rightarrow$ Thêm biến:
   * `SEPAY_WEBHOOK_API_KEY` = `<Chuỗi_Khóa_Bí_Mật_Tự_Đặt>` (Ví dụ: `FlowMoney_SecKey_2026_xYz`)
3. Bấm **Save Changes** (Render sẽ tự động redeploy trong 1 phút).

### Bước 2: Thêm tài khoản ngân hàng trên my.sepay.vn
1. Đăng nhập [https://my.sepay.vn](https://my.sepay.vn).
2. Vào mục **Ngân hàng** $\rightarrow$ Bấm **Kết nối thêm tài khoản**.
3. Chọn ngân hàng (MBBank, Vietcombank...), nhập Số tài khoản và CCCD/SĐT $\rightarrow$ Nhập mã OTP do ngân hàng gửi về để kích hoạt.

### Bước 3: Cài đặt Webhook trên SePay
1. Trên Dashboard SePay, vào mục **Tích hợp** $\rightarrow$ **Webhooks** $\rightarrow$ Bấm **Tạo Webhook mới**:
   * **URL nhận Webhook:** `https://managementfinance.onrender.com/api/bank/webhook`
   * **Sự kiện:** Chọn cả **Tiền vào** và **Tiền ra**.
   * **Kiểu xác thực:** Chọn `API Key` (Header `Authorization` với giá trị `ApiKey <SEPAY_WEBHOOK_API_KEY_BẠN_ĐÃ_ĐẶT>`).
2. Bấm **Kiểm tra Webhook** $\rightarrow$ SePay báo phản hồi `200 OK` là kết nối thành công 100%!
