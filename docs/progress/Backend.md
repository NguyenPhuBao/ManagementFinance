# Tiến Độ Backend — Các Nội Dung Đã Triển Khai & Kế Hoạch Đồng Bộ Với Client-App

Tài liệu này tổng hợp toàn bộ các tính năng, API, mô hình dữ liệu và cơ chế xử lý Backend đã hoàn thiện từ lúc đổi mới CSDL cho tới hiện tại, đồng thời định rõ các nội dung Backend cần làm để khớp hoàn toàn với **Client-app (Mobile App)**.

---

## 1. Cơ Sở Dữ Liệu & Mô Hình Dữ Liệu Mới (Supabase PostgreSQL)

Backend đã hoàn thành đồng bộ **13 bảng CSDL** theo đặc tả chuẩn [New_Database.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/superpowers/backend/New_Database.md):

* **`Transaction`**:
  * `Status` (`Varchar(10)`): Ràng buộc Check `Status IN ('Pending', 'Confirmed', 'Rejected', 'Fail') - Default 'Confirmed'`.
  * `Provider` (`Varchar(40)`): `Manual` (tạo thủ công), `BankSync` (từ ngân hàng Casso), `SMS`, `ORC` (OCR hình ảnh), `Bill`.
  * `DateTransaction` (`Timestamp`): Thời điểm giao dịch thực tế.
  * `Amount`: Số tiền giữ nguyên dấu $\pm$ (dương = tiền vào, âm = tiền ra).
  * `Deleted_at`: Xóa mềm riêng biệt của bảng giao dịch.
* **`Wallet`**:
  * `Name` (`nvarchar(100)`): Hỗ trợ độ dài tên ví lên đến 100 ký tự (phù hợp ví ngân hàng dài).
  * `Type` (`varchar(7)`): `Cash`, `Bank`, `Saving`, `Banking`.
  * `Id_bank_casso`: Khóa ngoại liên kết với bảng `Bank_account`.
* **`Category`**:
  * `Classify` (`nvarchar(7)`): `Thu`, `Chi`, `Vay/nợ` (hoặc `Vay/no`).
  * `Keyword` (`Text`): Chuỗi từ khóa phân tách bằng dấu `;` phục vụ AI và Keyword Matcher offline.
* **`Budget`**:
  * Bổ sung `Threshold_Warning_Amount`, `Threshold_Warning_Percent`, `Nexttime_recurrence`. Loại bỏ các cột tính toán tĩnh cũ.
* **`Bill`**:
  * Bổ sung `Start_date`, `Due_date`, `Pay_status` (`Pending`, `Payed`, `Overdue`), `Time_notification`.
* **`Goal`**:
  * Bổ sung `Start_date`, `Cycle_take_money`, `Time_cycle_take_money`, `Status_complete` (`'True'/'False'`), `Recurrence`, `Time_recurrence`.

---

## 2. Module Sync (Đồng Bộ Dữ Liệu 2 Chiều Offline-First)

* **`POST /api/sync/push` (Push Operations):**
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
    * **Tự động gọi AI Phân loại giao dịch** để dự đoán `idcategory`.
    * Ghi nhận `Transaction` với `Status = 'Pending'`, `Idcategory = predicted_category_id` (hoặc NULL nếu chưa xác định).
    * Đồng bộ cập nhật số dư cho cả `bank_account` và `wallet`.
    * Phát sự kiện nội bộ `bank_transaction.pending` lên EventBus.
* **`GET /api/bank/pending-transactions`:**
  * API dành riêng cho Client-app lấy danh sách toàn bộ giao dịch ngân hàng đang `Pending` (chờ người dùng duyệt).
