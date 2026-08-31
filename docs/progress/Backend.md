# Tiến Độ Backend — Các Nội Dung Đã Triển Khai (Hỗ Trợ Client-App)

Tài liệu này tổng hợp toàn bộ các tính năng, API, mô hình dữ liệu và cơ chế xử lý Backend đã hoàn thiện để phục vụ tích hợp với **Client-app (Mobile App)**.

---

## 1. Cơ Sở Dữ Liệu & Mô Hình Dữ Liệu Mới (Supabase PostgreSQL)

Backend đã hoàn thành đồng bộ **13 bảng CSDL** theo đặc tả chuẩn [New_Database.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/superpowers/backend/New_Database.md):

* **`Transaction`**:
  * `Status` (`Varchar(10)`): Hỗ trợ 4 trạng thái `Pending`, `Confirmed`, `Rejected`, `Fail`.
  * `Provider` (`Varchar(40)`): `Manual` (tạo thủ công), `BankSync` (từ ngân hàng Casso), `SMS`, `ORC` (OCR hình ảnh), `Bill`.
  * `DateTransaction` (`Timestamp`): Thời điểm giao dịch thực tế.
  * `Amount`: Số tiền giữ nguyên dấu $\pm$ (dương = tiền vào, âm = tiền ra).
  * `Deleted_at`: Xóa mềm riêng biệt của bảng giao dịch.
* **`Wallet`**:
  * `Name` (`nvarchar(100)`): Hỗ trợ độ dài tên ví lên đến 100 ký tự (phù hợp ví ngân hàng dài).
  * `Type` (`varchar(7)`): `Cash`, `Bank`, `Saving`, `Banking`.
  * `Id_bank_casso`: Khóa ngoại liên kết với bảng `Bank_account`.
* **`Category`**:
  * `Classify` (`varchar(7)`): `Thu`, `Chi`, `Vay`, `no`.
  * `Keyword` (`Text`): Chuỗi từ khóa phân tách bằng dấu `;` phục vụ AI và Keyword Matcher offline.
* **`Budget`**:
  * Bổ sung `Threshold_Warning_Amount`, `Threshold_Warning_Percent`, `Nexttime_recurrence`. Loại bỏ các cột tính toán tĩnh cũ.
* **`Bill`**:
  * Bổ sung `Start_date`, `Due_date`, `Pay_status` (`Pending`, `Payed`, `Overdue`), `Time_notification`.
* **`Goal`**:
  * Bổ sung `Start_date`, `Cycle_take_money`, `Time_cycle_take_money`, `Status_complete` (`'True'/'False'`), `Recurrence`, `Time_recurrence`.

---

## 2. Module Sync (Đồng Bộ Dữ Liệu 2 Chiều Offline-First)

* **`POST /api/sync/batch` (Push Operations):**
  * Nhận mảng các thao tác đồng bộ từ Client-app (`create`, `update`, `delete`) cho 6 thực thể (`category`, `wallet`, `transaction`, `budget`, `bill`, `goal`).
  * Áp dụng thuật toán **Last-Write-Wins (LWW)** dựa trên `Update_at` / `update_at`.
  * Tự động nhận diện Soft Delete (`Deleted_at` cho `transaction`, `Delete_at` cho các bảng còn lại).
* **`GET /api/sync/pull?since=YYYY-MM-DDTHH:mm:ss.sssZ` (Pull Changes):**
  * Trả về toàn bộ bản ghi được tạo mới/cập nhật/xóa mềm kể từ mốc thời gian `since`.
* **`GET /api/sync/status`:**
  * Trả về tổng số lượng bản ghi của người dùng trên Cloud để Client kiểm tra tính toàn vẹn.

---

## 3. Module Bank & Casso Webhook

* **`GET /api/bank/accounts`:**
  * Gọi Casso Open Banking API, tự động upsert vào bảng `bank_account` (`Connect_status = 'Active'`) và trả về danh sách tài khoản ngân hàng liên kết.
* **`POST /api/bank/webhook` (Tiếp nhận biến động số dư Realtime):**
  * Tiếp nhận webhook Non-blocking < 50ms, xác thực chữ ký HMAC `secure-token`.
  * Đẩy vào hàng đợi BullMQ `bank-webhook` xử lý ngầm:
    * Khử trùng lặp (Idempotency) dựa trên `Bank_tran_id` và `Provider = 'BankSync'`.
    * Tự động liên kết hoặc tạo Ví ảo ngân hàng (`Wallet` Type `'Banking'`, Name $\le 100$ ký tự).
    * Ghi nhận `Transaction` với `Status = 'Pending'`, `Idcategory = NULL`.
    * Đồng bộ cập nhật số dư cho cả `bank_account` và `wallet`.
    * Phát sự kiện nội bộ `bank_transaction.pending` lên EventBus.
