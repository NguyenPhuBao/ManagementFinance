# Trợ lý AI hỗn hợp: có mạng hỏi backend (Gemini), mất mạng hỏi mô hình trên máy — thiết kế

**Ngày:** 2026-10-11 · **Mảng:** `features/ai_chat` (+ `ai_edge/domain`, `core/api`, `core/network`, màn Cài đặt AI) · **Trạng thái:** thiết kế duyệt
từng phần trong chat; ✅ **thi công 2026-10-17** (Task 1, 3–12; Task 2 bỏ — mục 10 dòng 1; `core/network` không đổi), 🚧 **chưa
nghiệm thu máy thật** (Task 13, mục 6 — cần backend chạy được và `.env` có khoá Gemini). Chỗ mã khác thân spec: **mục 10**.

> Đảo quyết định treo từ 2026-09-26 (*chatbot trực tuyến của backend — 🛑 chưa nhận, chờ người dùng quyết*, mục 10.1
> `docs/AI_AGENT_ARCHITECTURE.md`): người dùng chốt ngày 2026-10-11 — **"kết nối AI chatbox ở backend vào, khi có mạng dùng ở
> backend, không có thì offline"**, và **"tuân thủ cấu trúc hệ thống, tránh sau này phải sửa lại"**. Tài liệu bàn giao của backend
> `docs/AI/ChatbotAI_Moblie.md` (2026-09-26) từ đây là **hợp đồng được tham chiếu**, với các chỗ cố ý không làm ở mục 4.3.

---

## 0. Quyết định của người dùng (brainstorm 2026-10-11, mỗi câu một lượt chọn)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Online hỏng (mạng chập, 503 bảo trì, 429, `done.fallback` vì thiếu khoá Gemini, hết giờ) thì sao? | **Tự rơi về AI trên máy** cho cùng câu khi hỏng **trước chữ đầu**; hỏng giữa dòng → giữ phần đã hiện + ghi chú, không hỏi lại. Mô hình trên máy **nạp khi cần**, không nạp sẵn lúc online |
| 2 | Phạm vi câu hỏi online | **Mở kiến thức, giữ chặn dữ liệu sống**: online trả lời câu kiến thức / tư vấn chung (quỹ khẩn cấp, 50/30/20, "nên mua món 5 triệu không", thuế, vay, đầu tư nói chung); **vẫn chặn** giá vàng · giá xăng · tỷ giá · lãi suất ngân hàng · thời tiết · tin tức · xổ số · bóng đá · câu hỏi *giá* cổ phiếu / bitcoin |
| 3 | Minh bạch dữ liệu rời máy | **Tờ thông tin một lần** (bottom sheet) trước câu online đầu tiên; mỗi bong bóng AI ghi nguồn |
| 4 | Lịch sử hội thoại | **Trong phiên màn** (như nay); gửi ≤ 6 tin gần nhất làm `history`; không bảng SQLite |
| 5 | Thẻ FHS từ `meta` | **Không ở đợt này** |
| 6 | Cơ chế chuyển đường | **Lối A — thử online từng câu, thang rơi**; không "chế độ" toàn màn, không huy hiệu thanh tiêu đề, không nút chọn tay trên màn chat; nút chỉnh tay duy nhất là công tắc *Trợ lý online* ở Cài đặt AI |
| 7 | Vị trí tệp / ranh giới | Theo bảng luật mục 8 `docs/KIEN_TRUC_CLIENT_APP.md` (mục 3.6); đọc mạng qua `ConnectionMonitor`, không gọi `Connectivity()` ở trang; thẻ lệnh tạo C3 dời ra widget để trang giữ dưới trần 1.200 dòng |
| 8 | Dừng | Nút **Dừng** chỉ cho đường online; đường trên máy giữ như nay |
| 9 | Cờ công tắc | **Gắn máy** (khuôn `CongTacAi`), không theo tài khoản |
| 10 | Bất biến số | Bất biến *"mọi con số trong câu phải có trong gói"* thu hạn về **AI trên máy**; câu online tin grounding phía server |
| 11 | Chờ đồng bộ trước câu online | **Không chờ**; nhãn nguồn là lời giải thích cho lệch số |

Tham khảo thị trường (kiến thức tới 06/2026, chưa kiểm lại trên web): MISA Money Keeper, Money Lover, Cleo, Copilot Money
đều chỉ có trợ lý online, không app nào tự rơi về mô hình trên máy hay lộ nút chọn — lối hỗn hợp là điểm riêng của FlowMoney;
vì thế không có khuôn UI nào để chép, Stitch phải vẽ mới (mục 7).

---

## 1. Mục tiêu và phạm vi

**Làm:** màn Trợ lý AI, với mỗi câu hỏi, nếu công tắc online bật ∧ máy có mạng lúc gửi ∧ câu không thuộc nhóm dữ liệu sống →
gọi `POST /api/ai/chatbot/chat/stream` của backend, hiện chữ chạy; hỏng trước chữ đầu → cùng câu đi mô hình trên máy như hôm
nay. Thêm tờ thông tin một lần, công tắc *Trợ lý online* ở Cài đặt AI, nhãn nguồn dưới bong bóng, nút Dừng cho online.

**Không làm (cố ý, có lý do):** huy hiệu / nút chuyển Online–Offline ở thanh tiêu đề (lối A không có "chế độ"); thẻ FHS từ
`meta` (hai bộ số khác nhau: server phân 50/30/20 theo từ khoá tên danh mục, app tính theo `tongThuChi`); bảng
`LocalChatMessages` (lịch sử chỉ sống trong phiên màn); nút Dừng cho mô hình trên máy; chờ `syncNow()` trước câu online; đọc
`GET /snapshot` (đòi quyền `financial_health_fhs` mà client đã bỏ); kiểm số câu online ở client.

---

## 2. Bối cảnh đo được (2026-10-11)

**Backend (đo thật trên `node index.js` đang chạy, HEAD sau gộp `main` @ `79e46225`):**

- Mô-đun `src/Backend/modules/ai/features/chatbot/` đủ: `chatbot.service.js` (snapshot → context → Gemini → tools → fallback),
  `tools/`, `rag/`, `snapshot/`, `privacy/pii.masker.js`, `resilience/circuit-breaker.js`, `rate-limiter/redis-token-bucket.js`;
  gói `@google/generative-ai` **0.24.1** đã cài. Route gắn ở `api/index.js:66` (`/ai`) → `api/ai.routes.js:21` (`/chatbot`).
