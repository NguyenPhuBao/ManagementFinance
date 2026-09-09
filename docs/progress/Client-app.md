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
  * Chuẩn hóa tên trường gửi lên trong `POST /api/sync/push`: `date_transaction`, `idwallet_transfer`, `deleted_at`, `status`.
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

Để khớp hoàn toàn với quy trình và kiến trúc của Backend, Client-app cần triển khai luồng xử lý và giao diện người dùng theo cả 2 chế độ **Online (Có Internet)** và **Offline (Ngoại tuyến)**:

### 6.1. Hai Luồng Xử Lý: Online vs. Offline (Kiến Trúc Đa Nền Tảng)

#### Luồng 1: Có Kết Nối Internet (Online — Sử Dụng Backend AI Pipeline)
1. Người dùng chụp ảnh hóa đơn/biên lai từ Camera hoặc chọn từ Thư viện.
2. Nén ảnh JPEG $80 - 85\%$ $\rightarrow$ Convert chuỗi `Base64` (Data URI `data:image/jpeg;base64,...`).
3. Gửi HTTP Request tới `POST /api/ai/ocr/parse` với Bearer Token.
4. Backend kích hoạt Gemini 2.0 Flash Multimodal Vision $\rightarrow$ Tự phục hồi dữ liệu $\rightarrow$ Khử trùng lặp CSDL (nếu trùng trả HTTP 409) $\rightarrow$ Classify 2 cấp độ $\rightarrow$ Gom nhóm DTO và trả về HTTP 200 kèm Socket `ocr.completed`.
5. Client-app nhận DTO và điều hướng sang **Màn hình xác nhận giao dịch (Review Screen)**.

#### Luồng 2: Không Có Kết Nối Internet (Offline — Client-App Xử Lý Cục Bộ)
1. Khi thiết bị ngoại tuyến (không có mạng Internet), Client-app tự động kích hoạt luồng Offline.
2. **On-Device OCR:** Gọi thư viện nhận diện văn bản cục bộ trên máy (Google ML Kit Text Recognition / Tesseract) để đọc chữ từ ảnh.
3. **Local Deduplication:** Truy vấn SQLite kiểm tra nhanh xem mã hóa đơn hoặc (ngày + số tiền) đã tồn tại trong bảng `transaction` cục bộ hay chưa để cảnh báo người dùng.
4. **Offline Keyword Matcher:** Dùng bộ so khớp từ khóa đọc từ cột `Category.Keyword` của các danh mục trong SQLite để gợi ý danh mục cho từng món và giao dịch tổng.
5. Gom nhóm các món có cùng danh mục lại với nhau tương tự như cấu trúc `option_grouped`.
6. Hiển thị **Màn hình xác nhận giao dịch (Review Screen)** để người dùng kiểm tra và chỉnh sửa.

> [!TIP]
> **Lưu ý chất lượng bóc tách giữa Online và Offline:**
> - **Online (Backend Gemini LLM):** Có khả năng hiểu ngữ cảnh sâu, tự nhận diện bảng giá, tự cộng dồn khi thiếu tổng tiền và độ chính xác cực cao.
> - **Offline (Client On-device OCR):** Nhận diện ký tự quang học thô, độ chính xác danh sách món phụ thuộc chất lượng camera. Do đó, giao diện Review khi Offline cần hỗ trợ người dùng chỉnh sửa tên món, số tiền và chọn lại danh mục linh hoạt.

---

### 6.2. Xử Lý Các Kịch Bản Chuyển Đổi Trạng Thái Mạng Đột Ngột
* **Kịch bản 1: Đang chạy luồng Offline mà có mạng bất ngờ:**
  * **Quy tắc:** **Vẫn mặc định tiếp tục hoàn thành theo luồng Offline**.
  * **Mục đích:** Bảo toàn tính nhất quán trạng thái (State Consistency) của ứng dụng, tránh làm gián đoạn màn hình nhập liệu và gây hoang mang cho người dùng.