* **`POST /api/bank/confirm-transaction`:**
  * Payload: `{ idtran, idcategory, note }`.
  * Duyệt giao dịch, gán danh mục `idcategory`, đổi `Status = 'Confirmed'`.
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
  * Làm mới token an toàn, tích hợp **Token Reuse Detection** (thu hồi toàn bộ token nếu phát hiện dùng lại token cũ `Status = true`).
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
* **Quản Lý Danh Mục Hệ Thống & Ràng Buộc Unique 2 Nhóm:**
  * `GET /api/admin/getcategory`, `POST /api/admin/addcategory`, `PUT /api/admin/updatecategory/:id`, `DELETE /api/admin/deletecategory/:id`: Quản lý danh mục mặc định (`is_default = true`), hỗ trợ `keyword`, `classify` (`Thu`, `Chi`, `Vay/no`) và xóa mềm an toàn.
  * **Ràng buộc Unique Nhóm 1 (`Idaccount & namecategory`)**: 1 tài khoản không được có $> 1$ danh mục trùng tên (áp dụng cho cả Thêm và Sửa).
  * **Ràng buộc Unique Nhóm 2 (`Is_default & namecategory`)**: Không được phép có 2 danh mục hệ thống trùng tên (áp dụng cho cả Thêm và Sửa).
  * **Chuẩn so khớp Case-Insensitive**: Tên danh mục được ép về chữ thường (`.trim().toLowerCase()`) để so khớp với dữ liệu CSDL.
  * **Bảo toàn dữ liệu gốc**: Khi lưu vào CSDL vẫn giữ trọn vẹn đúng định dạng chữ hoa/thường ban đầu người dùng nhập vào (ví dụ: "Ăn Uống").
  * **Cơ chế Sửa thông minh**: Tự động loại trừ chính danh mục đang sửa (`idcategory !== current_id`), cho phép giữ nguyên tên để đổi icon/keyword/classify.
  * **Chuẩn hóa phản hồi lỗi**: Trả về đúng mã **HTTP 400** kèm thông báo lỗi cụ thể khi vi phạm ràng buộc Unique.

---

## 7. Module AI — Chức Năng Phân Loại Giao Dịch (F012 — Hoàn Thành & Tối Ưu Hóa)

* **Chuẩn RAG 4 Giai Đoạn ([docs/AI/Standard_RAG.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/AI/Standard_RAG.md)):**
  * Áp dụng Tiền xử lý Unicode NFC (`cleanVietnameseText`), loại bỏ mã hex/FT ngân hàng, hỗ trợ không dấu (`removeVietnameseTones`).
* **Kiến Trúc Mô Hình Lai 3 Tầng (3-Tier Hybrid):**
  * **Tầng 1 (Keyword Matcher):** So khớp trực tiếp `Category.Keyword` của user ($0 - 5ms$, $\text{Confidence} \ge 0.95$). Chạy đồng bộ cả trên Client SQLite.
    * Tích hợp `counterpart_name` (đối tác chuyển khoản từ Casso như Shopee, Grab, Highlands...) vào chuỗi tìm kiếm chữ thường.
    * Tách từ khóa chuẩn hóa theo dấu phẩy `,` (`rawKw.split(',')`).
  * **Tầng 2 (Local NLP / Similarity):** So khớp độ tương đồng từ vựng N-gram / Jaccard Similarity ($5 - 15ms$, $0$đ) và sinh Top-3 `suggested_categories`. Phân tách từ khóa dấu phẩy thành khoảng trắng để tokenizer chính xác.
  * **Tầng 3 (LLM Gemini Flash):** Kích hoạt khi $\text{Confidence} < 0.60$ với Strict Grounding và xếp hạng danh mục U-Shaped Context Ordering.
* **Chuẩn Hóa Chữ Thường Tại Nguồn Repository ([classify.repository.js](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/modules/ai/features/classify/classify.repository.js)):**
  * Tự động sinh `namecategory_lower` và `keyword_lower` ngay khi truy vấn CSDL lên.
  * Cơ chế tự học `appendCategoryKeyword` chuẩn hóa phân tách và nối lại bằng dấu phẩy `,` không có khoảng trắng (`existingKeywords.join(',')`).
* **Cơ Chế Tự Học Cá Nhân Hóa (Self-Learning Feedback Loop):**
  * Khi người dùng đổi danh mục $\rightarrow$ API `POST /api/ai/classify/feedback` tự động lưu từ khóa mới vào `Category.Keyword` trong DB.