- Không token: bốn đường `/api/ai/chatbot/{chat/stream, chat, snapshot, reset}` trả **401** (`authenticate` đứng trước mọi thứ).
- `thug63` (Basic, idaccount 27) có token: `POST /chat/stream` → **403** sau 11 ms, thân
  `{code: 'FEATURE_DISABLED', featureId: 'ai_assistant', accountType: 'Basic', message}` (`middleware/feature-permission.middleware.js`).
- `node --test` chatbot: unit **28/28**, integration **3/3** — nhưng mỗi lượt `chatStream` in `[ChatbotService] GEMINI_API_KEY chưa
  cấu hình. Kích hoạt Fallback Stream` → `done {fallback: true, reason: 'Hệ thống chưa thiết lập API Key Google Gemini'}`.
- `.env` dev (sửa lần cuối 2026-09-12) **không có** `GEMINI_API_KEY` lẫn `GEMINI_MODEL`; mã mặc định `gemini-3.8-flash`
  (`chatbot.service.js:137`) — tên mô hình **chưa kiểm được** vì không có khoá. Tài khoản Premium duy nhất của CSDL dev: **10**
  (`dat`, hết hạn 2026-11-05).

**Client (HEAD `70c3425c`):** `ai_chat_page.dart` **1.080** dòng (trần quét 23 = 1.200); luồng `_hoi`: khoá Basic → lệnh tạo C3
(`coVeLenhTao`) → chưa có mô hình → `chuDeBiChan` → câu chào → vòng tool (`hoiBangCongCu`) → bậc 1. `ConnectionMonitor`
(`core/network`) chỉ phát sự kiện mất/khôi phục (ổn định 3 s), không lộ trạng thái tức thời. `AuthInterceptor` gắn Bearer, gặp 401
thì làm mới token và **phát lại trọn request** (`_retryRequest`). `CongTacAi` (`ai_edge/data/cong_tac_ai.dart`): một khoá secure
storage cho cả máy, nuốt lỗi. Bốn test quét kiến trúc 22–25 xanh (7/7, 24 s).

---

## 3. Thiết kế

### 3.1 Thứ tự cổng trong `_hoi` (phần 1)

1. Basic → khoá cả ô (như nay; cả hai đường đều đòi `ai_assistant`, server cũng 403).
2. Lệnh tạo C3 (`coVeLenhTao`) → đường trên máy như nay, **bất kể mạng** (backend không điền form được).
3. **Mới:** `nenHoiOnline(congTacBat, coMang, cauHoi)` (hàm thuần, `ai_chat/domain/duong_hoi.dart`) — `true` khi công tắc online
   bật ∧ `await sl<ConnectionMonitor>().coMangLucNay()` ∧ `!chuDeBiChanOnline(cau)` → **đường online** (mục 3.2–3.3), kể cả câu
   chào và câu định nghĩa.
4. Không thì **đường trên máy y như hôm nay**: `_coMoHinh` → `chuDeBiChan` → `laCauChao` → `_luongThat` → bậc 1. Nếu tới đây vì
   mất mạng mà máy chưa sẵn (chưa tải / công tắc trên máy tắt) → câu cố định mới `kKhongMangKhongMoHinh`.

`chuDeBiChanOnline` nằm **cạnh** `chuDeBiChan` trong `ai_edge/domain/chu_de_chan.dart`, dùng **cùng danh sách gốc**: tách
`_tuKhoaChan` thành hai nhóm có tên — *dữ liệu sống* (giá vàng · giá xăng · tỷ giá / tỉ giá · lãi suất (ngân hàng) · thời tiết · tin tức
· xổ số · bóng đá) và *tư vấn chung* (đầu tư · chứng khoán · cổ phiếu · trái phiếu · tiền mã hoá · tiền ảo · bitcoin · crypto · vay ngân
hàng · thuế); `chuDeBiChan` = cả hai nhóm + câu định nghĩa (không đổi hành vi); `chuDeBiChanOnline` = nhóm sống + câu hỏi **giá tài sản**:
có chữ *giá* / *gia* / *bao nhiêu tiền* **và** một tên tài sản (vàng, cổ phiếu, chứng khoán, bitcoin, crypto, tiền ảo, usd, đô)
trong cùng câu — so trên bản đã bỏ dấu; *"bitcoin là gì"* (không chữ giá) vẫn mở. Bản không dấu như hiện có.

`ConnectionMonitor.coMangLucNay()` (mới, `core/network`): `_coMang(await _connectivity.checkConnectivity())`, lỗi → `true` (cùng lý
lẽ `start()`); plugin `connectivity_plus` vẫn chỉ ở `core/` + hai chỗ cũ.

### 3.2 Nguồn online — datasource (phần 2)

`features/ai_chat/data/datasources/tro_ly_online_remote_data_source.dart`:

```dart
abstract class TroLyOnlineRemoteDataSource {
  /// Mở luồng SSE cho một câu. Kết thúc bằng [XongOnline] / [DuPhongOnline] / [LoiOnline]; huỷ qua [cancel].
  Stream<SuKienOnline> hoi({required String cauHoi, required String conversationId,
      required List<TinLichSu> history, required CancelToken cancel});
}
class TroLyOnlineRemoteDataSourceImpl implements TroLyOnlineRemoteDataSource { TroLyOnlineRemoteDataSourceImpl(this._dio); … }

sealed class SuKienOnline {}
class ChuOnline extends SuKienOnline { final String text; }          // event delta → data.text
class XongOnline extends SuKienOnline { final int? responseTimeMs; } // event done, không fallback
class DuPhongOnline extends SuKienOnline { final String reason; }    // event done {fallback: true}
class LoiOnline extends SuKienOnline { final int? http; final String lyDo; } // event error, HTTP ≠ 200, hết giờ, mất mạng, cancel
typedef TinLichSu = ({String role, String text}); // role 'user' | 'model'
```

- Request: `POST '/ai/chatbot/chat/stream'` (`AppConstants.baseUrl` đã có `/api`), header `Accept: text/event-stream`, thân
  `{message, conversationId, history}`; `Options(responseType: ResponseType.stream, receiveTimeout: 45 s)` — 45 s là **khoảng
  lặng giữa hai gói** (Gemini gọi tool rồi suy luận lượt hai có thể lâu hơn 30 s mặc định); `connectTimeout` dùng mặc định.
