# CHUẨN KIẾN TRÚC RAG CHO MODULE AI (Standard_RAG.md)
> **Tài liệu nguồn sự thật định chuẩn kiến trúc Retrieval-Augmented Generation (RAG) cho toàn bộ các chức năng thuộc Module AI**  
> *Trích xuất và chuẩn hóa từ bộ tài liệu chuyên sâu AI Course 2025 - 2026 (`docs/AI/Document_Application_AI/`). Được PO phê duyệt ngày 2026-09-02.*

---

## 1. TỔNG QUAN VỀ KIẾN TRÚC MODERN RAG (IN-CONTEXT LEARNING)

Retrieval-Augmented Generation (RAG) là giải pháp kiến trúc giải quyết triệt để 2 hạn chế cố hữu của các mô hình ngôn ngữ lớn (LLM):
1. **Hiện tượng ảo giác (Hallucination):** LLM tự sinh ra thông tin sai lệch nhưng với văn phong tự tin.
2. **Giới hạn tri thức (Knowledge Cutoff & Private Data):** LLM không có dữ liệu tài chính cá nhân thời gian thực và kiến thức nghiệp vụ nội bộ của người dùng.

### Tư duy chuyển dịch sang Modern RAG:
Khác với RAG nguyên bản (2020) phải fine-tuning đồng thời cả Retriever và Generator rất tốn kém, **Modern RAG (Hiện nay)** áp dụng hướng tiếp cận **In-Context Learning (Retrieve and Prompt)**: Giữ nguyên trọng số của LLM và tập trung tối ưu hóa quy trình 4 giai đoạn khép kín:

