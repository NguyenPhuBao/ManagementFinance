# THIẾT KẾ KIẾN TRÚC CHỨC NĂNG CHATBOT AI (FINANCIAL COPILOT) — BACKEND MODULE AI

> **Tài liệu đặc tả kiến trúc kỹ thuật (Technical Architecture Design Spec)**  
> **Ngày lập:** 2026-09-25 · **Cập nhật:** 2026-09-26 · **Phiên bản:** 2.0.0 (Phê duyệt Giải pháp 3)  
> **Vai trò đảm nhiệm:** Kỹ sư Fullstack Cao Cấp + AI Engineer + Senior BA  
> **Căn cứ nguồn sự thật:** [`docs/AI/Standard_RAG.md`](./Standard_RAG.md), [`docs/Rule_Project/Data_Security.md`](../Rule_Project/Data_Security.md), [`docs/AI/LogicBusinessAI.md`](./LogicBusinessAI.md), [`Project.md`](../../Project.md).

---

## 1. PHÂN TÍCH NGHIỆP VỤ & RANH GIỚI HỆ THỐNG (SENIOR BA)

### 1.1. Mục Tiêu & Đối Tượng Sử Dụng
- **Mục tiêu:** Cung cấp một Trợ lý Tài chính Thông minh (AI Financial Copilot) tại Backend, đóng vai trò như một **Chuyên gia Hoạch định Tài chính Cá nhân Cấp cao (CFP - Certified Financial Planner)** hoạt động 24/7. Trợ lý có khả năng:
  1. Trò chuyện tự nhiên, tiếp nhận mọi câu hỏi mở, tâm sự tài chính, các tình huống giả định ("Nếu tôi mua nhà...", "Tôi vừa có khoản thưởng 20 triệu thì nên làm gì?").
  2. Vận dụng tư duy suy luận đa chiều (Deep Reasoning & Critical Thinking) để phân tích hành vi chi tiêu, phát hiện điểm bất hợp lý và đưa ra lời khuyên tài chính chiến lược mang tính cá nhân hóa cao.
  3. Cung cấp tri thức tài chính, giải thích luật thuế TNCN, quy tắc phân bổ ngân sách chuẩn (50/30/20, 6 chiếc lọ).
- **Đối tượng sử dụng:**
  - Người dùng Mobile App (Client-app) khi có kết nối mạng trực tuyến.
  - Quản trị viên / Người dùng trên Admin Web.

### 1.2. Phân Định Ranh Giới Dữ Liệu & Ràng Buộc Pháp Lý Bắt Buộc
Tuân thủ tuyệt đối **Nghị định 13/2023/NĐ-CP** và nguyên tắc **F1** (`Data_Security.md`):
- **TUYỆT ĐỐI KHÔNG index dữ liệu cá nhân của người dùng vào Vector Database.** Không nhúng lịch sử giao dịch, số dư, ghi chú ví của User vào các bảng embedding tập trung trên server.
- **Nguyên tắc "Tấm Khiên Riêng Tư" (Privacy Shield):** AI bên ngoài (Google Gemini) **không thể và không được phép** nhìn thấy dữ liệu định danh cá nhân (PII) thô (họ tên, số tài khoản, số điện thoại, tên tiệm cụ thể, nội dung chuyển khoản nhạy cảm).
- **Tổng hợp & Ẩn danh hóa 100% trước khi đưa vào AI:** Dữ liệu tài chính cá nhân được Backend xử lý, gom nhóm theo danh mục, tính toán tỷ lệ % và ẩn danh hóa (Anonymized & Aggregated) trước khi đưa vào ngữ cảnh suy luận của LLM.
- **Dữ liệu lập chỉ mục Vector Database (RAG):** **CHỈ LƯU TRỮ TRI THỨC TÀI CHÍNH TĨNH / CHUNG** (Luật thuế TNCN, mẹo tiết kiệm, kiến thức đầu tư cơ bản, quy tắc tài chính).