- `Dio` tiêm qua constructor; DI đưa `sl<Dio>()` nên request đi qua `AuthInterceptor`: 401 → làm mới → phát lại trọn request
  (xảy ra trước khi có chunk nào); làm mới hỏng → `DioException` → `LoiOnline`.
- Datasource **không** chứa luật rơi, không đọc công tắc, không biết màn.
- Bộ tách khung SSE là hạ tầng HTTP → `core/api/khung_sse.dart` (Dart thuần, không import `features/`): `BoTachSse` nhận chunk
  `String` (đã `utf8.decoder`), giữ đệm, cắt theo dòng trống, chịu CRLF, bỏ dòng bắt đầu `:`; một khung = `event` + các dòng `data`
  nối bằng `\n`; trả `KhungSse(event, data)`; phần dư cuối luồng (không có dòng trống kết) vẫn phát khi `dong()`.
- Ánh xạ khung → sự kiện ở datasource: `delta` → `ChuOnline(json.text ?? json.content ?? '')`; `done` → `fallback == true` ?
  `DuPhongOnline(reason)` : `XongOnline(responseTimeMs)`; `error` → `LoiOnline(http: 200, lyDo: json.message)`; `meta` → chỉ
  `debugPrint('[Online] meta snapshotLoaded=… healthScore=…')`.

### 3.3 Luật rơi (hàm thuần, `ai_chat/domain/duong_hoi.dart`)

`quyetDinhSauOnline({required bool daCoChu, required SuKienOnline cuoi, required bool daDung})` →

| Tình huống | Kết quả |
|---|---|
| `XongOnline` sau ≥ 1 chữ | `HoanTat(nguon: online)` |
| `XongOnline` mà **chưa có chữ** | `RoiVeMay('rỗng')` — câu trả lời trống cũng là hỏng |
| `DuPhongOnline` / `LoiOnline` khi **chưa có chữ** (kể cả 403, 429, 503, hết giờ, mất mạng) | `RoiVeMay(lyDo)` → trang chạy đúng đường trên máy cho **cùng câu** (mục 3.1 bước 4) |
| `DuPhongOnline` / `LoiOnline` khi **đã có chữ** | `GiuPhanDaCo(ghiChu: 'kết nối gián đoạn')` |
| người dùng bấm Dừng (`daDung`) | `GiuPhanDaCo(ghiChu: 'đã dừng')`; chưa có chữ → bong bóng rỗng không tạo, chỉ huỷ lượt |

Thêm: 403 `FEATURE_DISABLED` → ngoài rơi, trang gọi `GoiRepository.lamMoi()` để băng khoá cập nhật (gói hết hạn giữa phiên). Lý
do kỹ thuật chỉ vào `debugPrint('[Online] rơi: http=… lyDo=…')`; người dùng chỉ thấy nhãn nguồn (3.4).

`xepHistory(List<TinNhan>)`: lấy tối đa **6** tin **chữ** gần nhất (bỏ thẻ lệnh tạo), vai `cuaToi → 'user'`, AI → `'model'`
(cả câu do AI trên máy trả lời); không gồm câu đang hỏi. `conversationId` = `Uuid().v4()` một lần khi mở màn (server hiện không
dùng, gửi để khớp hợp đồng).

### 3.4 Hiển thị (phần 3)

- **Chờ:** `_dangSoan` hiện `kDangHoiOnline = 'Đang hỏi trợ lý online…'` cho tới chữ đầu; rơi về máy → các câu cũ (*Đang nghĩ…*,
  *Đang tra cứu …*).
- **Chữ chạy:** chunk online **nối thẳng** vào `_traLoiDangDen` (không chèn khoảng trắng — chunk có thể cắt giữa từ), **không gác
  theo câu** (gác chỉ cho mô hình trên máy); vẽ qua `boDanhDauMarkdown` (hàm sẵn `ai_edge/domain/bo_markdown.dart`; Gemini hay
  trả `**`, `* `). Xong → `_themCuaAi(_TinNhan.cuaAi(text, nguon: NguonTraLoi.online))` — **không thẻ số liệu** (thẻ chỉ dựng từ
  gói trên máy; `_theChoCau` không chạy cho online).
- **Nhãn nguồn** (chữ 12 px, màu `onSurfaceVariant`, ngay dưới bong bóng AI, trước thẻ số liệu nếu có): `_TinNhan` thêm
  `nguon: NguonTraLoi {trenMay, online}` và `ghiChu: String?`; chữ = `nguon` (+ ` · ghiChu`): *Trợ lý online* · *AI trên máy* ·
  *AI trên máy · máy chủ không phản hồi* (rơi) · *Trợ lý online · kết nối gián đoạn* · *Trợ lý online · đã dừng*. Câu do mô
  hình trên máy sinh (vòng tool, bậc 1, câu chào, mẫu câu dự phòng của gói) mang *AI trên máy*; **câu cố định của hệ thống**
  (`kCauTuChoi`, `kChuaSanSangPhien`, `kChuaCoMoHinh`, `kKhongMangKhongMoHinh`, *Đã huỷ*…) và thẻ lệnh tạo **không có nhãn**
  (`nguon == null`) — chúng không đến từ AI nào.
- **Nút Dừng:** `TextButton('Dừng', key: Key('dung-online'))` trong hàng `_dangSoan` **chỉ khi** lượt online đang chạy →
  `cancel.cancel()`; phần đã hiện giữ lại với ghi chú *đã dừng*. Đường trên máy không có nút (như nay); nút *Huỷ* của C3 giữ.
- Không huy hiệu ở thanh tiêu đề; bốn chip `kChipGoiY` giữ nguyên — chip bật khi `!_khoaCaO && (_coMoHinh || _onlineBat)`.
- `dispose`: huỷ `CancelToken` đang mở; sự kiện tới sau `!mounted` bỏ qua.

### 3.5 Tờ thông tin, công tắc, băng khoá (phần 4)

- `features/ai_chat/data/cong_tac_online.dart` — `CongTacOnline` theo khuôn `CongTacAi` (secure storage, một khoá cho cả máy,
  nuốt lỗi): `docBat()` khoá `ai_online_bat` mặc định **true**; `ghiBat(bool)`; `daDocTo()` khoá `ai_online_da_doc_to` mặc định
  **false**; `ghiDaDocTo()`. Đăng xuất **không** đổi (cờ gắn máy).