* **Kịch bản 2: Đang chạy luồng Online mà bị mất mạng đột ngột:**
  * Khi Client-app đang chờ phản hồi từ Backend mà kết nối bị đứt (Timeout / `SocketException`):
  * Client-app bắt ngoại lệ mạng, hiển thị thông báo: *"Mất kết nối Internet trong lúc quét hóa đơn. Vui lòng kiểm tra lại mạng!"* và **dừng quy trình tạo giao dịch**.
  * **Tuyệt đối không ghi nhận dữ liệu dở dang vào SQLite**, số dư ví vẫn nguyên vẹn 100%.
  * Phía Backend: Request vẫn xử lý xong trong tiến trình bộ nhớ RAM, khi socket đứt thì kết thúc bình thường và Garbage Collector giải phóng RAM, không hề ghi CSDL.
  * **Lợi ích:** Khi người dùng có mạng trở lại và bấm quét lại cùng bức ảnh đó, do chưa có dữ liệu nào trong CSDL nên bộ Deduplication Engine của Backend sẽ **không bị chặn nhầm**, giao dịch được bóc tách bình thường!

---

### 6.3. Xử Lý Phản Hồi Từ Backend (Response & Error Handling khi Online)
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

---

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
       * **RÀNG BUỘC KỸ THUẬT QUAN TRỌNG:** Mỗi giao dịch con bắt buộc phải dùng chính xác mã `bank_tran_id` đã được sinh sẵn có định dạng `${baseBankTranId}_grp_${idx+1}` (ví dụ: `HD999_grp_1`, `HD999_grp_2`) và `provider = 'ORC'`. Điều này đảm bảo tuân thủ 100% ràng buộc Unique CSDL `@@unique([provider, bank_tran_id])` của PostgreSQL, ngăn chặn triệt để lỗi xung đột khi đồng bộ!

---

### 6.5. Quy Trình Lưu CSDL SQLite Cục Bộ & Biến Động Số Dư Ví
Client-app hoàn toàn làm chủ việc ghi nhận CSDL theo kiến trúc Offline-First:
1. **Sinh mã giao dịch:** Client tự sinh `Idtran = UUID v4` ngẫu nhiên cho từng giao dịch (hoặc từng giao dịch con).
2. **Thiết lập trạng thái:** Gán `Status = 'Confirmed'`.
3. **Gán nguồn gốc:** Gán `Provider = 'ORC'` (hoặc `'BankSync'` / `'SMS'`).
4. **Cập nhật số dư Ví cục bộ:**
   * Tính toán và cập nhật lại số dư (`balance`) của các Ví liên quan trong bảng `wallet` SQLite (trừ tiền ví chi tiêu, cộng tiền ví nhận).
5. **Ghi giao dịch vào bảng `transaction` SQLite.**

---

### 6.6. Đồng Bộ Dữ Liệu Lên Backend (Sync Engine)
* Sau khi ghi nhận thành công vào SQLite cục bộ, Client-app đưa các thao tác vào hàng đợi đồng bộ (`SyncQueue`):
  * Thao tác `create` cho các bản ghi `transaction` vừa tạo.
  * Thao tác `update` cho các bản ghi `wallet` bị biến động số dư.
* Gọi `POST /api/sync/push` để đẩy dữ liệu lên Cloud Backend (khi có kết nối Internet).
* Backend **không cần Direct API** tạo giao dịch riêng cho OCR, toàn bộ giao dịch được đồng bộ tự nhiên qua Sync Engine chuẩn hóa.

## 7. Khởi Tạo Danh Mục Khi Đăng Ký Tài Khoản Mới (Template & Cloned Model)