---

## 2. QUÁ TRÌNH TIẾN HÓA KIẾN TRÚC & PHÂN TÍCH ĐÁNH ĐỔI (TRADEOFF ANALYSIS)

Để tìm ra kiến trúc tối ưu nhất phục vụ cho báo cáo và triển khai thực tế, hệ thống đã trải qua quá trình nghiên cứu, phản biện và so sánh giữa 4 mô hình kiến trúc:

```
                           【CÂU HỎI MỞ CỦA NGƯỜI DÙNG】
                           (Bất kỳ câu hỏi, tâm sự, giả định)
                                         │
     ┌───────────────────┬───────────────┴───────────────┬───────────────────┐
     ▼                   ▼                               ▼                   ▼
【KIẾN TRÚC CŨ】   【GIẢI PHÁP 1】                【GIẢI PHÁP 2】        【GIẢI PHÁP 3 (DUYỆT)】
 Intent Router     Autonomous Agent              Financial Snapshot     Dual-Phase Reasoning
 (Cây quyết định)  (ReAct Dynamic Loop)          (Zero-Shot Context)    with Privacy Shield
```

### 2.1. Kiến Trúc Cũ (Baseline — Intent Router Pattern)
- **Cơ chế hoạt động:**
  - Request đi vào Backend $\rightarrow$ Chạy qua một bộ `Fast Intent Router` (sử dụng regex/keyword hoặc LLM nhỏ) để ép câu hỏi vào 1 trong 4 nhóm cố định: *Smalltalk*, *Personal Data*, *Knowledge*, hoặc *Hybrid Advice*.
  - Tùy theo nhóm, hệ thống rẽ nhánh cứng sang Tool CSDL hoặc RAG tri thức tĩnh.
- **Ưu điểm:**
  - Cấu trúc rẽ nhánh rõ ràng, dễ viết code ban đầu.
  - Tốc độ phản hồi các câu chào hỏi đơn giản rất nhanh ($< 100\text{ms}$).
- **Nhược điểm chí mạng (Lý do bị bác bỏ):**
  - **Bóp nghẹt năng lực suy luận của AI:** Ép người dùng vào "cây quyết định tự động (IVR)". Khi người dùng đặt câu hỏi mở, đa chiều (*"Tháng này tôi thấy áp lực tiền bạc quá, bạn xem giùm tôi có thể cắt giảm khoản nào được không?"*), Router không thể phân loại chính xác, dẫn đến câu trả lời máy móc, rời rạc và thiếu tính đồng cảm của một chuyên gia tài chính.

### 2.2. Giải Pháp 1: Autonomous Reasoning Agent (Pure ReAct Pattern)
- **Cơ chế hoạt động:**
  - Bỏ hoàn toàn Router. Câu hỏi mở của người dùng được gửi thẳng tới Gemini 2.0 Flash.
  - LLM sử dụng vòng lặp **ReAct (Reasoning + Acting)**: Tự suy nghĩ (*Thought*) $\rightarrow$ Tự quyết định gọi Tool (*Action*) $\rightarrow$ Backend query CSDL nội bộ và trả về kết quả đã ẩn danh (*Observation*) $\rightarrow$ LLM tiếp tục suy luận cho đến khi hoàn tất câu trả lời.
- **Ưu điểm:**
  - AI hoàn toàn tự do tiếp nhận mọi câu hỏi bất kỳ như ChatGPT Web.
  - Khả năng xử lý các yêu cầu phức tạp nhiều bước.
- **Nhược điểm:**
  - **Độ trễ cao (High Latency):** Phải qua 2 - 3 vòng lặp round-trip mạng giữa Backend và Google LLM, khiến thời gian xuất hiện chữ đầu tiên (**TTFT**) lên tới $2.5\text{s} - 4.5\text{s}$, làm giảm trải nghiệm người dùng trên Mobile.
  - **Tốn kém chi phí Token & Nguy cơ lặp vô tận (Loop):** Nếu LLM gọi nhiều tool liên tiếp sẽ gây hao tốn token và dễ nghẽn hạn ngạch API.