- Tờ thông tin `features/ai_chat/presentation/widgets/tro_ly_ai/to_thong_tin_online.dart` — `Future<LuaChonToThongTin?>
  moToThongTinOnline(BuildContext)` (`showModalBottomSheet`, `isScrollControlled`, thân cuộn — bẫy G60), chữ:

  > **Trợ lý online**
  > Khi có mạng, câu hỏi của bạn cùng bản tóm tắt tài chính (tỉ lệ chi theo nhóm, điểm sức khoẻ tài chính; khi cần, số tiền một
  > vài giao dịch với ghi chú đã che thông tin cá nhân) được gửi tới máy chủ FlowMoney và Google Gemini để trả lời. Mất mạng thì
  > AI trên máy trả lời, không gửi gì. Đổi lại được ở Cài đặt AI.

  Nút **Đã hiểu** → `ghiDaDocTo()`, câu đi online; **Chỉ dùng AI trên máy** → `ghiBat(false)` + `ghiDaDocTo()`, câu đi trên máy;
  vuốt tắt (`null`) → câu này đi trên máy, lần sau hỏi lại. Chỉ hiện khi `nenHoiOnline` đã `true` và `!daDocTo`.
- Cài đặt AI (`ai_edge/presentation/pages/cai_dat_ai_page.dart`): thẻ công tắc thứ hai cùng khuôn `_theCongTac` — *"Trợ lý
  online"* / *"Có mạng thì hỏi máy chủ; tắt thì chỉ dùng AI trên máy"* — đọc/ghi `CongTacOnline` (tiêm qua constructor như
  `congTac`, `null` = `sl`). Khối *Riêng tư* đổi chữ: *"AI trên máy không gửi gì khỏi thiết bị. Trợ lý online (khi bật và có
  mạng) gửi câu hỏi + bản tóm tắt tài chính tới máy chủ FlowMoney và Google Gemini."* (câu cũ *"Không có số liệu nào rời khỏi
  thiết bị"* sẽ thành sai).
- Băng khoá: `lyDoKhoa({laPremium, coTep, congTacBat, bool onlineBat = false})` — Basic → `goiBasic`; `(!coTep || !congTacBat)
  && !onlineBat` → lý do cũ (`chuaCoMoHinh` nếu `!coTep`, không thì `congTacTat`); còn lại `null`. Mặc định `false` giữ nguyên
  mọi chỗ gọi và test cũ. Khi mở nhờ online mà lúc hỏi `nenHoiOnline == false` và máy chưa sẵn → `kKhongMangKhongMoHinh = 'Đang
  không có mạng, và AI trên máy chưa sẵn (chưa tải / đang tắt). Nối mạng hoặc mở Cài đặt AI.'`.

### 3.6 Vị trí tệp, DI, khe tiêm test (theo bảng luật mục 8 `KIEN_TRUC_CLIENT_APP.md`)

| Tệp | Hàng luật | Mới / sửa |
|---|---|---|
| `core/api/khung_sse.dart` | Hạ tầng không biết mảng (`core/api` = HTTP) — không import `features/` | mới |
| `core/network/connection_monitor.dart` | Hạ tầng mạng | sửa: `coMangLucNay()` |
| `features/ai_chat/data/datasources/tro_ly_online_remote_data_source.dart` | Datasource bọc API | mới |
| `features/ai_chat/data/cong_tac_online.dart` | tệp rời dưới `data/` theo tiền lệ `cong_tac_ai.dart` (nhóm 52 tệp bảng chưa có hàng; dời chung khi bảng thêm hàng) | mới |
| `features/ai_chat/domain/duong_hoi.dart` | Hàm thuần | mới (thư mục `domain/` của mảng tạo mới) |
| `features/ai_edge/domain/chu_de_chan.dart` | Hàm thuần | sửa: tách nhóm + `chuDeBiChanOnline` |
| `features/ai_chat/presentation/widgets/tro_ly_ai/the_lenh_tao.dart` | Widget của một trang | **dời nguyên văn** từ `ai_chat_page.dart` (~100 dòng, giữ `Key` và chữ) |
| `features/ai_chat/presentation/widgets/tro_ly_ai/to_thong_tin_online.dart`, `nhan_nguon.dart` | Widget của một trang | mới |
| `features/ai_chat/presentation/pages/ai_chat_page.dart` | Trang | sửa: nhánh online mỏng; ước 1.080 − 100 + ~90 ≈ **1.070** < 1.200 |
| `features/ai_edge/presentation/pages/cai_dat_ai_page.dart` | Trang | sửa: thẻ công tắc thứ hai, chữ Riêng tư |
| `core/di/injection_container.dart` | Điểm ghép | đăng ký `TroLyOnlineRemoteDataSource` (lazy, `sl<Dio>()`), `CongTacOnline` |
| `test/core/api/khung_sse_test.dart`, `test/features/ai_chat/{data/datasources,data,domain,presentation/widgets/tro_ly_ai}/…` | Soi gương thư mục (quét 25) | mới |

Khe tiêm test của `AiChatPage` (khuôn `onHoi` / `onChao`): `onHoiOnline: Stream<SuKienOnline> Function(String cau,
List<TinLichSu> history)?`, `coMang: Future<bool> Function()?`, `congTacOnline: CongTacOnline?`; `null` = đường thật qua DI.
Không tầng mới, không chủ đề `core` mới, không Drift, không đổi schema / payload đồng bộ / `RealtimeEvent`. Ratchet `core →
features` không đổi. Soát với lộ trình G88 (2026-10-11): gạch 1–6 đều không bị thiết kế này cản (bảng ở lượt soát trong chat; tóm
tắt: không tệp nào trong `data/services/`, không kiểu Drift ở UI, `core/api` không import `features/`).

### 3.7 Bất biến đổi theo (phần 5)

- ① *"dữ liệu không rời máy"* → *"AI trên máy không gửi gì; trợ lý online gửi câu hỏi + tóm tắt tài chính + kết quả tool (số tiền
  giao dịch, ghi chú đã che PII) tới máy chủ FlowMoney và Google Gemini — theo quyết định người dùng 2026-10-11"*. Sửa: hàng *Bảo
  mật* mục 7 `KIEN_TRUC_CLIENT_APP.md`, mục 10.1 `AI_AGENT_ARCHITECTURE.md` (F1), khối *Riêng tư* Cài đặt AI.
