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
| **1** | **Tự Động Phân Loại Giao Dịch**<br>*(Transaction Auto Classification)* | **Client-app** (T1)<br>+<br>**Backend** (T3) | • **Client-app:** Xử lý Tầng 1 (Keyword Matcher qua `CategorySuggestionEngine`) chạy cục bộ trên Drift SQLite v24 để phản hồi tức thì. Tầng 2 không đưa lên client (đo sai 2/3).<br>• **Backend:** Giữ tầng sâu nhất (Tầng 3 - Cloud LLM Gemini Flash Few-Shot Reasoning). Mobile app chỉ gọi lên Backend khi gặp ca khó, kèm bộ lọc PII Masking. | 🟢 **T1 chạy ở Client-app** (`CategorySuggestionEngine`)<br>• T2 không đưa lên client<br>• T3 có ở Backend, Client chưa gọi |
| **2** | **Quét Hóa Đơn & Biên Lai**<br>*(Smart Receipt OCR)* | **Client-app** (chụp/xác nhận)<br>+<br>**Backend** (tầng sâu) | • **Client-app:** Chụp ảnh, hiển thị và cho người dùng chỉnh sửa/xác nhận phương án ghi nhận.<br>• **Backend:** Giữ tầng sâu nhất dùng Multimodal LLM (Gemini 2.0 Flash) để bóc tách các hóa đơn/biên lai chụp lên qua endpoint `POST /api/ai/ocr/parse`. | ⬜ **Client-app chưa làm** (lộ trình bước 6)<br>• Backend đã có `POST /api/ai/ocr/parse` |
| **3** | **Khử Trùng Lặp Giao Dịch**<br>*(Transaction Deduplication Engine)* | **Client-app** (khi có OCR) | Khử trùng lặp trên client chỉ cần khi và nếu client làm OCR (chống quét 2 lần 1 hóa đơn). Kênh ngân hàng và SMS đã dừng/bỏ. Backend giữ mã dedup phục vụ OCR nội bộ. | ⬜ **Chưa làm tại Client**<br>*(Sẽ đặc tả cùng spec OCR Client sau này)* |
| **4** | **Trợ Lý Tài Chính Thông Minh**<br>*(AI Financial Copilot / Chatbot)* | **Backend** (chính)<br>+<br>**Client-app** (offline) | • **Backend:** Trợ lý trực tuyến theo chuẩn [`docs/AI/ChatbotAI.md`](ChatbotAI.md) (Dual-Phase Reasoning with Privacy Shield: Anonymized Snapshot + On-demand Tools + RAG tri thức tĩnh). Không lưu dữ liệu cá nhân vào Vector DB.<br>• **Client-app:** Đã có Trợ lý AI chạy trên máy (Gemma 4 E2B + 7 tool chỉ đọc trên SQLite, dùng được khi mất mạng; xem chức năng 10). | 🟡 **Đang xây dựng tại Backend** theo `ChatbotAI.md`<br>*(Client-app đã có trợ lý offline)* |
| **5** | **Dự Báo Chi Tiêu & Dòng Tiền**<br>*(Cashflow Forecasting)* | **Client-app** (100%) | Đẩy hoàn toàn sang Client-app. Thuật toán dự báo dòng tiền 30 ngày chạy trực tiếp trên máy (`du_bao_dong_tien.dart`), tích hợp dữ liệu hóa đơn (`Bills`) và mục tiêu (`Goals`). | 🟢 **Đã hoàn thành**<br>*(Mã nguồn Client-app đã hoàn tất)* |
| **6** | **Gợi Ý Thiết Lập Ngân Sách Thông Minh**<br>*(Smart Budget Recommendation)* | **Client-app** (100%) | Đẩy hoàn toàn sang Client-app. Tính toán tại chỗ qua hàm `BudgetRepository.suggestAmount` với cửa sổ cuộn linh hoạt $\le 90$ ngày dựa trên lịch sử chi tiêu thực tế. | 🟢 **Đã hoàn thành**<br>*(Đã làm tại Client-app)* |
| **7** | **Đánh Giá Sức Khỏe Tài Chính & Lời Khuyên**<br>*(Financial Health Score & Insights)* | **Backend** (100%) | **Chốt Lối A (Backend tự tính):** Backend tự tính toán *Anonymized Financial Health Snapshot* từ CSDL PostgreSQL sẵn có (scoped `idaccount`), tính điểm FHS và cơ cấu 50/30/20. Client-app chỉ gọi API hiển thị hoặc tích hợp trong Chatbot AI, không bắt client đóng gói gửi định kỳ. | 🟡 **Đang xây dựng tại Backend** theo `ChatbotAI.md` |
| **8** | **Phát Hiện Chi Tiêu Bất Thường**<br>*(Spending Anomaly Detection)* | **Client-app** (100%) | Đẩy hoàn toàn sang Client-app. Phát hiện chi tiêu đột biến thông qua ngưỡng cấu hình người dùng đặt `nguongChiLon` (khoản chi lớn) kết hợp bộ luật cảnh báo tại chỗ (`notification_rules.dart`). | 🟢 **Đã hoàn thành**<br>*(Mã nguồn Client-app đã hoàn tất)* |
| **9** | **Đề Xuất Điều Chỉnh Ngân Sách**<br>*(Budget Rebalancing)* | **Client-app** (100%) | Hệ chuyên gia tính toán Essentiality Score, lựa chọn nguồn bù Donor C1–C7, chạy 100% offline trên SQLite v24 (`tai_phan_bo.dart`, `updateBudget`). | 🟢 **Đã hoàn thành (Client-app)**<br>*(P2 trọn 17 task, thông báo budgetRebalance)* |
| **10**| **AI Edge (Edge AI / On-Device SLM)** | **Client-app** (100%) | Mô hình Gemma 4 E2B (~2.41GB, engine LiteRT-LM qua `flutter_gemma`) chạy trên máy `arm64-v8a` (GPU/CPU canary). Mô hình phục vụ màn Trợ lý AI (offline, gọi tool chỉ đọc). Các khối Nhận xét và đề xuất ngân sách dùng mẫu câu (lối B). Mô hình không huấn luyện trên dữ liệu người dùng. | 🟢 **Đang chạy tại Client-app**<br>*(7 tools chỉ đọc offline, không gửi dữ liệu ra mạng)* |

