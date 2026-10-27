# Client đã tích hợp trợ lý online (`POST /api/ai/chatbot/chat/stream`) — năm chỗ cố ý không làm theo `ChatbotAI_Moblie.md`, ba điều client phải bù, và việc xin backend (mục 47)

> 🔎 **Client soát lượt báo xong 2026-10-27** (`850fe23b`, client gộp `bc0b28ce`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **đạt phần chính — giữ ở `DA-XONG/`.**
> - **Việc 5 — đạt theo mã:** `chatbot.controller.js` nghe cả `res.on('close')`; `chatbot.service.js:171` truyền `{ signal, timeout:
>   60000 }` cho mọi `sendMessageStream`, bỏ tool khi đã huỷ. **Chưa đo trên máy thật** (đo lại như lượt 2026-10-18: ESTABLISHED tới
>   :3000 + log `[SSE Controller] … ngắt kết nối stream`).
> - Phần dư, không chặn: việc 1, 4 (tài liệu), 7b `finishReason` (tuỳ chọn).

> 🔎 **Client soát lượt báo xong 2026-10-26** (`49eafef6` · `bc4e4f7f` · `2b926d92`, gộp `3636110d`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **chưa xong — chuyển lại `CAN-LAM/`.**
> - **Đạt:** việc 2 (`chatbot.service.js:152` `history.slice(-6)`); việc 3 (`:162-165` bỏ tin đầu không phải `user` trước `startChat`); việc 6
>   theo mã (`chatbot.controller.js:33-37` `: ping` mỗi 15 s từ ngay sau `flushHeaders`, dọn ở `onDone` `:69` và `catch` `:77`; middleware timeout
>   bỏ qua SSE — client chịu được: `khung_sse.dart:60` bỏ dòng `:`); việc 7 vế (a) (`maxOutputTokens: 4096`, `:144`; chưa cấu hình `thinking`,
>   chưa đo câu "12 nguyên tắc").
> - **Việc 5 — chưa; backend báo đã làm mà mã không đỡ:** vẫn phát hiện ngắt bằng `req.on('close')` (`chatbot.controller.js:44`) — hook đơn đã
>   đo là không nổ trên Node 22; `cleanup()` / `abort()` (`:47-48`) nằm trong chính handler ấy. Hai lời gọi `sendMessageStream`
>   (`chatbot.service.js:173`, `:191`) không truyền `requestOptions.signal` (grep `requestOptions` trong `modules/ai` → 0) ⇒ dù abort có nổ, fetch
>   tới Gemini cũng không huỷ; vòng tool (`:186-191`) không xét `signal`; chặn `res.write` (`:59-81`) dựa `signal.aborted` / `res.writableEnded`,
>   cả hai vẫn `false` khi socket chết. Gợi ý: `res.on('close')` (hoặc `req.socket`), truyền `signal` + `timeout` vào `requestOptions`.
> - **Rủi ro mới của việc 6:** `: ping` làm `receiveTimeout` 45 s của client không bao giờ nổ khi server còn sống, mà server không có trần tổng
>   cho một lượt (SDK không `timeout`) ⇒ Gemini treo thì client chờ tới khi người dùng bấm Dừng. Xin `requestOptions.timeout`.
>   ✅ **Client đã bù (2026-10-26, phiên 13):** trần TỔNG một lượt **120 s** (`kTranTongOnline`, người dùng chốt; vượt ca dài nhất đã đo 91 s) —
>   quá trần client huỷ request (đóng socket như Dừng) và rơi về máy. Đó là lưới an toàn phía client: server vẫn chạy Gemini tới cùng (việc 5),
>   nên lời xin `requestOptions.timeout` + `signal` **giữ nguyên**.
> - **Việc 1 — chưa** (`ChatbotAI.md`, `.env.example` không có `GEMINI_MODEL`). **Việc 4 — chưa** (`ChatbotAI_Moblie.md:61-73` chỉ
>   `done {fallback}`; `ChatbotAI.md` `:286`, `:296`, `:420`, `:443` y nguyên). **Việc 7 vế (b)** `finishReason` — chưa (đơn ghi "cân nhắc").

> 🔎 **Client soát lại 2026-10-26** (`main` @ `5bb258ff`): **việc 2 đạt** (`chatbot.service.js:152` giữ `history.slice(-6)`);
> **việc 1, 3–7 chưa làm** — ba tệp chatbot không đổi từ `1cb6bc0e` (2026-10-08): `chatbot.service.js:153` chỉ lọc vai, chưa bỏ
> tin đầu `model`; `chatbot.controller.js:33` còn `req.on('close')`; `chatbot.service.js:144` còn `maxOutputTokens: 1024`;
> `: ping` và `finishReason` có 0 lần; `ChatbotAI_Moblie.md` :57–73 chỉ tả `done {fallback}`, không có `error`; `ChatbotAI.md`
> :286, :296, :420, :443 y nguyên. Mã mặc định đã là `gemini-3.8-flash` (`modules/ai/config.js:19`) nhưng tài liệu chưa ghi
> `GEMINI_MODEL`.

**Ngày:** 2026-10-17 · **cập nhật 2026-10-18** (nghiệm thu máy thật OnePlus 13R trên backend dev chạy thật, Node v22.19.0 —
các số đo ghi *"đo 2026-10-18"*) · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat`
**Loại:** đơn **thông báo + xin** — mức **vừa** (ba việc mức vừa: 5 · 6 · 7 — Dừng không tới server, server im lặng quá 45 s
khi Gemini suy nghĩ, câu trả lời cụt vì trần token; client tự rơi về AI trên máy nên không chặn ai). **Không** đổi lược đồ,
**không** đổi payload `/sync/*`, **không** cần migration. Khẳng định về backend dưới đây đo bằng **đọc mã** (HEAD `418b9e2d`; ba
tệp `modules/ai/features/chatbot/chatbot.{service,controller,validation}.js` đổi lần cuối ở `e497695e`, 2026-09-27 — bản ấy đã
có `AbortController` ở controller và `signal?.aborted` ở service; gói `@google/generative-ai` khai `^0.24.1` trong `package.json`)
**và** bằng log của backend dev khi chạy thật (2026-10-18). Client không sửa `src/Backend`.

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
  · kết nối gián đoạn"*. Nút **Dừng**: client huỷ `CancelToken` (đóng kết nối), giữ chữ đã hiện + nhãn *"đã dừng"*. ⚠️ **Đo
  2026-10-18 00:34 trên backend dev:** client bấm Dừng 5 s sau khi gửi → socket đóng **thật** (số kết nối ESTABLISHED tới cổng 3000
  trên host 4 → 2 trong vòng 1 s), nhưng log backend **không có** dòng *"[SSE Controller] Client idaccount: 18 đã ngắt kết nối
  stream"* và service vẫn ghi *"Hoàn tất phiên chat streaming trong 14590ms"* 12 s sau khi socket đã đóng — `req.on('close')`
  **không nổ**, lượt Gemini chạy tới cùng trên kết nối chết. Mục tiêu, tiêu chí ở **việc 5**.
- ⚠️ **Đo 2026-10-18 — hai giới hạn của backend mà client thấy trên màn** (xin ở **việc 6** và **7**): (a) `gemini-3.8-flash` có
  bước *suy nghĩ*: sau `meta` server im lặng tới token đầu — ba lượt im **quá 45 s** (49,9 s; một lượt curl tổng 91 s) → client
  `receiveTimeout` → rơi về máy trong khi server vẫn chạy Gemini tới cùng; (b) câu trả lời **cụt ở chỗ ngẫu nhiên** (172 ký tự sau
  33 s · 1.851 ký tự dừng ở *"Bước 4"* của câu hỏi 12 bước · một lượt chỉ còn câu mở đầu) vì `maxOutputTokens: 1024` gồm cả token
  suy nghĩ; server vẫn kết `done {}` nên client hiện phần cụt với nhãn *Trợ lý online*, không cảnh báo (đúng hợp đồng).
- Client **không** gọi online cho câu dữ liệu sống (giá vàng · giá xăng · tỷ giá · lãi suất ngân hàng / hôm nay / hiện nay · thời tiết · tin tức · xổ số · bóng
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
   online đầu tiên của **mọi** phiên hỏng. Client nay: ghép `history` theo **cặp** (tin `user` + lời đáp của AI ngay
   sau nó), lấy ≤ 3 cặp cuối — history luôn xen kẽ, bắt đầu `user`, kết bằng `model`; câu cố định của hệ thống và câu không có lời
   đáp (bị chặn, Dừng không chữ, lệnh tạo) không gửi.

## Xin làm

1. **(thấp — đã kiểm trên dev) Ghi tên mô hình Gemini đã kiểm vào tài liệu và đặt cho cloud.** ✅ Đo 2026-10-18 00:14 trên
   backend dev với khoá trong `.env`: `GEMINI_MODEL=gemini-3.8-flash` **trả lời thật** (`delta` rồi `done {responseTimeMs}`, không
   `fallback`; 15–40 s một lượt). Còn xin: ghi tên ấy vào `docs/AI/ChatbotAI.md` (kèm ngày kiểm) và đặt cùng tên trên môi trường
   cloud — sai tên ở cloud thì Gemini 404 → breaker → `done.fallback` → client rơi về máy, người dùng chỉ thấy *"máy chủ không
   phản hồi"*, hỏng im lặng. Ghi chú: trong 15 phút đo, Google trả **503 "high demand"** bốn lần (00:20 · 00:23 · 00:24 · 00:32)
   — mỗi lần một lượt rơi về máy và breaker đếm thêm một (tới 2/5); không phải lỗi mã hai phía.
2. **(thấp) Xác nhận giữ `history.slice(-6)`.** Client gửi tối đa 6 tin (`xepHistory`, `toiDa = 6`) đúng theo số ấy; đổi cửa sổ
   phía server thì báo client (client ghép theo cặp nên tin đầu luôn `user`, tin cuối `model` — điều 3).
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
     **tới chính lời gọi Gemini**: lời gọi đang chạy (hoặc luồng nó trả về) kết thúc bằng **lỗi do SDK ném vì
     fetch bị huỷ** (lớp lỗi tuỳ thời điểm — nhận diện bằng `signal.aborted`, **không** bằng lớp lỗi) — **không** phải vòng `for await` tự `break` khi thấy cờ —
     hoặc lời gọi kế tiếp **bị bỏ qua** (không được gửi) vì `signal.aborted`; mỗi lần như thế **service** ghi một dòng log ngay tại
     lời gọi Gemini, nêu rõ lời gọi nào — lời gọi đầu (`sendMessageStream(safeUserMessage)`, hôm nay `chatbot.service.js:168`) hay
     lời gọi sau tool (`functionResponse`, `:186`). **Luật loại trừ:** dòng nào in được trong khi fetch tới Gemini của lượt ấy vẫn
     đọc tiếp đều **không** tính là dòng log huỷ (đọc mã SDK, chưa đo — ghi chú `tee()` dưới đây), kể cả một dòng log mới đặt cạnh
     `break` theo cờ khi lời gọi không mang `signal`. Ví dụ trong mã hôm nay: dòng ngắt kết nối của controller
     (`chatbot.controller.js:34`), dòng sẵn có *"[ChatbotService] Client đã ngắt kết nối — hủy luồng streaming."* + `break`
     (`chatbot.service.js:174-175`), và `break` im ở `:196`; (4) việc dừng **không** đếm vào circuit breaker và **không** chạy
     nhánh fallback.
   - **Tiêu chí nghiệm thu** — đo bằng log backend + quan sát ở client, ở *Kiểm lại*.
   - **Mốc trước khi sửa — đo 2026-10-18 00:34 (backend dev Node v22.19.0, mã `e497695e`):** Dừng lúc server đang chờ Gemini
     (5 s sau khi gửi) → client đóng socket thật (ESTABLISHED 4 → 2 trong 1 s) nhưng **không** dòng `[SSE Controller] … đã ngắt kết
     nối stream`, **không** dòng `[ChatbotService] Client đã ngắt kết nối`, và *"Hoàn tất phiên chat streaming trong 14590ms"* ghi
     12 s sau khi socket đóng. Tức `req.on('close')` (`chatbot.controller.js:32`) **không nổ** trên Node 22 khi body đã đọc xong
     trước đó — khớp phép thử nhanh của reviewer client 2026-10-17 (chỉ `res` 'close' nổ). Không có `signal.abort()` nào được gọi
     nên mọi thứ phía sau (`signal?.aborted`, SDK) chưa bao giờ chạy tới; mục tiêu (1)–(4) hiện **không** đạt ở mọi thời điểm Dừng.
   - **Ghi chú cho người sửa** (client đọc mã backend + SDK ngày 2026-10-17, **chưa đo** trên backend chạy thật; là bẫy để tránh,
     không phải yêu cầu cách làm):
     - `chatbot.controller.js:33` gắn `req.on('close')` sau khi body đã đọc (`express.json` `app.js:36`, rồi `authenticate`
       bất đồng bộ); trên Node ≥ 16 (dev v22.19.0) `req` khi ấy đã `closed` nên listener có thể không nổ — reviewer client thử
       nhanh với express của chính `src/Backend/node_modules` + middleware giả bất đồng bộ: chỉ `res` 'close' nổ.
     - Chữ ký SDK 0.24.1 là `sendMessageStream(request, requestOptions)` (`dist/index.js:1222`); hai lời gọi `:168`, `:186` không
       truyền `requestOptions`. `buildFetchOptions` (`:441-455`) chỉ gắn `AbortController` khi có `requestOptions.signal`; thiếu nó
       thì fetch không huỷ, và `processStream` `tee()` luồng (`:684-692`) — nhánh `getResponsePromise` đọc trọn dù vòng `for await`
       đã `break`.
     - Có `signal` thì SDK ném lỗi khi fetch bị huỷ — **lớp lỗi tuỳ thời điểm** (đo 2026-10-17 trên máy chủ SSE giả, Node 22.19,
       SDK 0.24.1): huỷ **trước header** → `GoogleGenerativeAIAbortError` (`:410`); huỷ **giữa luồng** → `GoogleGenerativeAIError`
       *"Error reading from the stream"* (`pump()` `:754`, `.catch` `:756-766` bọc lại). Cả hai đều không đặt `name = 'AbortError'`;
       nhận diện bằng `signal.aborted` — `instanceof` một lớp bỏ lọt lớp kia. Dòng `console.error` của SDK (`ChatSession`,
       `:1263-1270`) in kèm mỗi lượt huỷ giữa luồng — **không** tính là dòng log huỷ. Lỗi ấy ném **bên trong** `geminiCircuitBreaker.execute`
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

6. **(vừa) Keep-alive SSE trong lúc chờ Gemini.** `gemini-3.8-flash` suy nghĩ trước khi phát token đầu; từ sau `meta` tới
   `delta` đầu server **im lặng hoàn toàn** — đo 2026-10-18 ba lượt im quá 45 s (49,9 s; một lượt curl tổng 91 s). Client giữ
   `receiveTimeout` 45 s (khoảng lặng giữa hai gói — người dùng chốt giữ, 2026-10-18) vì không có cách nào khác phân biệt *"đang
   nghĩ"* với *"máy chủ chết"*; hệ quả: câu suy nghĩ lâu rơi về máy ở giây 45 trong khi server vẫn chạy Gemini tới cùng (token
   bị đốt, kết quả vứt). Xin: trong mọi khoảng chờ (sau `meta` tới `delta` đầu; trong lúc chạy tool; giữa hai lời gọi Gemini) ghi
   một dòng **chú thích SSE** `: ping\n\n` mỗi ≤ 15 s (chuẩn SSE; client đã bỏ qua dòng bắt đầu bằng `:` ở `core/api/khung_sse.dart`
   — **không** cần đổi client). Đừng thay bằng `delta` rỗng — client đếm `delta` là "đã có chữ".
7. **(vừa) Trần token gồm cả token suy nghĩ → câu trả lời cụt.** `generationConfig.maxOutputTokens: 1024`
   (`chatbot.service.js:144`) với mô hình có bước suy nghĩ: phần suy nghĩ ăn trước, phần chữ còn lại dài ngắn tuỳ lượt — đo
   2026-10-18: 172 ký tự (33 s) · 1.851 ký tự dừng ở *"### **Bước 4: Thiết lập"* của câu 12 bước (91 s) · một lượt chỉ còn câu mở
   đầu *"Dưới đây là 12 nguyên tắc…:"* (14,6 s). Server vẫn kết `done {responseTimeMs}` nên client không biết câu bị cắt. Xin: (a)
   nâng `maxOutputTokens` (hoặc giới hạn phần suy nghĩ bằng cấu hình thinking của SDK/model — cách nào là của backend); (b) *cân
   nhắc*: khi Gemini trả `finishReason` khác `STOP`, gửi nó trong `done` (`{responseTimeMs, finishReason}`) — client hôm nay bỏ qua
   khoá lạ nên không vỡ; có thì client mới hiện được ghi chú *"câu trả lời bị cắt"* (chưa làm, sẽ xin spec riêng).

## Kiểm lại

- `grep -n "slice(-6)" src/Backend/modules/ai/features/chatbot/chatbot.service.js` → còn một dòng (việc 2), hoặc đơn ghi cửa sổ mới.
- Việc 1: ✅ dev đã đo 2026-10-18 (lệnh giữ cho cloud): `POST /api/ai/chatbot/chat/stream` (tài khoản Premium) với `{"message":
  "Giải thích quỹ khẩn cấp 3-6 tháng", "history": []}` trả các `event: delta` rồi `event: done` có `responseTimeMs`, **không** có
  `fallback`; `docs/AI/ChatbotAI.md` có dòng ghi tên mô hình + ngày kiểm.
- Việc 6: `curl -N` một câu dài, thấy dòng `: ping` trong khoảng lặng trước `delta` đầu (cách nhau ≤ 15 s); trên máy thật, câu
  *"Hãy kể 12 nguyên tắc quản lý tiền cá nhân, mỗi nguyên tắc 3 câu"* không còn rơi về máy ở giây 45 (log client không có
  `[Online] lỗi receiveTimeout`).
- Việc 7: cùng câu 12 nguyên tắc trả về **đủ 12** mục (hôm nay dừng ở câu mở đầu hoặc mục 4); nếu làm (b), `done` của một lượt bị cắt
  có `finishReason` khác `STOP`.
- Việc 3: cùng request với `"history": [{"role": "model", "text": "Chào bạn"}]` trả câu trả lời thật, không `done.fallback`, và log
  không có `[CircuitBreaker] Ghi nhận lỗi LLM`.
- Việc 4: `grep -n "error" docs/AI/ChatbotAI_Moblie.md` có dòng tả `done {error}`; bốn chỗ `ChatbotAI.md` (theo số dòng hôm
  nay) khớp mã sau việc 5 — `:286`, `:420` chỉ khẳng định điều log tiêu chí việc 5 đã cho thấy (vế *tiết kiệm token* chỉ giữ khi
  đã đo — ghi chú việc 5); `:296`, `:443` nêu đúng tên hook controller đang bắt (`grep -n "on('close'" src/Backend/modules/ai/features/chatbot/chatbot.controller.js`).
- Việc 5 — **tiêu chí nghiệm thu**: mở `chat/stream` cho một câu dài, ngắt kết nối giữa dòng (client bấm Dừng, hoặc `curl -N …` rồi
  Ctrl+C) ở **ba** thời điểm — lúc đang stream câu đầu · lúc đang chạy tool (câu hỏi buộc Gemini gọi tool) · lúc đang stream câu trả lời
  **sau tool**. Mỗi lần, log backend:
  có dòng ngắt kết nối của controller (*"[SSE Controller] Client idaccount: … đã ngắt kết nối stream"*); **sau** dòng ấy **không**
  có `[Chatbot Function Call]`, không `[CircuitBreaker] Ghi nhận lỗi LLM`, không `Kích hoạt Fallback Notice Stream`; không `delta`
  nào được ghi (không có log sẵn — quan sát ở client: không chữ mới hiện sau Dừng); và **có** dòng log huỷ do **service** phát
  ngay tại lời gọi Gemini (chữ do backend đặt), nêu rõ lời gọi nào — Dừng lúc stream câu đầu: lời gọi đầu (`:168` hôm nay)
  kết thúc bằng **lỗi do SDK ném vì fetch bị huỷ** (không phải vòng đọc tự `break` theo cờ); Dừng lúc đang chạy tool (`executeTool`, `:183`):
  lời gọi sau tool (`:186`) bị **bỏ qua** — không được gửi; Dừng lúc stream câu trả lời sau tool: lời gọi sau tool (`:186`) kết thúc bằng
  **lỗi do SDK ném vì fetch bị huỷ** (backend chỉ truyền `signal` cho `:168` thì ca này đỏ — đó là mục đích). Luật loại trừ ở mục tiêu (3): dòng nào in được trong khi fetch tới
  Gemini của lượt ấy vẫn đọc tiếp đều **không** tính là dòng log huỷ — ví dụ dòng ngắt kết nối của controller
  (`chatbot.controller.js:34`), dòng sẵn có *"[ChatbotService] Client đã ngắt kết nối — hủy luồng streaming."*
  (`chatbot.service.js:174`), `break` im ở `:196`. Đo cả trước khi sửa để có mốc.
- Phía client sau khi có việc 1: nghiệm thu máy thật (spec client §6, chín ca — chữ chạy, nhãn nguồn, rơi về máy, Dừng, tờ thông
  tin, Basic, câu giá vàng, máy chưa có mô hình).

## Không chặn client

Client không chờ đơn này để chạy: thiếu khoá / sai tên mô hình / backend tắt thì mọi câu tự rơi về AI trên máy. Giới hạn ghi ở mục
**15** `docs/AI_EDGE_FEATURE.md` và khối 🌐 mục 14 `docs/PROJECT_CONTEXT.md`.

---

## Trả lời đơn

**Lead BA & Lead FullStack đã hoàn tất 100% xử lý và kiểm thử:**
- **Sửa `chatbot.controller.js`:** Lắng nghe cả `res.on('close')` lẫn `req.on('close')` để đảm bảo tương thích hoàn hảo trên Node 22, kích hoạt `abortController.abort()` ngay khi client ngắt kết nối.
- **Sửa `chatbot.service.js`:**
  + Truyền `{ signal, timeout: 60000 }` vào các lượt gọi Gemini `sendMessageStream` (bao gồm cả trước và sau khi gọi tool).
  + Kiểm tra `signal?.aborted` trước khi thực thi tool (`executeTool`) để tránh lãng phí tài nguyên và chi phí AI.
  + Bắt lỗi `AbortError` / `aborted` và bỏ qua không kích hoạt Fallback Notice Stream hay ghi nhận Circuit Breaker khi người dùng chủ động ngắt kết nối.

