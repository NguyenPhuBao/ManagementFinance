# Edge AI — xin thống nhất tên gọi, và hai mâu thuẫn cần backend chốt

> ✅ **ĐÃ XỬ LÝ XONG (2026-09-22):**
> 1. **Thuật ngữ:** Đã đổi đồng bộ "AI Edge" thành "Edge AI" trong toàn bộ tài liệu `docs/AI/`, làm rõ ranh giới hệ chuyên gia (luật/thống kê tất định) vs Edge AI (SLM on-device).
> 2. **Mâu thuẫn ① (Chốt lối A):** Dữ liệu tài chính của User **KHÔNG** index lên vector DB server (tuân thủ F1 & Nghị định 13/2023/NĐ-CP). Chatbot server chỉ RAG trên kho kiến thức tài chính chung/tĩnh; số liệu cá nhân dùng Function-Calling. Đã cập nhật `docs/AI/Standard_RAG.md` §6.
> 3. **Mâu thuẫn ②:** Giữ Cloud AI (Backend quản lý API Key, không đưa API Key lên Mobile). Đã bổ sung tầng lọc dữ liệu nhạy cảm `maskTransactionDescription` trong `src/Backend/utils/masking.util.js` (lọc thẻ tín dụng/CVV/mật khẩu, che SĐT, STK, Email) trước khi gửi prompt sang Cloud LLM, đồng thời kích hoạt Strict Grounding chống ảo giác danh mục trong `llm.classifier.js`. PO sẽ cấu hình `GEMINI_API_KEY` trong `.env` sau.

