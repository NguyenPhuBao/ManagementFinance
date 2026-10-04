# TỔNG HỢP LUỒNG NGHIỆP VỤ & PHÂN ĐỊNH PHẠM VI MODULE AI (LOGIC BUSINESS AI)

> **Tài liệu nguồn sự thật (Single Source of Truth) cho toàn bộ 10 chức năng thuộc Hệ sinh thái AI**  
> **Cập nhật chính thức:** 2026-09-23 · **Phê duyệt bởi:** Product Owner (PO)  
> **Quy định chiến lược:** Phân định rõ ràng trách nhiệm giữa **Client-app (Mobile)** và **Backend (Server)** nhằm tối đa hóa trải nghiệm người dùng (UX), giảm thiểu độ trễ, và bảo vệ an toàn thông tin & khóa API.

---

## 1. NGUYÊN TẮC THIẾT KẾ & ĐỊNH HƯỚNG CỦA PO

Ban đầu, dự án dự kiến xây dựng phần lớn các chức năng AI tập trung tại Backend. Tuy nhiên, sau khi khảo sát thực tế và đánh giá trải nghiệm người dùng, PO đã đưa ra quyết định chiến lược:

1. **Đưa các chức năng không thuần AI (thuật toán, máy học cục bộ, thống kê, hệ chuyên gia) lên Mobile App (Client-app):**
   - Các phép tính toán này có tốc độ xử lý cực nhanh (dưới 15ms), nếu đưa lên Backend sẽ phát sinh độ trễ truyền tải mạng (network latency 200–500ms), phụ thuộc kết nối Internet và làm giảm trải nghiệm người dùng (UX).
   - Chạy trực tiếp trên thiết bị (Offline-First) giúp ứng dụng phản hồi tức thì, bảo vệ quyền riêng tư dữ liệu cá nhân theo cam kết F1 và Nghị định 13/2023/NĐ-CP.
2. **Backend chỉ giữ lại các chức năng thuần AI và các tác vụ gọi Cloud LLM cần quản lý API Key:**
   - Tuyệt đối **không đưa API Key lên Client Mobile** để tránh nguy cơ rò rỉ token và mất kiểm soát chi phí.
   - Backend đóng vai trò AI Gateway: giữ `GEMINI_API_KEY`, thiết lập chốt chặn lọc dữ liệu nhạy cảm (**PII Masking**), kiểm soát định dạng phản hồi (**Strict Grounding**) và cung cấp năng lực tính toán AI cấp cao (Chatbot, Đánh giá sức khỏe tài chính).
3. **Nguyên tắc bảo tồn 100% mã nguồn Backend làm cơ sở cho Client-app xây dựng:**
   - Đối với các chức năng đưa lên Client-app (như Tầng 1 Keyword Matcher, Tầng 2 NLP Matcher của Phân loại giao dịch, hoặc Bộ khử trùng lặp Deduplication Engine `dedup.service.js`...), **TOÀN BỘ MÃ NGUỒN VÀ DỊCH VỤ HIỆN TẠI VẪN ĐƯỢC GIỮ LẠI NGUYÊN VẸN TRONG BACKEND**.
   - Mục đích: Làm cơ sở nền tảng chuẩn hóa (ground truth) để Client-app đối chiếu thuật toán, kế thừa logic và hỗ trợ kiểm thử liên thông (fallback).
   - **QUY TẮC CỐT LÕI: TUYỆT ĐỐI KHÔNG TỰ Ý XÓA BỎ BẤT KỲ MÃ NGUỒN HAY TÀI LIỆU NÀO ĐÃ LÀM TẠI BACKEND.**

---

## 2. BẢNG TỔNG HỢP 10 CHỨC NĂNG AI — PHÂN CHIA TRÁCH NHIỆM & TRẠNG THÁI

