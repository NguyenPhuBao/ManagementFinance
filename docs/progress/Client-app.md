# Kế Hoạch & Tiến Độ Client-App (Flutter Mobile App)

Tài liệu này tổng hợp toàn bộ các nhiệm vụ, hạng mục kỹ thuật và chức năng mà **Client-app** cần triển khai hoặc điều chỉnh để đồng bộ hoàn toàn với Backend và đặc tả CSDL mới ([New_Database.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/superpowers/backend/New_Database.md)).

---

## 1. Cập Nhật CSDL SQLite Cục Bộ (Drift / Sqflite Models)

Client-app cần cập nhật cấu trúc các bảng SQLite cục bộ trên thiết bị theo CSDL mới:

| Bảng | Các Cột Mới / Điều Chỉnh | Mô Tả & Lưu Ý Nghiệp Vụ |
|---|---|---|
| **`wallet`** | • `name`: `TEXT` (tối đa 100 ký tự)<br>• `type`: `TEXT` (`Cash`, `Bank`, `Saving`, `Banking`)<br>• `id_bank_casso`: `TEXT` NULL | Ví tạo từ liên kết ngân hàng sẽ có `type = 'Banking'` và gắn `id_bank_casso`. |
| **`transaction`** | • `status`: `TEXT` (`Pending`, `Confirmed`, `Rejected`, `Fail`)<br>• `provider`: `TEXT` (`Manual`, `BankSync`, `SMS`, `ORC`, `Bill`)<br>• `date_transaction`: `DATETIME`<br>• `deleted_at`: `DATETIME` NULL | Giao dịch tạo thủ công từ app: gán `status = 'Confirmed'`.<br>Giao dịch kéo từ Casso/SMS/OCR về: `status = 'Pending'`. |
| **`budget`** | • `threshold_warning_amount`: `REAL`<br>• `threshold_warning_percent`: `REAL`<br>• `nexttime_recurrence`: `DATETIME`<br>• *(Bỏ các cột tính toán tĩnh `remaining`, `percent_spent`)* | Cảnh báo ngân sách dựa trên ngưỡng phần trăm hoặc số tiền thực tế. |
| **`bill`** | • `start_date`: `DATETIME`<br>• `due_date`: `DATETIME`<br>• `pay_status`: `TEXT` (`Pending`, `Payed`, `Overdue`)<br>• `time_notification`: `TEXT` | Quản lý hóa đơn định kỳ và trạng thái thanh toán chu kỳ mới. |
| **`goal`** | • `start_date`: `DATETIME`<br>• `cycle_take_money`: `TEXT`<br>• `time_cycle_take_money`: `DATETIME`<br>• `status_complete`: `TEXT` (`'True'`/`'False'`)<br>• `recurrence`: `INTEGER` (Boolean)<br>• `time_recurrence`: `TEXT` | Hỗ trợ chu kỳ tích lũy tiền vào mục tiêu tiết kiệm. |
| **`category`** | • `classify`: `TEXT` (`Thu`, `Chi`, `Vay/nợ` hoặc `Vay/no`)<br>• `keyword`: `TEXT` | Lưu chuỗi từ khóa phân cách dấu `;` để phục vụ bộ so khớp Keyword Matcher khi offline. |

---

## 2. Module Sync — Đồng Bộ Dữ Liệu Offline-First

* **Cập nhật Mapping Entity & Data Transfer Objects (DTO):**
  * Chuẩn hóa tên trường gửi lên trong `POST /api/sync/batch`: `date_transaction`, `idwallet_transfer`, `deleted_at`, `status`.
* **Cơ chế Kéo Dữ Liệu (`Pull Changes`):**
  * Gọi `GET /api/sync/pull?since=last_sync_timestamp` khi khởi động ứng dụng hoặc khi phát hiện có mạng trở lại.
  * Cập nhật SQLite cục bộ theo thuật toán Last-Write-Wins (LWW).
* **Hàng Đợi Đồng Bộ Ngoại Tuyến (`SyncQueue`):**
  * Mọi thao tác thêm/sửa/xóa khi offline đều được ghi vào `SyncQueue` và tự động đẩy lên Backend khi có kết nối Internet.

---

## 3. Module Bank & Quy Trình Duyệt Giao Dịch Ngân Hàng (Bank Inbox UI)

Client-app cần xây dựng các màn hình và luồng giao dịch ngân hàng:

### 3.1. Màn hình Tài khoản Ngân hàng Liên kết
* Gọi `GET /api/bank/accounts` để hiển thị danh sách thẻ ngân hàng, số dư thực tế và trạng thái kết nối (`Active`).
* Hỗ trợ tạo Ví ngân hàng tương ứng.

### 3.2. Màn hình Hộp Thư Giao Dịch Chờ Duyệt (Pending Transactions Inbox)
* Gọi API chuyên biệt: **`GET /api/bank/pending-transactions`**.
* Hiển thị danh sách các giao dịch biến động số dư từ Casso đang ở trạng thái `Pending`:
  * Số tiền ($\pm$), Ngân hàng, Số tài khoản, Thời gian, Nội dung chuyển khoản.
  * Danh mục gợi ý (do AI phân loại sẵn từ Backend hoặc bộ Keyword Matcher).