### 2.3. Giải Pháp 2: Anonymized Financial Health Snapshot (Zero-Shot Context Injection)
- **Cơ chế hoạt động:**
  - Mô phỏng cách làm việc của Bác sĩ Tài chính: Mỗi khi bắt đầu phiên trò chuyện, Backend tự động tổng hợp sẵn một **Bản chụp sức khỏe tài chính ẩn danh (Financial Health Snapshot)** gồm các chỉ số vĩ mô (tỷ lệ 50/30/20, top danh mục ngốn tiền, hóa đơn sắp tới, điểm sức khỏe tài chính).
  - Snapshot ẩn danh này được nạp sẵn vào System Context của LLM cùng với câu hỏi của người dùng.
- **Ưu điểm:**
  - **Tốc độ phản hồi siêu nhanh (TTFT $< 600\text{ms}$):** Gemini stream câu trả lời về ngay lập tức mà không cần chờ gọi Tool.
  - LLM có cái nhìn toàn cảnh bức tranh tài chính nên đưa ra lời khuyên rất bao quát.
- **Nhược điểm:**
  - **Thiếu khả năng đào sâu chi tiết (Drill-down limitation):** Nếu người dùng hỏi một giao dịch rất cụ thể trong quá khứ (*"Cho tôi xem 3 lần tôi đi ăn lẩu đắt nhất tháng trước"*), Snapshot vĩ mô không chứa dữ liệu chi tiết này để trả lời.

### 2.4. Bảng Ma Trận So Sánh Toàn Diện Các Phương Án

| Tiêu Chí Đánh Giá | Kiến Trúc Cũ (Intent Router) | Giải Pháp 1 (Pure ReAct Agent) | Giải Pháp 2 (Snapshot Only) | **Giải Pháp 3 (Dual-Phase Shield) — ĐÃ DUYỆT** |
|---|:---:|:---:|:---:|:---:|
| **Độ tự do của câu hỏi** | ❌ Bị gò bó theo 4 nhóm | ✅ Tự do tuyệt đối | ✅ Tự do tuyệt đối | 🌟 **Tự do tuyệt đối (như ChatGPT web)** |
| **Năng lực suy luận & Khuyên tài chính** | ⚠️ Rất hạn chế (Rời rạc) | ✅ Khá cao (Tự gọi tool) | ✅ Rất cao (Thấy toàn cảnh) | 🌟 **Đỉnh cao (Toàn cảnh + Đào sâu đa chiều)** |
| **Bảo mật dữ liệu (Data_Security)** | ✅ Tuân thủ F1 | ✅ Tuân thủ F1 | ✅ Ẩn danh 100% | 🌟 **Tấm khiên Ẩn danh & Tổng hợp 100%** |
| **Thời gian phản hồi đầu tiên (TTFT)** | ⚠️ 1.5s - 3s | ❌ Chậm (2.5s - 4.5s) | ⚡ Siêu nhanh (< 600ms) | ⚡ **Siêu nhanh (< 800ms qua SSE Stream)** |
| **Chi phí Token & Tải hệ thống** | Thấp | ❌ Rất cao (Nhiều vòng lặp) | Rất thấp | **Tối ưu (80% câu hỏi không tốn round-trip)** |
| **Khả năng đào sâu giao dịch chi tiết** | Có (nếu khớp tool) | Rất tốt | ❌ Không thể | 🌟 **Xuất sắc (Kích hoạt tool on-demand)** |