```
 ┌──────────────────────────────────────────────────────────────────────────────────┐
 │  PHASE 1: ADVANCED INDEXING (TIỀN XỬ LÝ & LẬP CHỈ MỤC NÂNG CAO)                  │
 │  Tài liệu thô ──▶ Chuẩn hóa Unicode NFC ──▶ Semantic Chunking ──▶ Vector DB HNSW  │
 └────────────────────────────────────────┬─────────────────────────────────────────┘
                                          │
 ┌────────────────────────────────────────▼─────────────────────────────────────────┐
 │  PHASE 2: ADVANCED RETRIEVAL (TRUY XUẤT NÂNG CAO & TỐI ƯU HÓA)                   │
 │  Query ──▶ Query Transformations (HyDE / Query Decomposition)                    │
 │        ──▶ Hybrid Search (Dense Vector Search + Sparse BM25Okapi tiếng Việt)     │
 │        ──▶ Reciprocal Rank Fusion (RRF k=60)                                     │
 │        ──▶ Re-ranking (Cross-Encoder / Maximal Marginal Relevance)               │
 └────────────────────────────────────────┬─────────────────────────────────────────┘
                                          │
 ┌────────────────────────────────────────▼─────────────────────────────────────────┐
 │  PHASE 3: GENERATION & ATTRIBUTION (SINH CÂU TRẢ LỜI & DẪN CHỨNG NGUỒN)          │
 │  U-Shaped Context Reordering ──▶ Low Temperature ──▶ Strict Grounding & Citation │
 └────────────────────────────────────────┬─────────────────────────────────────────┘
                                          │
 ┌────────────────────────────────────────▼─────────────────────────────────────────┐
 │  PHASE 4: QUANTITATIVE EVALUATION (ĐÁNH GIÁ ĐỊNH LƯỢNG RAGAS)                    │
 │  Faithfulness | Answer Relevancy | Context Precision | Context Recall            │
 └──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. PHASE 1: CHUẨN TIỀN XỬ LÝ & LẬP CHỈ MỤC (ADVANCED INDEXING)

### 2.1. Chuẩn Hóa Văn Bản Tiếng Việt (`clean_vietnamese_text`)
Văn bản tiếng Việt trích xuất từ PDF, OCR, hoặc cơ sở dữ liệu thường chứa lỗi font, ký tự rác hoặc sai lệch encoding. Hệ thống bắt buộc phải đi qua pipeline làm sạch:
* Chuẩn hóa Unicode về dạng **NFC** (`unicodedata.normalize('NFC', text)`).
* Loại bỏ toàn bộ ký tự điều khiển (Control Characters không in được), giữ lại `\n` và `\t`.
* Gộp khoảng trắng thừa (`\s+` $\rightarrow$ `' '`) và gộp các dòng trống liên tiếp.

### 2.2. Chiến Lược Phân Mảnh (Chunking Strategies)

| Phương Pháp Chunking | Nguyên Lý Hoạt Động | Ưu Điểm | Nhược Điểm & Ứng Dụng |
|---|---|---|---|
| **Recursive Chunking** | Cắt đệ quy theo thứ tự ưu tiên: `\n\n` $\rightarrow$ `\n` $\rightarrow$ dấu chấm $\rightarrow$ khoảng trắng với `chunk_size = 400 - 1000`, `chunk_overlap = 10 - 20%`. | Tốc độ cực nhanh, giữ nguyên cấu trúc văn bản gốc. | Dễ cắt ngang ý tưởng quan trọng giữa 2 đoạn. Thích hợp cho văn bản có cấu trúc rõ ràng. |
| **Semantic Chunking (Khuyên dùng)** | Sử dụng embedding để tính độ tương đồng Cosine giữa các câu liên tiếp. Chỉ ngắt đoạn khi độ tương đồng giảm sâu dưới ngưỡng `breakpoint_threshold = 0.5`. | Giữ trọn vẹn ý tưởng, không làm đứt gãy đại từ ngữ nghĩa (tăng Faithfulness từ $0.73 \rightarrow 0.81$). | Tốn tài nguyên tính toán hơn do phải chạy embedding từng câu. Thích hợp cho tài liệu ít cấu trúc, báo cáo tài chính. |
| **Parent-Child Indexing (Small-to-Big)** | Chia Child Chunk nhỏ ($200$ tokens) để tìm kiếm chính xác $\rightarrow$ Khi đưa vào LLM trả về Parent Chunk lớn ($1000$ tokens). | Giải quyết mâu thuẫn: chunk nhỏ tốt cho tìm kiếm, chunk lớn tốt cho LLM hiểu ngữ cảnh. | Thích hợp cho sổ tay tài chính, hướng dẫn quy định chi tiêu. |

### 2.3. Vector Database & Chỉ Mục Đồ Thị Phân Tầng (HNSW Index)
Để tìm kiếm vector nhanh chóng trên quy mô lớn mà không bị nghẽn $O(N)$ của tìm kiếm vét cạn (Brute-force), hệ thống áp dụng cấu trúc đồ thị phân tầng **HNSW (Hierarchical Navigable Small World)**:
* **Layer 0:** Chứa toàn bộ điểm dữ liệu và liên kết chi tiết nhất để tìm chính xác vector đích.
* **Các Layer cao hơn:** Đóng vai trò như các "đường cao tốc" với liên kết thưa giúp thuật toán nhảy nhanh đến vùng dữ liệu tiềm năng.

#### 3 Tham số cấu hình cốt lõi của HNSW:
1. **$M$ (Max Links per Node = 16 - 64):** Mật độ kết nối của đồ thị. $M$ cao giúp tăng độ chính xác tìm kiếm nhưng tốn RAM hơn.
2. **$ef\_construction$ (50 - 200):** Độ sâu duyệt ứng viên khi tạo chỉ mục đồ thị ban đầu.
3. **$ef\_search$ (Runtime Search Depth):**
   * *Ứng dụng Chatbot thời gian thực:* Đặt $ef\_search = 50 - 100$ để tối ưu độ trễ thấp.
   * *Ứng dụng Tra cứu & Báo cáo chuyên sâu:* Đặt $ef\_search = 400 - 500$ để đạt độ chính xác tối đa.

---

## 3. PHASE 2: CHUẨN TRUY XUẤT NÂNG CAO (ADVANCED RETRIEVAL STRATEGIES)

### 3.1. Biến Đổi Câu Truy Vấn (Query Transformations)

#### A. HyDE (Hypothetical Document Embeddings):
* **Vấn đề:** Câu hỏi của người dùng thường ngắn ("xăng xe", "ăn uống"), trong khi tài liệu/giao dịch lại dài và chi tiết $\rightarrow$ Bất cân xứng vector.
* **Giải pháp:** Yêu cầu LLM viết 1 đoạn văn trả lời giả định mang phong cách tài chính $\rightarrow$ Dùng vector của câu trả lời giả định này đi truy vấn $\rightarrow$ Tăng độ tương đồng với tài liệu thực tế.

#### B. Query Decomposition (Phân Tách Câu Hỏi Đa Ý):
* **Vấn đề:** Các câu hỏi so sánh phức tạp (ví dụ: *"So sánh tiền ăn tháng 7 và tháng 8 năm 2026"*) khiến vector bị lơ lửng giữa 2 chủ đề.
* **Giải pháp:** Tách câu hỏi gốc thành các câu hỏi con độc lập:
  * `Sub-query 1`: *"Tổng chi tiêu ăn uống tháng 7/2026 là bao nhiêu?"*
  * `Sub-query 2`: *"Tổng chi tiêu ăn uống tháng 8/2026 là bao nhiêu?"*
  * `Synthesis`: Truy vấn độc lập từng sub-query $\rightarrow$ Tổng hợp cho LLM trả lời so sánh.
* **Hiệu quả thực nghiệm:** Đạt chỉ số **Faithfulness 0.93** (tăng $0.20$ so với baseline).

### 3.2. Tìm Kiếm Lai (Hybrid Search) & Hợp Nhất RRF

```
                        【CÂU TRUY VẤN (QUERY)】
                                  │
                 ┌────────────────┴────────────────┐
                 ▼                                 ▼
    【DENSE RETRIEVAL (VECTOR)】      【SPARSE RETRIEVAL (BM25)】
     • Tương đồng ngữ nghĩa            • Khớp từ khóa chính xác
     • Bắt từ đồng nghĩa, từ lóng       • Bắt mã HĐ, tên riêng, số tiền
                 │                                 │
                 └────────────────┬────────────────┘
                                  ▼
             【RECIPROCAL RANK FUSION (RRF k=60)】
             Hợp nhất thứ hạng nghịch đảo, loại bỏ nhiễu
                                  │
                                  ▼
                  【TOP-K TÀI LIỆU CHẤT LƯỢNG CAO】