* **Nút bấm hành động:**
  * **"Duyệt / Xác nhận"** $\rightarrow$ Gọi `POST /api/bank/confirm-transaction` với `{ idtran, idcategory, note }`.
  * **"Từ chối"** $\rightarrow$ Gọi `POST /api/bank/reject-transaction` với `{ idtran }`.

---

## 4. Tích Hợp Realtime Socket.io & Notification Client

* **Khởi tạo kết nối Socket.io Client:**
  * Kết nối tới server Backend qua WebSocket / Polling.
  * Khi người dùng đăng nhập thành công, emit sự kiện:
    ```dart
    socket.emit('join_account', currentUserIdAccount);
    ```
* **Lắng nghe sự kiện Realtime:**
  * Lắng nghe sự kiện **`bank_transaction.incoming`**:
    * Hiển thị In-app Banner / Toast thông báo: *"Bạn vừa có giao dịch mới +500,000đ từ Vietcombank. Nhấn để duyệt!"*.
    * Cập nhật Badge đỏ trên Tab Giao dịch (hiển thị số lượng giao dịch `Pending` chưa duyệt).

---

## 5. Tích Hợp Module AI Phân Loại Giao Dịch (AI Classification Client)

Client-app cần tích hợp các điểm chạm (touchpoints) với Backend Module AI:

### 5.1. Khi Nhập Tay Giao Dịch (Manual Entry)
* Khi người dùng gõ vào ô ghi chú (note) hoặc tên đơn vị bán:
  * Gọi `POST /api/ai/classify/single` kèm `{ text, amount, merchant }`.
  * Tự động chọn sẵn danh mục tốt nhất (`category_id`) và hiển thị chip Top-3 `suggested_categories` để người dùng chọn nhanh chỉ với 1 chạm.

### 5.2. Khi Đọc Tin Nhắn SMS Banking
* Khi ứng dụng nhận tin nhắn SMS biến động số dư:
  * Trích xuất nội dung tin nhắn và gọi `POST /api/ai/classify/single`.
  * Tự động điền danh mục phù hợp trước khi hiển thị dialog xác nhận.

### 5.3. Khi Quét Hóa Đơn Mua Sắm (Receipt OCR)
* Sau khi trích xuất danh sách các món hàng con trong hóa đơn:
  * Gọi `POST /api/ai/classify/batch` với mảng `items: [{ item_id, text, amount }]`.
  * Nhận kết quả phân loại từng món hàng để hiển thị lên bảng chi tiết hóa đơn.

### 5.4. Vòng Lặp Tự Học Cá Nhân Hóa (Feedback Loop)
* Mỗi khi người dùng chủ động chọn lại một danh mục khác so với gợi ý của AI:
  * Client-app tự động gọi ngầm `POST /api/ai/classify/feedback` kèm `{ idcategory, rawText }`.
  * Backend sẽ tự động ghi nhớ từ khóa vào `Category.Keyword` trong DB. Ở các lần giao dịch sau, AI sẽ nhận diện chuẩn xác 100% thói quen của người dùng này!

### 5.5. Bộ So Khớp Ngoại Tuyến (Offline Keyword Matcher - Offline Parity)
* **Khi mất mạng (Offline):**
  * Client-app sử dụng bộ so khớp từ khóa cục bộ chạy trên SQLite (đọc cột `Category.Keyword` của các danh mục).
  * Đảm bảo tính nhất quán (Parity) giữa Online (Backend 3-Tier) và Offline (SQLite Keyword Matcher).

---

## 6. Danh Sách Các Endpoint Backend Client-App Cần Kết Nối

| Module | Method | Endpoint | Mục Đích |
|---|---|---|---|
| **Auth** | `POST` | `/api/auth/register/send-otp` | Gửi mã OTP đăng ký |
| **Auth** | `POST` | `/api/auth/register/verify-otp` | Xác thực OTP & tạo tài khoản |
| **Auth** | `POST` | `/api/auth/login` | Đăng nhập lấy AccessToken + RefreshToken |
| **Auth** | `POST` | `/api/auth/refresh` | Làm mới AccessToken |
| **Auth** | `POST` | `/api/auth/logout` | Đăng xuất |
| **Auth** | `GET` | `/api/auth/me` | Lấy thông tin tài khoản hiện tại |
| **Sync** | `POST` | `/api/sync/batch` | Đẩy hàng loạt thao tác offline lên server |
| **Sync** | `GET` | `/api/sync/pull` | Kéo dữ liệu mới nhất từ server về máy |
| **Sync** | `GET` | `/api/sync/status` | Kiểm tra tổng số lượng bản ghi |
| **Bank** | `GET` | `/api/bank/accounts` | Lấy danh sách tài khoản ngân hàng liên kết |
| **Bank** | `GET` | `/api/bank/pending-transactions` | Lấy danh sách giao dịch ngân hàng chờ duyệt |
| **Bank** | `POST` | `/api/bank/confirm-transaction` | Xác nhận duyệt giao dịch & gán danh mục |
| **Bank** | `POST` | `/api/bank/reject-transaction` | Từ chối giao dịch ngân hàng |
| **AI Classify** | `POST` | `/api/ai/classify/single` | Gợi ý danh mục cho 1 giao dịch (SMS, Nhập tay) |
| **AI Classify** | `POST` | `/api/ai/classify/batch` | Gợi ý danh mục hàng loạt cho các món trong hóa đơn OCR |
| **AI Classify** | `POST` | `/api/ai/classify/feedback` | Ghi nhận phản hồi người dùng để AI tự học |