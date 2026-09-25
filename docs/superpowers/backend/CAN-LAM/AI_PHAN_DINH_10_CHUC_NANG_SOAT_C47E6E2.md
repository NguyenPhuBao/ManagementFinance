**Ngày:** 2026-09-25 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat` @ `4f37653` (đã gộp `main` @ `c47e6e2`)
**Tệp được soát:** `docs/AI/LogicBusinessAI.md`, `docs/AI/AI_ARCHITECTURE_DIAGRAM.md`, `Project.md` §8.5 + §11.42,
`docs/AI/Classify.md` §1.3, `docs/AI/ORC.md` (NPBao, commit `c47e6e2` ngày 2026-09-23). Các tệp này do backend quản
nên client **không tự sửa**, kể cả một dòng.
**Việc xin:** chủ yếu **sửa chữ**, cộng **hai quyết định** chỉ backend/nhóm đưa ra được (mục 1 và mục 5). Không có
yêu cầu nào đòi đổi mã backend để client chạy được. Mục 7 liệt kê vài lỗi mã tìm thấy trong lúc soát, để backend tự
xếp lịch.

---

## Tệp cần đọc

Mọi đường dẫn tính từ gốc repo, đã kiểm tồn tại ngày 2026-09-25. Số dòng là của bản `c47e6e2`.

**Tài liệu backend phải sửa:**

| Tệp | Chỗ | Mục của đơn |
|---|---|---|
| `docs/AI/LogicBusinessAI.md` | bảng 10 chức năng (dòng 30–39), §3.3, §3.4, §4 | 1, 2, 3, 4, 5 |
| `docs/AI/AI_ARCHITECTURE_DIAGRAM.md` | dòng 22, 30, 43, 60, 67, 80, 92, 94 | 6 |
| `Project.md` | §8.5 (dòng 1608–1617), §11.42 (dòng 2728–2729) | 1, 2, 3, 4 |
| `docs/AI/Classify.md` §1.3, `docs/AI/ORC.md` | ô trạng thái chức năng 1–3 | 4 |
| `docs/AI/AI_Edge-SLM.md/Client-app.md` | luật F1, **chỉ khi** chọn lối A | 1.3 |

**Mã client làm bằng chứng (chỉ đọc):**

| Tệp | Chứng minh điều gì | Mục |
|---|---|---|
| `src/Client-app/lib/core/di/injection_container.dart` (~dòng 549) | lối B: `BoDienGiai` không đăng ký, khối Nhận xét dùng mẫu câu | 2 |
| `src/Client-app/lib/features/ai_edge/data/bo_cong_cu.dart` | bảy tool chỉ đọc của Trợ lý AI trên máy | 1.1, 3 |
| `src/Client-app/lib/features/ai_edge/domain/canary_gpu.dart` | lùi từ GPU về CPU khi sập native | 2 |
| `src/Client-app/pubspec.yaml` | `flutter_gemma` 1.9.0 + `flutter_gemma_litertlm` 1.8.0 (LiteRT-LM) | 2 |
| `src/Client-app/lib/features/ai_edge/domain/tai_phan_bo.dart` (dòng 7–9) | luật C1–C7 có thật; Essentiality = 0,5; không có Welford | 3 |
| `src/Client-app/lib/features/category/data/services/category_suggestion_engine.dart` | tầng 1 phân loại đã chạy ở client | 4.1 |
| `src/Client-app/lib/features/budget/domain/cua_so_nhin_lai.dart` | cửa sổ cuộn thay "trượt 3 tháng" | 5 |
| `src/Client-app/lib/features/analytics/domain/dong_tien_tu_do.dart` (`thuNhapCua`), `khoan_vao_thong_ke.dart` | thu nhập ≠ tổng `type = 'thu'`; các khoản bị loại khỏi thống kê | 5 |

**Tài liệu client làm bối cảnh:** `docs/AI_EDGE_FEATURE.md` mục 10.3 (vì sao không huấn luyện mô hình) ·
`docs/AI_AGENT_ARCHITECTURE.md` mục 10.1 (hai mâu thuẫn F1).

**Mã backend liên quan tới mục 7** (lỗi phụ, backend tự xếp lịch):

| Tệp | Lỗi |
|---|---|
| `src/Backend/modules/ai/ai.controller.js` | route cũ `POST /api/ai/classify` luôn 500 |
| `src/Backend/modules/ai/features/classify/classify.service.js` | `category_id = 'unclassified'` |
| `src/Backend/modules/ai/features/classify/pipeline/nlp.matcher.js` | T2 đoán sai kiểu "chợ/cho" |
| `src/Backend/modules/ai/features/classify/pipeline/llm.classifier.js`, `src/Backend/modules/ai/config.js` | `OPENAI_API_KEY` đọc mà không dùng; `defaultProvider:'openai'` |
| `src/Backend/modules/ai/features/ocr/pipeline/vision.extractor.js` | ảnh gửi Gemini không che |
| `src/Backend/modules/ai/features/dedup/dedup.repository.js` | báo trùng giả khi ghi chú rỗng; so phân biệt hoa thường |
| `src/Backend/workers/bank.worker.js` | khoản chi lưu dạng âm, dedup so số dương |
| `src/Backend/utils/masking.util.js` | phạm vi của bộ che PII (chỉ văn bản) |

---

## 0. Tóm tắt

Phần lớn bảng 10 chức năng **khớp** với client: nguyên tắc giữ `GEMINI_API_KEY` ở backend, che PII trước khi gửi
Gemini, không đưa dữ liệu cá nhân vào vector DB, RAG chỉ cho kiến thức chung. Trạng thái của mục **5, 6, 8** cũng
đúng (dự báo 30 ngày ở `du_bao_dong_tien.dart`; `suggestAmount` với cửa sổ cuộn ≤ 90 ngày; `nguongChiLon`).

Chỗ lệch chia năm nhóm:

| # | Nhóm | Mức | Cần gì từ backend |
|---|---|---|---|
| 1 | Chatbot backend và cam kết F1 | quyết định | chọn một trong ba lối ở mục 1.3 |
| 2 | Mục 10 tả sai vai trò của mô hình trên máy | sửa chữ | thay câu, mục 2 |
| 3 | Trạng thái sai của mục 9 và 10 | sửa chữ | thay ô trạng thái, mục 3 |
| 4 | Mục 1, 2, 3 giao việc client chưa có kế hoạch làm | sửa chữ | thay ô trạng thái/trách nhiệm, mục 4 |
| 5 | Mục 7: gói số liệu client "gửi về định kỳ" | quyết định | chọn A hay B, mục 5 |
| 6 | Sơ đồ kiến trúc tự mâu thuẫn | sửa chữ | mục 6 |

Số dòng dưới đây là của bản `c47e6e2`. Dòng sẽ trôi sau mỗi lần sửa, nên xin `grep` theo cụm chữ.

---

## 1. Chatbot backend (chức năng 4) và cam kết F1: cần backend quyết định

### 1.1 Client đồng ý: chatbot backend vẫn làm

Nhóm client **không** xin bỏ chatbot backend. Nhưng bảng cần ghi thêm một điều: client **đã có** một trợ lý hỏi đáp
chạy trên máy. Đó là màn *Trợ lý AI* (`lib/features/ai_chat/`). Mô hình Gemma 4 E2B gọi **bảy tool chỉ đọc** trên
SQLite cục bộ và **chạy được khi không có mạng**. Nhóm chọn đặt trợ lý trên máy chính vì lý do ấy, không phải vì
F1. Hai trợ lý có thể cùng tồn tại (trên máy khi mất mạng, backend khi có mạng và cần RAG kiến thức chung). Nhưng
câu *"Trợ lý Tài chính … **Backend (100%)**"* ở `LogicBusinessAI.md:33` và `Project.md:1611` làm người đọc hiểu
rằng client không có trợ lý nào.

**Câu đề nghị cho ô "Nơi triển khai" của chức năng 4:**

> **Backend** (chatbot trực tuyến: function-calling + RAG kiến thức chung) · **Client-app** đã có trợ lý hỏi đáp
> chạy trên máy (Gemma 4 E2B + tool chỉ đọc trên SQLite, dùng được khi mất mạng; xem chức năng 10).

### 1.2 Mâu thuẫn với F1: client chỉ nêu, backend quyết

`LogicBusinessAI.md` §1 và §3.3 cùng lúc nói hai điều:

- Đưa xử lý lên client để *"bảo vệ quyền riêng tư … theo cam kết F1 và Nghị định 13/2023/NĐ-CP"*.
- Chatbot backend *"gọi các hàm domain … bằng `idaccount` từ JWT"* rồi dùng Gemini để trả lời.

Để Gemini viết được câu trả lời, **kết quả của các hàm ấy** (số chi theo danh mục, số dư, hoá đơn sắp tới, tên ví,
tên danh mục) phải nằm trong prompt gửi Google. Tức số liệu tài chính cá nhân **ra khỏi hạ tầng của nhóm**, sang
một bên thứ ba. `maskTransactionDescription` không giúp gì ở đây: nó che số thẻ, số điện thoại, số tài khoản trong
chuỗi mô tả, còn con số tiền và tên danh mục vẫn đi nguyên.

Hai đường khác trong mã hiện tại cũng nằm đúng chỗ này:

- **OCR gửi nguyên ảnh sang Gemini, không che gì** (`vision.extractor.js:103-128`). Ảnh biên lai chuyển khoản có
  họ tên, số tài khoản hai bên, mã giao dịch. `masking.util.js` chỉ áp cho văn bản ở tầng 3 phân loại.
- **Tầng 3 phân loại** gửi mô tả giao dịch (đã che PII) sang Gemini. Đây là mâu thuẫn ② ở mục 10.1 của
  `docs/AI_AGENT_ARCHITECTURE.md` phía client.

Hiện chưa có gì bị lộ, vì `.env` dev **không có** `GEMINI_API_KEY` (đo 2026-09-25). Tầng 3 và OCR chưa từng chạy
thật: OCR luôn trả 500 `CONFIG_MISSING`, phân loại không bao giờ qua tầng 2.

### 1.3 Ba lối, backend chọn

| Lối | Làm gì | Hệ quả |
|---|---|---|
| **A. Sửa F1** | F1 nói rõ: dữ liệu **ở trên máy** không rời máy; chatbot backend, OCR và tầng 3 là tính năng **trực tuyến** gửi dữ liệu cho Gemini, và người dùng được báo trước | giữ nguyên mã; phải sửa F1 ở `docs/AI/AI_Edge-SLM.md/Client-app.md` cùng các câu viện dẫn F1 trong `LogicBusinessAI.md` §1 |
| **B. Xin đồng ý** | Ba đường ấy chỉ chạy khi người dùng bật một công tắc riêng; mặc định tắt | client phải thêm màn/công tắc (khi ấy client sẽ đề nghị spec riêng) |
| **C. Giảm dữ liệu gửi đi** | Chỉ gửi số liệu đã gộp, không gửi tên ví, danh mục do người dùng đặt, ghi chú; OCR che vùng ảnh trước khi gửi | nhiều việc nhất; chất lượng câu trả lời giảm |

Client **không** đề nghị lối nào. Chỉ xin một điều: tài liệu đừng cùng lúc viện dẫn F1 và mô tả một đường gửi số
liệu cá nhân sang Gemini mà không nói hai thứ ấy khớp nhau thế nào.

---

## 2. Chức năng 10 (Edge AI) tả sai vai trò của mô hình

**Câu đang ghi** (`LogicBusinessAI.md:39`, `Project.md:1617`, `Project.md:2729`, và §4 mục 6 của `LogicBusinessAI.md`):

> Mô hình SLM cục bộ (Gemma 4 E2B, 2.41GB qua LiteRT/MediaPipe) chạy trên chip thiết bị (GPU/arm64-v8a) để **học
> hỏi thói quen** và **diễn giải tự nhiên cho "Gợi ý thiết lập ngân sách" và "Đề xuất điều chỉnh ngân sách"**.

**Mã client đang làm khác ở bốn chỗ:**

1. **Mô hình không diễn giải cho chức năng 6 và 9.** Ngày 2026-09-21 nhóm chốt *lối B*: mô hình phục vụ **đúng một
   chỗ**, là màn Trợ lý AI. Mọi khối *Nhận xét* (trang Ngân sách, Phân tích, Mục tiêu, Hoá đơn, Quản lý ví, Trang
   chủ) và thẻ *Đề xuất cân đối* vẫn dùng **mẫu câu viết sẵn**. Lối B được thi hành bằng cách **không đăng ký**
   `BoDienGiai` vào DI (`lib/core/di/injection_container.dart:549`). Lý do: đo trên máy thật, câu mô hình viết cho
   khối Nhận xét gần bằng mẫu câu (khác giọng văn, không khác thông tin), mà giá là ~2,3 s mỗi khối cộng tệp 2,41 GB.
2. **Không có "học hỏi thói quen".** Mô hình không được huấn luyện hay tinh chỉnh trên dữ liệu người dùng, và gói
   `flutter_gemma` không có API huấn luyện. Phần "cá nhân hoá" nằm ở **dữ liệu** mô hình đọc qua tool, không nằm ở
   trọng số (mục 10.3 `docs/AI_EDGE_FEATURE.md`).
3. **Engine là LiteRT-LM** (`flutter_gemma` 1.9.0 + `flutter_gemma_litertlm` 1.8.0), **không phải MediaPipe**.
4. **Chạy GPU hoặc CPU, không chỉ GPU.** Trên máy Mali (Realme, Dimensity 1100), nạp mô hình bằng GPU **sập native**.
   Client có một cơ chế canary (`lib/features/ai_edge/domain/canary_gpu.dart`): lượt sập đầu tiên đánh dấu máy, các
   lượt sau đi CPU. Máy không phải `arm64-v8a` (kể cả máy ảo) thì dùng mẫu câu.

**Câu đề nghị thay thế:**

> **AI Edge (On-Device SLM).** Mô hình Gemma 4 E2B (~2,41 GB, tệp `.litertlm`, engine LiteRT-LM qua `flutter_gemma`)
> chạy trên máy `arm64-v8a`: GPU khi được, lùi về CPU khi GPU sập, còn lại dùng mẫu câu. Mô hình phục vụ **màn Trợ lý
> AI**, trả lời câu hỏi bằng cách gọi tool chỉ đọc trên SQLite cục bộ, dùng được khi mất mạng, không gửi dữ liệu ra
> Internet. Các khối Nhận xét và đề xuất ngân sách dùng mẫu câu (quyết định "lối B" ngày 2026-09-21). Mô hình
> **không** được huấn luyện trên dữ liệu người dùng.

---

## 3. Trạng thái sai của chức năng 9 và 10

| Chức năng | Tài liệu ghi | Mã client hôm nay | Đề nghị |
|---|---|---|---|
| **9. Đề xuất điều chỉnh ngân sách** | 🟡 Đang làm | ✅ **Xong 2026-09-20** (P2 trọn 17 task): thẻ + sheet kế hoạch trên trang Ngân sách (nút Áp dụng đi qua `updateBudget` rồi đồng bộ lên PostgreSQL), thông báo `budgetRebalance` hằng tuần. Luật ở `lib/features/ai_edge/domain/tai_phan_bo.dart` | 🟢 Đã hoàn thành (Client-app) |
| **9.** chi tiết kỹ thuật | *"… thuật toán Welford O(1)"* | **Không có Welford** trong mã (`grep -ri welford src/Client-app/lib` → 0). Luật C1–C7 có thật. **Essentiality đang là hằng 0,5 cho mọi danh mục** (`tai_phan_bo.dart:7-9`) vì chưa có thống kê, nên xếp hạng nguồn bù quy về xếp theo dư địa; cờ "Cố định" (C2) là lớp bảo vệ của người dùng | bỏ chữ "Welford O(1)", hoặc ghi "dự kiến" |
| **10. AI Edge** | 🟡 Đang làm | ✅ **Chạy trong app** từ 2026-09-22 (trả lời bằng gói số), ✅ **gọi tool** từ 2026-09-23. Bảy tool chỉ đọc; bộ 34 câu đo trên máy thật qua cổng D ngày 2026-09-25 (0 câu trả lời sai số) | 🟢 Đang chạy; đang mở rộng phạm vi câu hỏi |

---

## 4. Chức năng 1, 2, 3 giao việc client chưa có kế hoạch làm

Ba ô ghi *"Client-app đang hoàn thiện …"*. Client đã khảo sát xem có làm ngay được không. Kết quả dưới đây, kèm
đề nghị sửa chữ để bảng không ghi một việc không ai đang làm.

### 4.1 Chức năng 1: phân loại giao dịch. T1 **đã xong** ở client; T2 **không làm**; client **không gọi** T3

- **Tầng 1 (từ khoá) đã chạy ở client từ trước:** `CategorySuggestionEngine`
  (`lib/features/category/data/services/category_suggestion_engine.dart`) trên bảng Drift `CategoryKeywords`. Nó so
  chuỗi con, còn dấu trước rồi mới bỏ dấu, và **hoà thì không đoán**. Kết quả hiện thành thẻ gợi ý ở màn Thêm giao
  dịch. Từ khoá đi qua đồng bộ bằng cột `category.Keyword`.
- **Tầng 2 (Jaccard) không đưa lên client, vì đã đo và nó đoán sai nhiều hơn đúng.** Cách đo: chép luật của
  `nlp.matcher.js:50-121` (token ≥ 2 ký tự, lấy max Jaccard còn dấu/bỏ dấu, `conf = 0,5 + 0,4·J`, nhận khi ≥ 0,60), chạy
  với **bộ từ khoá thật** của tài khoản 10 và 20 ghi chú thường gặp. Ở 11 câu mà T1 im, T2 đoán thêm 3 câu và **sai 2**:
  - *"đi chợ"* → **Cho vay**: "chợ" bỏ dấu thành "cho", trùng "cho vay", J = 0,33.
  - *"tiền nước"* → **Nhà cửa**: chung chữ "tiền" với từ khoá "tien nha", J = 0,25.
  - *"mua áo"* → Mua sắm (đúng).

  Với gợi ý danh mục, đoán sai tệ hơn im lặng: người dùng tin thẻ gợi ý rồi lưu nhầm. CSDL thật chưa đủ ghi chú do
  người dùng tự gõ để đo quy mô lớn (chỉ **1** câu, còn lại là ghi chú app tự sinh).
  ⚠️ **Phần này liên quan tới chính backend:** T2 đang chạy ở `classifyBatch` (OCR) và ở `bank.worker.js`. Kiểu sai
  *"chợ/cho"* sẽ xảy ra ở đó.
- **Client không gọi tầng 3.** Không có lời gọi nào tới `/api/ai/classify/*` trong `lib/`, và chưa lên lịch: vướng mục
  1.2 (F1), và `.env` dev không có key nên không nghiệm thu được.

**Câu đề nghị cho ô trạng thái chức năng 1:** *"🟢 T1 chạy ở Client-app (`CategorySuggestionEngine`) · T2 không đưa
lên client (đo: đoán sai 2/3) · T3 có ở Backend, client chưa gọi."*

### 4.2 Chức năng 2: OCR. Client **chưa có dòng mã nào**, chưa lên lịch

`grep -ril ocr src/Client-app/lib` chỉ ra tên hai sự kiện socket (`ocr.completed`, `ocr.duplicate`) và chú thích.
Không có màn chụp ảnh, không có gói chọn ảnh, không có lời gọi `/api/ai/ocr/parse`. Trong lộ trình client, "chụp
hoá đơn" là **bước 6**, sau nhập giao dịch bằng câu. Muốn làm sớm hơn thì còn bốn điều kiện chưa có:

1. `GEMINI_API_KEY` trên môi trường dev. Thiếu key, endpoint luôn trả 500 `CONFIG_MISSING`, không nghiệm thu được.
2. Quyết định ở mục 1.2 (ảnh gửi Gemini không che gì).
3. Thiết kế màn trên Stitch (quy ước của client: màn mới phải có thiết kế trước).
4. Chống quét trùng cần `provider` + `bank_tran_id` đi qua đồng bộ. Hai trường này hiện **cố ý không** nằm trong payload
   (từ khi bỏ liên kết ngân hàng 2026-09-18). Mở lại là một quyết định riêng.

**Câu đề nghị:** *"⬜ Client-app chưa làm (lộ trình bước 6) · Backend đã có `POST /api/ai/ocr/parse`."*

### 4.3 Chức năng 3: khử trùng lặp. Client **không có nguồn dữ liệu** để khử

`LogicBusinessAI.md:77` ghi client khử trùng *"khi nhận dữ liệu từ SMS hoặc nhập hóa đơn"*, theo `bank_tran_id`. Cả
ba mảnh đều không có:

- **Client không đọc SMS** (không có quyền `READ_SMS`, không có mã). Google Play cũng hạn chế quyền này rất chặt.
- **Liên kết ngân hàng đã bỏ** (chính `ORC.md` bản `c47e6e2` ghi *"Module Bank tạm dừng hoàn toàn"*).
- **`bank_tran_id` không đi qua đồng bộ.**

Nguồn trùng lặp duy nhất còn lại là OCR (quét lại cùng một biên lai), và mã dedup của backend hiện cũng chỉ được
`ocr.service.js:83` gọi. Vì thế dedup phía client chỉ có nghĩa **khi và nếu** client làm OCR (mục 4.2), và nên được
đặc tả cùng lúc với nó. Tới lúc ấy, giữ dedup ở backend (nơi đã có mã và đã được `ocr.service` gọi) có lẽ đơn giản
hơn chuyển sang client. Nhóm sẽ bàn khi viết spec OCR.

**Câu đề nghị:** *"⬜ Chưa làm. Chỉ cần khi có OCR phía client; quyết định nơi chạy (client hay backend) cùng spec
OCR. Kênh ngân hàng và SMS đã bỏ."*

---

## 5. Chức năng 7 (sức khoẻ tài chính): cần backend chọn A hay B

`LogicBusinessAI.md:36` và `:64-68` ghi: *"Client-app đóng gói định kỳ gói số liệu tổng hợp (tổng thu, tổng chi
theo nhóm, tỷ lệ tiết kiệm trượt 3 tháng) gửi về Backend."* Client đã khảo sát. Việc đóng gói **làm được về kỹ
thuật**, nhưng có ba vấn đề phải giải trước:

1. **Server đã có đủ dữ liệu.** Mọi giao dịch, ví, ngân sách, mục tiêu, hoá đơn đều đồng bộ lên PostgreSQL. Client
   đóng gói rồi gửi về tức là có **hai định nghĩa** của cùng một con số (tổng thu, tổng chi) ở hai đầu, và chúng sẽ
   lệch nhau. Client đã vấp đúng kiểu lệch này: *thu nhập* **không phải** tổng các khoản `type = 'thu'`, vì con số ấy
   gồm cả tiền **đi vay** và **thu nợ** (luật ở `lib/features/analytics/domain/dong_tien_tu_do.dart`, hàm `thuNhapCua`).
   Khoản chuyển ví, khoản điều chỉnh số dư và khoản mở sổ cũng phải bị loại (`khoan_vao_thong_ke.dart`).
2. **"Trượt 3 tháng" theo tháng lịch là một cửa sổ đã chết.** Giao dịch sớm nhất trong toàn bộ CSDL là **02/09/2026**.
   Client đã dùng đúng kiểu cửa sổ ấy cho gợi ý hạn mức và phép neo theo thu nhập, và **cả hai cho 0 trên mọi tài
   khoản** cho tới 2026-09-21. Client đổi sang cửa sổ cuộn `[max(now − 90 ngày, giao dịch đầu tiên), now)`, dưới 14 ngày
   thì im (`lib/features/budget/domain/cua_so_nhin_lai.dart`). Phía nào tính tỉ lệ tiết kiệm thì cũng cần luật này.
3. **50/30/20 cần nhãn "thiết yếu / mong muốn" cho từng danh mục, và cả hai đầu đều chưa có.** Essentiality phía
   client đang là hằng 0,5 (mục 3). Không có nhãn này thì điểm 50/30/20 chỉ có thể là số bịa.

**Hai lối, backend chọn:**

| Lối | Làm gì | Client phải làm |
|---|---|---|
| **A (client đề nghị)** | Backend tự tính từ PostgreSQL mà nó đã có; client chỉ gọi `GET` để hiển thị kết quả | không làm gì cho tới khi có endpoint; khi có thì thêm màn hiển thị |
| **B** | Giữ như tài liệu: client đóng gói | backend công bố **schema từng trường** (tên, kiểu, đơn vị, định nghĩa từng con số, cửa sổ thời gian) trước khi client viết mã. Hiện chưa có schema ở đâu cả; `modules/ai/features/advisory/` chưa tồn tại |

Theo chính nguyên tắc §1.1 của `LogicBusinessAI.md` (phần thuật toán/thống kê đặt ở client), phần **chấm điểm**
cũng có thể chạy trên máy, và backend chỉ giữ phần LLM viết lời khuyên. Nếu nhóm muốn lối ấy, client sẽ viết spec
riêng. Nhưng vướng điểm 3 ở trên vẫn còn nguyên.

---

## 6. Sơ đồ kiến trúc (`AI_ARCHITECTURE_DIAGRAM.md`) tự mâu thuẫn

| Dòng | Sơ đồ vẽ | Thực tế / văn bản cùng commit | Đề nghị |
|---|---|---|---|
| **43**, **80** | Mũi tên client → gateway: *"Gửi ảnh biên lai & **Text đã lọc PII**"* | Việc che PII chạy ở **backend** (`llm.classifier.js:97-98` gọi `maskTransactionDescription`); client gửi văn bản thô qua HTTPS. **Ảnh thì không bị che ở đâu cả** (mục 1.2) | *"Gửi ảnh biên lai & văn bản (HTTPS)"*; đặt nhãn "che PII" ở hộp Gateway, và ghi rõ chỉ áp cho văn bản |
| **30**, **67**, **94** | *"**3** Dịch Vụ AI Cốt Lõi"*: OCR, Classifier, Assistant | `LogicBusinessAI.md` §1.2 và `Project.md` §8.5.2 nói backend giữ **4** tác vụ; thiếu **Đánh giá sức khoẻ tài chính** | thêm hộp thứ tư, hoặc ghi chú rằng nó chưa có mã |
| **22**, **60**, **92** | Hộp Edge AI: *"Gemma 4 E2B + Hệ luật — **Dự báo dòng tiền & Tái phân bổ**"* | Dự báo và tái phân bổ là **hệ luật thuần**, không dùng mô hình. Mô hình phục vụ **Trợ lý AI** (mục 2) | *"Hệ luật: dự báo dòng tiền, tái phân bổ, nhận xét · Gemma 4 E2B: Trợ lý AI (tool chỉ đọc, offline)"* |
| — | Mọi LLM đi qua Gemini | Đúng. Riêng `llm.classifier.js:17` còn đọc `OPENAI_API_KEY` mà không dùng, và `config.js:18` ghi `defaultProvider:'openai'` | (tuỳ backend) dọn hai dòng ấy để sơ đồ và mã nói cùng một điều |

---

## 7. Lỗi mã backend tìm thấy trong lúc soát (không chặn client hôm nay)

Client chưa gọi các endpoint này, nên không cái nào chặn client. Ghi lại để backend tự xếp lịch:

1. **`POST /api/ai/classify` (route cũ) luôn trả 500:** `ai.controller.js:21` gọi `classifyController.handleClassify`,
   hàm này không tồn tại.
2. **Nhóm OCR có thể mang `category_id = 'unclassified'`** (`classify.service.js:386`). Chuỗi này không phải UUID;
   client nào ghi thẳng nó vào `transaction.Idcategory` sẽ vỡ khoá ngoại.
3. **Dedup quy tắc 2 báo trùng giả khi ghi chú rỗng:** `normalizedMerchant.includes('')` luôn đúng
   (`dedup.repository.js:119-121`), nên mọi khoản cùng số tiền, cùng ngày, cùng provider đều bị coi là trùng. Phép so
   còn phân biệt hoa thường (bỏ dấu nhưng không hạ chữ thường).
4. **Dedup quy tắc 2 và 3 so số tiền dương đúng từng đồng**, trong khi `bank.worker.js:194` lưu khoản chi dạng **âm**.
   Còn giao dịch client đẩy lên thì được `sync.service` gắn dấu theo `type`. Cần kiểm lại khoản chi có bao giờ khớp.
5. **`existing_transaction.note`** trong body 409 và payload socket `ocr.duplicate` lấy thẳng từ CSDL, nên có thể là
   **bản mã AES** chứ không phải chữ đọc được.
6. **Tầng 2 phân loại đoán sai kiểu *"chợ/cho"***, xem mục 4.1. Đang chạy thật ở `bank.worker.js` và `classifyBatch`.

---

## 8. Nghiệm thu

Sau khi sửa, các lệnh dưới đây phải ra **0 dòng**:

```bash
grep -n "học hỏi\|MediaPipe\|Welford" docs/AI/LogicBusinessAI.md Project.md
grep -n "Text đã lọc PII\|Text đã Mask PII" docs/AI/AI_ARCHITECTURE_DIAGRAM.md
grep -n "đang hoàn thiện T1/T2\|đang hoàn thiện giao diện" docs/AI/LogicBusinessAI.md Project.md
```

Và hai quyết định (mục 1.3, mục 5) được ghi vào `LogicBusinessAI.md` kèm ngày chốt.