**Ngày:** 2026-09-22 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat`
**Việc xin:** (1) **sửa chữ** — một tên gọi; (2) **hai quyết định** — không xin đổi mã ngay, nhưng
quyết định nào cũng kéo theo một chỗ mã phải đổi, ghi rõ bên dưới. **Không** xin migration,
**không** thêm trường payload, **không** chặn việc nào của client.

Mọi con số và mọi lời dẫn dưới đây **đo bằng máy ngày 2026-09-22** trên nhánh `TranQuangDat`
đã gộp `main`, kèm số dòng để người nhận mở đúng chỗ.

---

## 1. Tên gọi: "Edge AI" thay cho "AI Edge"

"Edge AI" là thuật ngữ ngành — học sâu chạy trên thiết bị (LiteRT, CoreML, NPU/GPU). "AI Edge"
là cách gọi ngược, chỉ dự án này dùng. Client đã đổi ở tài liệu client quản từ 2026-09-22
(`docs/AI_EDGE_FEATURE.md` banner đầu tệp, `docs/AI_AGENT_ARCHITECTURE.md` mục **1.2**). Xin đổi ở:

| Tệp | Chỗ | Đề nghị |
|---|---|---|
| `docs/AI/AI_Edge-SLM.md/Client-app.md` | tiêu đề, mọi chỗ "AI Edge" | "Edge AI" |
| thư mục `docs/AI/AI_Edge-SLM.md/` | tên thư mục | **giữ** nếu đổi làm hỏng liên kết; chỉ xin sửa chữ bên trong |

⚠️ Và xin nói rõ trong đặc tả: tầng **luật + thống kê** (39 luật A–H) **không** phải học máy;
tầng **SLM on-device** mới là Edge AI theo nghĩa ngành. Hiện đặc tả gộp cả hai dưới một tên, và
người đọc — **kể cả trong nhóm** — đã hiểu nhầm phần đang chạy là một mô hình. Client cũng vừa
sửa đúng lỗi ấy ở tài liệu của mình: một câu gọi tầng luật là *"công nghệ thập niên 1980"*, đúng
về kỹ thuật nhưng mời gọi cách đọc sai về cả mảng.

**Client không đổi tên thư mục mã** `lib/features/ai_edge/`: đổi là sửa 36 tệp import cộng ba
test quét, để không ai ngoài nhóm thấy khác biệt. Tên đi trước ruột, và đó không phải lỗi.

## 2. Mâu thuẫn ①: dữ liệu cá nhân có được rời thiết bị không?

| Tài liệu | Nói gì |
|---|---|
| `AI_Edge-SLM.md/Client-app.md:367` (**F1**) | *"Toàn bộ dữ liệu giao dịch thô, bảng đặc trưng Feature JSON (Tầng 1) và kế hoạch tái phân bổ Reallocation JSON (Tầng 2) **hoàn toàn không được phép rời khỏi thiết bị di động**. Không gửi dữ liệu này lên bất kỳ API phân tích nào của bên thứ ba."* — dẫn Nghị định 13/2023/NĐ-CP và PCI-DSS |
| `Standard_RAG.md:169` (**§6**, hàng *Financial Chatbot*) | phạm vi truy xuất là *"Toàn bộ dữ liệu tài chính của User (`Transaction`, `Wallet`, `Bill`, `Goal`, `Budget`) và kiến thức tài chính"* — tức index lên vector DB phía server |

Hai câu không thể cùng đúng. Client đã thi công theo **F1**: P2 xong, P3 chạy mô hình on-device.
Xin chốt **một** trong hai:

- **(A) Giữ F1** → sửa §6: chatbot phía server chỉ truy xuất **kiến thức tài chính chung**; số
  liệu cá nhân do client cung cấp dưới dạng **gói số đã tính**. Câu đề nghị thay ô phạm vi của
  hàng ấy:
  > *"Kiến thức tài chính chung. **Dữ liệu tài chính của User không index lên server** (F1); số
  > liệu cá nhân đến từ client dưới dạng gói số đã tính."*
- **(B) Bỏ F1** → sửa F1, và **toàn bộ P2/P3 phía client phải thiết kế lại**. Client xin được báo
  trước, vì đây là đổi kiến trúc chứ không phải sửa một chỗ.

**Client đề nghị (A)**, vì F1 là ràng buộc pháp lý, và vì backend **đã hành xử theo (A)**: nó mã
hoá `transaction.Note` at-rest (mục 3 dưới đây) — một hệ thống vừa mã hoá ghi chú vừa index ghi
chú lên vector DB thì lớp mã hoá ấy không còn tác dụng gì.

## 3. Mâu thuẫn ②: tầng 3 classifier gửi mô tả giao dịch ra ngoài

`modules/ai/features/classify/classify.service.js:75` gọi
`llmClassifier.classifyWithLLM(text, categories, context)`, và
`modules/ai/features/classify/pipeline/llm.classifier.js:15-16` đọc `GEMINI_API_KEY` /
`OPENAI_API_KEY` — tức chuỗi mô tả giao dịch đi sang Gemini hoặc OpenAI.

Trong khi đó `modules/sync/sync.repository.js:5-16` **mã hoá `Note` at-rest**
(`prepareSafeNote` → `encrypt(filterSensitiveNote(note))`). Backend vừa bảo vệ ghi chú, vừa có
một đường gửi mô tả giao dịch cho bên thứ ba.

**Hiện chưa lộ**, và đo được hôm nay còn chặt hơn bản đo 2026-09-21: `src/Backend/.env` **không
khai** `GEMINI_API_KEY` lẫn `OPENAI_API_KEY` (16 biến, không có biến nào chứa hai tên ấy), nên
`llm.classifier.js:61-63` đi thẳng vào nhánh
`logger.debug('LLM Classifier: No GEMINI_API_KEY configured. Skipping Tier 3.')` rồi trả `null`.
Tầng 3 **chưa từng chạy một lần nào**. Đó là lý do việc này là *quyết định*, không phải *sự cố*.

Xin chốt một trong ba:

| Lối | Việc phải làm |
|---|---|
| **Bỏ tầng 3** | Xoá nhánh gọi ở `classify.service.js:75-79`; giữ keyword + NLP. Đơn giản nhất, và **không mất gì đang chạy** vì nó chưa từng chạy |
| **Chuyển tầng 3 về client** | Backend không làm gì; client dùng Gemma 4 on-device để phân loại (sau P3). Phù hợp F1 |
| **Giữ, xin phép tường minh** | Thêm cờ người dùng bật/tắt + nói rõ dữ liệu gửi đi đâu; và ghi vào F1 một **ngoại lệ có tên**, kẻo F1 thành câu không đúng với mã |

**Client đề nghị "bỏ"**: nó chưa từng chạy, nên giữ nó là giữ một mâu thuẫn với chính F1 mà không
đổi lấy được hành vi nào.

## 4. Kiểm lại thế nào

- **Tên gọi:** `grep -rn "AI Edge" docs/AI/` → 0 dòng (ngoài tên thư mục, nếu giữ).
  ⚠️ `grep` trên máy Windows của client **đã bỏ sót một dòng tiếng Việt** trong lượt soát cùng
  ngày; nếu kết quả trông đáng ngờ thì đọc tệp bằng Python thay vì tin `grep`.
- **①:** ô phạm vi của hàng *Financial Chatbot* (`Standard_RAG.md:169`) không còn cụm *"Toàn bộ
  dữ liệu tài chính của User"*.
- **②:** `grep -n "classifyWithLLM" modules/ai/features/classify/classify.service.js` → 0 dòng
  (nếu chọn "bỏ"); hoặc có cờ bật/tắt và F1 mang ngoại lệ có tên (nếu chọn "giữ").

## 5. Việc này KHÔNG chặn client — nhưng ① nay có thêm một dữ kiện đo được

Client vẫn đi tiếp theo F1 (dữ liệu cá nhân ở lại máy). Quyết định ① chỉ đổi **ai làm RAG cho
kiến thức chung** — client hay server; câu *"hệ thống có áp dụng RAG"* đúng ở cả hai lối.

⚠️ **Cập nhật cùng ngày, sau một phép đo trên máy thật:** client đã chạy spike RAG on-device
(OnePlus 13R / Snapdragon 8 Gen 3) và kết luận **không làm RAG phía client**. Bảng đo đầy đủ ở
`docs/AI_AGENT_ARCHITECTURE.md` mục **5.5**; ba con số quyết định:

| Đo được | Ý nghĩa |
|---|---|
| Mô hình embedding **tải tự do** duy nhất là Gecko 110M **English-only** → top-3 đúng **3/5** trên câu hỏi tiếng Việt | Corpus của dự án là tiếng Việt, nên đây là hạn chế trúng đích |
| Mọi bản **EmbeddingGemma đa ngữ** trả **401** (gated), kể cả `litert-community/embeddinggemma-300m` | Không ship được nếu mỗi máy phải có token HuggingFace |
| Truy vấn **251 ms**, index **253 ms/đoạn** | Trên ngưỡng client đặt trước (200 ms) |

Hệ quả cho backend: nếu chọn **(A)** thì phần **RAG kiến thức tài chính chung nằm hoàn toàn ở
server**, và client chỉ gọi một endpoint — không có bản RAG thứ hai ở client để phải giữ đồng bộ.
Đó cũng là lối client thích hơn, vì corpus kiến thức chung cần cập nhật được mà không phải phát
hành lại ứng dụng. Client **không** xin backend làm việc này gấp; đây là dữ kiện để ① được chốt
trên nền đầy đủ, không phải một yêu cầu mới.
