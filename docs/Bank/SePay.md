# Tổng Quan Cơ Chế & Cấu Trúc Dữ Liệu SePay Cá Nhân (SePay Personal — my.sepay.vn)

Tài liệu này tổng hợp toàn bộ các **cơ chế vận hành, kiến trúc bảo mật, luồng mapping danh tính và cấu trúc dữ liệu** của nền tảng **SePay Cá Nhân (`my.sepay.vn`)** áp dụng trực tiếp cho hệ sinh thái quản lý tài chính cá nhân **FlowMoney**.

---

## 1. Bối Cảnh & Mô Hình Kiến Trúc Ứng Dụng

### 1.1. Tại Sao Chọn SePay Cá Nhân Cho Dự Án?
* **Phù hợp với dự án cá nhân & đồ án tốt nghiệp:** 
  * SePay Bank Hub (B2B Open Banking) đòi hỏi pháp nhân doanh nghiệp (giấy phép ĐKKD) và ký hợp đồng đối tác.
  * **SePay Cá Nhân (`my.sepay.vn`)** được mở tự do cho cá nhân / lập trình viên / sinh viên đăng ký miễn phí, kích hoạt tức thì bằng số điện thoại cá nhân.
* **Hoàn toàn độc lập, không rào cản tài khoản bên thứ 3:**
  * Thay thế triệt để mô hình Casso cũ (vốn bắt từng người dùng phải có tài khoản Casso).
  * Với SePay Cá Nhân, **người dùng cuối trên ứng dụng FlowMoney KHÔNG CẦN tài khoản SePay**.
  * Chủ hệ thống (Admin / Sinh viên thực hiện dự án) chỉ cần 1 tài khoản SePay Cá Nhân duy nhất để quản lý các tài khoản ngân hàng và kết nối Webhook về Server.

---

### 1.2. Sơ Đồ Khái Niệm Vận Hành

```
┌────────────────────────────────────────────────────────────────────────┐
│                        HỆ SINH THÁI FLOWMONEY                          │
│                                                                        │
│   ┌──────────────┐     (1) Khai báo STK         ┌──────────────────┐   │
│   │  Client-app  │─────────────────────────────►│  Backend Cloud   │   │
│   │   (Mobile)   │  (POST /bank/register-acc)   │  (Render Cloud)  │   │
│   └──────────────┘                              └────────┬─────────┘   │
│                                                          ▲             │
│                                                          │ (3) Webhook │
│                                                          │     IPN     │
│   ┌──────────────────────────────────────────────┐       │ (Realtime   │
│   │    Tài Khoản SePay Cá Nhân (my.sepay.vn)     │───────┘   < 2s)     │
│   │  - Thêm tài khoản ngân hàng thực (MB, VCB...)│                     │
│   │  - Cài đặt 1 Webhook URL duy nhất về Render  │                     │
│   └──────────────────────┬───────────────────────┘                     │
│                          │                                             │
│                          ▲ (2) Phát sinh biến động tiền                │
│                          │                                             │
│                 [Ngân Hàng Thực Tế]                                    │
│             (Chuyển khoản / Nhận tiền)                                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Toàn Bộ Các Cơ Chế Vận Hành Của SePay Cá Nhân

### Cơ Chế 1: Quản Lý Webhook & Bảo Mật ApiKey Tập Trung
* **Không cần Client ID / Client Secret:** Tài khoản SePay Cá Nhân không sử dụng mô hình OAuth Doanh nghiệp phức tạp.
* **Xác thực Webhook an toàn qua ApiKey:**
  * Khi tạo Webhook trên Dashboard [my.sepay.vn](https://my.sepay.vn), bạn tự đặt một khóa bí mật (ví dụ: `FlowMoney_Webhook_Secret_2026`).
  * Cấu hình Header gửi kèm: `Authorization: ApiKey <KEY_BÍ_MẬT>` (hoặc `x-api-key`).
  * Backend xác thực bằng thuật toán `crypto.timingSafeEqual` để loại bỏ 100% nguy cơ giả mạo request hoặc tấn công dò thời gian (Timing Attack).

---

### Cơ Chế 2: Luồng Khai Báo Tài Khoản Không Thu Thập Mật Khẩu (Zero Credential Risk)
> [!IMPORTANT]
> **Nguyên tắc an toàn bảo mật tuyệt đối:**
> * FlowMoney **TUYỆT ĐỐI KHÔNG YÊU CẦU** người dùng nhập Tên đăng nhập, Mật khẩu Internet Banking hay mã OTP ngân hàng trên ứng dụng di động.
> * Việc thu thập mật khẩu ngân hàng của người dùng trên app cá nhân là vi phạm pháp luật (Nghị định 13/2023/NĐ-CP về Bảo vệ dữ liệu cá nhân) và sẽ bị Hội đồng chấm đồ án đánh giá trượt vì lỗi bảo mật nghiêm trọng.

**Luồng người dùng khai báo trên Client-app:**
1. Người dùng vào mục **"Thêm tài khoản ngân hàng"** trên App.
2. Chỉ cần nhập các thông tin công khai:
   * **Ngân hàng:** Chọn từ danh sách (MBBank, Vietcombank, Techcombank, ACB, VPBank...).
   * **Số tài khoản ngân hàng:** Ví dụ `0987654321`.
   * **Tên chủ tài khoản:** Ví dụ `NGUYEN PHU BAO`.
   * **Số dư ban đầu:** Ví dụ `5,000,000 đ`.
3. Client-app gửi request: `POST /api/bank/register-account`.
4. Backend lưu vào CSDL bảng `bank_account`, tự động tạo ví `wallet` tương ứng (`type = 'Banking'`).

---

### Cơ Chế 3: Nhận Biến Động Số Dư & Tự Động Định Tuyến Người Dùng (Multi-Tenancy Routing)
Tất cả các tài khoản ngân hàng liên kết trên tài khoản SePay Cá Nhân đều bắn về **1 URL Webhook duy nhất**:
* **URL:** `https://managementfinance.onrender.com/api/bank/webhook`
* Khi có biến động số dư phát sinh:
  1. SePay gửi Webhook IPN mang số tài khoản nhận tiền (`accountNumber`).
  2. Backend tra cứu CSDL:
     ```javascript
     const bankAcc = await prisma.bank_account.findFirst({
       where: { account_number: payload.accountNumber, connect_status: 'Active' }
     });
     const idaccount = bankAcc.idaccount; // Tìm ra ngay User sở hữu!
     ```
  3. Hệ thống tự động định tuyến giao dịch về đúng người dùng sở hữu tài khoản ngân hàng đó mà không cần bất kỳ mã token người dùng nào!

