# Client đã tích hợp trợ lý online (`POST /api/ai/chatbot/chat/stream`) — năm chỗ cố ý không làm theo `ChatbotAI_Moblie.md`, ba điều client phải bù, và việc xin backend (mục 47)

**Ngày:** 2026-10-17 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat`
**Loại:** đơn **thông báo + xin** — mức **vừa** (thiếu một tên mô hình Gemini đã kiểm thì đường online chưa bao giờ trả lời
thật; client tự rơi về AI trên máy nên không chặn ai). **Không** đổi lược đồ, **không** đổi payload `/sync/*`, **không** cần
migration. Mọi khẳng định về backend dưới đây đo bằng **đọc mã** (HEAD `fb92c16d`; ba tệp
`modules/ai/features/chatbot/chatbot.{service,controller,validation}.js` đổi lần cuối ở `e497695e`, 2026-09-27; gói
`@google/generative-ai` khai `^0.24.1` trong `package.json`). Client không chạy backend, không sửa `src/Backend`.

## Vì sao client gửi đơn này

`docs/AI/ChatbotAI_Moblie.md` (2026-09-26) giao client dựng *chế độ trực tuyến* cho màn Trợ lý AI. Ngày 2026-10-11 người dùng chốt
tích hợp **hỗn hợp**: có mạng thì hỏi backend, hỏng hoặc mất mạng thì AI trên máy (Gemma) trả lời cùng câu. Client **thi công
xong 2026-10-17** (22 commit `80d9dee8` → `fb92c16d`; spec
`docs/superpowers/specs/2026-10-11-tro-ly-online-backend-fallback-tren-may-design.md`, mục 10 ghi chỗ mã khác spec). Đơn này
(1) báo hình dạng client đang gọi để backend đổi gì thì biết đụng ai, (2) nêu năm chỗ client cố ý không làm theo tài liệu bàn
giao, (3) nêu ba hành vi của mã backend client đã phải bù, (4) xin năm việc. ⚠️ **Chưa nghiệm thu đầu-cuối**: backend dev chưa
khởi động được sau lượt gộp `d72ccd45` (đơn 44 — cần `npm install` và hai tệp `database/20`, `database/24` thanh toán), nên mọi
hành vi dưới đây đo bằng test client với máy chủ giả.

## Client gọi gì (hiện trạng mã)

- `POST {baseUrl}/ai/chatbot/chat/stream` qua Dio chung của app (`sl<DioClient>().dio`) — `AuthInterceptor` gắn Bearer; 401 thì
  làm mới token rồi **phát lại trọn request** (giữ `responseType: stream`, `receiveTimeout`, `cancelToken`, header).
- Header `Accept: text/event-stream`; thân `{"message", "conversationId" (UUID v4, một lần mỗi lần mở màn), "history": [{"role":
  "user"|"model", "text"}, … ≤ 6]}`. `receiveTimeout` **45 s** (khoảng lặng giữa hai gói). Câu > 2000 ký tự **không** cắt ở client
  — nhận 400 rồi rơi về máy.
- Ánh xạ khung SSE: `delta` → nối `data.text` (rơi về `content`); `done {fallback: true}` → rơi về máy; `done {error}` → rơi về máy;
  `done {}` khác → xong; `error` → lỗi; `meta` → chỉ log `snapshotLoaded`, `healthScore` (bỏ `snapshot`).
- HTTP 403 `FEATURE_DISABLED` → rơi về máy + client đọc lại gói; 429, 503, 5xx, mất mạng, hết 45 s → rơi về máy. Rơi **trước chữ
  đầu**: cùng câu đi Gemma, nhãn *"AI trên máy · máy chủ không phản hồi"*; đứt **giữa dòng**: giữ phần đã hiện, nhãn *"Trợ lý online
  · kết nối gián đoạn"*. Nút **Dừng**: client huỷ `CancelToken` (đóng kết nối), giữ chữ đã hiện + nhãn *"đã dừng"*. Backend nghe
  `req.on('close')` (`chatbot.controller.js:33`) — ⚠️ **cần kiểm**: trên Node ≥ 16 (máy dev: v22.19.0) `req` đã `closed` sau khi
  body được đọc (`express.json`, `app.js:36`, rồi `authenticate` bất đồng bộ) nên listener có thể **không nổ** — reviewer client
  thử nhanh với express của chính `src/Backend/node_modules` + middleware giả bất đồng bộ: chỉ `res` 'close' nổ. Khi ấy
  `abortController.abort()` không chạy và `signal.aborted` (`chatbot.service.js:173`, `:196`) không bao giờ đúng. Và **kể cả khi**
  `abort()` chạy, lượt Gemini vẫn không bị huỷ: hai lời gọi `chatSession.sendMessageStream(…)` (`:168`, `:186`) không truyền
  `requestOptions`, mà SDK chỉ huỷ fetch khi có `requestOptions.signal` (`@google/generative-ai` `dist/index.js:441-455`,
  `buildFetchOptions`); `processStream` còn `tee()` luồng (`:684-690`) và đọc trọn phản hồi dù vòng `for await` đã `break`. **Chưa
  đo trên backend thật** — việc 5.
- Client **không** gọi online cho câu dữ liệu sống (giá vàng · giá xăng · tỷ giá · lãi suất · thời tiết · tin tức · xổ số · bóng
  đá, và câu hỏi *giá* một tài sản) và lệnh tạo hoá đơn / mục tiêu / ngân sách — những câu ấy đi AI trên máy như cũ.
- Log `[Online]` chỉ loại sự kiện, mã HTTP, thời gian — không in câu hỏi / câu trả lời.

## Năm chỗ cố ý không làm theo `ChatbotAI_Moblie.md` (spec client §4.3)

| # | `ChatbotAI_Moblie.md` | Client | Vì sao |
|---|---|---|---|
| 1 | §3.1 mục 1 — huy hiệu *Trực tuyến / Ngoại tuyến* + nút chuyển chế độ ở header | **Không làm.** Mỗi câu thử online rồi rơi; nguồn ghi dưới **từng** bong bóng (*Trợ lý online* · *AI trên máy*); công tắc duy nhất là *Trợ lý online* ở màn Cài đặt AI | người dùng chốt lối *thử từng câu, thang rơi* (2026-10-11) — không có "chế độ" toàn màn |
| 2 | §3.1 mục 2 + §2.2 `GET /snapshot` + AC-MOB-04 — thẻ FHS 50/30/20 | **Không làm** (không đọc `meta.snapshot`, không gọi `/snapshot`) | hai bộ số khác nhau: server phân 50/30/20 theo từ khoá tên danh mục, app tính theo sổ; quyền `financial_health_fhs` client đã bỏ (2026-10-08) |
| 3 | §5 + AC-MOB-06 — bảng `LocalChatMessages` | **Không làm.** Hội thoại sống trong phiên màn | người dùng chốt; thêm bảng là nâng schema SQLite, không mua được gì cho một hội thoại ngắn |
| 4 | §4 mẫu `Dio()` trần tự gắn `Bearer $accessToken` | Dio chung + `AuthInterceptor` | mẫu trần không làm mới token khi 401 và không phát lại request |
| 5 | `conversationId` | **Vẫn gửi** (UUID v4 mỗi lần mở màn) dù server không dùng (`handleResetConversation` trả `{reset: true}` cố định) | khớp hợp đồng, server dùng sau này thì không phải đổi client |

Ngoài năm chỗ trên: khi `done.fallback` client **không** hiện banner / toast như §2.1 gợi ý mà rơi im lặng về AI trên máy cho cùng
câu (người dùng chỉ thấy nhãn nguồn); 429 cũng rơi về máy, không hiện câu *"giới hạn 15 tin nhắn/phút"*. Bốn chip gợi ý của client
giữ nguyên (không dùng bốn chip ở §3.1 mục 3).

## Ba điều đo trên mã backend mà client phải bù

1. **Dự phòng phát câu thông báo qua `delta` trước `done {fallback}`.** `_streamFallbackResponse` (`chatbot.service.js:44-65`)
   chẻ câu *"⚠️ Thông báo từ Hệ thống Trợ lý Tài chính AI…"* thành từng `delta` (15 ms một từ) rồi mới `done {fallback: true,
   reason}`. Với client, "đã có chữ" vì thế **không** chứng minh có câu trả lời thật → client coi `done.fallback` là rơi về máy
   **bất kể** đã nhận bao nhiêu chữ, và gỡ bong bóng thông báo.
2. **`done {error}` — nhánh tài liệu không tả.** Khi chính luồng dự phòng ném (`chatbot.service.js:229-237`), server phát chunk
   *"⚠️ Sự cố kết nối: …"* rồi `done {error: <message>}` (controller `:53` ghi nguyên `doneData`). `ChatbotAI_Moblie.md` §2.1 và
   `ChatbotAI.md` không nhắc khoá `error`. Client xếp nó như `fallback` (rơi về máy) — xếp như lỗi giữa dòng là để câu báo lỗi của
   server ở lại màn dưới nhãn *Trợ lý online*.
3. **`history` bắt đầu bằng vai `model` làm hỏng lượt và đếm vào circuit breaker dùng chung.** Server lấy `history.slice(-6)`
   (`chatbot.service.js:152`) rồi `model.startChat({history})`; SDK `@google/generative-ai` 0.24.1 `validateChatHistory` ném
   *"First content should be with role 'user', got model"*. Lỗi ấy đi vào `geminiCircuitBreaker` — **một** instance cho mọi tài khoản
   (`resilience/circuit-breaker.js:113`, ngưỡng 5 lỗi, mở 30 s). Màn client gieo sẵn một lời chào của AI, nên nếu gửi thẳng thì câu
   online đầu tiên của **mọi** phiên hỏng. Client nay: cắt cửa sổ 6 rồi bỏ các tin đầu cho tới tin `user` đầu tiên, và không gửi
   câu cố định của hệ thống (câu từ chối, câu *chưa có mô hình*…).

## Xin làm

1. **(vừa) Một tên mô hình Gemini đã kiểm, cho dev và cloud.** `.env` dev (người dùng chép 2026-10-17) **có** `GEMINI_API_KEY` và
   `GEMINI_MODEL`; giá trị `GEMINI_MODEL` trùng mặc định của mã `gemini-3.8-flash` (`chatbot.service.js:137`) — tên này **chưa
   ai kiểm** với Google (trước 2026-10-17 dev không có khoá). Sai tên → Gemini 404 → breaker → `done.fallback` → client rơi về máy;
   người dùng chỉ thấy *"máy chủ không phản hồi"*, hỏng im lặng. Xin: chạy một lượt `chat/stream` thật với khoá, ghi tên mô hình đã
   chạy được vào `docs/AI/ChatbotAI.md` (kèm ngày), và đặt cùng tên ấy trên môi trường cloud.
2. **(thấp) Xác nhận giữ `history.slice(-6)`.** Client gửi tối đa 6 tin (`xepHistory`, `toiDa = 6`) đúng theo số ấy; đổi cửa sổ
   phía server thì báo client (client cắt trước để tin đầu luôn là `user` — xem điều 3 ở trên).
3. **(thấp, cân nhắc) Kiểm vai tin đầu ở server.** Sau `slice(-6)`, bỏ các tin đầu không phải `user` trước `startChat` (hoặc trả
   400). Client đã tự làm, nhưng Admin-web hay một client cũ gửi `history` bắt đầu bằng `model` vẫn mở breaker **cho mọi tài khoản**
   sau 5 lần.
4. **(thấp, chữ) Tả nhánh `done {error}`** ở §2.1 `ChatbotAI_Moblie.md` và mục tương ứng của `ChatbotAI.md`.
5. **(vừa, kiểm trước) Dừng phải huỷ được lượt Gemini — cần HAI mảnh, thiếu mảnh nào cũng không đạt.**
   (a) **Nghe đóng kết nối ở `res`**: `chatbot.controller.js:33` gắn `req.on('close')` sau khi body đã đọc xong; trên Node ≥ 16 sự
   kiện ấy có thể đã qua (xem *Client gọi gì*, gạch Dừng). Đổi sang `res.on('close')` (hoặc nghe cả hai, và chỉ `abort()` khi
   `!res.writableEnded`) để `signal.aborted` đúng và vòng ghi `delta` thoát.
   (b) **Truyền `{ signal }` cho SDK**: tham số thứ hai của `chatSession.sendMessageStream(…, { signal })` ở **cả** `:168` lẫn `:186`
   — không có nó, (a) chỉ làm server thôi ghi `delta` lên kết nối chết, còn fetch tới Gemini vẫn chạy và tải trọn câu trả lời
   (SDK `buildFetchOptions` chỉ gắn `AbortController` khi `requestOptions.signal` có mặt; `processStream` đọc trọn luồng qua
   `tee()`). Làm (a) mà thiếu (b) thì phép kiểm log vẫn xanh trong khi lượt Gemini vẫn tiêu — hỏng im lặng.
   ⚠️ Google có ngừng tính token khi fetch bị huỷ giữa chừng hay không — **chưa đo**; (b) ít nhất thôi giữ kết nối và thôi đọc
   phần còn lại.

## Kiểm lại

- `grep -n "slice(-6)" src/Backend/modules/ai/features/chatbot/chatbot.service.js` → còn một dòng (việc 2), hoặc đơn ghi cửa sổ mới.
- Việc 1: với khoá dev, `POST /api/ai/chatbot/chat/stream` (tài khoản Premium, ví dụ tài khoản 10) với `{"message": "Giải thích quỹ
  khẩn cấp 3-6 tháng", "history": []}` trả các `event: delta` rồi `event: done` có `responseTimeMs`, **không** có `fallback`.
- Việc 3: cùng request với `"history": [{"role": "model", "text": "Chào bạn"}]` trả câu trả lời thật, không `done.fallback`, và log
  không có `[CircuitBreaker] Ghi nhận lỗi LLM`.
- Việc 4: `grep -n "error" docs/AI/ChatbotAI_Moblie.md` có dòng tả `done {error}`.
- Việc 5: mở `chat/stream` cho một câu dài, ngắt kết nối giữa dòng (client bấm Dừng, hoặc `curl -N …` rồi Ctrl+C) → log backend có
  dòng *"[SSE Controller] Client idaccount: … đã ngắt kết nối stream"* (controller `:34`); sau dòng ấy **không** còn
  `[Chatbot Function Call]` nào của lượt ấy và không `delta` nào được ghi. Dòng *"[ChatbotService] Hoàn tất phiên chat streaming…"*
  (`:214`) và `onDone` (`:216-218`) vẫn chạy sau khi thoát vòng — **bình thường**, không phải dấu hỏng; dòng *"Client đã ngắt kết
  nối — hủy luồng streaming"* (`:174`) chỉ có khi Dừng rơi vào vòng ngoài (Dừng sau một tool call thì vòng trong `:196` thoát im
  lặng). Với vế (b): xin thêm một dòng log ở chỗ fetch bị huỷ (bắt `AbortError` của `sendMessageStream` / vòng đọc) để quan sát
  được fetch tới Gemini đã dừng. Đo trước khi sửa để biết `req` 'close' có nổ thật không.
- Phía client sau khi có việc 1: nghiệm thu máy thật (spec client §6, chín ca — chữ chạy, nhãn nguồn, rơi về máy, Dừng, tờ thông
  tin, Basic, câu giá vàng, máy chưa có mô hình).

## Không chặn client

Client không chờ đơn này để chạy: thiếu khoá / sai tên mô hình / backend tắt thì mọi câu tự rơi về AI trên máy. Giới hạn ghi ở mục
**15** `docs/AI_EDGE_FEATURE.md` và khối 🌐 mục 14 `docs/PROJECT_CONTEXT.md`.