### 2.5. Lý Do Lựa Chọn Giải Pháp 3 (Architectural Decision Rationale)
> **Quyết định của PO & Kỹ sư trưởng:** Phê duyệt **Giải pháp 3 (Dual-Phase Reasoning with Privacy Shield)** vì đây là phương án **kết hợp hoàn hảo nhất (Best of Both Worlds)**:
> 1. **Giải phóng 100% năng lực suy luận:** Người dùng hỏi bất kỳ câu hỏi nào, AI đóng vai trò Cố vấn Tài chính CFP với tư duy phản biện sắc sảo.
> 2. **Phản hồi tức thì (Low Latency):** Nhờ có sẵn *Anonymized Financial Health Snapshot*, hơn **80% câu hỏi** được LLM suy luận và stream trả lời ngay lập tức qua SSE ($< 800\text{ms}$).
> 3. **Linh hoạt đào sâu khi cần:** Với **20% câu hỏi** yêu cầu chi tiết lịch sử, LLM tự động kích hoạt *On-demand Tool* để truy vấn sâu hơn.
> 4. **Bảo mật tuyệt đối (100% Privacy Compliance):** Toàn bộ dữ liệu người dùng đều đi qua bộ lọc tổng hợp và ẩn danh của Backend trước khi chạm vào LLM.

---

## 3. THIẾT KẾ CHI TIẾT GIẢI PHÁP 3: DUAL-PHASE REASONING WITH PRIVACY SHIELD

### 3.1. Sơ Đồ Kiến Trúc Hệ Thống (Mermaid tương thích Draw.io)

```mermaid
flowchart TD
    %% TẦNG 1: GIAO DIỆN CLIENT
    subgraph CLIENT ["1. CLIENT LAYER (Trò chuyện tự do không giới hạn)"]
        UI["Mobile App & Web Admin<br/>Hỏi bất kỳ: tâm sự, giả định, phân tích"]
        SSE["SSE Consumer (Streaming UI)<br/>Hiển thị chữ chạy theo thời gian thực"]
    end

    %% TẦNG 2: BACKEND PRIVACY SHIELD & AGGREGATOR
    subgraph SHIELD ["2. BACKEND PRIVACY SHIELD & CONTEXT AGGREGATOR"]
        Auth["JWT Authenticate<br/>Trích xuất idaccount"]
        RateLimit["Redis Token-Bucket Limiter<br/>Giới hạn 15 req/phút / user"]
        SnapshotEngine["Financial Health Aggregator<br/>Tính sẵn tỷ lệ 50/30/20, Top chi tiêu, Điểm FHS"]
        PIIMasker["PII Masking & Anonymizer<br/>Khử toàn bộ tên riêng, STK, SĐT, làm tròn số"]
    end

    %% TẦNG 3: SUY LUẬN & TƯ VẤN CHIẾN LƯỢC
    subgraph REASONING ["3. REASONING & ADVICE CORE (GEMINI 2.0 FLASH)"]
        Context["Context Assembler<br/>System Prompt CFP + Anonymized Snapshot + Knowledge"]
        LLM["Google Gemini 2.0 Flash<br/>Deep Reasoning · Strict Grounding · Temp 0.1"]
    end

    %% TẦNG 4: ĐÀO SÂU CHI TIẾT & TRI THỨC TĨNH
    subgraph DRILLDOWN ["4. ON-DEMAND DRILLDOWN & KNOWLEDGE ENGINE"]
        subgraph TOOLS ["On-Demand Aggregation Tools (Chỉ gọi khi cần chi tiết)"]
            ToolReg["Financial Tools Registry<br/>6 công cụ truy vấn có cấu trúc"]
            Prisma["Prisma Executor<br/>WHERE idaccount = user_id"]
            DB[("PostgreSQL CSDL")]
        end

        subgraph RAG ["Standard RAG Engine (Tri Thức Tĩnh Chung)"]
            Hybrid["Hybrid Search (Dense + BM25Okapi)"]
            RRF["Hợp nhất RRF k=60 & Re-rank"]
            VectorStore[("Knowledge Base (HNSW)<br/>Luật thuế TNCN, Quy tắc 50/30/20")]
        end
    end

    %% LUỒNG DỮ LIỆU
    UI -->|"1. POST /api/ai/chatbot/chat/stream (Open Query)"| Auth
    Auth --> RateLimit
    RateLimit --> SnapshotEngine
    SnapshotEngine --> PIIMasker
    PIIMasker --> Context
    UI -.-> Context

    Context --> LLM
    LLM -->|"Pha 1: Đã đủ dữ liệu ẩn danh vĩ mô"| LLM
    LLM -->|"Pha 2a: Cần đào sâu số liệu quá khứ"| ToolReg
    LLM -->|"Pha 2b: Cần tra cứu luật thuế/tri thức"| Hybrid

    ToolReg --> Prisma
    Prisma <--> DB
    Prisma --> PIIMasker
    PIIMasker --> Context

    Hybrid <--> VectorStore
    Hybrid --> RRF
    RRF --> Context

    LLM ==>|"Stream Token (text/event-stream)"| SSE
    SSE --> UI
```