Theo quyết định nghiệp vụ đã thống nhất của PO:
* **Nguyên tắc:** Danh mục mặc định hệ thống (`is_default = true`) chỉ đóng vai trò là Template mẫu. Backend **không** tự động sinh danh mục cho người dùng khi gọi API đăng ký.
* **Quy trình thực hiện tại Client-app:**
  1. Sau khi người dùng xác thực OTP và đăng ký tài khoản thành công (`/api/auth/register/verify-otp`) hoặc đăng nhập lần đầu chưa có danh mục:
  2. Client-app gọi API **`GET /api/sync/default-categories`** để nhận danh sách toàn bộ danh mục mẫu đang hoạt động của hệ thống.
  3. Client-app sinh một bộ danh mục cá nhân tương ứng:
     - `create_by = currentUserIdAccount`
     - `is_default = false`
     - `idcategory`: UUID v4 do Client-app tự sinh
     - Giữ nguyên `name_category`, `classify`, `icon`, `keyword` từ template.
  4. Lưu toàn bộ danh mục này vào bảng `category` trong CSDL SQLite cục bộ (Client-app không lưu danh mục hệ thống vào bảng này).
  5. Đẩy bộ danh mục cá nhân này lên Backend qua cơ chế **`POST /api/sync/push`** (với `operation: 'create'`).
  6. Từ thời điểm này, bộ danh mục thuộc sở hữu cá nhân độc lập của tài khoản, người dùng có thể tự do thêm/sửa/xóa hoặc đổi tên mà không ảnh hưởng tới hệ thống mẫu.

---

## 8. Tích Hợp Realtime Socket.io Client Cho Toàn Ứng Dụng

Client-app duy trì kết nối Socket.io liên tục với Backend để nhận thông báo thời gian thực:

* **Kết nối bảo mật qua JWT Handshake Token (Không dùng `join_account`):**
  ```dart
  socket = IO.io(backendUrl, <String, dynamic>{
    'transports': ['websocket', 'polling'],
    'autoConnect': true,
    'auth': {
      'token': accessToken, // Token JWT hợp lệ từ auth.service
    },
  });
  // Socket.io middleware trên Backend sẽ tự động xác thực token và đưa socket
  // vào room riêng 'account_${idaccount}' an toàn tuyệt đối.
  ```

* **Danh sách các sự kiện Realtime cần lắng nghe:**
  | Tên Sự Kiện | Payload Nhận Về | Hành Động Phía Client-App |
  |---|---|---|
  | **`bank_transaction.incoming`** | `{ idaccount, amount, bank_name, description }` | Hiển thị Banner/Push giao dịch ngân hàng mới về, tăng Badge đếm tại Tab Giao dịch chờ duyệt. |
  | **`notification.new`** | `{ idaccount, title, content, type }` | Hiển thị thông báo chung hệ thống / cập nhật chuông thông báo. |
  | **`ocr.completed`** | `{ idaccount, status, total_amount, ... }` | Nhận thông báo tiến trình bóc tách OCR ngầm đã xong $\rightarrow$ Hiển thị thông báo hoàn tất bóc tách. |
  | **`ocr.duplicate`** | `{ idaccount, error, existing_transaction }` | Nhận cảnh báo realtime phát hiện hóa đơn/biên lai đã tồn tại. |

---

## 9. Danh Sách Các Endpoint Backend Client-App Cần Kết Nối

| Module | Method | Endpoint | Mục Đích |
|---|---|---|---|
| **Auth** | `POST` | `/api/auth/register/send-otp` | Gửi mã OTP đăng ký qua email |
| **Auth** | `POST` | `/api/auth/register/verify-otp` | Xác thực OTP & tạo tài khoản |
| **Auth** | `POST` | `/api/auth/login` | Đăng nhập lấy cặp AccessToken + RefreshToken |
| **Auth** | `POST` | `/api/auth/refresh` | Làm mới AccessToken khi hết hạn |
| **Auth** | `POST` | `/api/auth/logout` | Đăng xuất & thu hồi RefreshToken |
| **Auth** | `GET` | `/api/auth/me` | Lấy thông tin tài khoản và người dùng hiện tại |
| **Sync** | `GET` | `/api/sync/default-categories` | Lấy danh sách danh mục mẫu mặc định để nhân bản cho user mới đăng ký |
| **Sync** | `POST` | `/api/sync/push` | Đẩy hàng loạt thao tác offline (create/update/delete) lên server |
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