- ② *"mọi con số trong câu phải có trong gói"* → chỉ cho **AI trên máy**; câu online tin grounding phía server (Strict Grounding +
  Privacy Shield, `ChatbotAI.md` §3). Client không kiểm số, không chặn câu online.
- ④ *"không tool nào ghi thẳng"* giữ: tool backend chỉ đọc; lệnh tạo vẫn trên máy, form điền sẵn.
- Độ tươi dữ liệu: server trả lời từ PostgreSQL (thiếu thao tác còn `pending`) + cache snapshot Redis 120 s → cùng câu, hai nguồn
  có thể lệch vài phút; không chờ đồng bộ; nhãn nguồn là lời giải thích; ghi giới hạn vào `AI_EDGE_FEATURE.md`.
- Log `[Online]`: chỉ loại sự kiện, mã HTTP, thời gian; không in câu hỏi / câu trả lời.

---

## 4. Hợp đồng với backend

### 4.1 Request

`POST {baseUrl}/ai/chatbot/chat/stream` · `Authorization: Bearer` (interceptor) · `Accept: text/event-stream` · `Content-Type:
application/json` · thân `{"message": "<≤ 2000 ký tự>", "conversationId": "<uuid v4>", "history": [{"role": "user"|"model",
"text": "…"}, …≤ 6]}` (`chatbot.validation.js` nhận `history` hoặc `conversationHistory`; `message` rỗng / > 2000 → 400).

### 4.2 Response (SSE, `chatbot.controller.js:47–59`)

| event | data | Client |
|---|---|---|
| `meta` | `{snapshotLoaded, healthScore, snapshot}` | log hai trường đầu, bỏ `snapshot` |
| `delta` | `{text, content}` (trùng nhau) | nối `text` |
| `done` | `{responseTimeMs}` hoặc `{fallback: true, reason}` | `XongOnline` / `DuPhongOnline` |
| `error` | `{message}` | `LoiOnline` |

HTTP: 401 (interceptor), **403 `FEATURE_DISABLED`** (Basic / hết hạn — rơi + `lamMoi()`), **429** (15 req/phút/tài khoản — rơi),
**503 `MAINTENANCE_MODE`** (bảo trì — rơi; G89), 5xx / mất mạng / hết 45 s → rơi.

### 4.3 Lệch với `ChatbotAI_Moblie.md` — cố ý, đưa vào đơn CAN-LAM thông báo

- §3.1 huy hiệu *Trực tuyến / Ngoại tuyến* + nút chuyển ở header → **không làm** (lối A); nguồn ghi trên bong bóng.
- §3.1 thẻ FHS + §2.2 `GET /snapshot` → **không làm** (quyết định 5; quyền `financial_health_fhs` client đã bỏ).
- §5 bảng `LocalChatMessages` → **không làm** (quyết định 4).
- §4 mẫu Dio tạo `Dio()` trần và tự gắn Bearer → client dùng `sl<Dio>()` + `AuthInterceptor` (làm mới token, phát lại request).
- `conversationId` server không dùng (`handleResetConversation` trả `{reset: true}` cố định) — client vẫn gửi.
- Xin backend: `GEMINI_MODEL` hợp lệ (mặc định `gemini-3.8-flash` chưa kiểm) + khoá trên môi trường dev/cloud; khi chưa có khoá,
  client **tự rơi về AI trên máy**, người dùng chỉ thấy nhãn *máy chủ không phản hồi*.

---

## 5. Kiểm thử (TDD; mọi ca kèm `reason:` nói nó canh gì; bản sai có chủ ý cho ca rơi)

- `test/core/api/khung_sse_test.dart`: một khung trọn; hai khung một chunk; khung cắt giữa dòng và giữa `\n\n` qua ba chunk;
  CRLF; dòng `:` bị bỏ; nhiều `data:` nối `\n`; `dong()` phát phần dư; chunk rỗng không phát gì.
- `test/features/ai_chat/data/datasources/tro_ly_online_remote_data_source_test.dart` (adapter Dio giả, khuôn
  `auth_interceptor_test`): thân + header đúng; `meta/delta/delta/done` → `ChuOnline×2, XongOnline`; `done.fallback` →
  `DuPhongOnline(reason)`; event `error` → `LoiOnline(200)`; HTTP 403 / 429 / 503 → `LoiOnline(http)`; hết giờ → `LoiOnline`;
  `cancel` → luồng đóng, không sự kiện thừa; `receiveTimeout` của request = 45 s.
- `test/features/ai_chat/domain/duong_hoi_test.dart`: ma trận `nenHoiOnline` (công tắc × mạng × chủ đề sống); `quyetDinhSauOnline`
  đủ 5 hàng bảng 3.3; `xepHistory` (≤ 6, bỏ thẻ lệnh, vai đúng, thứ tự cũ → mới, không gồm câu đang hỏi).
- `test/features/ai_edge/domain/chu_de_chan_test.dart` (+ca): `chuDeBiChan` không đổi trên bộ câu hiện có (ca canh); `chuDeBiChanOnline`
  chặn *giá vàng hôm nay*, *gia vang*, *giá bitcoin*, *lãi suất ngân hàng*; **mở** *quỹ khẩn cấp là gì*, *bitcoin là gì*, *nên đầu
  tư thế nào*, *thuế thu nhập cá nhân tính thế nào*.
- `test/features/ai_chat/data/cong_tac_online_test.dart`: mặc định bật / chưa đọc; ghi rồi đọc; kho ném → mặc định.
- `test/features/ai_chat/ai_chat_page_test.dart` (+nhóm *online*): chunk nối không khoảng trắng; nhãn *Trợ lý online*; nhãn *AI trên
  máy* cho câu cũ; rơi về `onHoi` khi `LoiOnline` trước chữ đầu + nhãn *máy chủ không phản hồi*; `DuPhongOnline` giữa dòng → giữ
  chữ + *kết nối gián đoạn*; Dừng → cancel + *đã dừng*; tờ hiện một lần, *Chỉ dùng AI trên máy* tắt công tắc; băng khoá **mở**
  khi `onlineBat` dù `coTep=false`; `kKhongMangKhongMoHinh` khi mất mạng + chưa mô hình; C3 vẫn đi trước online; câu *giá vàng*
  đi trên máy dù online bật. Bản sai có chủ ý: bỏ nhánh rơi → ca rơi phải đỏ.