* **`GET /api/bank/pending-transactions`:**
  * API dành riêng cho Client-app lấy danh sách toàn bộ giao dịch ngân hàng đang `Pending` (chờ người dùng duyệt).
* **`POST /api/bank/confirm-transaction`:**
  * Payload: `{ idtran, idcategory, note }`.
  * Duyệt giao dịch, gán danh mục `idcategory`, đổi `Status = 'Confirmed'`. Nếu có sự cố backend sẽ tự động đổi `Status = 'Fail'`.
* **`POST /api/bank/reject-transaction`:**
  * Payload: `{ idtran }`.
  * Từ chối giao dịch ngân hàng, đổi `Status = 'Rejected'`.

---

## 4. Module Notification (Thông Báo Realtime Độc Lập)

* Tách biệt hoàn toàn khỏi Module Bank, lắng nghe sự kiện `bank_transaction.pending` qua EventBus.
* Tích hợp **Socket.io Engine**:
  * Client kết nối socket và emit `join_account` kèm `idaccount` để gia nhập phòng riêng `account_${idaccount}`.
  * Backend tự động bắn sự kiện realtime **`bank_transaction.incoming`** và **`notification.new`** trực tiếp xuống điện thoại ngay khi Webhook ngân hàng về.

---

## 5. Module Auth (Xác Thực & Quản Lý Phiên)

* **`POST /api/auth/register/send-otp` & `verify-otp`:**
  * Gửi OTP 6 số qua email (purpose: `'Register'`), xác thực và tạo `Account` (`Type = 'Basic'`, `Status = 'Active'`) kèm `User` (`Country_code`).
* **`POST /api/auth/login`:**
  * Đăng nhập sinh cặp Token (Access Token JWT 15 phút, Refresh Token lưu DB có thời hạn `Expired` và `Status: false`).
* **`POST /api/auth/refresh`:**
  * Làm mới token an toàn, tích hợp **Token Reuse Detection** (thu hồi toàn bộ token của tài khoản nếu phát hiện dùng lại token cũ `Status = true`).
* **`POST /api/auth/logout`:**
  * Thu hồi toàn bộ Refresh Token của tài khoản (`Status = true`).
* **`GET /api/auth/me` & `GET /api/auth/profile`:**
  * Trả về thông tin chi tiết: `idaccount`, `username`, `fullname`, `email`, `phone`, `country_code`, `type`, `status`.

---

## 6. Module Admin (Quản Trị Hệ Thống & Thống Kê)

* **Thống Kê & Dashboard:**
  * `GET /api/admin/totaluser`, `GET /api/admin/totalcategories`, `GET /api/admin/getusertotime`: Thống kê tổng số và tỷ lệ tăng trưởng.
  * `GET /api/admin/login-stats` & `GET /api/admin/request-stats`: Thống kê tần suất đăng nhập và lưu lượng request dựa trên bảng `audit_log`.
* **Quản Lý Người Dùng:**
  * `GET /api/admin/getuser` & `GET /api/admin/getuser/:id`: Lấy danh sách & chi tiết người dùng kèm `type` (`Basic`/`Premium`), `status`, `country_code`.
  * `PATCH /api/admin/updatestatus/:id`: Khóa / mở khóa tài khoản người dùng.
* **Quản Lý Danh Mục Hệ Thống:**
  * `GET /api/admin/getcategory`, `POST /api/admin/addcategory`, `PUT /api/admin/updatecategory/:id`, `DELETE /api/admin/deletecategory/:id`: Quản lý danh mục mặc định (`is_default = true`), hỗ trợ `keyword`, `classify` (`Thu`, `Chi`, `Vay`, `no`) và xóa mềm an toàn.

---

## 7. Trạng Thái Kiểm Thử Backend

* Tất cả các test suite tích hợp đã đạt **100% PASS**:
  * `Test/test_admin_new_schema.js`: PASS 100%
  * `Test/test_bank_full_flow.js`: PASS 100%
  * `Test/test_bank_new_schema.js`: PASS 100%
  * `Test/test_sync_new_schema.js`: PASS 100%
  * `Test/test_auth_new_schema.js`: PASS 100%
  * `Test/test_req_statuses.js`: PASS 12/12 (100%)