```

* **Công thức chuẩn Reciprocal Rank Fusion (RRF):**
  $$\text{Score}(d) = \sum_{i} \frac{1}{k + rank_i(d)}$$
  *Trong đó: $rank_i(d)$ là thứ hạng của tài liệu trong danh sách tìm kiếm $i$, hằng số $k = 40 - 60$ giúp làm mượt điểm số.*
* **Hiệu quả:** Cân bằng hoàn hảo giữa **Context Precision (0.80)** và **Context Recall (0.80)**, loại bỏ nhược điểm của việc cộng điểm lệch thang đo.

### 3.3. Tái Xếp Hạng Tầng Cuối (Re-ranking) — Chiến Lược "Hình Phễu"
* **Bước 1 (Retrieve Many):** Sử dụng Bi-Encoder (HNSW Vector + BM25) lấy nhanh **Top 50** ứng viên.
* **Bước 2 (Re-rank Few):** Sử dụng mô hình **Cross-Encoder (Qwen-Reranker / BGE-Reranker)** để đọc đồng thời `(Query, Document)` qua cơ chế Self-Attention toàn phần $\rightarrow$ Chấm điểm tương quan chính xác và lọc lấy **Top 3 - 5** tài liệu tinh túy nhất.
* **Maximal Marginal Relevance (MMR):** Sử dụng khi cần loại bỏ thông tin trùng lặp để tối ưu Context Window:
  $$\text{Score}_{MMR} = \lambda \cdot \text{Sim}(Query, Doc) - (1 - \lambda) \cdot \max_{Doc_i \in Selected} \text{Sim}(Doc, Doc_i) \quad (\lambda = 0.5)$$

---

## 4. PHASE 3: CHUẨN SINH CÂU TRẢ LỜI & DẪN CHỨNG (GENERATION & ATTRIBUTION)

### 4.1. Sắp Xếp Ngữ Cảnh Hình Chữ U (U-Shaped Context Reordering)
* **Khắc phục hiện tượng "Lost in the Middle":** LLM chú ý tốt nhất vào thông tin ở ĐẦU và CUỐI prompt, hay quên thông tin ở GIỮA.
* **Quy tắc sắp xếp:** Đưa tài liệu quan trọng nhất vào đầu và cuối prompt:
  $$\text{Context Array} = [\text{Doc 1 (Quan trọng nhất)}, \text{Doc 3}, \text{Doc 5}, \text{Doc 4}, \text{Doc 2 (Quan trọng nhì)}]$$

### 4.2. Cấu Hình Tham Số & Kỹ Thuật Prompting Chuẩn
1. **Low Temperature ($\text{temperature} = 0.0 - 0.2$):** Bắt buộc đối với ứng dụng tài chính để giảm thiểu sự sáng tạo ngẫu nhiên, đảm bảo tính nhất quán và triệt tiêu ảo giác.
2. **Strict Grounding:** Bắt buộc có câu lệnh: *"Chỉ trả lời dựa trên tài liệu được cung cấp. Nếu tài liệu không chứa thông tin, hãy trả lời rõ 'Không có thông tin' thay vì tự suy đoán."*
3. **Chain-of-Thought (CoT):** Yêu cầu mô hình suy nghĩ từng bước trước khi đưa ra con số kết luận cuối cùng.
4. **Trích Dẫn Nguồn (Citation / Attribution):** Yêu cầu mọi kết luận số liệu phải kèm mã định danh tham chiếu (ví dụ: `[Giao dịch #TX-1234, 15/08/2026]`).

---

## 5. PHASE 4: KHUNG ĐÁNH GIÁ ĐỊNH LƯỢNG RAGAS (EVALUATION FRAMEWORK)

Chất lượng hệ thống RAG được đo lường định lượng tự động thông qua **4 chỉ số cốt lõi của framework RAGAS** (thang điểm từ $0.0 \rightarrow 1.0$):

```
                        ┌────────────────────────────────────────┐
                        │        RAGAS EVALUATION METRICS        │
                        └───────────────────┬────────────────────┘
                                            │
                    ┌───────────────────────┴───────────────────────┐
                    ▼                                               ▼
     【GENERATION METRICS (SINH VĂN BẢN)】             【RETRIEVAL METRICS (TRUY XUẤT)】
     1. Faithfulness (Độ trung thực)                  1. Context Precision (Độ chính xác)
     2. Answer Relevancy (Độ liên quan)               2. Context Recall (Độ bao phủ)
```

| Chỉ Số Ragas | Công Thức / Cơ Chế Tính | Ý Nghĩa Thực Tế | Ngưỡng Chuẩn Đạt |
|---|---|---|---|
| **Faithfulness** | $\frac{\text{Số phát biểu suy ra được từ Context}}{\text{Tổng số phát biểu trong câu trả lời}}$ | Đảm bảo câu trả lời không bịa đặt số liệu tài chính. | $\ge 0.85$ |
| **Answer Relevancy** | Trung bình Cosine Similarity giữa câu hỏi gốc và các câu hỏi sinh ngược từ câu trả lời. | Đảm bảo câu trả lời đi thẳng vào trọng tâm câu hỏi của người dùng. | $\ge 0.70$ |
| **Context Precision** | $\frac{\sum_{k=1}^K (\text{Precision@}k \times v_k)}{\text{Tổng số context liên quan}}$ | Đảm bảo các giao dịch/tài liệu liên quan nằm ở top đầu danh sách truy xuất. | $\ge 0.80$ |
| **Context Recall** | $\frac{\text{Số claims trong Reference gán được cho Context}}{\text{Tổng số claims trong Reference}}$ | Đảm bảo hệ thống không bỏ sót các khoản chi tiêu hoặc sự kiện tài chính quan trọng. | $\ge 0.80$ |

---

## 6. MA TRẬN ÁP DỤNG CHUẨN RAG VÀO CÁC TÍNH NĂNG CỦA MODULE AI

| Chức Năng Module AI | Giai Đoạn RAG Áp Dụng | Kỹ Thuật Trọng Tâm | Dữ Liệu Nguồn Cần Truy Xuất |
|---|---|---|---|
| **Receipt OCR & Classify** | Phase 1 + Phase 2 | • Text Normalization NFC<br>• Hybrid Search (BM25 + Semantic)<br>• Keyword Matcher Tầng 1 | Bảng `Category.Keyword`, Danh mục của User trong DB. |
| **Financial Advice (Tư vấn)** | Phase 2 + Phase 3 | • Hybrid RRF Search<br>• U-Shaped Context Reordering<br>• Low Temperature (0.2) + CoT | Lịch sử giao dịch 3 tháng gần nhất, Quy tắc phân bổ 50/30/20, Định mức tiết kiệm. |
| **Smart Budget (Ngân sách)** | Phase 1 + Phase 2 | • Parent-Child Indexing<br>• Query Decomposition<br>• Strict Grounding | Bảng `Budget`, Hạn mức cảnh báo, Lịch sử biến động số dư các tháng trước. |
| **Financial Chatbot (Trợ lý ảo)** | Phase 1 $\rightarrow$ Phase 4 | • Semantic Chunking + HNSW<br>• HyDE + Hybrid Search + RRF<br>• Cross-Encoder Reranker<br>• Ragas Benchmark | Toàn bộ dữ liệu tài chính của User (`Transaction`, `Wallet`, `Bill`, `Goal`, `Budget`) và kiến thức tài chính. |
| **Cash Flow Forecast** | Phase 2 + Phase 3 | • Time-series context extraction<br>• Citation attribution | Hóa đơn định kỳ (`Bill`), Mục tiêu (`Goal`), Biến động dòng tiền dự kiến. |