---

## 10. Hướng Dẫn Triển Khai: Cơ Chế Nhận Diện Internet & Xử Lý Cưỡng Chế Đăng Xuất (Force Logout)

Để đáp ứng đầy đủ yêu cầu nghiệp vụ quản lý tài khoản từ Backend (khi tài khoản bị Admin xóa mềm hoặc vô hiệu hóa), **Client-app** cần triển khai cơ chế nhận diện mạng và xử lý cưỡng chế đăng xuất theo đặc tả sau:

### 10.1. Cơ chế Nhận Diện Kết Nối Mỗi Khi Có Internet
* Sử dụng `ConnectionMonitor` (kết hợp `connectivity_plus: ^6.1.1`):
  * Lắng nghe luồng `Connectivity().onConnectivityChanged`.
  * Khi trạng thái mạng chuyển từ offline sang online (`results.any((r) => r != ConnectivityResult.none)`):
    1. Tự động kích hoạt kết nối lại kênh **Socket.IO Client**.
    2. Gửi request kiểm tra phiên / đồng bộ dữ liệu (`GET /api/auth/me` hoặc `GET /api/sync/pull`).

### 10.2. Lắng Nghe Sự Kiện Socket Real-Time (`account.force_logout`)
* Khi Socket.IO kết nối và tham gia phòng cá nhân, đăng ký lắng nghe sự kiện:
  ```dart
  socket.on('account.force_logout', (data) {
    // data: { 'idaccount': 28, 'reason': 'ACCOUNT_DELETED', 'message': '...' }
    final int? targetIdAccount = data['idaccount'] as int?;
    
    // BẮT BUỘC: Kiểm tra đúng ID tài khoản đang đăng nhập trên thiết bị
    // Tránh đăng xuất nhầm hoặc ảnh hưởng tới các tài khoản khác
    if (targetIdAccount != null && targetIdAccount == currentUserIdAccount) {
      _executeForceLogout(data['message'] ?? 'Tài khoản của bạn đã bị ngừng hoạt động.');
    }
  });
  ```

### 10.3. Xử Lý Mã Lỗi `ACCOUNT_DELETED` trong Dio Interceptor (`auth_interceptor.dart`)
* Trong `onError` của Dio:
  * Khi nhận phản hồi HTTP `401 Unauthorized` từ bất kỳ request nào:
    * Kiểm tra payload phản hồi:
      ```dart
      if (err.response?.statusCode == 401) {
        final resData = err.response?.data;
        if (resData is Map && resData['code'] == 'ACCOUNT_DELETED') {
          // Bỏ qua thử làm mới token (không gọi /auth/refresh)
          _executeForceLogout(resData['message'] ?? 'Tài khoản của bạn đã bị xóa hoặc ngưng hoạt động.');
          return;
        }
      }
      ```

### 10.4. Luồng Thực Thi Cưỡng Chế Đăng Xuất (`_executeForceLogout`)
1. **Xóa dữ liệu bảo mật cục bộ**:
   * Xóa sạch các khóa lưu trữ trong `FlutterSecureStorage`:
     ```dart
     await secureStorage.delete(key: AppConstants.accessTokenKey);
     await secureStorage.delete(key: AppConstants.refreshTokenKey);
     ```
2. **Cập nhật State Management**:
   * Phát sự kiện đăng xuất vào `AuthBloc`: `context.read<AuthBloc>().add(AuthLoggedOut())`.
   * Chuyển trạng thái ứng dụng về `Unauthenticated`.
3. **Điều hướng & Giao diện người dùng**:
   * Sử dụng `go_router` điều hướng cưỡng chế về màn hình Đăng nhập (`/login`).
   * Hiển thị thông báo dạng `Dialog` hoặc `SnackBar` cảnh báo:
     > *"Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi Quản trị viên. Bạn không thể tiếp tục truy cập vào hệ thống."*
4. **Ngăn chặn đăng nhập lại**:
   * Khi người dùng cố gắng đăng nhập lại với thông tin cũ, Backend sẽ từ chối với mã HTTP 403 Forbidden (*"Tài khoản đã bị xóa khỏi hệ thống"*).