| STT | Tên Chức Năng | Nơi Triển Khai | Bản Chất Kỹ Thuật & Cơ Chế Phối Hợp | Trạng Thái |
|:---:|---|:---:|---|:---:|
| **1** | **Tự Động Phân Loại Giao Dịch**<br>*(Transaction Auto Classification)* | **Client-app** (T1)<br>+<br>**Backend** (T3) | • **Client-app:** Xử lý Tầng 1 (Keyword Matcher qua `CategorySuggestionEngine`) chạy cục bộ trên Drift SQLite v27 để phản hồi tức thì. Tầng 2 không đưa lên client (đo sai 2/3).<br>• **Backend:** Giữ tầng sâu nhất (Tầng 3 - Cloud LLM Gemini Flash Few-Shot Reasoning) sẵn sàng phục vụ khi cần, kèm bộ lọc PII Masking. Phía Client-app hiện phân loại tại chỗ, không bắt buộc gọi API Backend. | 🟢 **T1 chạy ở Client-app** (`CategorySuggestionEngine`)<br>• T2 không đưa lên client<br>• T3 sẵn sàng ở Backend |
| **2** | **Quét Hóa Đơn & Biên Lai**<br>*(Smart Receipt OCR)* | **Client-app** (chụp/xác nhận)<br>+<br>**Backend** (tầng sâu) | • **Client-app:** Chụp ảnh, hiển thị và cho người dùng chỉnh sửa/xác nhận phương án ghi nhận.<br>• **Backend:** Giữ tầng sâu nhất dùng Multimodal LLM (Gemini 3.8 Flash, đọc linh hoạt qua `process.env.GEMINI_MODEL`) để bóc tách các hóa đơn/biên lai chụp lên qua endpoint `POST /api/ai/ocr/parse`. | ⬜ **Client-app chưa làm** (lộ trình bước 6)<br>• Backend đã có `POST /api/ai/ocr/parse` |
| **3** | **Khử Trùng Lặp Giao Dịch**<br>*(Transaction Deduplication Engine)* | **Client-app** (trên máy)<br>+<br>**Backend** (OCR) | • **Client-app:** Gộp trùng từ 3 nguồn dữ liệu giao dịch trên máy: (1) Tin biến động số dư đọc qua `NotificationListenerService` từ danh sách trắng đã đo thực tế: **MB Bank** (`com.mbmobile`), **MoMo** (`com.mservice.momotransfer`), **ZaloPay** (`vn.com.vng.zalopay`) — **không đọc SMS**; (2) **Ảnh biên lai người dùng chủ động chia sẻ** (bóc tách chữ qua Google ML Kit Text Recognition, 100% on-device offline); (3) **Nhắc ghi sau khi dùng app ngân hàng $\ge$ 20s** (quyền `PACKAGE_USAGE_STATS`, WorkManager 15 phút, 100% on-device offline, không gửi dữ liệu ra ngoài, form mở số tiền trống để người dùng tự nhập). Lọc OTP trước khi ghi đĩa; nhắc khi sổ đã có khoản cùng số tiền trong ngày (không chặn). Kênh liên kết ngân hàng (Module Bank) và SMS server đã dừng hoàn toàn, không liên quan đến cơ chế chia sẻ biên lai và nhắc nhở cục bộ.<br>• **Backend:** Giữ `dedup.service.js` cho `POST /api/ai/ocr/parse`. | 🟢 **Đã hoàn thành (Client-app, 2026-09-30, 2026-10-02 & 2026-10-03)**<br>*(Nghiệm thu trên OnePlus 13R & Realme debug + release)*<br>• Backend đã có cho OCR |
| **4** | **Trợ Lý Tài Chính Thông Minh**<br>*(AI Financial Copilot / Chatbot)* | **Backend** (chính)<br>+<br>**Client-app** (offline) | • **Backend:** Trợ lý trực tuyến theo chuẩn [`docs/AI/ChatbotAI.md`](ChatbotAI.md) (Dual-Phase Reasoning with Privacy Shield: Anonymized Snapshot + On-demand Tools + RAG tri thức tĩnh + Redis Token-Bucket Limiter + Snapshot Cache + Circuit Breaker). Không lưu dữ liệu cá nhân vào Vector DB.<br>• **Client-app:** Đã có Trợ lý AI chạy trên máy (Gemma 4 E2B + 9 tool chỉ đọc trên SQLite, dùng được khi mất mạng; xem chức năng 10). | 🟢 **Đã hoàn thành (Backend + Admin-web)**<br>*(Client-app đã có trợ lý offline)* |
| **5** | **Dự Báo Chi Tiêu & Dòng Tiền**<br>*(Cashflow Forecasting)* | **Client-app** (100%) | Đẩy hoàn toàn sang Client-app. Thuật toán dự báo dòng tiền 30 ngày chạy trực tiếp trên máy (`du_bao_dong_tien.dart`), tích hợp dữ liệu hóa đơn (`Bills`) và mục tiêu (`Goals`). | 🟢 **Đã hoàn thành**<br>*(Mã nguồn Client-app đã hoàn tất)* |
| **6** | **Gợi Ý Thiết Lập Ngân Sách Thông Minh**<br>*(Smart Budget Recommendation)* | **Client-app** (100%) | Đẩy hoàn toàn sang Client-app. Tính toán tại chỗ qua hàm `BudgetRepository.suggestAmount` với cửa sổ cuộn linh hoạt $\le 90$ ngày dựa trên lịch sử chi tiêu thực tế. | 🟢 **Đã hoàn thành**<br>*(Đã làm tại Client-app)* |
| **7** | **Đánh Giá Sức Khỏe Tài Chính & Lời Khuyên**<br>*(Financial Health Score & Insights)* | **Backend** (100%) | **Chốt Lối A (Backend tự tính):** Backend tự tính toán *Anonymized Financial Health Snapshot* từ CSDL PostgreSQL sẵn có (scoped `idaccount`), tính điểm FHS và cơ cấu 50/30/20, lưu đệm Redis TTL 120s. Backend phục vụ trực tiếp cho Chatbot AI / báo cáo vĩ mô; Client-app hiện vận hành độc lập, không bắt buộc gọi API FHS. | 🟢 **Đã hoàn thành (Backend + Admin-web)**<br>*(Endpoint /snapshot & /financial-health)* |
| **8** | **Phát Hiện Chi Tiêu Bất Thường**<br>*(Spending Anomaly Detection)* | **Client-app** (100%) | Đẩy hoàn toàn sang Client-app. Phát hiện chi tiêu đột biến thông qua ngưỡng cấu hình người dùng đặt `nguongChiLon` (khoản chi lớn) kết hợp bộ luật cảnh báo tại chỗ (`notification_rules.dart`). | 🟢 **Đã hoàn thành**<br>*(Mã nguồn Client-app đã hoàn tất)* |
| **9** | **Đề Xuất Điều Chỉnh Ngân Sách**<br>*(Budget Rebalancing)* | **Client-app** (100%) | Hệ chuyên gia tính toán Essentiality Score, lựa chọn nguồn bù Donor C1–C7, chạy 100% offline trên SQLite v27 (`tai_phan_bo.dart`, `updateBudget`). | 🟢 **Đã hoàn thành (Client-app)**<br>*(P2 trọn 17 task, thông báo budgetRebalance)* |
| **10**| **AI Edge (Edge AI / On-Device SLM)** | **Client-app** (100%) | Mô hình Gemma 4 E2B (~2.41GB, engine LiteRT-LM qua `flutter_gemma`) chạy trên máy `arm64-v8a` (GPU/CPU canary). Mô hình phục vụ màn Trợ lý AI (offline, gọi 9 tool chỉ đọc). Các khối Nhận xét và đề xuất ngân sách dùng mẫu câu (lối B). Mô hình không huấn luyện trên dữ liệu người dùng. | 🟢 **Đang chạy tại Client-app**<br>*(9 tools chỉ đọc offline, không gửi dữ liệu ra mạng)* |