---

### Cơ Chế 4: Chống Trùng Lặp Giao Dịch 2 Lớp (Idempotency)
* SePay Cá Nhân luôn gửi kèm mã định danh giao dịch duy nhất:
  * `referenceCode`: Mã tham chiếu giao dịch do ngân hàng cấp (ví dụ mã FT của Vietcombank, MB).
  * `id`: ID giao dịch tự tăng không đổi trên hệ thống SePay.
* **Lớp 1 (Worker Logic):** Kiểm tra trong bảng `transaction`:
  ```javascript
  const existing = await prisma.transaction.findFirst({
    where: { provider: 'BankSync', bank_tran_id: String(referenceCode || id) }
  });
  if (existing) return; // Bỏ qua nếu đã nhận trước đó
  ```
* **Lớp 2 (Ràng buộc duy nhất CSDL Supabase PostgreSQL):**
  ```prisma
  @@unique([provider, bank_tran_id], map: "uq_transaction_external")
  ```
  Dù SePay có retry gửi lại nhiều lần do mạng chập chờn, CSDL cũng sẽ chặn đứng 100%, bảo đảm không bao giờ bị ghi trùng giao dịch.

---

### Cơ Chế 5: Xử Lý Bất Đồng Bộ Qua BullMQ & AI Phân Loại Chi Tiêu
1. **Phản hồi siêu tốc (< 500ms):** Controller nhận Webhook $\rightarrow$ Verify ApiKey $\rightarrow$ Đẩy payload vào hàng đợi Redis BullMQ (`bank-webhook`) $\rightarrow$ Phản hồi ngay `HTTP 200 OK: {"success": true}` để SePay không báo timeout.
2. **Worker xử lý ngầm (`bank.worker.js`):**
   * Đọc số dư lũy kế thực tế `accumulated` từ ngân hàng và cập nhật cho `bank_account.balance` và `wallet.balance`.
   * Tự động gọi **AI Classify 3-Tier** bóc tách chuỗi `content` để gợi ý danh mục chi tiêu (Ăn uống, Mua sắm, Hóa đơn...).
   * Tạo bản ghi giao dịch ở trạng thái `Pending` (chờ duyệt).
   * Phát sự kiện Socket.io `bank_transaction.incoming` tới điện thoại người dùng (`user_${idaccount}`) và `admin.bank_transaction_created` tới Admin-web.

---

## 3. Cấu Trúc Dữ Liệu Webhook IPN Thực Tế (SePay Cá Nhân)