---

## 3. CHI TIẾT 4 CHỨC NĂNG ĐƯỢC XÂY DỰNG & GIỮ LẠI TẠI BACKEND

### 3.1. Tầng Sâu Nhất Gọi LLM Của Tự Động Phân Loại Giao Dịch (Tier 3 Classifier)
- **Vị trí:** [`src/Backend/modules/ai/features/classify/pipeline/llm.classifier.js`](../../src/Backend/modules/ai/features/classify/pipeline/llm.classifier.js)
- **Vai trò:** Khi Tầng 1 (Keyword) và Tầng 2 (NLP) tại Client-app không đạt độ tự tin ($\text{Confidence} < 0.60$), Mobile app mới gửi yêu cầu lên Backend.
- **Bảo mật & Kiểm duyệt:**
  - Áp dụng bộ lọc `maskTransactionDescription` từ `masking.util.js` (lọc số thẻ tín dụng qua Luhn, mã CVV, mật khẩu; che `[SĐT]`, `[STK]`, `[EMAIL]`) trước khi gửi sang Google Gemini.
  - Sử dụng chiến thuật U-Shape Context và prompt ép kiểu JSON Schema.
  - Thi hành **Strict Grounding**: từ chối tuyệt đối kết quả nếu LLM bịa đặt `category_id` lạ.

### 3.2. Tầng Sâu Nhất Gọi LLM Của Quét Hóa Đơn & Biên Lai (Smart Receipt OCR)
- **Vị trí:** [`src/Backend/modules/ai/features/ocr/ocr.service.js`](../../src/Backend/modules/ai/features/ocr/ocr.service.js)
- **Vai trò:** Nhận ảnh hóa đơn/biên lai từ Mobile app qua endpoint `POST /api/ai/ocr/parse`, gọi mô hình Gemini 2.0 Flash Multimodal để bóc tách thông tin phức tạp.
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
  - **Cơ chế:** Chốt Lối A (Backend tự tính). Client-app gọi API lấy kết quả hiển thị hoặc nhận lời khuyên thông qua Chatbot AI.

---

## 4. CHI TIẾT 6 CHỨC NĂNG ĐƯỢC XÂY DỰNG TẠI CLIENT-APP (MOBILE)

1. **Phân Loại Giao Dịch Tầng 1:**
   - Xử lý cục bộ trên SQLite v24 (`CategoryKeywords`, so khớp từ khóa qua `CategorySuggestionEngine`). Phản hồi ngay tức thì khi người dùng gõ ghi chú giao dịch.
2. **Khử Trùng Lặp Giao Dịch (Deduplication):**
   - Phía Client chỉ cần khi triển khai tính năng OCR. Kênh liên kết ngân hàng và SMS server đã dừng.
3. **Dự Báo Chi Tiêu & Dòng Tiền 30 Ngày:**
   - Đã triển khai tại `features/analytics/domain/du_bao_dong_tien.dart`. Tính toán dòng tiền dự kiến 30 ngày dựa vào các hóa đơn sắp đến hạn (`Bills`) và mục tiêu tích lũy (`Goals`).
4. **Gợi Ý Thiết Lập Ngân Sách Thông Minh:**
   - Đã triển khai tại `BudgetRepository.suggestAmount`. Tự động tính toán mức ngân sách khuyến nghị dựa trên cửa sổ cuộn dữ liệu thực tế $\le 90$ ngày.
5. **Phát Hiện Chi Tiêu Bất Thường:**
   - Đã triển khai thông qua cơ chế cảnh báo khoản chi lớn (`nguongChiLon`) do người dùng cài đặt, phát thông báo tức thời qua `notification_rules.dart`.
6. **Đề Xuất Điều Chỉnh Ngân Sách & On-Device Edge AI:**
   - Thuật toán cân đối thâm hụt (tìm donor cắt giảm ngân sách C1–C7) chạy 100% offline (`tai_phan_bo.dart`).
   - Mô hình **Gemma 4 E2B** trên máy phục vụ màn Trợ lý AI (gọi 7 tool chỉ đọc trên SQLite cục bộ), hoạt động khi mất mạng, không gửi dữ liệu ra Internet. Các khối nhận xét dùng mẫu câu.

---

## 5. TÀI LIỆU THAM CHIẾU LIÊN QUAN
* Sơ đồ kiến trúc tối giản: [`docs/AI/AI_ARCHITECTURE_DIAGRAM.md`](AI_ARCHITECTURE_DIAGRAM.md).
* Đặc tả phân loại giao dịch Backend: [`docs/AI/Classify.md`](Classify.md).
* Đặc tả bóc tách hóa đơn OCR: [`docs/AI/ORC.md`](ORC.md).
* Đặc tả chuẩn RAG & Chatbot: [`docs/AI/Standard_RAG.md`](Standard_RAG.md).
* Đặc tả Edge AI trên Mobile: [`docs/AI/AI_Edge-SLM.md/Client-app.md`](AI_Edge-SLM.md/Client-app.md).
* Quy tắc bảo mật dữ liệu: [`docs/Rule_Project/Data_Security.md`](../Rule_Project/Data_Security.md).