---

## 3. CHI TIẾT 4 CHỨC NĂNG ĐƯỢC XÂY DỰNG & GIỮ LẠI TẠI BACKEND

### 3.1. Tầng Sâu Nhất Gọi LLM Của Tự Động Phân Loại Giao Dịch (Tier 3 Classifier)
- **Vị trí:** [`src/Backend/modules/ai/features/classify/pipeline/llm.classifier.js`](../../src/Backend/modules/ai/features/classify/pipeline/llm.classifier.js)
- **Vai trò:** Tầng sâu nhất sẵn sàng tại Backend phục vụ khi cần mở rộng (Cloud LLM Gemini Flash Few-Shot Reasoning). Phía Client-app hiện phân loại hoàn toàn tại chỗ qua `CategorySuggestionEngine` trên máy, không bắt buộc gửi lên Backend.
- **Bảo mật & Kiểm duyệt:**
  - Áp dụng bộ lọc `maskTransactionDescription` từ `masking.util.js` (lọc số thẻ tín dụng qua Luhn, mã CVV, mật khẩu; che `[SĐT]`, `[STK]`, `[EMAIL]`) trước khi gửi sang Google Gemini.
  - Sử dụng chiến thuật U-Shape Context và prompt ép kiểu JSON Schema.
  - Thi hành **Strict Grounding**: từ chối tuyệt đối kết quả nếu LLM bịa đặt `category_id` lạ.