- `test/features/ai_edge/presentation/cai_dat_ai_page_test.dart` (+ca): công tắc thứ hai đọc/ghi; chữ Riêng tư mới.
- `test/features/ai_chat/lyDoKhoa` (+ca): bảng chân trị với `onlineBat`.
- Test quét 22–25 xanh; `ai_chat_page.dart` < 1.200; `khong_snackbar` (không SnackBar); `icon_button_co_tooltip` (Dừng là TextButton).

---

## 6. Nghiệm thu máy thật (OnePlus 13R ưu tiên; tài khoản 10 Premium của người dùng; bản debug trỏ `127.0.0.1` qua `adb reverse`)

Điều kiện cho ca 1–2: người dùng đặt `GEMINI_API_KEY` + `GEMINI_MODEL` hợp lệ vào `src/Backend/.env` (tệp backend, không
phải việc của client). Thiếu → chỉ nghiệm thu được thang rơi (ca 3–9).

| # | Ca | Đo |
|---|---|---|
| 1 | Có mạng + khoá: *"Giải thích quỹ khẩn cấp 3–6 tháng"* | chữ chạy, nhãn *Trợ lý online*, thời gian tới chữ đầu, không chip số liệu |
| 2 | Cùng câu số liệu *"Tháng này tôi chi nhiều nhất cho gì?"* online rồi tắt mạng hỏi lại | hai con số; ghi lệch và lý do (pending / cache 120 s) |
| 3 | Backend tắt (hoặc không khoá) | rơi về máy, nhãn *máy chủ không phản hồi*, tổng chờ so với trước |
| 4 | Máy bay | đi thẳng trên máy, không request nào (`[Online]` không in) |
| 5 | Dừng giữa dòng | phần đã hiện giữ, nhãn *đã dừng*, server log `Client … đã ngắt kết nối stream` |
| 6 | Lần đầu hỏi online | tờ hiện một lần; *Chỉ dùng AI trên máy* → Cài đặt AI công tắc tắt → câu sau đi trên máy |
| 7 | Basic `thug63` / `thuG63pass` | băng khoá, không request |
| 8 | *"Giá vàng hôm nay?"* online bật | câu từ chối cũ, không request |
| 9 | Xoá mô hình + online bật | ô nhập mở; có mạng → online; máy bay → `kKhongMangKhongMoHinh` |

Chấm theo **câu hiện trên màn** (bản ghi `uiautomator` / ảnh), không theo log.

---

## 7. Stitch (vẽ trước khi làm giao diện; người dùng xác nhận — công cụ có độ trễ, không gọi lại)

1. *Trợ lý AI — bong bóng online*: bong bóng AI với dòng nhãn nguồn 12 px bên dưới (hai biến thể *Trợ lý online* / *AI trên máy ·
   máy chủ không phản hồi*), hàng chờ *Đang hỏi trợ lý online…* kèm nút **Dừng**.
2. *Trợ lý AI — tờ thông tin online*: bottom sheet chữ ở 3.5, hai nút.
3. *Cài đặt AI — công tắc Trợ lý online*: thẻ thứ hai dưới *Dùng AI trên máy*, khối Riêng tư chữ mới (màn gốc `1da347e7…`).

**Đã vẽ 2026-10-17** (ba lượt `generate_screen_from_text` đều trả `timeout`, màn xuất hiện sau ~25 phút; `list_screens` 129 → 132):
`1896d02b79b64053af4dd56ea9895b51` *Trợ lý AI - Bong bóng online* · `7a6519d69cce49f1b64692f677af6193` *Trợ lý AI - Tờ thông tin
online* · `b320f4b91f9d425d8bc74da1d0234ca0` *Cài đặt AI - Công tắc Trợ lý online*. Chữ ba màn đối chiếu từng câu với §3.4–3.5:
khớp. Lệch nhỏ so với §0 q6: nền phía sau tờ thông tin Stitch tự vẽ huy hiệu *Trực tuyến* trên thanh tiêu đề — app **không** làm.
Nhãn nguồn Stitch vẽ kèm chấm tròn 6 px (xanh `#006E1C` online · đỏ `#BA1A1A` khi có ghi chú) — app theo. *Người dùng chưa xác
nhận trên Stitch lúc ghi dòng này; Task 8–11 thi công theo bản đã vẽ, góp ý sau sửa ở đợt review cuối.*

---

## 8. Tài liệu và đơn CAN-LAM

`docs/AI_EDGE_FEATURE.md` mục mới *Trợ lý online*; `docs/AI_AGENT_ARCHITECTURE.md` mục 10.1 + bốn bất biến (①, ②); `docs/KIEN_TRUC_CLIENT_APP.md`
mục 3 (tệp mới, `ai_chat/domain`, `widgets/tro_ly_ai`) + mục 7 *Bảo mật*; `docs/PROJECT_CONTEXT.md` mục 14; CLAUDE.md hàng *AI
Edge-SLM* (🛑 → ✅ 2026-10-11); `docs/superpowers/backend/CAN-LAM/` **đơn thông báo** (mục 4.3 ở trên) + README mục 0.

---

## 9. Rủi ro, giới hạn

- Tên mô hình mặc định `gemini-3.8-flash` chưa kiểm; sai → Gemini 404 → circuit breaker → `done.fallback` → client rơi về máy
  (vô hình với người dùng ngoài nhãn). Backend phải chốt `GEMINI_MODEL`.
- 15 req/phút/tài khoản: người hỏi nhanh gặp 429 → rơi về máy (chậm hơn) — chấp nhận; không đếm trước ở client.
- Rơi về máy = **chờ cộng dồn** (thử online tới 45 s + nạp mô hình lần đầu 27 s CPU Realme / ~9 s GPU OnePlus + sinh câu).
  Hỏng nhanh (403/429/503/mất mạng) rơi ngay; hỏng vì lặng 45 s là ca xấu nhất — đo ở ca 3.
- `receiveTimeout` của Dio là khoảng lặng giữa hai gói với `ResponseType.stream`; nếu đo thấy khác (hết giờ dù chữ vẫn chảy) thì
  bỏ `receiveTimeout` và tự canh bằng `Stream.timeout` trong datasource — ghi ở mục 10.
- Chữ online không qua lớp chắn số: sai số là trách nhiệm grounding phía server; nhãn nguồn để người dùng biết đang nghe ai.
- Người dùng thường bị bất ngờ bởi hai con số khác nhau cho cùng câu (độ tươi) — nhãn nguồn + ghi chú giới hạn trong tài liệu.