Khi tài khoản ngân hàng của bạn nhận hoặc chuyển tiền, SePay Cá Nhân ([my.sepay.vn](https://my.sepay.vn)) sẽ gửi gói tin HTTP POST dạng JSON `camelCase` như sau:

### 3.1. Payload Mẫu Thực Tế (JSON)
```json
{
  "id": 92704,
  "gateway": "Vietcombank",
  "transactionDate": "2026-09-05 19:20:00",
  "accountNumber": "1017588888",
  "subAccount": "",
  "code": "SEVN63DC8E5C",
  "content": "NGUYEN VAN A chuyen tien an toi",
  "transferType": "in",
  "description": "NGUYEN VAN A chuyen tien an toi",
  "transferAmount": 50000,
  "accumulated": 10500000,
  "referenceCode": "FT24012345678"
}
```

### 3.2. Bảng Mô Tả Chi Tiết Các Trường Dữ Liệu

| Tên Trường (SePay Cá Nhân) | Kiểu Dữ Liệu | Ý Nghĩa Nghiệp Vụ | Ánh Xạ Vào CSDL FlowMoney |
|---|---|---|---|
| `id` | Integer | ID duy nhất của giao dịch trên hệ thống SePay | Dùng làm fallback cho `bank_tran_id` |
| `gateway` | String | Tên ngân hàng xử lý (`Vietcombank`, `MBBank`...) | `bank_name` trong bảng `bank_account` |
| `transactionDate` | String | Thời gian phát sinh tại ngân hàng (`YYYY-MM-DD HH:mm:ss`) | `date_transaction` (`TIMESTAMP(6)`) |
| `accountNumber` | String | Số tài khoản ngân hàng nhận/chuyển tiền | `account_number` trong bảng `bank_account` (dùng để tìm `idaccount`) |
| `transferType` | String | `"in"` (Tiền vào $\rightarrow$ Thu) hoặc `"out"` (Tiền ra $\rightarrow$ Chi) | Chuyển đổi thành `type: "Thu"` hoặc `"Chi"` |
| `transferAmount` | Number | Số tiền biến động thực tế | `amount` trong bảng `transaction` |
| `accumulated` | Number | Số dư lũy kế cuối cùng trong tài khoản ngân hàng | Cập nhật trực tiếp vào `balance` của `bank_account` và `wallet` |
| `content` | String | Nội dung chuyển khoản thô từ phía ngân hàng | `note` trong `transaction` (đưa vào AI Classify) |
| `referenceCode` | String | Mã tham chiếu ngân hàng (Mã FT / Trace No) | `bank_tran_id` trong `transaction` (khử trùng lặp) |

---

## 4. Bảng Ánh Xạ CSDL FlowMoney (Supabase PostgreSQL)

| Bảng CSDL | Cột Lưu Trữ | Kiểu Dữ Liệu | Giá Trị Ghi Nhận |
|---|---|---|---|
| `bank_account` | `id_casso_account` | `VARCHAR(100)` (UNIQUE) | Lưu `acc_${account_number}` làm mã định danh duy nhất |
| `bank_account` | `account_number` | `VARCHAR(50)` | Lưu số tài khoản ngân hàng |
| `bank_account` | `bank_name` | `VARCHAR(100)` | Tên ngân hàng (`gateway`) |
| `bank_account` | `balance` | `DECIMAL(15, 2)` | Cập nhật từ `accumulated` (số dư thực tế từ SePay) |
| `bank_account` | `connect_status` | `VARCHAR(12)` | Cố định `'Active'` |
| `wallet` | `type` | `VARCHAR(7)` | Cố định `'Banking'` |
| `wallet` | `id_bank_casso` | `VARCHAR(36)` | Trỏ tới `bank_account.id_bank_account` |
| `wallet` | `balance` | `DECIMAL(15, 2)` | Cập nhật đồng bộ với `bank_account.balance` |
| `transaction` | `provider` | `VARCHAR(40)` | Cố định `'BankSync'` |
| `transaction` | `bank_tran_id` | `VARCHAR(100)` | Lưu `referenceCode` hoặc `id` từ SePay |
| `transaction` | `status` | `VARCHAR(10)` | Khởi tạo `'Pending'` $\rightarrow$ User duyệt chuyển `'Confirmed'` |
| `transaction` | `type` | `VARCHAR(20)` | `transferType: "in"` $\rightarrow$ `'Thu'`, `"out"` $\rightarrow$ `'Chi'` |

---

## 5. Quy Tắc Bảo Toàn Số Dư Ví `Banking` (Bất Di Bất Dịch)

1. **Khóa sửa số dư thủ công:** Người dùng không được phép tự gõ sửa số dư ví Banking trên ứng dụng di động. Số dư luôn phản ánh số dư thực tế từ ngân hàng.
2. **Khóa tạo giao dịch thủ công:** Dropdown chọn ví ở màn hình tạo giao dịch chi tiêu/thu nhập tay sẽ **ẩn hoặc vô hiệu hóa** các ví có `type == 'Banking'`.
3. **Chỉ biến động qua 3 nguồn dữ liệu duy nhất:**
   * **SePay Webhook IPN:** Tự động đồng bộ từ giao dịch ngân hàng $\rightarrow$ Người dùng duyệt.
   * **Quét hóa đơn ORC AI:** Người dùng chụp hóa đơn và chọn nguồn thanh toán là ví Banking.
   * **SMS Parser:** Đọc tin nhắn biến động số dư ngân hàng qua SMS thiết bị.

---

*Tài liệu này là căn cứ kỹ thuật chính thức cho toàn bộ Module Bank theo chuẩn SePay Cá Nhân.*