* **Kiến Trúc Phân Loại 2 Cấp Độ (Type & Category):**
  * **Cấp 1 (Loại giao dịch):** Module `typeDetector` phân biệt chính xác giữa `Transaction` (Thu/Chi) và `Transfer` (Chuyển dời tiền nội bộ) dựa trên **3 cơ sở đối soát CSDL** (danh sách món `items`, đối soát tên/STK với profile & ví user, từ khóa nội dung chuyển khoản).
  * **Cấp 2 (Danh mục):** Khi là `Transfer` $\rightarrow$ **HOÀN TOÀN BỎ QUA PHÂN LOẠI DANH MỤC**, trả về `category_id: null` (`Idcategory = NULL` trong CSDL), bảo vệ toàn vẹn dòng tiền không bị trừ ảo vào chi phí và tiết kiệm 100% tài nguyên RAG/LLM. Khi là `Transaction` $\rightarrow$ phân loại danh mục qua bộ 3 Tầng.
* **Các API Endpoints Cung Cấp:**
  * `POST /api/ai/classify/transaction`: Phân loại giao dịch 2 cấp độ (Type & Category).
  * `POST /api/ai/classify/single`: Phân loại danh mục giao dịch đơn lẻ (SMS, Casso, Nhập tay).
  * `POST /api/ai/classify/batch`: Phân loại danh sách mặt hàng (Receipt OCR).
  * `POST /api/ai/classify/feedback`: Ghi nhận phản hồi tự học.

---

## 8. Module AI — Chức Năng Receipt & Bank Transfer OCR (F013 — Hoàn Thành)

* **Tầng Thị Giác Máy Tính (Vision & Extraction Layer):**
  * Sử dụng Google Gemini 2.0 Flash Multimodal REST API (`inlineData` Base64) với Structured JSON Output (tốc độ $1 - 2s$, không phụ thuộc C++ binary nặng nề).
  * Hỗ trợ 3 loại chứng từ: Hóa đơn mua sắm (`RECEIPT`), Biên lai ngân hàng (`BANK_TRANSFER`), Tin nhắn SMS Banking (`SMS_BANKING`).
* **Thuật Toán Tự Phục Hồi Dữ Liệu (Self-Healing Logic):**
  * Tự cộng dồn tổng tiền $\text{total\_amount} = \sum(\text{items.total\_price})$ khi ảnh bị thiếu/khuyết dòng tổng tiền.
  * Tự động fallback ngày giao dịch `new Date()` nếu thiếu.
  * Bắt lỗi HTTP **`422 Unprocessable Entity`** (`OCR_PARSE_FAILED`) khi ảnh mờ, lóa hoặc không chứa thông tin tài chính hợp lệ.
* **Bộ Khử Trùng Lặp Dữ Liệu CSDL (AI Deduplication Engine):**
  * Kiểm tra và đối soát trực tiếp trên bảng CSDL `transaction` của người dùng qua **3 cấp độ quy tắc nghiêm ngặt**:
    * **Quy tắc 1 (Strict Code Match - 100%):** So khớp chính xác `bank_tran_id` hoặc tiền tố `${code}_grp_` (nhận diện các giao dịch con được chia nhóm từ cùng một hóa đơn).
    * **Quy tắc 2 (Fuzzy Invoice Match):** Đối soát hóa đơn mua sắm theo bộ 3: Tên đơn vị bán (`merchant_name`), Tổng tiền (`amount`), và Khoảng thời gian trong ngày ($\pm 24h$).
    * **Quy tắc 3 (Transfer / SMS Matching):** Đối soát giao dịch chuyển tiền/SMS theo số tiền và tài khoản/tên người nhận (`counterpart_name` / `counterpart_account`).
  * **Cơ Chế Chặn Đứng Tức Thì (Early-Exit Interception):** Khi phát hiện trùng lặp, hệ thống lập tức ném lỗi HTTP **`409 Conflict`** (`TRANSACTION_ALREADY_EXISTS`), phát sự kiện realtime `ocr.duplicate` về Client-app và **tuyệt đối không gọi Classify AI**, giúp tiết kiệm 100% chi phí token và thời gian xử lý LLM.