---

## 10. Chỗ bản thi công KHÁC bản viết

*(Điền trong lúc thi công — kế hoạch và mã thắng spec ở những dòng ghi tại đây.)*

**Thi công 2026-10-17** trên nhánh `TranQuangDat`, base `909ae016`: **22** commit `80d9dee8` → `fb92c16d` (21 commit mã + test,
`b6eb9975` ghi id Stitch) và commit tài liệu Task 12. Task 2 bỏ; Task 13 (nghiệm thu máy thật) chưa làm. Số đo 2026-10-17:
`flutter test` **7.368 pass / 10 skip** (trước 7.240; +128), `flutter analyze` **20** (mức nền), `ai_chat_page.dart` **1.141** dòng,
`cai_dat_ai_page.dart` **694** dòng. Khuôn mỗi dòng: *§ — bản viết → bản thi công — vì … (task)*.

1. §3.1 bước 3 / §3.6 hàng `connection_monitor` — `ConnectionMonitor.coMangLucNay()` (mới) → dùng **`coMangNgay()`** có sẵn từ
   C4 (2026-10-12; cùng nghĩa, cùng thân, đã đăng ký DI và có test) — vì nếp *một định nghĩa*; Task 2 **bỏ**, không commit,
   `core/network` không đổi (Task 2, Task 9).
2. §3.2 / §3.6 hàng DI / §4.3 gạch 4 — "DI đưa `sl<Dio>()`" → **`TroLyOnlineRemoteDataSourceImpl(sl<DioClient>().dio)`** — vì
   GetIt không đăng ký `Dio` (`grep "registerLazySingleton<Dio>"` = 0), chỉ `DioClient`; đăng ký lazy nên `flutter test` lẫn
   `flutter analyze` đều mù, sai tên là lỗi lúc chạy app. Docstring sai cùng gốc ở `core/api/dio_client.dart:11` sửa ở Task 12
   (Task 7, Task 12).
3. §3.3 bảng, dòng *"`DuPhongOnline` khi đã có chữ → `GiuPhanDaCo`"* → **`DuPhongOnline` LUÔN `RoiVeMay(reason)` bất kể chữ** —
   vì backend `_streamFallbackResponse` (`chatbot.service.js:44-66`) luôn chẻ câu thông báo ⚠️ thành `delta` rồi mới
   `done {fallback}`, nên "chữ đã có" là thông báo của server; trang gỡ bong bóng đang hiện rồi hỏi máy với cùng câu.
   `LoiOnline` sau chữ vẫn `GiuPhanDaCo(kGhiChuGianDoan)`; `ChuOnline` làm sự kiện cuối (luồng đóng không `done`) đi như
   `LoiOnline`. `HoanTat()` / `GiuPhanDaCo(ghiChu)` dùng tham số vị trí, không `nguon:` / `ghiChu:` (Task 4).
4. §3.3 `xepHistory` — thêm hai luật: (a) sau khi cắt cửa sổ 6, **gọt tin đầu cho tới tin `user`** — vì `@google/generative-ai`
   0.24.1 `validateChatHistory` ném *First content should be with role 'user'*, mà trang gieo lời chào AI ở `initState` → câu
   online đầu mọi phiên hỏng và đếm vào circuit breaker dùng chung (một instance cho mọi tài khoản, ngưỡng 5 lỗi, mở 30 s —
   `resilience/circuit-breaker.js:113`); (b) **không gửi câu cố định của hệ thống** (tin AI `nguon == null`: `kCauTuChoi`,
   `kChuaCoMoHinh`…) — chúng không phải lời của mô hình nào. ⚠️ **Còn để** (giới hạn đã biết, chưa sửa): bỏ câu hệ thống để lại
   tin `user` mồ côi — *"Giá vàng hôm nay?"* bị chặn ở client vẫn vào `history` của lượt online sau, Gemini có thể trả lời; hướng
   sửa: bỏ theo cặp ở `xepHistory`. `toiDa = 6` gắn với `history.slice(-6)` của backend (`chatbot.service.js:152`) — không nâng
   (Task 4, Task 9).
5. §4.2 — thêm hàng: `done` có khoá **`error`** (chính luồng dự phòng của server ném — `chatbot.service.js:229-237`,
   `chatbot.controller.js:53`) → **`DuPhongOnline(error)`** — vì server đã phát chunk *"⚠️ Sự cố kết nối…"* trước đó, `LoiOnline`
   sẽ giữ câu báo lỗi dưới nhãn *Trợ lý online*; `done {}` (không `fallback`, không `error`) → `XongOnline(responseTimeMs: null)`,
   cố ý không đoán — đoán sai là mọi câu trả lời rơi về máy, hỏng im lặng (Task 5).
6. §4.1 — `message ≤ 2000`: client **không cắt, không chặn**; câu dài → 400 (`chatbot.validation.js`) → `LoiOnline(400)` → rơi
   về máy — vì một câu hiếm đi đường chậm rẻ hơn một luật cắt câu (phán quyết D19, Task 12).
7. §3.4 — nút Dừng *"trong hàng `_dangSoan`"* → vẽ theo **`_huyOnline != null && !_daDungOnline` bất kể `_traLoiDangDen`** (hàng
   chờ khi chưa có chữ; hàng dưới bong bóng đang đến khi đã có chữ; cùng `Key('dung-online')`) — vì `itemBuilder` thay hàng chờ
   bằng bong bóng ngay chữ đầu, đặt trong `_dangSoan` là nút biến mất, ngược §0 q8. Hàng chờ có nút: chữ `Flexible(fit:
   FlexFit.tight)`, bỏ `Spacer` — ở 360 dp chữ *Đang hỏi trợ lý online…* bị ép xuống hai dòng (Task 10).
