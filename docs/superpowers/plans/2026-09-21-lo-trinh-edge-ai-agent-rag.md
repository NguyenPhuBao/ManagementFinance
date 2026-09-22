# Lộ trình Edge AI → Agent → RAG · kế hoạch tổng

> **Đây là lộ trình, không phải kế hoạch thi công.** Nó xếp thứ tự các kế hoạch con, nêu **cổng
> kiểm** giữa các chặng, và ghi rõ chặng nào đã có kế hoạch chi tiết, chặng nào **cố ý chưa viết**
> vì phụ thuộc kết quả đo của chặng trước. Người thi công đi từ trên xuống, không nhảy chặng.
>
> Viết ngày **2026-09-21**, sau cuộc trao đổi về kiến trúc (`docs/AI_AGENT_ARCHITECTURE.md`).
> Bắt đầu thi công: **2026-09-22**.

> 🛑 **BẪY ĐÁNH SỐ — đọc trước khi làm bất cứ việc gì theo số chặng.** Dự án có **hai** hệ
> "chặng" khác nhau và chúng **lệch nhau**: tệp này (lộ trình kiến trúc) đánh 1–6, còn
> `2026-09-21-ai-viec-tiep-theo.md` (việc theo tính năng) đánh 0–5 theo nghĩa khác.
> *"Chặng 2"* ở đây là **P3**, ở tệp kia là **function calling**; *"chặng 4"* ở đây là
> **tool-calling**, ở tệp kia là **P3**. Bảng đối chiếu đầy đủ nằm ở đầu tệp kia.
>
> **Trạng thái 2026-09-22 (tối muộn):** chặng 1 ✅ · chặng 2 ✅ (P3 xong 10/10 task) ·
> ✅ **CỔNG A ĐÃ QUA** — việc số 1 của thứ tự thi công (chặn theo câu, `kiemNhan`, sáu gói số,
> bốn chip theo gói) xong tối 2026-09-22, đo trên máy thật: bảng ở mục **9.9**
> `docs/AI_EDGE_FEATURE.md`. ✅ Việc số 2 (**tải nền + resume**, 7 task) cũng xong cùng tối,
> nghiệm thu trên máy thứ hai — Realme RMX2205, mục **9.10**.
> ✅ **Chặng 3 XONG cùng tối — CỔNG B QUA.** Đo 20 câu trên **Realme RMX2205** (CPU), tài khoản
> thật: **✅ 5 · rơi mẫu 3 · sai 0 · lệch câu hỏi 12**. Bảng đầy đủ + đơn đặt hàng **sáu** tool
> ở mục **5.6** `docs/AI_AGENT_ARCHITECTURE.md`.
> **Việc tiếp theo: chặng 4** (tool-calling + vòng lặp) — kế hoạch viết tại cổng B, tức bây giờ.
> Chặng 5 🛑 **bỏ** (M4 trả lời KHÔNG, 2026-09-22).
> Chặng 6 ✅ NPBao đã chốt lối ① cùng ngày.
>
> *(Câu cũ ở đây — "🛑 CỔNG A CHƯA QUA: điểm 2 chưa có, điểm 4 đang hỏng, điểm 5 chưa đo" — là
> ảnh chụp buổi chiều cùng ngày, trước khi việc số 1 đóng cả ba điểm ấy.)*

**Goal:** Từ hệ luật đang chạy, đi tới một hệ thống mà ba câu sau **đều đúng và kiểm được**:
*"dùng Edge AI"*, *"là AI Agent"*, *"có áp dụng RAG"* — mà không phá bất biến *mô hình không bịa số*.

**Kiến trúc đích:** `docs/AI_AGENT_ARCHITECTURE.md` — ba vòng (tất định ✅ / SLM 📝 / agent ⬜),
bốn bất biến, ranh giới **văn bản vs số** giữa backend và client.

## Quyết định đã có (không hỏi lại)