* **Giải Pháp Chống Xung Đột Ràng Buộc Unique CSDL (`_grp_${idx+1}`):**
  * Bảng `transaction` trên Supabase PostgreSQL có ràng buộc `@@unique([provider, bank_tran_id])` để ngăn chặn trùng lặp giao dịch bên thứ ba.
  * Khi người dùng chọn lưu theo nhóm danh mục (`option_grouped`), nếu nhiều giao dịch con cùng mang một mã `bank_tran_id = invoice_no` sẽ gây lỗi vi phạm ràng buộc Unique.
  * **Giải pháp đã triển khai:** Module Classify tự động sinh mã phân nhóm riêng biệt cho từng giao dịch con: `bank_tran_id = ${baseBankTranId}_grp_${idx + 1}` kèm `provider = 'ORC'`, bảo đảm an toàn dữ liệu 100% khi ghi nhận vào CSDL.
* **Tích Hợp Module AI Classify 2 Cấp Độ:**
  * OCR đẩy dữ liệu sang `classifyService.classifyExtractedReceipt`.
  * Khi là `Transfer`: bỏ qua hoàn toàn danh mục (`category_id = null`, `Idcategory = NULL`).
  * Khi là `Transaction`: phân loại danh mục qua bộ 3 Tầng, sinh `option_single` và `option_grouped` gom nhóm theo danh mục nhưng bảo tồn trọn vẹn chi tiết từng món hàng.
* **Phân Định Trách Nhiệm Kiến Trúc (Separation of Concerns & Offline-First):**
  * Backend OCR giữ vai trò Stateless AI Service: Nhận ảnh $\rightarrow$ Self-healing $\rightarrow$ Khử trùng lặp $\rightarrow$ Phân loại 2 cấp $\rightarrow$ Đóng gói DTO $\rightarrow$ Bắn Realtime Notification và trả DTO về Client.
  * Backend OCR **không ghi CSDL giao dịch**, **không can thiệp số dư ví** hay quản lý trạng thái giao dịch tại bước này.
  * Việc xác nhận giao dịch, chọn phương thức lưu (đơn lẻ hay chia nhóm), sinh UUID v4, ghi nhận CSDL SQLite cục bộ (với `status = 'Confirmed'`), cập nhật biến động số dư ví là do **Client-app đảm nhiệm**. Sau đó dữ liệu được đồng bộ an toàn lên Backend qua Sync Engine (`POST /api/sync/push`).
* **Tích Hợp Hệ Thống Thông Báo Realtime (Notification Module):**
  * EventBus publish sự kiện `ocr.completed` và `ocr.duplicate`.
  * Notification Service nhận sự kiện và gọi Socket.io (`emitOcrCompleted`, `emitOcrDuplicate`) gửi thông báo tới phòng riêng `account_<idaccount>` của user trên Client-app.
* **API Endpoints:**
  * `POST /api/ai/ocr/parse`: Tiếp nhận ảnh Base64 và trả về DTO chuẩn hóa (hoặc HTTP 409 khi trùng, 422 khi ảnh mờ).

---

## 9. Các Hạng Mục Backend Cần Làm Tiếp Theo Để Khớp Client-App

Để hỗ trợ đầy đủ các màn hình và chức năng trên **Client-app**, Backend tiếp tục triển khai các tính năng AI bổ trợ:

| STT | Tính Năng Backend Cần Làm | Mô Tả Kỹ Thuật & Mục Đích Phục Vụ Client | Trạng Thái |
|:---:|---|---|:---:|
| 1 | **AI Financial Advice & Insights (F014)** | Phân tích dòng tiền chi tiêu theo tuần/tháng $\rightarrow$ Đưa ra lời khuyên tài chính cá nhân hóa và cảnh báo lạm chi bằng LLM. | `Kế hoạch tiếp theo` |
| 2 | **AI Budget Forecasting (F015)** | Dự báo chi tiêu cho các danh mục trong chu kỳ tới dựa trên dữ liệu lịch sử và thói quen người dùng. | `Chờ triển khai` |
| 3 | **AI Chatbot Assistant (F016)** | Trợ lý tài chính tương tác hỏi đáp về số dư, báo cáo thu chi, tư vấn tiết kiệm thông qua Text & Voice. | `Chờ triển khai` |