---

### 3.2. Cấu Trúc Bản Tóm Tắt Sức Khỏe Tài Chính Ẩn Danh (Anonymized Financial Health Snapshot)

Để LLM có thể suy luận sắc sảo ngay lập tức mà không cần hỏi đi hỏi lại từng bảng dữ liệu, Backend tính toán sẵn một gói dữ liệu cô đọng ($< 300\text{ tokens}$), **hoàn toàn ẩn danh**:

```json
{
  "period": "Tháng hiện tại (09/2026)",
  "financialHealthScore": 72,
  "budgetAllocation": {
    "needs_essential": "58% (Mục tiêu chuẩn: 50%)",
    "wants_lifestyle": "27% (Mục tiêu chuẩn: 30%)",
    "savings_debt": "15% (Mục tiêu chuẩn: 20%)"
  },
  "spendingInsights": {
    "topExpenseCategories": [
      { "category": "Ăn uống", "percentage": 34, "trendVsLastMonth": "+15%" },
      { "category": "Thuê nhà & Tiện ích", "percentage": 24, "trendVsLastMonth": "0%" },
      { "category": "Mua sắm cá nhân", "percentage": 18, "trendVsLastMonth": "+40%" }
    ],
    "overBudgetAlerts": ["Ăn uống đã chạm 92% ngân sách tháng"]
  },
  "liquidityAndObligations": {
    "emergencyFundMonths": 2.1,
    "upcomingBillsIn7DaysCount": 2,
    "hasHighInterestDebt": true,
    "activeSavingsGoalsCount": 1
  }
}
```

> **Đặc điểm bảo mật:**
> - Không chứa: Số tài khoản ngân hàng, họ tên, số điện thoại, địa chỉ, tên cửa hàng cụ thể.
> - Số tiền cụ thể được quy đổi thành **tỷ lệ % phân bổ**, **xu hướng tăng/giảm** và **thời lượng quỹ dự phòng (số tháng)**.
> - Đủ $100\%$ dữ kiện chất lượng cao để AI suy luận: *"Ăn uống đang chiếm tới 34% và tăng 15%, trong khi quỹ khẩn cấp mới chỉ đủ 2.1 tháng chi tiêu, bạn nên ưu tiên..."*.

---

### 3.3. Tầng Suy Luận & Tư Vấn Cấp Cao (Reasoning & Advice Core)

#### Vai trò & Triết lý của AI Copilot:
- Đóng vai trò là **Senior Personal Financial Advisor (CFP)**:
  - Lắng nghe thấu cảm, không phán xét hành vi tiêu dùng của người dùng.
  - Phân tích nguyên nhân gốc rễ (Root Cause) thay vì chỉ đọc lại số liệu.
  - Luôn đưa ra lời khuyên theo công thức **"Nhận định $\rightarrow$ Phân tích tác động $\rightarrow$ 2-3 Hành động cụ thể (Actionable Steps)"**.