---

## 11. Xử Lý Cơ Chế Vô Hiệu Hóa Tài Khoản Kèm Lý Do (`ACCOUNT_INACTIVE` & `Reason_Inactive`)

Thành viên phụ trách **Client-app** cần triển khai các hạng mục sau để hoàn tất đồng bộ với Backend:

### 11.1. Cập Nhật CSDL SQLite Cục Bộ (Drift / Sqflite)
* Bổ sung cột `reason_inactive`: `TEXT` NULL vào bảng lưu trữ tài khoản / thông tin người dùng (`account_table` hoặc `user_table`).
* Lưu trữ lý do vô hiệu hóa khi nhận từ API login, profile hoặc qua sự kiện Socket/HTTP 401.

### 11.2. Lắng Nghe Sự Kiện Socket.IO Real-Time (`account.force_logout`)
* Khi nhận sự kiện `account.force_logout`:
  ```dart
  socket.on('account.force_logout', (data) {
    final int? targetIdAccount = data['idaccount'] as int?;
    final String? code = data['reason'] as String?;
    final String message = data['message'] ?? 'Tài khoản của bạn đã bị vô hiệu hóa.';
    
    if (targetIdAccount != null && targetIdAccount == currentUserIdAccount) {
      if (code == 'ACCOUNT_INACTIVE') {
        // Hiển thị Dialog thông báo tài khoản bị vô hiệu hóa kèm lý do cụ thể
        _showInactivationDialog(message);
      }
      _executeForceLogout(message);
    }
  });
  ```

### 11.3. Bắt Mã Lỗi `ACCOUNT_INACTIVE` Trong Dio Interceptor (`auth_interceptor.dart`)
* Trong hàm `onError`:
  * Khi API trả về HTTP `401 Unauthorized` với mã `{ code: 'ACCOUNT_INACTIVE' }`:
    * Bỏ qua cơ chế thử làm mới token (`/auth/refresh`).
    * Trích xuất `reason_inactive = resData['reason_inactive']`.
    * Hiển thị thông báo dạng `AlertDialog`:
      > *"Tài khoản của bạn đã bị quản trị viên vô hiệu hóa.*  
      > *Lý do: [reason_inactive]"*
    * Gọi `_executeForceLogout` xóa sạch token trong `FlutterSecureStorage` và điều hướng về màn hình Đăng nhập.

### 11.4. Màn Hình Đăng Nhập (`/login`)
* Khi đăng nhập thất bại với HTTP 403 Forbidden:
  * Trích xuất thông điệp từ response (`resData['message']`).
  * Nếu tài khoản bị vô hiệu hóa, thông điệp từ Backend sẽ có dạng:  
    `"Tài khoản đã bị vô hiệu hóa. Lý do: <Lý do cụ thể>"`
  * Hiển thị trực quan thông điệp này trên form đăng nhập để người dùng hiểu rõ nguyên nhân.

---

## 12. Hướng Dẫn Triển Khai Cơ Chế Chờ Xóa Tài Khoản (PendingDelete) & Đếm Ngược 30 Ngày

Thành viên phụ trách **Client-app** cần triển khai các hạng mục sau để hoàn tất luồng người dùng yêu cầu xóa tài khoản:

### 12.1. Cập Nhật CSDL SQLite Cục Bộ
* Bổ sung cột `countdown`: `INTEGER` NULL vào bảng lưu trữ tài khoản người dùng (`account_table`).
* Mặc định là `NULL` khi tài khoản `Active` hoặc `Deleted`.
* Giá trị là số nguyên (`30, 29, ..., 1`) khi tài khoản ở trạng thái `PendingDelete`.

