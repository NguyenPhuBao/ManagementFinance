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

### 5.3. Khi Quét Hóa Đơn Mua Sắm & Biên Lai Chuyển Tiền (Receipt & Transfer OCR)
* Client-app gọi trọn gói API **`POST /api/ai/ocr/parse`** (xem chi tiết mục 6 bên dưới).
* Backend sẽ thực hiện Vision bóc tách $\rightarrow$ Khử trùng lặp CSDL $\rightarrow$ Phân loại 2 cấp độ (Type & Category) $\rightarrow$ Đóng gói sẵn DTO gồm 2 tùy chọn lưu (`option_single` và `option_grouped`).

### 5.4. Vòng Lặp Tự Học Cá Nhân Hóa (Feedback Loop)
* Mỗi khi người dùng chủ động chọn lại một danh mục khác so với gợi ý của AI:
  * Client-app tự động gọi ngầm `POST /api/ai/classify/feedback` kèm `{ idcategory, rawText }`.
  * Backend sẽ tự động ghi nhớ từ khóa vào `Category.Keyword` trong DB. Ở các lần giao dịch sau, AI sẽ nhận diện chuẩn xác 100% thói quen của người dùng này!

### 5.5. Bộ So Khớp Ngoại Tuyến (Offline Keyword Matcher - Offline Parity)
* **Khi mất mạng (Offline):**
  * Client-app sử dụng bộ so khớp từ khóa cục bộ chạy trên SQLite (đọc cột `Category.Keyword` của các danh mục).
  * Đảm bảo tính nhất quán (Parity) giữa Online (Backend 3-Tier) và Offline (SQLite Keyword Matcher).

---

## 6. Quy Trình & Chức Năng Client-App Cần Triển Khai Cho OCR AI (Receipt & Bank Transfer Scanning)

Để khớp hoàn toàn với pipeline bóc tách và phân loại của Backend, Client-app cần triển khai luồng xử lý và giao diện người dùng theo các bước chuẩn hóa sau:

### 6.1. Yêu Cầu Kết Nối Mạng (Online Feature)
* Tính năng Quét Hóa Đơn & Biên Lai sử dụng mô hình Multimodal Vision LLM và bộ khử trùng đối soát đám mây tại Backend, do đó **bắt buộc người dùng phải có kết nối Internet**.
* Khi thiết bị mất mạng: Ứng dụng hiển thị thông báo yêu cầu kết nối mạng để sử dụng tính năng này (không xử lý offline cho tầng OCR).

### 6.2. Luồng Chụp / Chọn Ảnh & Gửi Request Bóc Tách
* Cho phép người dùng chụp ảnh hóa đơn từ Camera hoặc chọn ảnh sẵn có từ Thư viện.
* Nén ảnh tối ưu dung lượng (JPEG chất lượng $80 - 85\%$, kích thước phù hợp) và chuyển đổi sang chuỗi `Base64` (định dạng Data URI `data:image/jpeg;base64,...`).
* Gửi HTTP Request:
  * **Method:** `POST`
  * **Endpoint:** `/api/ai/ocr/parse`
  * **Header:** `Authorization: Bearer <AccessToken>`
  * **Body:** `{ "image": "<base64_string>" }`
* Hiển thị trạng thái Loading / Shimmer trực quan trong thời gian xử lý ($1 - 2$ giây).

### 6.3. Xử Lý Phản Hồi Từ Backend (Response & Error Handling)
Client-app cần bắt các mã HTTP Status Code và hiển thị UI tương ứng:

* **HTTP 200 OK — Bóc tách thành công:**
  * Nhận DTO hoàn chỉnh gồm: `ocr_data`, `type` (`Transaction` hoặc `Transfer`), `type_detection`, `classify_result`, và `options` (`option_single` và `option_grouped`).
  * Điều hướng sang Màn hình xác nhận giao dịch (Review Screen).
* **HTTP 409 Conflict — Phát hiện giao dịch trùng lặp (`TRANSACTION_ALREADY_EXISTS`):**
  * Bắt mã lỗi 409 khi hóa đơn hoặc biên lai đã từng được quét hoặc đã tồn tại trong CSDL.
  * Hiển thị Dialog / BottomSheet cảnh báo màu cam/đỏ:
    * Tiêu đề: *"Giao dịch đã tồn tại!"*.
    * Nội dung chi tiết: Hiển thị thông tin giao dịch trùng từ object `existing_transaction`: Mã giao dịch (`bank_tran_id`), Ngày (`date_transaction`), Số tiền (`amount`), Đơn vị bán (`merchant_name`).
    * Nút hành động: *"Đóng"* hoặc *"Xem lại giao dịch cũ"* (chặn không cho phép lưu trùng).