#### Kỹ thuật Prompting chuẩn:
- **In-Context Chain-of-Thought (CoT):** Yêu cầu mô hình tự suy luận logic các bước trong khối `thought` trước khi sinh câu trả lời.
- **Strict Grounding:** Chỉ lập luận dựa trên Snapshot và dữ liệu cung cấp; tuyệt đối không tự bịa đặt các khoản tiền không có thật.
- **Low Temperature:** Đặt $0.1$ để phản hồi nhất quán, chặt chẽ, không bị ảo giác.

---

### 3.4. Danh Mục Công Cụ Truy Vấn Đào Sâu (On-Demand Drilldown Tools)

Khi người dùng muốn đào sâu vào chi tiết cụ thể mà Snapshot chưa có, LLM kích hoạt các công cụ có cấu trúc:

| Tên Tool | Tham số đầu vào | Chức năng nghiệp vụ | Ràng buộc bảo mật |
|---|---|---|---|
| `get_category_transactions` | `categoryName`, `limit` (max 10), `timeRange` | Lấy danh sách giao dịch lớn nhất hoặc gần nhất của 1 danh mục. | Bắt buộc `idaccount`. Che PII ghi chú qua `maskTransactionDescription`. |
| `compare_spending_periods` | `period1`, `period2`, `category` | So sánh chi tiêu giữa 2 mốc thời gian (ví dụ: tháng này vs tháng trước). | Dữ liệu trả về dạng chênh lệch tổng và %. |
| `get_bill_details` | `status` (unpaid/all), `daysAhead` | Chi tiết các hóa đơn sắp đến hạn thanh toán trong tuần. | Chỉ lấy hạn nợ và số tiền làm tròn, không kèm thông tin thẻ tín dụng. |
| `get_goal_simulation` | `goalId`, `monthlyContribution` | Giả lập thời gian hoàn thành mục tiêu tiết kiệm với mức đóng góp mới. | Ràng buộc `idaccount`. |

---

## 4. THI CÔNG CHUẨN RAG 4 PHA CHO TRI THỨC TĨNH (STANDARD_RAG.MD)

Tri thức tài chính chung/tĩnh (Luật thuế TNCN, mẹo chi tiêu, biểu thuế lũy tiến) tuân thủ 100% tài liệu [`docs/AI/Standard_RAG.md`](./Standard_RAG.md):

- **Phase 1 (Advanced Indexing):**
  - Chuẩn hóa Unicode **NFC** (`unicodedata.normalize('NFC')`), khử ký tự điều khiển.
  - **Parent-Child Chunking:** Child Chunk 200 tokens (độ trùng 20 tokens) dùng cho Dense Vector Search; Parent Chunk 1000 tokens nạp vào Prompt để trọn vẹn ngữ cảnh.
  - **HNSW Indexing:** $M = 16$, $ef\_construction = 128$, $ef\_search = 64$ (truy vấn $< 10\text{ms}$).
- **Phase 2 (Advanced Retrieval):**
  - **Query Transformation:** Áp dụng HyDE và Query Decomposition khi gặp câu hỏi so sánh phức tạp.
  - **Hybrid Search:** Kết hợp Dense Search (`text-embedding-004`) và Sparse Search (BM25Okapi tiếng Việt).
  - **Hợp nhất RRF ($k = 60$):** $\text{Score}(d) = \sum \frac{1}{60 + rank_i(d)}$.
  - **Cross-Encoder Re-ranking:** Lấy Top 20 từ Hybrid Search $\rightarrow$ Re-ranker chọn **Top 3 - 5 chunks** chuẩn xác nhất.