| Quyết định | Ai / khi nào |
|---|---|
| Gemma 4 **E2B cho mọi máy**, bỏ E4B | người dùng, 2026-09-20 |
| **Lối B**: mô hình chỉ ở màn Trợ lý AI; sáu khối Nhận xét giữ mẫu câu | người dùng, 2026-09-20 |
| Ưu tiên **giá trị người dùng** hơn phần demo — nhưng RAG/Agent là **yêu cầu của môn**, nên làm, theo thứ tự de-risk dưới đây | người dùng, 2026-09-21 |
| Client **vẫn làm P3** (cách hiểu (b)); RAG phía client làm nếu spike cho phép | suy từ câu *"làm cả hai bước"* 2026-09-21 — ⚠️ chưa chốt tường minh, xem "Còn mở" |
| Backend làm RAG cho **văn bản không thuộc về một người**; client giữ **số của người dùng** | ✅ **NPBao đã chốt lối ① ngày 2026-09-22** (`b147fee`): dữ liệu tài chính người dùng **không** index lên vector DB server — `Standard_RAG.md` §6 đã sửa; số liệu cá nhân đi bằng **function-calling**. Tài liệu xin nay ở `DA-XONG/EDGE_AI_THUAT_NGU_VA_HAI_MAU_THUAN.md` |

## Còn mở — trả lời trước khi tới chặng tương ứng

| # | Câu hỏi | Chặn chặng | Mặc định nếu không trả lời |
|---|---|---|---|
| M1 | Đổi cách gọi sang "Edge AI" ở văn bản, giữ tên thư mục mã? | 1 (Task 4) | **Có** — làm theo (a) |
| M2 | Xác nhận cách hiểu (b): client vẫn thi công P3? | 2 | **Có** |
| M3 | Luật ngủ đông (essentiality = 0,5; C4 bị C5 nuốt): thi công thật hay bỏ vế? | 4 | **Bỏ vế**, ghi lý do |
| M4 | ~~RAG client có đáng làm không~~ — ✅ **ĐÃ TRẢ LỜI 2026-09-22: KHÔNG**, chuyển sang backend RAG (chặng 6). Bảng đo ở mục **5.5** `AI_AGENT_ARCHITECTURE.md`: mô hình tải tự do duy nhất là English-only (top-3 **3/5** trên tiếng Việt), mọi bản đa ngữ **gated 401**, truy vấn **251 ms** so với ngưỡng 200 ms | ~~5~~ | — |

---

## Sơ đồ phụ thuộc

```
Chặng 1 ── chặn lỗi + tài liệu + spike RAG ──────────────── độc lập, làm ngay
   │        (kế hoạch: 2026-09-21-chan-loi-va-tai-lieu-truoc-p3.md)
   │
   ▼
Chặng 2 ── P3: cắm SLM ─────────────────────────────────── kế hoạch có sẵn
   │        (2026-09-20-ai-edge-p3-cam-slm.md, đã vá Task 1 & 6 ở chặng 1)
   │
   ├─► CỔNG A: "dùng Edge AI" thành ĐÚNG (nghiệm thu máy thật, 5 điểm)
   │
   ▼
Chặng 3 ── đo: câu hỏi nào bậc 1 trả lời KHÔNG nổi ────── 1 buổi, dữ liệu thật
   │
   ├─► CỔNG B: danh sách câu hỏi hỏng thật → thiết kế tool từ đó
   │
   ▼
Chặng 4 ── vòng 3: tool-calling + vòng lặp ─────────────── kế hoạch VIẾT TẠI CỔNG B
   │
   ├─► CỔNG C: "là AI Agent" thành ĐÚNG
   │
   ▼
Chặng 5 ── RAG client: traCuuKienThuc ─────────────────── kế hoạch VIẾT SAU SPIKE (M4)
   │
   └─► CỔNG D: "có áp dụng RAG" thành ĐÚNG

Song song, ngoài tay client:
Chặng 6 ── backend RAG (NPBao) ── đầu vào: DA-XONG/EDGE_AI_THUAT_NGU_VA_HAI_MAU_THUAN.md ✅ chốt ①
```

---

## Chặng 1 — Chặn lỗi, tài liệu, spike RAG

**Kế hoạch chi tiết:** `docs/superpowers/plans/2026-09-21-chan-loi-va-tai-lieu-truoc-p3.md` (6 task).

