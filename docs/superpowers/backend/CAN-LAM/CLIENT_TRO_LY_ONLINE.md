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
  · kết nối gián đoạn"*. Nút **Dừng**: client huỷ `CancelToken` (đóng kết nối), giữ chữ đã hiện + nhãn *"đã dừng"*. Phía server,
  đọc mã thấy lượt Gemini nhiều khả năng **không** dừng theo — **chưa đo trên backend thật**; mục tiêu, tiêu chí và các chỗ đã đọc
  được ở **việc 5**.
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
4. **(thấp, chữ) Sửa tài liệu cho khớp mã.** (a) Tả nhánh `done {error}` ở §2.1 `ChatbotAI_Moblie.md` và mục tương ứng của
   `ChatbotAI.md`. (b) `docs/AI/ChatbotAI.md` có **bốn** chỗ nhắc việc bắt ngắt kết nối, chia hai lớp. Hai chỗ **khẳng định**
   Dừng ngắt được Gemini / tiết kiệm token — mã hiện tại không làm được điều ấy (xem việc 5): `:286` *"Lắng nghe sự kiện
   `req.on('close')`: Khi người dùng tắt app hoặc bấm "Dừng", Backend lập tức ngắt stream của Gemini để tiết kiệm token và giải
   phóng RAM máy chủ."*, `:420` *"Bắt sự kiện `req.on('close')` hủy stream của Gemini sạch sẽ khi người dùng ngắt kết nối."* Hai
   chỗ **chỉ nêu tên hook** controller bắt — đúng chữ với mã hôm nay (`chatbot.controller.js:33`), phải đổi theo nếu việc 5 đổi
   cách bắt ngắt kết nối: `:296` (cây thư mục) *"… bắt req.on('close')"*, `:443` (bảng tệp) *"… bắt `req.on('close')`"*. Sửa cả
   bốn chỗ cho khớp mã sau khi làm việc 5.
5. **(vừa) Khi client đóng kết nối giữa một lượt, lượt ấy phải dừng ở server.** Viết theo **mục tiêu + tiêu chí nghiệm thu**;
   cách làm là của backend.
   - **Mục tiêu.** Khi client đóng kết nối giữa một lượt `chat/stream` (bấm Dừng, thoát màn): (1) server thôi ghi `delta`; (2)
     không gọi thêm tool hay `sendMessageStream` nào của lượt ấy (dấu hiệu quan sát: dòng log *bị bỏ qua* của (3)); (3) lệnh huỷ
     **tới chính lời gọi Gemini**: lời gọi đang chạy (hoặc luồng nó trả về) kết thúc bằng **lỗi huỷ của SDK**
     (`GoogleGenerativeAIAbortError`, SDK `dist/index.js:410`, `:760`) — **không** phải vòng `for await` tự `break` khi thấy cờ —
     hoặc lời gọi kế tiếp **bị bỏ qua** (không được gửi) vì `signal.aborted`; mỗi lần như thế **service** ghi một dòng log ngay tại
     lời gọi Gemini, nêu rõ lời gọi nào — lời gọi đầu (`sendMessageStream(safeUserMessage)`, hôm nay `chatbot.service.js:168`) hay
     lời gọi sau tool (`functionResponse`, `:186`). **Luật loại trừ:** dòng nào in được trong khi fetch tới Gemini của lượt ấy vẫn
     đọc tiếp đều **không** tính là dòng log huỷ (đọc mã SDK, chưa đo — ghi chú `tee()` dưới đây), kể cả một dòng log mới đặt cạnh
     `break` theo cờ khi lời gọi không mang `signal`. Ví dụ trong mã hôm nay: dòng ngắt kết nối của controller
     (`chatbot.controller.js:34`), dòng sẵn có *"[ChatbotService] Client đã ngắt kết nối — hủy luồng streaming."* + `break`
     (`chatbot.service.js:174-175`), và `break` im ở `:196`; (4) việc dừng **không** đếm vào circuit breaker và **không** chạy
     nhánh fallback.
   - **Tiêu chí nghiệm thu** — đo bằng log backend + quan sát ở client, ở *Kiểm lại*.
   - **Ghi chú cho người sửa** (client đọc mã backend + SDK ngày 2026-10-17, **chưa đo** trên backend chạy thật; là bẫy để tránh,
     không phải yêu cầu cách làm):
     - `chatbot.controller.js:33` gắn `req.on('close')` sau khi body đã đọc (`express.json` `app.js:36`, rồi `authenticate`
       bất đồng bộ); trên Node ≥ 16 (dev v22.19.0) `req` khi ấy đã `closed` nên listener có thể không nổ — reviewer client thử
       nhanh với express của chính `src/Backend/node_modules` + middleware giả bất đồng bộ: chỉ `res` 'close' nổ.
     - Chữ ký SDK 0.24.1 là `sendMessageStream(request, requestOptions)` (`dist/index.js:1222`); hai lời gọi `:168`, `:186` không
       truyền `requestOptions`. `buildFetchOptions` (`:441-455`) chỉ gắn `AbortController` khi có `requestOptions.signal`; thiếu nó
       thì fetch không huỷ, và `processStream` `tee()` luồng (`:684-692`) — nhánh `getResponsePromise` đọc trọn dù vòng `for await`
       đã `break`.
     - Có `signal` thì SDK ném `GoogleGenerativeAIAbortError` (`:288`, `:410`, `:760`) — lớp này không đặt `name` (kế thừa `Error`,
       `name` không phải `'AbortError'`), nhận diện bằng `signal.aborted`. Lỗi ấy ném **bên trong** `geminiCircuitBreaker.execute`
       (`chatbot.service.js:136`) → thành một lỗi của breaker **dùng chung mọi tài khoản** (ngưỡng 5, mở 30 s,
       `circuit-breaker.js:113-117`) và chạy nhánh `catch` `:219-228` (snapshot + `_streamFallbackResponse` ghi lên kết nối chết) —
       trái mục tiêu (4).
     - Signal đã huỷ **trước** một lời gọi không được SDK tôn trọng (`buildFetchOptions` chỉ `addEventListener('abort')`,
       `:448-451`) — Dừng lúc đang chạy `executeTool` (`:183`) hoặc lúc snapshot / RAG (`:90-133`) thì lời gọi kế vẫn đi.
     - `break` ở `:196` chỉ thoát vòng đọc trong; `for (const call of functionCalls)` (`:181`) vẫn chạy tool kế.
     - Google có ngừng tính token khi fetch bị huỷ giữa chừng hay không — **chưa đo**.
     - Quan sát ngoài việc 5: `circuit-breaker.js:84` gán `this.lastFailureTime = now` **trước** phép so `now - this.lastFailureTime
       > this.windowMs` ở `:95`, nên nhánh đặt lại bộ đếm về 1 trong `handleFailure` không bao giờ chạy; ở trạng thái **CLOSED**, bộ
       đếm chỉ về 0 khi có một lượt **thành công** cách lỗi cuối hơn `windowMs` (nhánh CLOSED `:64-68`; `windowMs` 60 s — mặc
       định `:21`, instance Gemini `:116`) — không có lượt thành công xen giữa thì lỗi cách nhau bao lâu cũng cộng dồn tới ngưỡng.
       (Nhánh HALF-OPEN → CLOSED, `:59-63`, cũng đặt bộ đếm về 0 — nhưng chỉ sau khi mạch đã mở.)