- **Phase 3 (Generation & Attribution):**
  - **U-Shaped Context Ordering:** Đặt thông tin quan trọng nhất ở đầu và cuối prompt chống hiện tượng *"Lost in the Middle"*.
  - **Trích dẫn nguồn:** Mọi con số trích từ cẩm nang phải có dẫn chứng `[Nguồn: Quy tắc 50/30/20]` hoặc `[Nguồn: Biểu thuế TNCN 2026]`.
- **Phase 4 (Quantitative Evaluation Ragas):**
  - Đảm bảo: $\text{Faithfulness} \ge 0.85$, $\text{Answer Relevancy} \ge 0.70$, $\text{Context Precision} \ge 0.80$, $\text{Context Recall} \ge 0.80$.

---

## 5. THIẾT KẾ CHỊU TẢI CAO (HIGH CONCURRENCY) & TÍNH ỔN ĐỊNH

Khi số lượng lớn người dùng cùng chat với AI, hệ thống áp dụng các tầng phòng thủ:

```
[User Request] ──▶ [Redis Rate Limiter] ──▶ [Redis Semantic Cache (<20ms)]
                           │                               │
                    (Chặn spam 429)                 (Cache hit 40-50%)
                           │                               │
                           ▼                               ▼
                 [Connection Pool Pg] ──▶ [Gemini Timeout 15s + Circuit Breaker]
```

1. **Redis Token-Bucket Rate Limiter:**
   - 15 request / phút / user; tối đa 100 request / ngày. Toàn hệ thống kiểm soát $60\text{ RPM}$ tới Gemini API.
2. **Bộ nhớ đệm thông minh 2 lớp (Multi-layer Cache):**
   - **Semantic Cache trên Redis (TTL 1h):** Các câu hỏi tri thức chung có độ tương đồng ngữ nghĩa $\ge 0.95$ sẽ được trả về ngay trong $< 20\text{ms}$, không gọi Gemini.
   - **Snapshot Cache (TTL 120s):** Bản tóm tắt sức khỏe tài chính được cache 2 phút trên Redis trong suốt phiên trò chuyện, tránh query CSDL liên tục.
3. **Quản lý tài nguyên & Chống sập (Fault Tolerance):**
   - Connection Pool PostgreSQL `max: 20`, giải phóng ngay sau câu lệnh SELECT.
   - Timeout Gemini API: $15\text{s}$; Timeout DB Query: $3\text{s}$.
   - **Circuit Breaker:** Khi lỗi 5 lần liên tiếp trong 1 phút, tự động chuyển sang OPEN trong 30 giây và trả về Graceful Fallback thân thiện.

---

## 6. TỐI ƯU HÓA TỐC ĐỘ PHẢN HỒI (LOW LATENCY — TTFT < 800MS)

1. **Giao thức Server-Sent Events (SSE Streaming):**
   - Endpoint `POST /api/ai/chatbot/chat/stream` đẩy từng token từ Gemini 2.0 Flash về Client ngay khi vừa sinh ra.
   - Thời gian xuất hiện ký tự đầu tiên (**Time To First Token - TTFT**) đạt mức **$< 800\text{ms}$**.
2. **Xử lý ngắt kết nối (Client Disconnect Handler):**
   - Lắng nghe sự kiện `req.on('close')`: Khi người dùng tắt app hoặc bấm "Dừng", Backend lập tức ngắt stream của Gemini để tiết kiệm token và giải phóng RAM máy chủ.

---

## 7. CẤU TRÚC THƯ MỤC MODULE & ĐẶC TẢ API CHI TIẾT

### 7.1. Cấu Trúc Thư Mục Triển Khai (`src/Backend/modules/ai/features/chatbot/`)