8. §3.1 bước 4 — thêm hằng **`kMayChuHongKhongMoHinh`** (*"Máy chủ không phản hồi, và AI trên máy chưa sẵn (chưa tải / đang tắt).
   Thử lại sau hoặc mở Cài đặt AI."*); cổng máy-chưa-sẵn chọn câu theo **nguyên nhân thật**: vừa rơi từ online →
   `kMayChuHongKhongMoHinh`; mất mạng (`matMang`) → `kKhongMangKhongMoHinh`; chủ đề bị chặn (`chuDeBiChan`) → `kCauTuChoi`; còn
   lại `cauKhoaHoiDap`. Tách vị từ **`_maySan`** (có tệp ∧ công tắc trên máy) khỏi `_coMoHinh` (ô mở) — vì với
   `lyDoKhoa(onlineBat: true)` = `null` thì `_coMoHinh` true dù không có mô hình, nhánh `kKhongMangKhongMoHinh` của bản viết
   không bao giờ chạy; và *"Đang không có mạng"* sai sự thật khi mạng có mà máy chủ hỏng (Task 9).
9. §3.1 `chuDeBiChanOnline` — *"so trên bản đã bỏ dấu"* → so **HAI lượt**: (A) có dấu, từ trọn — vế giá `giá` | `bao nhiêu tiền`
   × tài sản vàng · cổ phiếu · chứng khoán · tiền ảo · tiền mã hoá / hóa · đô la · **đô** · usd · bitcoin · crypto; (B) bỏ dấu CHỈ
   với từ một nghĩa — `gia` | `bao nhieu tien` × bitcoin · crypto · usd · dola · chung khoan — vì bỏ dấu gộp *đó là* / *vâng* /
   *tiền áo* / *có phiếu* vào tên tài sản, đẩy câu nối tiếp hội thoại sang máy. Bất đối xứng cố ý: *"tháng này tôi mua vàng hết
   bao nhiêu tiền"*, *"ví USD còn bao nhiêu tiền"* bị chặn ONLINE (đi máy, tool trả lời từ sổ) nhưng mở trên máy. Giới hạn chấp
   nhận: câu giá **gõ không dấu** của đô la / tiền ảo / cổ phiếu (*"gia do la hom nay"*) nay đi Gemini (vàng / xăng / tỉ giá
   không dấu vẫn chặn); `đô` từ trọn chặn oan *thủ đô* / *đô thị* (đi máy). Danh sách chặn cũ tách thành `_tuKhoaSong` **10** mục
   + `_tuKhoaTuVan` **11** mục (đếm 2026-10-17; `_tuKhoaSongKhongDau` 8); `chuDeBiChan` = cả hai + câu định nghĩa, hành vi không
   đổi (Task 3).
10. §3.5 — chữ khối Riêng tư: bản **kế hoạch** *"AI trên máy không gửi gì rời khỏi thiết bị. Trợ lý online (khi bật và có mạng)
    gửi câu hỏi và bản tóm tắt tài chính tới máy chủ FlowMoney và Google Gemini."* — vì `+` của spec là ký hiệu tóm tắt, không
    phải chữ giao diện, và cụm *rời khỏi thiết bị* giữ liên tục với ca test cũ (Task 11).
11. §3.4 nhãn nguồn — thêm **chấm tròn 6 px** trước chữ (Stitch `1896d02b…`): xanh `#006E1C` online không ghi chú · đỏ
    `AppColors.error` khi có ghi chú · xám khi trên máy không ghi chú; chữ 12 px màu hằng cục bộ **`Color(0xFF454743)`** — KHÔNG
    `AppColors.onSurfaceVariant` (= `#767872`, 3,8:1 trên nền trang ở 12 px, dưới AA — số của lượt review Task 8, 2026-10-17) —
    khuôn `hop_thoai_bi_day_ra.dart` / `bill_page.dart` / `the_cho_xoa_trang_chu.dart` (Task 8).
12. §3.6 — ngoài danh sách tệp: **`core/api/interceptors/auth_interceptor.dart` `_retryRequest`** phát lại sau 401 **giữ**
    `responseType` / `receiveTimeout` / `cancelToken` / header (`fetch(requestOptions.copyWith(headers:))`) — đo: bản cũ đọc dồn SSE
    thành `String` rồi `DioException(unknown)` (câu online đầu sau khi token hết hạn chờ trọn câu, Dừng vô hiệu, rồi vẫn rơi về máy
    dù server đã tốn một lượt Gemini). Datasource bắt **mọi** lỗi giữa luồng (`catch (e)` chung sau `on DioException`) →
    `LoiOnline` — đo: `HttpException` khi đứt mạng, `FormatException` khi UTF-8 cụt; lỗi lập trình cũng thành `LoiOnline`, chỉ lộ
    qua log `[Online] lỗi <kiểu>` (Task 5).
13. §3.6 hàng `ai_chat_page.dart` (ước ≈ 1.070 dòng) → trang **1.164** dòng sau Task 9; dời thêm **`DongKhoa`** (`dong_khoa.dart`)
    và **`HangChip`** (`hang_chip.dart`) ra `widgets/tro_ly_ai/` (kế hoạch, rủi ro 4) → **1.141** dòng (`wc -l` 2026-10-17); không
    `mienTru` (Task 10).
14. **Chưa quyết — hỏi người dùng khi nghiệm thu:** (a) câu định nghĩa / tư vấn khi máy chủ hỏng → AI trên máy trả `kCauTuChoi`
    trần, không ghi chú *máy chủ không phản hồi*; (b) khi tờ thông tin đang mở, hàng phía sau hiện *Đang nghĩ…*; (c) `_hoiOnline`
    `catch` khi đã có chữ → `GiuPhanDaCo` (đúng §3.3) nhưng datasource không bao giờ ném nên nhánh ấy chưa có ca phủ.
15. §7 — id ba màn Stitch đã ghi (commit `b6eb9975`); người dùng chưa xác nhận trên Stitch (Task 0).
16. §3.5 c — thẻ *Trợ lý online* và khối Riêng tư đặt **ngoài** cổng quyền `ai_edge_model` của màn Cài đặt AI (thẻ online chỉ khi
    `coQuyen(ai_assistant)`; Riêng tư luôn hiện; khối mô hình + *Dùng AI trên máy* vẫn trong cổng) — vì gói có `ai_assistant` mà
    không `ai_edge_model` sẽ kẹt sau khi bấm *Chỉ dùng AI trên máy* (cờ gắn máy, không bật lại được), trái lời hứa *"Đổi lại được
    ở Cài đặt AI"*; mặc định Basic / Premium không gặp, chỉ cấu hình admin tách khoá. Hai thẻ công tắc gom vào helper
    `_theCongTacChung` (Task 11).
17. Test — ca *"thẻ thứ hai đọc cờ"* seed `'false'` (seed `'true'` trùng mặc định nên không canh vế đọc); fixture kho trống
    `KhoGia({})` ở ba ca tờ thông tin để canh §3.5 a (máy mới → câu đầu đi online + tờ hiện) (Task 10, Task 11).
