# Đề xuất: đọc tin biến động số dư NGAY TRÊN MÁY để điền sẵn form giao dịch — xin backend xem có phù hợp

**Ngày:** 2026-09-25 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat`
**Loại:** xin ý kiến trước khi thiết kế xong. **Không xin đổi mã backend, không migration, không trường đồng bộ mới.**
**Trạng thái phía client:** đang thiết kế (brainstorming); **chưa viết mã**. Client sẽ chờ ý kiến ở mục 4 trước khi
viết spec.

---

## Tệp cần đọc

Mọi đường dẫn tính từ gốc repo, đã kiểm tồn tại ngày 2026-09-25.

**Tài liệu backend để trả lời mục 4:**

| Tệp | Chỗ | Câu hỏi |
|---|---|---|
| `Project.md` | B12 và §8.4 (lý do chính sách dừng Module Bank) | 1 |
| `Project.md` | dòng ~1000 (*"Tạo giao dịch từ SMS — Mobile"*), dòng 2253 (giao dịch từ `SMS` khởi tạo `Pending`) | 1, 2 |
| `docs/AI/Classify.md` | §4.1–4.3, mẫu tin BIDV, MB Bank, Techcombank | 3 |
| `docs/Rule_Project/Data_Security.md` | Nghị định 13/2023 | 4 |
| `docs/AI/LogicBusinessAI.md` | chức năng 3 (khử trùng lặp) | 5 |
| `src/Backend/prisma/schema.prisma` | CHECK của cột `transaction.Provider`, **chỉ khi** câu 2 trả lời "mở `provider`" | 2 |

**Mã client làm bằng chứng (chỉ đọc):**

| Tệp | Chứng minh điều gì |
|---|---|
| `src/Client-app/test/core/sync/sync_payload_contract_test.dart` | payload giao dịch 13 trường, không có `provider` / `bank_tran_id` |
| `src/Client-app/lib/core/database/tables/notification_table.dart` | trung tâm thông báo là bảng cục bộ, không đồng bộ |
| `src/Client-app/lib/features/category/data/services/category_suggestion_engine.dart` | bộ gợi ý danh mục tầng 1 mà form sẽ dùng |

**Đơn liên quan:** `docs/superpowers/backend/CAN-LAM/AI_PHAN_DINH_10_CHUC_NANG_SOAT_C47E6E2.md` mục 4.1 (vì sao client
không gọi `/api/ai/classify/*`) và mục 4.3 (chức năng 3).

---

## 0. Tóm tắt

Người dùng muốn một tính năng mới:

1. App **phát hiện** tin biến động số dư, cả SMS lẫn thông báo của app ngân hàng.
2. App **báo** cho người dùng là có giao dịch.
3. Người dùng chạm vào thì app mở **form Thêm giao dịch đã điền sẵn** thông tin trích từ tin (số tiền, chiều, thời
   gian, nội dung).
4. Người dùng **sửa nếu cần rồi mới bấm Lưu**.

Mọi xử lý chạy **trên máy**, không qua server. Tính năng **không tự tạo giao dịch nào**.

Client đọc thấy `Project.md` đã có sẵn hai chỗ khớp với việc này:

- Bảng chức năng giao dịch (dòng ~1000): *"4 · Tạo giao dịch từ SMS · **Mobile** · User"*.
- §8.4 (quyết định đóng băng ngày 2026-09-21): *"Các luồng tự động hoá tập trung 100% vào OCR Hoá đơn / Biên lai và
  **Nhập liệu qua SMS / Manual**"*.

Phần **SMS** vì vậy nằm trong phạm vi backend đã ghi. Phần **đọc thông báo của app ngân hàng** là mới. Client xin
backend xác nhận nó không đụng lý do chính sách đã khiến Module Bank bị dừng (mục 4, câu hỏi 1).

---

## 1. Khác Module Bank đã dừng ở chỗ nào

| | Module Bank (SePay/Casso), **đã dừng** | Tính năng đề xuất |
|---|---|---|
| Nguồn dữ liệu | API/webhook của bên trung gian, dữ liệu đi qua **server** | thông báo **đã hiện trên chính điện thoại** người dùng |
| Liên kết tài khoản ngân hàng | có (OTP, lưu `bank_account`) | **không**: không đăng nhập, không lưu thông tin ngân hàng nào |
| Ai tạo giao dịch | `bank.worker.js` tự tạo hàng `Pending` | **chỉ người dùng**, bằng nút Lưu của form hiện có |
| Dữ liệu rời máy | có (server ↔ SePay) | **không**. Tin thô nằm trong tệp riêng của app và không đồng bộ; khi người dùng lưu, giao dịch đi đồng bộ **như một giao dịch nhập tay** |
| Nền tảng | mọi nền tảng | **chỉ Android** (iOS không cho app đọc SMS hay thông báo của app khác) |

---

## 2. Cách client định làm (thiết kế đang chốt, để backend đánh giá)

- **Một cơ chế đọc:** `NotificationListenerService` của Android. Tin SMS cũng hiện thành thông báo của app Tin nhắn,
  nên một cơ chế đọc được cả hai nguồn. Chỉ một quyền, *"Truy cập thông báo"*, do người dùng tự bật trong Cài đặt hệ
  thống. **Không** dùng `READ_SMS` / `RECEIVE_SMS`. App phát hành bằng APK, không qua Google Play.
- **Danh sách trắng đứng đầu:** chỉ xét thông báo của 4 app ngân hàng (MB Bank, Vietcombank, Techcombank, BIDV) và các
  app Tin nhắn. Mọi thông báo khác bị bỏ **ngay**, không đọc nội dung, không lưu.
- **Bỏ tin OTP** trước khi ghi đĩa. Chỉ giữ tin có mẫu số tiền kèm dấu ±.
- **Bộ đọc tin** là một hàm Dart thuần. Khuôn trích xuất **dựa trên chính bảng mẫu của backend**, `docs/AI/Classify.md`
  §4.1–4.3 (BIDV, MB Bank, Techcombank). Vietcombank chưa có mẫu, client sẽ thu thêm. Tên trường theo §4.2 để hai phía
  nói cùng một ngôn ngữ.
- **Gộp trùng:** cùng số tiền + cùng chiều + cách nhau ≤ 5 phút, hoặc cùng mã giao dịch, thì chỉ báo một lần. Khi mở
  form, nếu sổ đã có khoản cùng số tiền trong cùng ngày thì hiện dòng nhắc *"có thể bạn đã ghi khoản này"*. Người dùng
  tự quyết, app không chặn.
- **Ví chọn sẵn:** app học "ngân hàng + đuôi số tài khoản → ví" từ lần lưu đầu. Bảng nhớ này **cục bộ**.
- **Danh mục:** bộ gợi ý tầng 1 sẵn có ở client (`CategorySuggestionEngine`) chạy trên ghi chú. **Không** gọi
  `/api/ai/classify/*` (xem đơn `AI_PHAN_DINH_10_CHUC_NANG_SOAT_C47E6E2.md` mục 4.1).
- Tin chưa xử lý nằm trong **trung tâm thông báo** của app (bảng cục bộ `AppNotifications`, loại thứ 20).

---

## 3. Backend KHÔNG phải làm gì. Ba chỗ client cố ý giữ nguyên

1. **`provider` giữ `'Manual'`.** Giao dịch lưu từ form đi đúng đường nhập tay, payload vẫn 13 trường. Hai trường
   `provider` và `bank_tran_id` **không** mở qua đồng bộ (quy ước client từ 2026-09-18). Hệ quả: server **không phân
   biệt** được giao dịch nhập từ SMS với giao dịch nhập tay (xem câu hỏi 2).
2. **Mã giao dịch ngân hàng chỉ dùng cục bộ**, để gộp trùng giữa SMS và thông báo app. Không gửi lên.
3. **Không đụng** module `bank/`, `dedup.service.js`, `bank.worker.js`.

---

## 4. Câu hỏi cho backend

Mỗi câu có sẵn **mặc định của client**. Backend không trả lời thì client làm theo mặc định.

| # | Câu hỏi | Mặc định của client |
|---|---|---|
| **1** | "Lý do chính sách" dừng Module Bank (`Project.md` §8.4, B12: *pháp lý, bảo mật dữ liệu mở ngân hàng Open Banking*) có áp cho việc **đọc thông báo đã hiện trên máy** không? Hay chỉ áp cho việc lấy dữ liệu qua API bên thứ ba? | coi là **không áp**: không có API ngân hàng, không liên kết, dữ liệu không rời máy |
| **2** | Backend có cần phân biệt giao dịch "nhập từ SMS/thông báo" với "nhập tay" không (thống kê, `Project.md` dòng 2253 nói giao dịch từ `SMS` khởi tạo `Pending`)? Nếu cần thì phải mở `provider` qua đồng bộ, và giá trị nào: `'SMS'`, hay thêm giá trị mới cho thông báo app (CHECK của cột phải nhận nó)? | **không mở**; mọi giao dịch lưu từ form là `'Manual'`, `Status` như nhập tay |
| **3** | Bảng mẫu `Classify.md` §4 có còn đúng khuôn tin hiện tại của các ngân hàng không? Backend có mẫu Vietcombank không? | client dùng §4 làm bộ test đầu tiên, đo lại trên máy thật |
| **4** | Nghị định 13/2023: backend có muốn app hiện **màn giải thích + xin đồng ý** riêng trước khi bật quyền "Truy cập thông báo", hay hộp thoại xin quyền của Android là đủ? | có **một màn giải thích** trước khi dẫn người dùng tới Cài đặt: đọc gì, bỏ gì, không gửi đi đâu |
| **5** | Bảng 10 chức năng AI (`LogicBusinessAI.md`, chức năng 3) ghi dedup "theo `bank_tran_id`, SMS" và giao cho client. Tính năng này có phải là thứ backend hình dung cho chức năng 3 không? Nếu phải, backend có muốn đổi ô trạng thái sau khi client làm xong? | coi phần gộp trùng SMS/thông báo này **là** phần client của chức năng 3, và báo lại khi xong |

---

## 5. Phản hồi chính thức từ Backend (Đã phê duyệt 2026-09-26)

Đội ngũ Backend và PO đã xem xét chi tiết toàn bộ đề xuất và đưa ra phản hồi chính thức cho 5 câu hỏi tại Mục 4:

1. **Về chính sách dừng Module Bank (Câu 1):**  
   ✅ **ĐỒNG Ý VỚI CLIENT (Không áp dụng lệnh cấm).**  
   Lý do Module Bank bị dừng là vì rủi ro pháp lý khi lưu trữ thông tin ngân hàng và gọi qua API trung gian (Open Banking, webhook bên thứ 3). Đề xuất của Client đọc thông báo ngay trên máy (`NotificationListenerService`), không kết nối ngân hàng, không gửi dữ liệu ra Internet và do người dùng tự bấm "Lưu" hoàn toàn an toàn và tuân thủ đúng định hướng "Nhập liệu qua SMS / Manual" tại `Project.md` §8.4.
2. **Về cột `provider` và luồng đồng bộ (Câu 2):**  
   ✅ **ĐỒNG Ý GIỮ NGUYÊN `provider = 'Manual'`.**  
   Không cần mở `provider` hay `bank_tran_id` qua sync payload, không đổi schema PostgreSQL. Giao dịch sau khi người dùng xác nhận lưu từ form được ghi nhận chuẩn xác là `'Manual'`.
3. **Về khuôn mẫu tin nhắn `Classify.md` §4 (Câu 3):**  
   ✅ **ĐỒNG THUẬN.**  
   Client lấy bộ quy chuẩn ở `Classify.md` §4 làm baseline suite. Với Vietcombank và các ngân hàng khác, Client chủ động thu thập mẫu thực tế trên thiết bị để bổ sung regex.
4. **Về tuân thủ Nghị định 13/2023/NĐ-CP (Câu 4):**  
   ✅ **BẮT BUỘC MÀN HÌNH MINH BẠCH & XIN ĐỒNG THUẬN (CONSENT SCREEN).**  
   Theo `Data_Security.md`, app bắt buộc hiển thị màn hình giải thích rõ ràng trước khi dẫn người dùng tới Cài đặt quyền truy cập thông báo của Android (nêu rõ: mục đích đọc, danh sách trắng các app ngân hàng, cam kết lọc bỏ tin OTP, lưu cục bộ và không gửi ra ngoài).
5. **Về Chức năng 3 trong bảng 10 chức năng AI (Câu 5):**  
   ✅ **XÁC NHẬN CHÍNH THỨC.**  
   Cơ chế gộp trùng SMS/thông báo app và cảnh báo trùng lặp tại chỗ của Client chính là hiện thân thực tế của Chức năng 3 (Deduplication) phía Client. Khi Client hoàn thành và nghiệm thu, Backend sẽ cập nhật ngay trạng thái Chức năng 3 thành 🟢 Đã hoàn thành (Client-app).

---

## 6. Kết luận & Nghiệm thu
Đề xuất của Client-app được **PHÊ DUYỆT TOÀN DIỆN**. Client-app có thể bắt tay viết spec và tiến hành triển khai theo đúng thiết kế đã nêu.
Tệp này đã hoàn thành vai trò giải đáp và được di chuyển sang `docs/superpowers/backend/DA-XONG/`.