### 3.2. Tầng Sâu Nhất Gọi LLM Của Quét Hóa Đơn & Biên Lai (Smart Receipt OCR)
- **Vị trí:** [`src/Backend/modules/ai/features/ocr/ocr.service.js`](../../src/Backend/modules/ai/features/ocr/ocr.service.js)
- **Vai trò:** Nhận ảnh hóa đơn/biên lai từ Mobile app qua endpoint `POST /api/ai/ocr/parse`, gọi mô hình Gemini 3.8 Flash Multimodal (đọc linh hoạt qua `process.env.GEMINI_MODEL`) để bóc tách thông tin phức tạp.
- **Đầu ra:** Trích xuất chi tiết từng mặt hàng (`items`), tổng tiền (`total_amount`), thuế, ngày giờ, đơn vị bán (`merchant`), và tự động sửa sai tổng tiền (self-healing).

### 3.3. Trợ Lý Tài Chính Thông Minh (AI Financial Copilot / Chatbot) — *Xây dựng đợt này*
- **Vị trí:** [`src/Backend/modules/ai/features/chatbot/`](../../src/Backend/modules/ai/features/chatbot/) (Chuẩn kiến trúc: [`docs/AI/ChatbotAI.md`](ChatbotAI.md)).
- **Bản chất:** Chatbot trực tuyến áp dụng kiến trúc **Dual-Phase Reasoning with Privacy Shield**:
  - **Tấm khiên riêng tư (Privacy Shield):** Dữ liệu tài chính cá nhân được tổng hợp thành bản chụp sức khỏe tài chính vĩ mô ẩn danh (*Anonymized Financial Health Snapshot*) trước khi đưa vào ngữ cảnh của LLM. Tuyệt đối không lưu dữ liệu cá nhân vào Vector DB (tuân thủ F1 & Nghị định 13/2023/NĐ-CP).
  - **Standard RAG cho tri thức tài chính tĩnh:** Lập chỉ mục tài liệu kiến thức tài chính chung (thuế TNCN, quy tắc tiết kiệm 50/30/20, mẹo quản lý nợ).

### 3.4. Đánh Giá Sức Khỏe Tài Chính & Đưa Ra Lời Khuyên (Financial Health Score & Insights)
- **Vị trí:** Tích hợp trong Module Chatbot AI & Advisory Backend.
- **Vai trò:** 
  - Backend là trung tâm phân tích: tự động tính điểm sức khỏe tài chính toàn diện (thang điểm 100), đánh giá cơ cấu chi tiêu 50/30/20 từ CSDL PostgreSQL sẵn có (scoped `idaccount`).
  - **Cơ chế:** Chốt Lối A (Backend tự tính từ PostgreSQL). Phục vụ trực tiếp cho Trợ lý AI Backend và API tổng hợp; Client-app hiện vận hành độc lập, không phụ thuộc vào API này để hiển thị.