* **HTTP 422 Unprocessable Entity — Ảnh không hợp lệ / mờ lóa (`OCR_PARSE_FAILED`):**
  * Bắt mã lỗi 422 khi ảnh chụp quá mờ, lóa sáng, mất góc hoặc không chứa chứng từ tài chính.
  * Hiển thị thông báo: *"Không thể nhận diện hóa đơn. Vui lòng chụp lại ảnh rõ nét, đầy đủ thông tin!"*.
* **HTTP 400 / 500 — Lỗi hệ thống:**
  * Hiển thị Toast thông báo sự cố kỹ thuật và cho phép người dùng thử lại.

### 6.4. Màn Hình Xác Nhận Giao Dịch OCR (Review Screen UI/UX)
Màn hình Review cho phép người dùng kiểm tra lại thông tin trước khi chính thức ghi nhận vào ví:

1. **Hiển thị thông tin chung:**
   * Ảnh hóa đơn thu nhỏ (cho phép chạm vào để phóng to xem lại).
   * Tên đơn vị bán / Đối tác chuyển tiền (`merchant_name` / `counterpart_name`).
   * Thời gian giao dịch (`date_transaction`).
   * Chọn Ví thực hiện giao dịch (`wallet_id`).

2. **Nếu là `Transfer` (Chuyển dời tiền nội bộ):**
   * Hiển thị giao diện chuyển ví: Cho phép chọn **Ví nguồn** (`idwallet`) và **Ví đích** (`idwallet_transfer`).
   * Số tiền chuyển: `amount`.
   * **Quy tắc bắt buộc:** Giao dịch Transfer **không có danh mục** thu/chi (`idcategory = null`).

3. **Nếu là `Transaction` (Thu / Chi thông thường):**
   * Cung cấp nút chuyển đổi (Toggle / Segmented Control) giữa 2 phương thức lưu:
     * **Tùy chọn 1: Lưu 1 giao dịch tổng (`option_single`):**
       * Lưu 1 giao dịch duy nhất với tổng số tiền `total_amount`.
       * Danh mục gợi ý mặc định từ `suggested_category.idcategory` (cho phép người dùng đổi sang danh mục khác).
       * Ghi chú tự động điền danh sách các món hàng.
       * Mã giao dịch: `bank_tran_id = base_bank_tran_id` (nếu có), `provider = 'ORC'`.
     * **Tùy chọn 2: Lưu theo nhóm danh mục (`option_grouped`):**
       * Tự động chia thành nhiều giao dịch con theo từng nhóm danh mục đã phân loại (ví dụ: Nhóm Ăn uống, Nhóm Đồ gia dụng...).
       * Cho phép người dùng chỉnh sửa số tiền hoặc gán lại danh mục cho từng nhóm con.
       * **RÀNG BUỘC KỸ THUẬT QUAN TRỌNG:** Mỗi giao dịch con bắt buộc phải dùng chính xác mã `bank_tran_id` đã được Backend sinh sẵn có định dạng `${baseBankTranId}_grp_${idx+1}` (ví dụ: `HD999_grp_1`, `HD999_grp_2`) và `provider = 'ORC'`. Điều này đảm bảo tuân thủ 100% ràng buộc Unique CSDL `@@unique([provider, bank_tran_id])` của PostgreSQL, ngăn chặn triệt để lỗi xung đột khi đồng bộ!

### 6.5. Quy Trình Lưu CSDL SQLite Cục Bộ & Biến Động Số Dư Ví
Client-app hoàn toàn làm chủ việc ghi nhận CSDL theo kiến trúc Offline-First:
1. **Sinh mã giao dịch:** Client tự sinh `Idtran = UUID v4` ngẫu nhiên cho từng giao dịch (hoặc từng giao dịch con).
2. **Thiết lập trạng thái:** Gán `Status = 'Confirmed'`.
3. **Gán nguồn gốc:** Gán `Provider = 'ORC'` (hoặc `'BankSync'` / `'SMS'`).
4. **Cập nhật số dư Ví cục bộ:**
   * Tính toán và cập nhật lại số dư (`balance`) của các Ví liên quan trong bảng `wallet` SQLite (trừ tiền ví chi tiêu, cộng tiền ví nhận).
5. **Ghi giao dịch vào bảng `transaction` SQLite.**