| Task | Việc | Vì sao ở đây |
|---|---|---|
| 1 | `kiemGiong` — bộ kiểm giọng; **vá kế hoạch P3** Task 1 (prompt mang MỨC) và Task 6 (gọi sau `kiemSo`) | Lỗ hổng "đủ số đúng, sai nghĩa" phải đóng **trước** ngày mô hình lên; sửa kế hoạch rẻ hơn sửa mã |
| 2 | Nói ra "cần thêm N ngày dữ liệu" (thẻ + nhãn form) | Im lặng là thứ che `suggestAmount` chết hai tuần |
| 3 | `test/tool/kiem_csdl_that_test.dart` — phép kiểm trên SQLite thật | Bộ test mù với đầu vào chết |
| 4 | Thuật ngữ **Edge AI**; mục 1.2 kiến trúc | Người dùng đã vấp thật với "thập niên 1980" |
| 5 | CAN-LAM cho NPBao: tên gọi + hai mâu thuẫn (F1 vs §6; tầng 3 classifier) | Chỉ backend quyết được; client không sửa backend |
| 6 | **Spike RAG on-device** — đo mô hình embedding + kho vector | Trả lời M4 bằng số, trước khi viết kế hoạch chặng 5 |

**Ước lượng:** 1,5 ngày (Task 1–5 một ngày; Task 6 nửa ngày, cần máy thật).
**Cổng ra:** `flutter test` 3265/3265 · analyze 26 · nghiệm thu máy ảo Task 2 · bảng đo 5.5 có số.

## Chặng 2 — P3: cắm SLM

**Kế hoạch chi tiết:** `docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md` (10 task) —
**đã vá** ở chặng 1: Task 1 có `_dongMuc`, Task 6 gọi `kiemGiong`.

🚧 **Tiến độ: xong Task 0–7 / 10 (2026-09-22).** Còn **Task 8** (màn Trợ lý AI, đóng A11) và
**Task 9** (nghiệm thu máy thật + bảng đo P3 → **cổng A**). ⚠️ Kế hoạch ấy nay có thêm mục *"Ba
chỗ kế hoạch này lệch mã thật"* ở cuối — **hai chỗ đầu tái phát ở Task 8**, đọc trước khi làm.

**Điều kiện vào:** M2 = có. Điện thoại arm64 thật nối được `adb` (kiểm **trước** ngày bắt đầu,
không phải ngày nghiệm thu — bẫy driver `DeviceInterfaceGUIDs`, mục "Chạy trên MÁY THẬT" `CLAUDE.md`).

**Ước lượng:** 3–4 ngày (P2 17 task mất hai ngày; P3 10 task nhưng có phần native + tải 2,41 GB).

**CỔNG A — "dùng Edge AI" thành đúng.** Năm điểm, **trên máy thật**, không phải `flutter test`:

1. Màn Cài đặt AI báo mô hình đã tải, đúng dung lượng.
2. Hỏi ở màn Trợ lý AI → chữ **hiện dần** (streaming), không bật ra nguyên khối.
3. Logcat có dòng nạp mô hình và thời gian sinh ≈ 2,3 s (E2B/GPU).
4. Hỏi câu mà gói số **không có** con số → **rơi về mẫu câu**, không bịa (`kiemSo` sống).
5. Hỏi câu ở mức cảnh báo, mô hình trấn an → **rơi về mẫu câu** (`kiemGiong` sống — mới từ chặng 1).
6. Chế độ máy bay → vẫn trả lời (suy luận cục bộ).

Quay video 4, 5, 6 — đó là ba bằng chứng *đúng*, *đúng giọng*, *đúng nghĩa Edge*.

> ✅ **CỔNG A QUA 2026-09-22 tối** — sáu điểm đo trên OnePlus 13R, bảng ở mục **9.9**
> `docs/AI_EDGE_FEATURE.md` (điểm 2 bằng ảnh chụp liên tiếp thay video; điểm 4 = không bịa nhưng
> mô hình chọn số liên quan thay vì nói "không có dữ liệu"). Theo thứ tự ở đầu
> `2026-09-21-ai-viec-tiep-theo.md`, việc kế là **tải nền + resume** rồi mới **chặng 3**.

## Chặng 3 — Đo: bậc 1 hỏng ở đâu (cổng B)

**Không phải task mã.** Một buổi, trên máy thật với tài khoản thật (39 giao dịch, 20 ngày):