---

## 4. CHI TIẾT 6 CHỨC NĂNG ĐƯỢC XÂY DỰNG TẠI CLIENT-APP (MOBILE)

1. **Phân Loại Giao Dịch Tầng 1:**
   - Xử lý cục bộ trên SQLite v27 (`CategoryKeywords`, so khớp từ khóa qua `CategorySuggestionEngine`). Phản hồi ngay tức thì khi người dùng gõ ghi chú giao dịch.
2. **Khử Trùng Lặp Giao Dịch (Deduplication):**
   - Client-app đã hoàn thành Deduplication (D1, 2026-09-30 & mở rộng 2026-10-02): gộp trùng tin biến động số dư đọc qua `NotificationListenerService` từ thông báo app (**không đọc SMS** — danh sách trắng thực tế đã đo: MB Bank, MoMo, ZaloPay) cùng **ảnh biên lai do người dùng chủ động chia sẻ** (bóc tách chữ qua Google ML Kit Text Recognition offline hoàn toàn trên thiết bị), nhắc khi sổ đã có khoản cùng số tiền trong ngày (không chặn). Chống quét trùng biên lai đi kèm spec OCR phía Client. Kênh liên kết ngân hàng (Module Bank) và SMS phía server đã dừng hoàn toàn, không liên quan đến việc chia sẻ biên lai cục bộ. Backend giữ `dedup.service.js` cho OCR nội bộ.
3. **Dự Báo Chi Tiêu & Dòng Tiền 30 Ngày:**
   - Đã triển khai tại `features/analytics/domain/du_bao_dong_tien.dart`. Tính toán dòng tiền dự kiến 30 ngày dựa vào các hóa đơn sắp đến hạn (`Bills`) và mục tiêu tích lũy (`Goals`).
4. **Gợi Ý Thiết Lập Ngân Sách Thông Minh:**
   - Đã triển khai tại `BudgetRepository.suggestAmount`. Tự động tính toán mức ngân sách khuyến nghị dựa trên cửa sổ cuộn dữ liệu thực tế $\le 90$ ngày.
5. **Phát Hiện Chi Tiêu Bất Thường:**
   - Đã triển khai thông qua cơ chế cảnh báo khoản chi lớn (`nguongChiLon`) do người dùng cài đặt, phát thông báo tức thời qua `notification_rules.dart`.
6. **Đề Xuất Điều Chỉnh Ngân Sách & On-Device Edge AI:**
   - Thuật toán cân đối thâm hụt (tìm donor cắt giảm ngân sách C1–C7) chạy 100% offline (`tai_phan_bo.dart`, SQLite v27).
   - Mô hình **Gemma 4 E2B** trên máy phục vụ màn Trợ lý AI (gọi 9 tool chỉ đọc trên SQLite cục bộ), hoạt động khi mất mạng, không gửi dữ liệu ra Internet. Các khối nhận xét dùng mẫu câu.

---

## 5. TÀI LIỆU THAM CHIẾU LIÊN QUAN
* Sơ đồ kiến trúc tối giản: [`docs/AI/AI_ARCHITECTURE_DIAGRAM.md`](AI_ARCHITECTURE_DIAGRAM.md).
* Đặc tả phân loại giao dịch Backend: [`docs/AI/Classify.md`](Classify.md).
* Đặc tả bóc tách hóa đơn OCR: [`docs/AI/ORC.md`](ORC.md).
* Đặc tả chuẩn RAG & Chatbot: [`docs/AI/Standard_RAG.md`](Standard_RAG.md).
* Đặc tả Edge AI trên Mobile: [`docs/AI/AI_Edge-SLM.md/Client-app.md`](AI_Edge-SLM.md/Client-app.md).
* Quy tắc bảo mật dữ liệu: [`docs/Rule_Project/Data_Security.md`](../Rule_Project/Data_Security.md).