---

## 10. Trạng Thái Kiểm Thử Backend (100% PASS)

* Tất cả các test suite tích hợp đã đạt **100% PASS**:
  * `Test/test_ai_dedup_flow.js`: **PASS 10/10 (100%)** - Kiểm thử toàn diện Bộ Khử Trùng Lặp Dữ Liệu 3 cấp độ, kiểm tra tiền tố `_grp_` và Chặn đứng HTTP 409
  * `Test/test_ai_ocr_full_flow.js`: **PASS 18/18 (100%)** - Kiểm thử toàn diện OCR 3 loại chứng từ, Self-Healing, HTTP 422, và Realtime Notification
  * `Test/test_ai_classify_2level.js`: **PASS 23/23 (100%)** - Kiểm thử toàn diện kiến trúc 2 cấp độ và 3 cơ sở đối soát CSDL

  * `Test/test_category_template_rules.js`: **PASS 8/8 (100%)** - Kiểm thử toàn diện Mô hình Template & Cloned, gỡ bỏ trigger chéo, bảo vệ danh mục hệ thống
  * `Test/test_can_lam_fixes.js`: **PASS 10/10 (100%)** - Toàn bộ 11 bản vá theo CAN-LAM

---

## 11. Hoàn Thiện Nghiệp Vụ Danh Mục Mẫu & Admin-web (2026-09-07)

* **Chuyển đổi Mô hình Template & Cloned cho Danh mục:**
  * Toàn bộ danh mục mặc định hệ thống (`is_default = true`) đóng vai trò là bộ khung mẫu (Template) do Admin quản lý.
  * Khi người dùng đăng ký mới: Client-app gọi API `GET /api/sync/default-categories` để lấy template, tự sinh danh mục cá nhân (`is_default = false`, `create_by = idaccount`) lưu vào SQLite và đồng bộ lên Backend qua `POST /api/sync/push`.
  * Gỡ bỏ Trigger kiểm tra chéo `trg_category_name_cross_default`: Cho phép người dùng sở hữu danh mục trùng tên với danh mục mẫu hệ thống.
  * Tái xác nhận 2 Partial Unique Indexes chuẩn hóa NFC & case-insensitive:
    * `uq_category_owner_name`: `(Create_by, lower(...))` khi `Is_default = FALSE AND Delete_at IS NULL`.
    * `uq_category_default_name`: `(lower(...))` khi `Is_default = TRUE AND Delete_at IS NULL`.
* **Bảo vệ Danh mục Hệ thống:**
  * Cấm xóa: `admin.service.deleteCategory` trả về HTTP 400 Bad Request nếu `category.is_default === true`.
  * Cấm chuyển đổi: Không cho phép chuyển đổi danh mục người dùng thành danh mục hệ thống kể cả với quyền Admin (`admin.service.updateCategory` trả về HTTP 400).
* **Chuẩn Hóa Admin-web & FinanceAdmin:**
  * Đồng bộ nhận diện thương hiệu `FinanceAdmin`.
  * Bổ sung tiện ích `normalizeCategoryName` và `normalizeVietnameseUnaccent`.
  * Vô hiệu hóa nút xóa danh mục hệ thống trên giao diện Admin-web.
  * Quản lý kết nối Socket.io tập trung qua `useSocket.js`.

---

## 5. Cập Nhật Ngày 2026-09-07 — Nghiệp Vụ Quản Lý Người Dùng, Xóa Mềm & Ràng Buộc Đăng Ký

### 5.1. Chức năng Xóa Mềm Người Dùng (Soft Delete User)
* **API Endpoints:**
  * `DELETE /api/admin/deleteuser/:id`
  * `DELETE /api/admin/users/:id` (RESTful alias)
  * Yêu cầu xác thực Admin: `authenticate` + `authorize('admin')`.
  * Kiểm tra an toàn: Chặn không cho xóa tài khoản Quản trị viên (`idrole === 1`).