```
src/Backend/modules/ai/features/chatbot/
├── chatbot.controller.js          # Tiếp nhận HTTP request, điều phối SSE stream
├── chatbot.routes.js              # Định tuyến router: /chat/stream, /chat, /history
├── chatbot.service.js             # Nhạc trưởng điều phối: Snapshot -> Context -> LLM -> Tools
├── chatbot.validation.js          # Kiểm tra tính hợp lệ của input schema
├── snapshot/
│   └── financial.snapshot.js      # Tính toán Bản tóm tắt sức khỏe tài chính ẩn danh (50/30/20, FHS)
├── privacy/
│   └── pii.masker.js              # Bộ lọc làm mờ STK, SĐT, danh tính, làm tròn số
├── rag/
│   ├── knowledge.repository.js    # Quản lý tri thức tĩnh, truy vấn Vector HNSW / BM25
│   ├── chunker.js                 # Chuẩn hóa NFC và cắt Parent-Child chunks
│   ├── hybrid.search.js           # Dense + Sparse BM25 + RRF Reciprocal Rank Fusion
│   └── reranker.js                # Cross-encoder re-ranking top chunks
├── tools/
│   ├── financial.tools.js         # Khai báo JSON Schema Tools cho Gemini Function-Calling
│   └── tools.executor.js          # Thực thi query CSDL thực tế (scoped idaccount)
└── prompts/
    └── advisor.system.prompt.js   # System Prompt chuyên gia CFP, quy tắc Strict Grounding
```

### 7.2. Đặc Tả API Endpoints

#### `POST /api/ai/chatbot/chat/stream` (Khuyên dùng — SSE Streaming)
- **Headers:** `Authorization: Bearer <JWT_TOKEN>`, `Accept: text/event-stream`
- **Request Body:**
  ```json
  {
    "message": "Dạo này tôi thấy áp lực chi tiêu quá, bạn có lời khuyên nào giúp tôi cân đối lại không?",
    "conversationId": "uuid-v4-optional",
    "history": []
  }
  ```
- **Response Format (Server-Sent Events):**
  ```http
  HTTP/1.1 200 OK
  Content-Type: text/event-stream
  Cache-Control: no-cache
  Connection: keep-alive

  event: meta
  data: {"snapshotLoaded": true, "healthScore": 72}

  event: delta
  data: {"text": "Tôi "}

  event: delta
  data: {"text": "rất hiểu cảm giác áp lực này của bạn. "}

  event: delta
  data: {"text": "Nhìn vào bức tranh chi tiêu tháng này, danh mục Ăn uống đang chiếm tới 34%..."}

  event: done
  data: {"status": "completed", "responseTimeMs": 680}
  ```

---

## 8. LỘ TRÌNH THỰC THI THEO 4-PHASE DELIVERY WORKFLOW (TDD)

1. **Phase 1: Scope & Plan (Đã hoàn tất):** PO duyệt kiến trúc Giải pháp 3 tại `docs/AI/ChatbotAI.md`.
2. **Phase 2: TDD & Execution:**
   - Bước 2.1: Xây dựng module `snapshot/financial.snapshot.js` và `privacy/pii.masker.js` kèm Unit Tests (Red $\rightarrow$ Green).
   - Bước 2.2: Xây dựng bộ công cụ `tools/financial.tools.js` & `tools.executor.js`.
   - Bước 2.3: Xây dựng kho tri thức tĩnh `rag/hybrid.search.js` theo chuẩn `Standard_RAG.md`.
   - Bước 2.4: Xây dựng `chatbot.service.js` kết nối Gemini 2.0 Flash SDK (hỗ trợ SSE Stream & Function-Calling loop).
   - Bước 2.5: Xây dựng Controller, Rate Limiter và Route SSE.
3. **Phase 3: Systematic Debug & Load Test:**
   - Kiểm thử chịu tải 50 concurrent requests.
   - Kiểm thử sự kiện client disconnect ngắt stream sạch sẽ.
4. **Phase 4: Verify & Ship:**
   - Đo lường chỉ số Ragas (Faithfulness $\ge 0.85$).
   - Nghiệm thu chức năng cùng PO và cập nhật CodeGraph.