1. Soạn **20 câu hỏi** người dùng thật sẽ hỏi (5 về ngân sách, 5 về chi tiêu theo kỳ tuỳ ý,
   5 về mục tiêu/hoá đơn, 5 cần ghép nhiều nguồn — ví dụ *"tháng này tôi tiêu cho ăn uống nhiều
   hơn tháng trước bao nhiêu?"*).
2. Hỏi từng câu ở màn Trợ lý AI bậc 1 (P3). Ghi: trả lời được / rơi về mẫu / trả lời sai.
3. Với mỗi câu **hỏng**, ghi **con số nào thiếu trong sáu gói số** — đó là tool cần có.

**Đầu ra:** bảng 20 hàng trong `docs/AI_AGENT_ARCHITECTURE.md` mục mới **5.6**, và danh sách tool
**rút từ bảng** (không phải từ mười tool đoán sẵn ở mục 5.1 — mười tool ấy là *ứng viên*, bảng đo
mới là *đơn hàng*).

⚠️ Đây là bài học lát "cửa sổ nhìn lại": một hàm đúng từng dòng mà đầu vào chết thì vẫn vô dụng.
Dựng 10 tool rồi thấy 7 cái không ai gọi là cùng lớp lãng phí.

**Ước lượng:** nửa ngày. **Cổng B:** bảng 20 hàng có số, và ≥ 1 câu hỏng thật (nếu **0** câu hỏng
→ vòng 3 **không có việc**, dừng lộ trình ở đây và báo — đó cũng là một kết quả).

## Chặng 4 — Vòng 3: tool-calling + vòng lặp (cổng C)

**Kế hoạch chi tiết: VIẾT TẠI CỔNG B**, không viết trước — vì (1) danh sách tool đến từ bảng đo,
(2) `SlmRuntime` của P3 hiện là `Future<String> sinh(String prompt)` — **một lượt**, không có hội
thoại/tool; vòng 3 phải **thêm** một phương thức (dùng `InferenceChat` + `generateChatResponseWithTools()`),
và hình dạng chính xác chỉ biết sau khi P3 đã chạy trên máy thật.

**Khung cố định** (để người viết kế hoạch ở cổng B không thiết kế lại từ đầu):

| Thành phần | Ràng buộc |
|---|---|
| Khai báo tool | `Tool{name, description, parameters}` của gói; Gemma 4 dùng `tools_json` native (`SdkPassthroughFunctionCallFormat`) |
| Kết quả tool | **`List<SoLieu>`**, không văn bản — bất biến ② `AI_AGENT_ARCHITECTURE.md` mục 6 |
| Gói số | **tích luỹ** qua các lượt gọi; `kiemSo`/`kiemGiong` chạy trên gói tích luỹ |
| Trần | tối đa **3** lượt gọi tool; hết trần → mẫu câu (nhánh lùi thứ sáu) |
| `ToolChoice` | `auto` (mặc định) |
| Test quét | chỉ `slm_runtime.dart` import `flutter_gemma` — **giữ nguyên** (test quét thứ 16 của P3) |
| Chiều ghi | **không có tool ghi** ở chặng này (bất biến ④) |
| Luật M3 | trước khi viết kế hoạch, chốt essentiality/C4 — vì tool `budgetPaceOf`/tái phân bổ sẽ lộ luật ngủ đông ra câu trả lời |

**Ước lượng:** 2 ngày (≈ 4 task). **Cổng C:** một câu trong bảng 5.6 từng **hỏng ở bậc 1** nay
**trả lời đúng** trên máy thật, logcat cho thấy đúng tool được gọi; và câu bịa số vẫn bị chặn.

## 🛑 Chặng 5 — RAG client: KHÔNG LÀM (quyết định 2026-09-22)

**Spike đã chạy trên máy thật và M4 trả lời KHÔNG** — bảng đo mục **5.5**
`docs/AI_AGENT_ARCHITECTURE.md`. Kiến thức chung chuyển sang **backend RAG** (chặng 6); client
gọi một endpoint. Câu *"có áp dụng RAG"* vẫn đúng, chỉ là đúng ở phía server, và đó cũng là lối
client thích hơn vì corpus cập nhật được mà không phải phát hành bản mới.

Phần dưới **giữ nguyên làm hồ sơ thiết kế** — đọc nếu có ngày quyết định ấy được mở lại (chẳng
hạn khi có mô hình embedding đa ngữ **không gated** ở định dạng LiteRT).

## ~~Chặng 5~~ — RAG client: `traCuuKienThuc` (cổng D)

**Kế hoạch chi tiết: VIẾT SAU SPIKE** (chặng 1 Task 6) — vì tên/dung lượng mô hình embedding, và
API thật của `flutter_gemma_rag_sqlite`, chỉ biết sau khi đo.

**Điều kiện vào:** M4 = *đáng làm*, tức bảng đo 5.5 cho: tổng tải về chấp nhận được, truy vấn dưới
~200 ms, top-3 đúng ≥ 4/5. Nếu không → chuyển **kiến thức chung sang backend RAG** (chặng 6) và
client chỉ gọi một endpoint; câu *"có áp dụng RAG"* vẫn đúng, chỉ là đúng ở phía server.

**Khung cố định:**

| Thành phần | Ràng buộc |
|---|---|
| Corpus | kiến thức tài chính **chung**, không dữ liệu cá nhân; đóng gói asset, nhúng sẵn lúc build |
| Kho vector | `flutter_gemma_rag_sqlite` (cùng nền SQLite của app) — **không** tự viết cosine nếu gói dùng được |
| Tool | `traCuuKienThuc(cau)` trả `List<SoLieu>`? — **không**: kiến thức chung là *văn bản*, không phải số. Trả `List<String>` đoạn trích, và **prompt tách rõ** *"đoạn trích"* với *"số liệu"*; `kiemSo` vẫn chỉ kiểm phần số |
| Ghi chú cá nhân (`transaction.Note`) | **không** index ở chặng này — 39 dòng × 39 byte; `LIKE` đủ (mục 9.1 kiến trúc) |

**Ước lượng:** 2 ngày (≈ 4 task). **Cổng D:** hỏi *"quy tắc 50/30/20 là gì?"* → câu trả lời dẫn
đúng đoạn corpus; hỏi *"tôi có đang theo 50/30/20 không?"* → câu ghép **đoạn trích + số liệu cá
nhân**, số qua `kiemSo`.

## Chặng 6 — Backend RAG (NPBao, ngoài tay client)

Đầu vào duy nhất từ client: `DA-XONG/EDGE_AI_THUAT_NGU_VA_HAI_MAU_THUAN.md` (chặng 1 Task 5;
tệp đặt vào `CAN-LAM/` ngày 2026-09-22 và **đóng cùng ngày**, nên nay nằm ở `DA-XONG/`).
Client **không** viết kế hoạch cho phần này.

✅ **NPBao đã chốt lối ① ngày 2026-09-22** — mục "Quyết định đã có" ở trên đã cập nhật theo.
Không còn gì phải chờ ở mâu thuẫn ①.

---

## Sổ cái tuyên bố — câu nào đúng từ cổng nào

| Câu | Đúng từ | Điều kiện |
|---|---|---|
| "Có guardrail chống bịa số" | ✅ **hôm nay** | — |
| "Có guardrail chống diễn giải sai" | chặng 1 | Task 1 xanh + P3 nối |
| "Dùng Edge AI / SLM on-device" | **cổng A** | arm64 đã tải mô hình; máy ảo luôn rơi về mẫu |
| "Là AI Agent" | **cổng C** | — |
| "Có áp dụng RAG" | **cổng D** (client) hoặc chặng 6 (server) | theo M4 |
| "Hệ thống chia theo loại dữ liệu: server biết tiền nói chung, máy biết tiền của bạn" | chặng 6 chốt (A) | NPBao |

## Lịch dự kiến

| Ngày | Chặng |
|---|---|
| 22/09 | Chặng 1 Task 1–5 |
| 23/09 sáng | Chặng 1 Task 6 (spike, cần máy thật) |
| 23/09 chiều → 26/09 | Chặng 2 (P3) → **cổng A** |
| 27/09 sáng | Chặng 3 → **cổng B** |
| 27/09 chiều | Viết kế hoạch chặng 4 (và chặng 5 nếu M4 = có) |
| 28–29/09 | Chặng 4 → **cổng C** |
| 30/09–01/10 | Chặng 5 → **cổng D** |

⚠️ Lịch giả định máy thật nối được ngay. Kiểm `adb devices` **ngày 22/09**, không phải 23.

## Nếp chung cho mọi chặng

- Mỗi hạng mục: TDD, bản sai có chủ ý, `flutter test` + `flutter analyze` đối chiếu mức nền,
  commit, **rồi soát tài liệu** (`grep` tên tính năng trên toàn `docs/`), rồi mới hỏi push.
- Mọi con số vào tài liệu **đếm bằng máy**, kèm ngày.
- Đụng giao diện → nghiệm thu máy ảo 411dp; đụng mô hình → máy thật arm64. `flutter test` mù với
  cả hai.
- Không đổi schema (v24), không thêm trường đồng bộ, không đụng `src/Backend`.