* **Quy trình Transaction 5 bước (`adminRepository.softDeleteUser`):**
  1. `account`: `status = 'Deleted'`, `delete_at = now()`, `update_at = now()`.
  2. `user`: `delete_at = now()`, `update_at = now()`.
  3. `wallet`: Toàn bộ ví của tài khoản chuyển sang `status = 'Inactive'`, `update_at = now()`.
  4. `bank_account`: Dữ liệu ngân hàng không bị xóa; ngắt kết nối `connect_status = 'Disconnected'`, `update_at = now()`.
  5. `refreshtoken`: Thu hồi toàn bộ refresh token (`status = true`), `update_at = now()`.
* **Cơ chế Cưỡng chế Đăng xuất (Force Logout 24/24):**
  * Xóa cache xác thực bộ nhớ: `invalidateAccountCache(idaccount)`.
  * Kênh Socket.io: Phát sự kiện `account.force_logout` tới phòng cá nhân `account_${idaccount}` và ngắt kết nối socket của client ngay lập tức.
  * Kênh HTTP Fallback (khi offline có internet lại):
    * `isAccountValid` kiểm tra trạng thái tài khoản và `delete_at`.
    * Middleware `authenticate` trả về HTTP 401 với mã lỗi `{ code: 'ACCOUNT_DELETED' }` để Client-app nhận diện và xử lý đăng xuất.
    * Socket handshake từ chối kèm mã `ACCOUNT_DELETED`.

### 5.2. Điều Chỉnh Ràng Buộc CSDL & Quy Tắc Đăng Ký Mới
* **Migration 7 (`database/7_Update_Account_User_Delete_Rules.sql`):**
  * `account_Email_key` & `user_Email_key`: Chuyển sang Partial Unique Index `WHERE ("Delete_at" IS NULL)` $\rightarrow$ Cho phép người dùng đăng ký tài khoản mới bằng email và số điện thoại trùng với tài khoản cũ đã bị xóa mềm.
  * `account_Username_key`: Chuyển từ UNIQUE đơn lẻ sang regular index `idx_account_username` $\rightarrow$ Cho phép nhiều tài khoản cùng Username nếu khác Password.
  * `wallet.Status`: Mở rộng từ `VARCHAR(7)` lên `VARCHAR(20)` để lưu trữ chuẩn xác giá trị `'Inactive'` (8 ký tự).
* **Kiểm Soát Cặp `(Username + Password)` tại Service:**
  * Thêm `authService.validateUsernamePasswordPair(username, password)` sử dụng `bcrypt.compare` đối chiếu với tất cả tài khoản có cùng username trong hệ thống.
  * Cấm trùng đồng thời cả `Username + Password`. Cho phép nếu trùng Username nhưng khác Password, hoặc trùng Password nhưng khác Username.
  * `authService.login`: Duyệt danh sách các tài khoản có cùng username, so khớp mật khẩu bằng `bcrypt.compare` để tìm đúng tài khoản người dùng, sau đó kiểm tra trạng thái xóa mềm / vô hiệu hóa.

### 5.3. Kiểm Thử Tự Động (TDD)
* Bộ test `Test/test_user_soft_delete_and_auth_rules.js`:
  * `TEST 1`: Xóa mềm account, user, ví inactive, bank disconnected, tokens revoked, cache invalid $\rightarrow$ **PASS**.
  * `TEST 2`: Tạo lại tài khoản mới với email & sđt trùng của tài khoản đã xóa mềm $\rightarrow$ **PASS**.
  * `TEST 3`: Ràng buộc cặp (Username + Password) cả 3 case: trùng cả 2 (chặn), trùng username khác pass (cho phép), khác username trùng pass (cho phép) $\rightarrow$ **PASS**.
  * `TEST 4`: Đăng nhập vào tài khoản đã xóa mềm bị từ chối với mã 403 $\rightarrow$ **PASS**.
  * **Kết quả: 4/4 bài kiểm thử đạt 100% PASS.**