### 6.6. Đồng Bộ Dữ Liệu Lên Backend (Sync Engine)
* Sau khi ghi nhận thành công vào SQLite cục bộ, Client-app đưa các thao tác vào hàng đợi đồng bộ (`SyncQueue`):
  * Thao tác `create` cho các bản ghi `transaction` vừa tạo.
  * Thao tác `update` cho các bản ghi `wallet` bị biến động số dư.
* Gọi `POST /api/sync/batch` để đẩy dữ liệu lên Cloud Backend.
* Backend **không cần Direct API** tạo giao dịch riêng cho OCR, toàn bộ giao dịch được đồng bộ tự nhiên qua Sync Engine chuẩn hóa.

---

## 7. Tích Hợp Realtime Socket.io Client Cho Toàn Ứng Dụng

Client-app duy trì kết nối Socket.io liên tục với Backend để nhận thông báo thời gian thực:

* **Kết nối & Gia nhập phòng cá nhân:**
  ```dart
  socket = IO.io(backendUrl, <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': true,
  });
  // Khi đăng nhập thành công
  socket.emit('join_account', currentUserIdAccount);
  ```

* **Danh sách các sự kiện Realtime cần lắng nghe:**
  | Tên Sự Kiện | Payload Nhận Về | Hành Động Phía Client-App |
  |---|---|---|
  | **`bank_transaction.incoming`** | `{ idaccount, amount, bank_name, description }` | Hiển thị Banner/Push giao dịch ngân hàng mới về, tăng Badge đếm tại Tab Giao dịch chờ duyệt. |
  | **`notification.new`** | `{ idaccount, title, content, type }` | Hiển thị thông báo chung hệ thống / cập nhật chuông thông báo. |
  | **`ocr.completed`** | `{ idaccount, status, total_amount, ... }` | Nhận thông báo tiến trình bóc tách OCR ngầm đã xong $\rightarrow$ Hiển thị thông báo hoàn tất bóc tách. |
  | **`ocr.duplicate`** | `{ idaccount, error, existing_transaction }` | Nhận cảnh báo realtime phát hiện hóa đơn/biên lai đã tồn tại. |

---

## 8. Danh Sách Các Endpoint Backend Client-App Cần Kết Nối

| Module | Method | Endpoint | Mục Đích |
|---|---|---|---|
| **Auth** | `POST` | `/api/auth/register/send-otp` | Gửi mã OTP đăng ký qua email |
| **Auth** | `POST` | `/api/auth/register/verify-otp` | Xác thực OTP & tạo tài khoản |
| **Auth** | `POST` | `/api/auth/login` | Đăng nhập lấy cặp AccessToken + RefreshToken |
| **Auth** | `POST` | `/api/auth/refresh` | Làm mới AccessToken khi hết hạn |
| **Auth** | `POST` | `/api/auth/logout` | Đăng xuất & thu hồi RefreshToken |
| **Auth** | `GET` | `/api/auth/me` | Lấy thông tin tài khoản và người dùng hiện tại |
| **Sync** | `POST` | `/api/sync/batch` | Đẩy hàng loạt thao tác offline (create/update/delete) lên server |
| **Sync** | `GET` | `/api/sync/pull` | Kéo dữ liệu mới nhất từ server về SQLite máy |
| **Sync** | `GET` | `/api/sync/status` | Kiểm tra tổng số lượng bản ghi để đối soát tính toàn vẹn |
| **Bank** | `GET` | `/api/bank/accounts` | Lấy danh sách tài khoản ngân hàng liên kết qua Casso |
| **Bank** | `GET` | `/api/bank/pending-transactions` | Lấy danh sách giao dịch ngân hàng đang `Pending` chờ duyệt |
| **Bank** | `POST` | `/api/bank/confirm-transaction` | Xác nhận duyệt giao dịch ngân hàng & gán danh mục |
| **Bank** | `POST` | `/api/bank/reject-transaction` | Từ chối giao dịch ngân hàng |
| **AI OCR** | `POST` | `/api/ai/ocr/parse` | Bóc tách ảnh hóa đơn/biên lai bằng AI Vision & Phân loại 2 cấp |
| **AI Classify** | `POST` | `/api/ai/classify/single` | Gợi ý danh mục cho 1 giao dịch lẻ (SMS, Nhập tay) |
| **AI Classify** | `POST` | `/api/ai/classify/batch` | Gợi ý danh mục hàng loạt cho các món hàng |
| **AI Classify** | `POST` | `/api/ai/classify/feedback` | Ghi nhận phản hồi người dùng khi đổi danh mục để AI tự học |