### 12.2. Giao Diện Yêu Cầu Xóa Tài Khoản (Màn hình Cài đặt)
* **Vị trí**: `SettingsScreen` $\rightarrow$ "Xóa tài khoản".
* **Luồng xử lý**:
  1. Hiển thị Dialog cảnh báo nghiêm ngặt:
     > *"Bạn có chắc chắn muốn yêu cầu xóa tài khoản? Tài khoản của bạn sẽ có 30 ngày ân hạn để khôi phục. Sau 30 ngày, tài khoản cùng toàn bộ ví và dữ liệu liên kết sẽ bị xóa vĩnh viễn."*
  2. Yêu cầu người dùng nhập lại mật khẩu hiện tại để xác thực.
  3. Gửi request HTTP:
     * **Method**: `DELETE /api/auth/account`
     * **Headers**: `Authorization: Bearer <access_token>`
     * **Body**: `{"password": "<mật khẩu người dùng>"}`
  4. Phản hồi thành công từ Backend:
     ```json
     {
       "success": true,
       "data": {
         "idaccount": 123,
         "status": "PendingDelete",
         "countdown": 30,
         "scheduled_delete_at": "2026-10-09T..."
       },
       "message": "Tài khoản của bạn đã được chuyển sang trạng thái chờ xóa trong 30 ngày."
     }
     ```
  5. Cập nhật state tài khoản cục bộ sang `PendingDelete` kèm `countdown = 30`.

### 12.3. Trải Nghiệm Tiếp Tục Sử Dụng & Banner Cảnh Báo
* **Cho phép dùng tiếp**: Trong suốt 30 ngày, người dùng **vẫn được phép đăng nhập và sử dụng toàn bộ tính năng của app bình thường** (thêm giao dịch, quản lý ví, đồng bộ sync).
* **Banner cảnh báo**: Khi `status == 'PendingDelete'`, hiển thị một Banner cảnh báo nổi bật ở đầu `HomeScreen` hoặc `DashboardScreen`:
  > *"⚠️ Tài khoản của bạn đang trong thời gian chờ xóa. Còn **[countdown]** ngày nữa tài khoản sẽ bị xóa vĩnh viễn.*  
  > *[Nút: Tiếp tục dùng / Hủy xóa]"*

### 12.4. Tính Năng Kích Hoạt Lại Tài Khoản (Hủy Xóa)
* Khi người dùng đổi ý và nhấn vào nút **"Kích hoạt lại"** trên Banner hoặc trong mục Cài đặt:
  1. Gửi request HTTP:
     * **Method**: `POST /api/auth/cancel-delete`
     * **Headers**: `Authorization: Bearer <access_token>`
     * **Body**: `{}`
  2. Phản hồi thành công từ Backend:
     ```json
     {
       "success": true,
       "data": {
         "idaccount": 123,
         "status": "Active",
         "countdown": null
       },
       "message": "Yêu cầu xóa tài khoản đã được hủy thành công, tài khoản đã được kích hoạt lại."
     }
     ```
  3. Cập nhật state cục bộ sang `Active`, xóa `countdown = null` và ẩn Banner cảnh báo.

### 12.5. Xử Lý Khi Hết Hạn 30 Ngày (Countdown Chạm 0)
* **Thời điểm**: Vào lúc **00:00:00 theo múi giờ Việt Nam (UTC+7)** mỗi ngày, Scheduler của Backend sẽ tự động giảm `countdown`. Khi countdown về 0, server tự động thực thi xóa mềm toàn diện và gửi Socket `account.force_logout` (`reason: 'ACCOUNT_DELETED'`).
* **Trách nhiệm của Client-app**:
  1. Khi nhận được Socket `account.force_logout` hoặc khi mở app nhận lỗi HTTP 401 `{ code: 'ACCOUNT_DELETED' }`:
     * Đánh dấu toàn bộ ví cục bộ sang `Inactive`.
     * Đánh dấu ngân hàng cục bộ sang `Disconnected`.
     * Xóa sạch token trong `FlutterSecureStorage`.
     * Điều hướng ngay về màn hình Đăng nhập.
     * Hiển thị thông báo: *"Tài khoản của bạn đã hết thời hạn 30 ngày chờ xóa và đã được xóa khỏi hệ thống."*