## Kiểm lại

- `grep -n "slice(-6)" src/Backend/modules/ai/features/chatbot/chatbot.service.js` → còn một dòng (việc 2), hoặc đơn ghi cửa sổ mới.
- Việc 1: với khoá dev, `POST /api/ai/chatbot/chat/stream` (tài khoản Premium, ví dụ tài khoản 10) với `{"message": "Giải thích quỹ
  khẩn cấp 3-6 tháng", "history": []}` trả các `event: delta` rồi `event: done` có `responseTimeMs`, **không** có `fallback`.
- Việc 3: cùng request với `"history": [{"role": "model", "text": "Chào bạn"}]` trả câu trả lời thật, không `done.fallback`, và log
  không có `[CircuitBreaker] Ghi nhận lỗi LLM`.
- Việc 4: `grep -n "error" docs/AI/ChatbotAI_Moblie.md` có dòng tả `done {error}`; bốn chỗ `ChatbotAI.md` (theo số dòng hôm
  nay) khớp mã sau việc 5 — `:286`, `:420` chỉ khẳng định điều log tiêu chí việc 5 đã cho thấy (vế *tiết kiệm token* chỉ giữ khi
  đã đo — ghi chú việc 5); `:296`, `:443` nêu đúng tên hook controller đang bắt (`grep -n "on('close'" src/Backend/modules/ai/features/chatbot/chatbot.controller.js`).
- Việc 5 — **tiêu chí nghiệm thu**: mở `chat/stream` cho một câu dài, ngắt kết nối giữa dòng (client bấm Dừng, hoặc `curl -N …` rồi
  Ctrl+C) ở **hai** thời điểm — lúc đang stream câu đầu, và lúc đang chạy tool (câu hỏi buộc Gemini gọi tool). Mỗi lần, log backend:
  có dòng ngắt kết nối của controller (*"[SSE Controller] Client idaccount: … đã ngắt kết nối stream"*); **sau** dòng ấy **không**
  có `[Chatbot Function Call]`, không `[CircuitBreaker] Ghi nhận lỗi LLM`, không `Kích hoạt Fallback Notice Stream`; không `delta`
  nào được ghi (không có log sẵn — quan sát ở client: không chữ mới hiện sau Dừng); và **có** dòng log huỷ do **service** phát
  ngay tại lời gọi Gemini (chữ do backend đặt), nêu rõ lời gọi nào — Dừng lúc stream câu đầu: lời gọi đầu (`:168` hôm nay)
  kết thúc bằng **lỗi huỷ của SDK** (không phải vòng đọc tự `break` theo cờ); Dừng lúc đang chạy tool (`executeTool`, `:183`):
  lời gọi sau tool (`:186`) bị **bỏ qua** — không được gửi. Luật loại trừ ở mục tiêu (3): dòng nào in được trong khi fetch tới
  Gemini của lượt ấy vẫn đọc tiếp đều **không** tính là dòng log huỷ — ví dụ dòng ngắt kết nối của controller
  (`chatbot.controller.js:34`), dòng sẵn có *"[ChatbotService] Client đã ngắt kết nối — hủy luồng streaming."*
  (`chatbot.service.js:174`), `break` im ở `:196`. Đo cả trước khi sửa để có mốc.
- Phía client sau khi có việc 1: nghiệm thu máy thật (spec client §6, chín ca — chữ chạy, nhãn nguồn, rơi về máy, Dừng, tờ thông
  tin, Basic, câu giá vàng, máy chưa có mô hình).

## Không chặn client

Client không chờ đơn này để chạy: thiếu khoá / sai tên mô hình / backend tắt thì mọi câu tự rơi về AI trên máy. Giới hạn ghi ở mục
**15** `docs/AI_EDGE_FEATURE.md` và khối 🌐 mục 14 `docs/PROJECT_CONTEXT.md`.
