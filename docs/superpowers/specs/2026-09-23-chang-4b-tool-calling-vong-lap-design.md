# Chặng 4b — tầng tool + vòng lặp cho màn Trợ lý AI (thiết kế)

**Ngày:** 2026-09-23 · **Nhánh:** `TranQuangDat` @ `94ac53c` · **Trạng thái:** đã duyệt (người dùng, 2026-09-23, sau lượt tự soát năm chỗ)
**Đầu vào:** bảng đo 20 câu + đơn đặt hàng sáu tool, mục **5.6** `docs/AI_AGENT_ARCHITECTURE.md`;
kết quả lát 4a (*"Đo lại sau chặng 4a"* ở cuối mục ấy, và mục **9.12** `docs/AI_EDGE_FEATURE.md`)
**Khung cố định:** lộ trình `docs/superpowers/plans/2026-09-21-lo-trinh-edge-ai-agent-rag.md`, mục
*"Chặng 4"* · **Ba quyết định của người dùng trong lượt brainstorm 2026-09-23** (mục 1.2)

> ✅ **THI CÔNG XONG 9/9 TASK — CỔNG C ĐẠT trên cả hai máy (2026-09-23 chiều).** Màn Trợ lý AI đi
> bậc tool từ `863c4cd`. Tám câu mục 5, APK release: nhóm A trả lời **bằng tên** Realme **4/4**,
> OnePlus **3/4**; câu 2, 9 đúng; ĐC1 không bịa số; ĐC2 không tụt; 0 lần sập; mô hình chọn đúng tool
> + tham số ở 8/8 câu mỗi máy. Tổng một câu 10–15 s Realme CPU / 4,5–8,6 s OnePlus GPU — nằm trong
> dải mục 1.2. Bảng: mục **9.14** `docs/AI_EDGE_FEATURE.md`. Lượt đo bắt **ba lỗi thật** ở phía
> app, sửa cùng ngày (`ace9a53`, bẫy **4.34–4.36**): thẻ số liệu xét "câu nhắc tới" trên cả tin nhắn;
> `GoiSoTraCuu.mauCau()` (mục 3.3) phẳng nên sau nhiều lời gọi lặp hàng và mất nhãn kỳ — spec
> **không lường** trường hợp mô hình gọi cùng tool với nhiều kỳ rồi chạm trần; câu trả lời bậc tool
> có thể là markdown. Và mục **3.6** đoán sai một điều: *"trước khi có hàng, chữ bị bỏ"* đúng, nhưng
> giá của L1 trên Realme là **~23 s** cho một câu chào (vứt câu mô hình rồi sinh lại ở bậc 1).
>
> *(Banner giữa ngày, giữ làm lịch sử:)* Task 1–4 (`0c9ca1e` → `87ef4f3`) và 5a (`21389ea`, hàng
> hoá đơn) khi ấy chưa nối vào màn nào. Với gói cũ, engine **sập native** ở mọi phiên có
> tool trên **cả hai máy** — Realme 3/3 (`SIGSEGV`), OnePlus 13R 2/2 (`SIGBUS`) — trong
> `CompositeLogitMask::Apply`. ⚠️ **Mục 4 dưới đây ("không thêm gói `pubspec`") ĐÃ BỊ PHÁ, có duyệt**:
> người dùng duyệt đích danh nâng `flutter_gemma` 1.8.3 → **1.9.0** và `flutter_gemma_litertlm`
> ^1.7.0 → **1.8.0** (`af2aa81`) — sau đó **6/6 không sập**, E2B gọi đúng tool, lượt gọi 0 ký tự
> chữ. Mục **9.13** + bẫy **4.33** `docs/AI_EDGE_FEATURE.md`.
> **Hai chỗ spec đoán sai:** (1) mục **2** tả `tools_json` native nhưng **không** nói gói gắn cứng
> `enable_constrained_decoding = true` hễ có tool (`flutter_gemma_litertlm-1.7.0/lib/src/ffi/
> litert_lm_client.dart:1080–1086`) — chính thứ sập; (2) mục **3.7** bảo đo `chat.currentTokens`
> để canh trần token — thuộc tính ấy chỉ cộng token **câu trả lời** (`flutter_gemma-1.8.3/lib/core/
> chat.dart:706–708`), không đo được thứ bẫy 4.29 cần. Ngân sách độ trễ mục **1.2** chưa tính
> **0,7–1,2 s** dựng FST ràng buộc ở **mỗi** phiên — nhưng tổng thể lại **nhanh hơn** ước lượng:
> câu cần tool ~9 s OnePlus / ~12 s Realme, không phải 20–25 s.

---

## 1. Vì sao lát này tồn tại, và đích của nó

### 1.1 Điều 4a chứng minh

Chặng 3 đo 20 câu trên máy thật: **✅ 5 · rơi mẫu 3 · sai 0 · lệch câu hỏi 12**. Lát 4a cho mỗi con
số mang **tên đối tượng** và đo lại bốn câu nhóm A (*"cái nào"*): **1/4**. Log gói số thật cho thấy
tên đã vào đủ mà ba câu vẫn hỏng — gói nói `Quá hạn: 1` ở một dòng và `Kiem · Đã quá hạn: 45.000 đ`
ở dòng khác, mô hình lấy mục đếm trả lời. **Danh sách có tên là cần nhưng chưa đủ**: E2B không nối
hai mục rời bằng suy luận, và mục đếm nằm ngay cạnh câu hỏi là thứ nó bám vào.

Kết luận của 4a, chép nguyên: *"ba câu còn hỏng không chữa được bằng cách làm gói giàu thêm; thứ
cần là tool trả về **một hàng đầy đủ** (tên + số + trạng thái trong cùng kết quả)"*.

### 1.2 Ba quyết định đã chốt (2026-09-23, không hỏi lại)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Đích của lát | **Tầng tool + bốn tool "danh sách có tên"**: `danh_sach_ngan_sach` · `danh_sach_hoa_don` · `danh_sach_vi` · `chi_tieu_theo_ky`. `duBaoMucTieu`, `goiYHanMuc` và nhóm D (so sánh / trừ) **để lát sau** |
| 2 | Độ trễ hai lượt sinh (OnePlus GPU ~5–7 s · Realme CPU ~20–25 s) | **Chấp nhận trên cả hai máy, đo thật**; màn hiện trạng thái *"Đang tra cứu…"* trong lúc chờ; quá chậm thì quyết sau bằng số đo |
| 3 | Hướng | **A — tool THAY gói số trong prompt** (mục 3.1). B (tool cộng gói) bị loại vì prompt sát trần 2048 và tái hiện đúng lỗi 4a; C (định tuyến tất định) bị loại vì mô hình không chọn gì — câu *"là AI Agent"* của cổng C không đứng |

Cộng một quyết định giao diện: dòng chỉ báo đổi chữ theo tool đang chạy **không cần lên Stitch** —
tái dùng hàng chỉ báo sẵn có, không khối mới (màn `75abffa956bb4da99a112df704f2d487` *"Trợ lý Tài
chính AI"* giữ nguyên bố cục).

### 1.3 M3 không chặn lát này

Lộ trình dặn *"chốt M3 (luật ngủ đông: essentiality = 0,5; C4 bị C5 nuốt) trước khi viết kế hoạch
chặng 4"* vì tool tái phân bổ sẽ lộ luật ấy ra câu trả lời. **Sáu tool bảng 5.6 đặt hàng không có
tool tái phân bổ**, bốn tool của lát này càng không — M3 để nguyên trạng thái mở, áp mặc định của
lộ trình (*bỏ vế, ghi lý do*) khi nào có tool chạm tới `tai_phan_bo.dart`.

---

## 2. Điều đo được từ gói `flutter_gemma` 1.8.3 (đọc mã nguồn 2026-09-23, được phép)

Người viết kế hoạch **không phải đọc lại gói** — mọi điều lát này dựa vào ghi ở đây, kèm chỗ đọc.

| Điều | Ở đâu |
|---|---|
| `InferenceModel.createChat({tools, supportsFunctionCalls, toolChoice, systemInstruction, temperature, …})` | `lib/flutter_gemma_interface.dart:348` |
| Với `ModelType.gemma4` trên LiteRT-LM, khai báo tool đi bằng **`tools_json` native** lúc tạo hội thoại (`litert_lm_conversation_config_set_tools`), dạng OpenAI `{type: function, function: {name, description, parameters}}`; **prompt tool phía Dart bị bỏ qua** (`runtimeInjectsToolDeclarations = true`) | `flutter_gemma_litertlm-1.7.0/lib/src/ffi/ffi_inference_model.dart:120`, `lib/core/parsing/sdk_response_parser.dart` (`serializeToolsForSdk`), `lib/core/chat.dart:63,135` |
| Lượt mô hình gọi tool **thường không phát chữ**: luồng `{`-đầu bị gói nuốt (`sdkSwallow`), lời gọi có cấu trúc đọc từ `session.lastRawResponse` và phát ở **cuối** luồng dưới dạng `FunctionCallResponse` / `ParallelFunctionCallResponse`. Chữ đứng **trước** một lời gọi (nếu có) vẫn chảy ra luồng — vòng lặp phải bỏ nó (mục 3.6) | `lib/core/chat.dart:576–615` |
| Kết quả tool trả về mô hình bằng `Message.toolResponse(toolName:, response: Map<String, dynamic>)` — JSON, phía người dùng | `lib/core/message.dart` |
| `ToolChoice.required` **không ép được Gemma 4**: nó chỉ đổi prompt Dart, mà Gemma 4 bỏ qua prompt ấy → chỉ có `auto`; `none` thì tắt tool | `lib/core/tool.dart`, `chat.dart:141,991` |
| Gói có sẵn vòng lặp `generateChatResponseWithTools(onToolCall:, maxToolTurns:, isCancelled:)`; `maxToolTurns` đếm **cả** lượt trả lời cuối (3 lượt gọi tool + 1 câu trả lời = 4). Lát này **tự viết vòng lặp** trên `generateChatResponseAsync` + `addQueryChunk(Message.toolResponse)` — lý do ở mục 3.5 | `lib/core/chat.dart:787–914` |
| `Tool(name, description, parameters)` — `parameters` là JSON Schema dạng `Map` | `lib/core/tool.dart` |
| README ghi Gemma 4 E2B *"Full function calling support"*; **chưa ai đo trên máy của dự án** — đó là Task 1 | `README.md:1779` |

---

## 3. Thiết kế

### 3.1 Một câu, và sơ đồ

*Mô hình chọn công cụ, app chạy hàm domain có sẵn và trả về những hàng đầy đủ, mô hình viết câu từ
đúng những hàng ấy — và ba lớp chắn kiểm câu trên chính những hàng ấy.*

```
câu hỏi ──► chuDeBiChan? ──► PhienCongCu (chat có 4 tool; prompt KHÔNG mang số)
                                  │
                 ┌────────────────┴───── lượt 1..3 ──────────────┐
                 │  mô hình phát  GoiCongCu(ten, args)            │
                 │  app chạy CongCu.chay(args) → List<HangSoLieu> │
                 │  ├─ trả JSON cho mô hình (Message.toolResponse)│
                 │  └─ TÍCH LUỸ vào GoiSoTraCuu                    │
                 └───────────────────────────────────────────────┘
                                  │ lượt không gọi tool = câu trả lời
                                  ▼
                 gacTheoCau(kiem: kiemCauTraLoi(cau, [GoiSoTraCuu]))
                                  │
                 chưa tool nào chạy ──► rơi về BẬC 1 (sáu gói, đường hôm nay)
```

Prompt bậc tool **không mang con số nào**: chính mục đếm `Quá hạn: 1` nằm cạnh câu hỏi là thứ làm
câu 13 và 15 hỏng, và hướng A bỏ nó khỏi tầm nhìn của mô hình cho tới khi tool trả hàng về.

### 3.2 Bốn mảnh mới — theo đúng khuôn thư mục hiện có

| Mảnh | Ở đâu | Là gì |
|---|---|---|
| `HangSoLieu`, `KetQuaCongCu`, `GoiSoTraCuu` | `ai_edge/domain/hang_so_lieu.dart` (hai kiểu đầu), `ai_edge/domain/goi_so_tra_cuu.dart` | **Một hàng đầy đủ** = `ten` + `trangThai` (chữ, có thể `null`) + cờ `canhBao` + các `SoLieu` mang chính `ten` ấy. `GoiSoTraCuu extends GoiSo` (`man = 'tra_cuu'`) gom mọi hàng và mục tổng hợp của mọi lượt gọi trong **một** câu hỏi; `mauCau()` là bản liệt kê tất định các hàng (mục 3.6) |
| `CongCu`, `KhaiBaoCongCu` | `ai_edge/domain/cong_cu.dart` | Giao diện thuần của một tool và khai báo cho mô hình (tên, mô tả, JSON Schema tham số). Runtime dịch `KhaiBaoCongCu` sang `Tool` của gói |
| `SuKienLuot`, `PhienCongCu`, `PhienCongCuGia` | `ai_edge/data/phien_cong_cu.dart` — **không** import `flutter_gemma` | Giao diện **thuần** của một phiên hội thoại có tool + bản giả cho test, đúng tiền lệ `nguon_tai_nen.dart` (giao diện + `NguonTaiNenGia` cạnh nhau, bản thật ở tệp riêng) |
| `SlmRuntime.moPhien` | `ai_edge/data/slm_runtime.dart` | Bản thật của `PhienCongCu` (lớp riêng tư trong tệp) — **chỗ duy nhất** dịch sang `Tool` / `createChat` / `generateChatResponseAsync` / `Message.toolResponse`. **Test quét 16 giữ nguyên** |
| `CongCu` × 4 | `ai_edge/data/cong_cu_*.dart` (đọc repository) + `ai_edge/domain/hang_*.dart` (dựng hàng, thuần) | Khuôn `NguonGoiSo` ↔ `GoiSoX.tu()`: data **lấy**, domain **chép** số từ hàm domain sang hàng và gán `canhBao` từ enum domain. Không tool ghi |
| `BoCongCu` | `ai_edge/data/bo_cong_cu.dart` | Gom bốn `CongCu`, khai báo cho mô hình, tra tool theo tên; đăng ký DI **lazy** như `NguonGoiSo`. Hai phép chép dữ liệu mà `NguonGoiSo` đang làm inline (ví → `ViChoGoiSo`, lọc ngân sách đang chạy) **tách thành hàm dùng chung** trong `nguon_goi_so.dart` để tool và gói số không giữ hai bản |
| Vòng lặp | `ai_edge/data/vong_lap_cong_cu.dart` | Điều khiển `PhienCongCu`: trần 3 lời gọi, tích luỹ, phát `DangTraCuu` / `KhongTraCuu`, đưa chữ qua `gacTheoCau` **từ khi đã có hàng**, thang lùi (mục 3.6). Không import `flutter_gemma`; log bằng `print` (`// ignore_for_file: avoid_print`, tiền lệ `main.dart`) |

`ai_chat_page._luongThat` đổi **một** chỗ: gọi vòng lặp thay cho `NguonGoiSo.tatCa + promptHoiDap +
sinhDan`; đường cũ giữ nguyên làm **bậc 1** (nhánh lùi L1). `SuKienGac` (sealed) thêm `DangTraCuu`
— mọi `switch` thiếu nhánh **lỗi biên dịch**, cố ý.

**Vì sao hình dạng này.** (1) `GoiSoTraCuu implements GoiSo` giữ `kiemSoNhieuGoi` / `kiemNhan` /
`kiemGiong` / `theCuaCau` **không đổi một dòng** — bất biến ② (*"mọi tool trả `List<SoLieu>`"*) vẫn
đúng, chỉ khác là `SoLieu` đi **theo hàng** thay vì rời; (2) `PhienCongCu` thuần để vòng lặp và bốn
tool test được trên x86_64, đúng khuôn `SlmRuntime` / `NguonTaiNen`; (3) lượt gọi tool của Gemma 4
không phát chữ (mục 2) nên `gacTheoCau` chỉ chạy ở lượt cuối — không phải hoà giải streaming với tool.

### 3.3 Kiểu dữ liệu

```dart
/// Một hàng đầy đủ — thứ 4a đo được là còn thiếu.
class HangSoLieu {
  final String ten;              // "Kiem", "Giáo dục", "Tiền mặt", "Ăn uống"
  final String? trangThai;       // chữ do DOMAIN quyết: "đã quá hạn", "vượt hạn mức", "đang âm"…
                                 // null = hàng không có trạng thái (danh mục chi)
  final bool canhBao;            // do tool gán từ enum domain (overdue / isOverBudget / âm) —
                                 // GoiSoTraCuu suy `muc` từ cờ này, KHÔNG đọc chuỗi trangThai
  final List<SoLieu> soLieu;     // mỗi SoLieu mang ten == ten của hàng
  Map<String, dynamic> get json; // {"ten":…, "trang_thai":…, "<nhan>": "<chuoi>", …} — CHUỖI đã định dạng
}

/// Kết quả một lần chạy tool.
class KetQuaCongCu {
  final List<HangSoLieu> hang;   // ≤ kToiDaMucMoiGoi, đã xếp theo thứ tự đáng chú ý
  final List<SoLieu> tongHop;    // không ten: "Tổng còn lại", "Quá hạn" (đếm), "Tổng chi"…
  final Map<String, String> chuThem; // chữ KHÔNG số kèm cho mô hình: {"ky": "tháng trước"}
  final String? loi;             // tham số lạ → tool từ chối, nói vì sao
  factory KetQuaCongCu.loi(String vi);
  Map<String, dynamic> get json; // {"hang": [...], "<nhan>": "<chuoi>", …chuThem, "loi": …}
}

/// Gói tích luỹ của MỘT câu hỏi — extends GoiSo để ba lớp chắn dùng nguyên.
class GoiSoTraCuu extends GoiSo {
  void them(String tenCongCu, KetQuaCongCu kq);   // tool KHÔNG tồn tại thì không gọi — không tính là đã tra cứu
  bool get daTraCuu;             // đã có ít nhất một tool thật chạy, kể cả trả 0 hàng (chốt L1)
  // man = 'tra_cuu'; soLieu = mọi SoLieu của hàng + tổng hợp; thieuDuLieu = !daTraCuu;
  // mauCau() = liệt kê tất định (3.6); muc = canhBao khi có hàng canhBao == true (3.5)
}

/// Khai báo cho mô hình — kiểu thuần, runtime dịch sang Tool của gói.
class KhaiBaoCongCu { final String ten; final String moTa; final Map<String, dynamic> thamSo; }

abstract class CongCu {
  KhaiBaoCongCu get khaiBao;
  /// [args] do mô hình sinh. Tool TỰ kiểm enum: giá trị lạ → từ chối (0 hàng + `loi`
  /// trong JSON trả về), không đoán (mục 3.4, quyết định 1). [idaccount] và [now] do
  /// vòng lặp truyền từ màn — tool không tự đọc phiên đăng nhập (quy tắc 2 `CLAUDE.md`).
  Future<KetQuaCongCu> chay(Map<String, dynamic> args, {required int idaccount, required DateTime now});
}

/// Bộ tool: khai báo cho mô hình + tra theo tên. `null` = mô hình bịa tên tool.
class BoCongCu {
  List<KhaiBaoCongCu> get khaiBao;
  Future<KetQuaCongCu?> chay(String ten, Map<String, dynamic> args, {required int idaccount, required DateTime now});
}

sealed class SuKienLuot {}                 // một lượt sinh phát:
class Chu extends SuKienLuot { final String token; }
class GoiCongCu extends SuKienLuot { final String ten; final Map<String, dynamic> args; }

// Hai sự kiện MỚI của `SuKienGac` (sealed, ở `gac_cau.dart`) mà vòng lặp phát cho màn:
class DangTraCuu extends SuKienGac { final String? ten; }  // ten = tool đang chạy; null = đã có hàng, mô hình đang viết
class KhongTraCuu extends SuKienGac {}                       // L1: lượt đầu không gọi tool → màn tự rơi về bậc 1

abstract class PhienCongCu {
  Stream<SuKienLuot> sinhLuot();           // kết thúc lượt: có GoiCongCu = mô hình muốn tool; không = câu trả lời
  Future<void> traKetQua(String ten, Map<String, dynamic> json);
  Future<void> huy();                      // stopGeneration lượt đang sinh
  Future<void> dong();
}
```

`SlmRuntime` thêm: `Future<PhienCongCu> moPhien({required String heThong, required String cauHoi,
required List<KhaiBaoCongCu> congCu})`. Bản thật: `createChat(tools: …, supportsFunctionCalls: true,
toolChoice: ToolChoice.auto, systemInstruction: heThong, temperature: 0.2)` rồi `addQueryChunk(
Message.text(text: cauHoi, isUser: true))`; `sinhLuot()` bọc `generateChatResponseAsync()` — `TextResponse`
→ `Chu`, `FunctionCallResponse` / `ParallelFunctionCallResponse` → `GoiCongCu` (mỗi lời gọi một sự kiện);
`traKetQua` → `addQueryChunk(Message.toolResponse(...))`.

### 3.4 Bốn tool

Tên tool là ASCII `snake_case` (định danh cho mô hình); **mô tả tiếng Việt nêu thẳng câu hỏi kiểu
nào thì gọi** — đó là thứ duy nhất dẫn E2B chọn đúng (không có few-shot ở bậc tool). Mỗi tool trả
**tối đa `kToiDaMucMoiGoi` = 4 hàng**, xếp theo thứ tự đáng chú ý (quá hạn trước · âm trước · tỉ lệ
cao trước · chi nhiều trước) — mô hình đọc từ trên xuống.

| Tool | Tham số | Mỗi hàng | Tổng hợp | Nguồn số — không tính gì mới |
|---|---|---|---|---|
| `danh_sach_ngan_sach` — *ngân sách nào sắp hết / còn bao nhiêu / dùng bao nhiêu %* | không | `displayName` · trạng thái: *vượt hạn mức* (`isOverBudget`) hoặc nhịp *tiêu nhanh / đúng nhịp / tiêu chậm* (`BudgetPace.status`) · Đã chi · Hạn mức · Tỉ lệ · Còn lại (`BudgetEntity.remaining`) · Còn (ngày) | Tổng còn lại · Số ngân sách | `BudgetView` đang chạy (lọc `isExpired` như `NguonGoiSo`), `budgetPaceOf` |
| `danh_sach_hoa_don` — *hoá đơn nào quá hạn / sắp đến hạn / còn phải trả* | `trang_thai` ∈ {`qua_han`, `chua_tra`, `da_tra`, `tat_ca`}, mặc định `chua_tra` | tên · trạng thái theo `billDisplayStatusOf` (*đã quá hạn / sắp đến hạn / chưa trả / đã trả / bỏ qua*) · Số tiền | Còn phải trả · Quá hạn (đếm) · Chưa trả (đếm) — `summarizeBills`, cùng bộ lọc kỳ của `GoiSoHoaDon` | `watchBills`, `conPhaiTra`, `billDisplayStatusOf`, `summarizeBills` |
| `danh_sach_vi` — *ví nào đang âm / tiền trong ví / có mấy ví* | không | tên · trạng thái: *đang âm* (cùng luật `GoiSoVi`: dưới ngưỡng và không `allowNegative`) / *ngoài tổng* / *lưu trữ* / *bình thường* · Số dư | Tổng tài sản (`viTinhVaoTong`) · Số ví | `watchAll`, `viTinhVaoTong` — chép từ `GoiSoVi` |
| `chi_tieu_theo_ky` — *tuần này / tháng trước / quý này tiêu bao nhiêu, chi nhiều nhất vào danh mục nào* | `ky` ∈ {`tuan_nay`, `thang_nay`, `thang_truoc`, `quy_nay`, `nam_nay`} | tên danh mục · Chi (`ThongKeKy.danhMuc`, đã giảm dần) | Tổng chi · Tổng thu · kỳ ghi bằng **chữ** (*"tháng trước"*) | `watchKy(ky:)` với `Ky.tuan / thang / quy / nam` + `lui` |

**Bốn quyết định:**

1. **Tham số là enum chữ, không phải ngày.** E2B sinh `"2026-08-01"` là rủi ro; `thang_truoc` thì
   không. Câu 9 (*tháng trước*) và 7 (*tuần này*) đủ với năm giá trị. Khoảng tuỳ chọn để lát sau.
   Giá trị lạ (ngoài enum) → tool **từ chối** (trả hàng rỗng + `loi` cho mô hình), không đoán.
2. **Không hàng nào mang ngày tháng.** Ngày cũng là số với `trichSo` (giới hạn cố ý ghi ở
   `kiem_so.dart`); đưa hạn *20/09* vào hàng là câu *"Kiem hạn 20/09"* bị chặn, hoặc phải thêm
   `LoaiSo.ngayThang`. Lát này không mở việc ấy — *"khi nào đến hạn"* ghi vào phần chưa làm.
3. **Trạng thái là chữ do domain quyết**: `billDisplayStatusOf`, `BudgetPaceStatus`, `viTinhVaoTong`
   + `allowNegative`. `ai_edge/` chỉ **dịch** enum sang chữ, không đặt thêm ngưỡng nào (test quét 14).
4. **Trần 4 hàng mỗi tool** — cùng hằng đã đo ở 4a. Cần hơn là số đo cho lát sau.

Với tham số, câu *"hoá đơn nào quá hạn"* nhận **đúng một hàng** `Kiem · đã quá hạn · 45.000 đ` — hình
dạng bảng 5.6 đặt hàng; mục đếm `Quá hạn: 1` vẫn có ở tổng hợp nhưng đứng **cạnh** hàng có tên.

### 3.5 Ba lớp chắn trên gói tích luỹ — không sửa lớp nào

Câu cuối đi qua `gacTheoCau(kiem: (c) => kiemCauTraLoi(c, [goiTraCuu]))` — cùng hàm với hôm nay,
chỉ khác danh sách gói. Hệ quả có sẵn từ 4a: hàng nào cũng mang `ten`, nên `kiemNhan` **đòi câu nêu
tên** — *"Kiem đã quá hạn 45.000 đ"* lọt, *"Có 45.000 đ hoá đơn quá hạn"* không. `mucTongHop` lấy
`canhBao` khi `GoiSoTraCuu` có hàng quá hạn / ví âm / vượt hạn mức (định nghĩa trong chính
`GoiSoTraCuu.mauCau().muc`, suy từ `trangThai` của hàng), nên `kiemGiong` chặn câu trấn an như cũ. Cờ `canhBao` do **tool** gán từ enum domain
(`BillDisplayStatus.overdue`, `isOverBudget`, ví âm theo luật `GoiSoVi`) — `GoiSoTraCuu` không đọc
chuỗi `trangThai` để đoán, vì đổi một chữ trong nhãn là đổi mức im lặng.
`theCuaCau(cau, [goiTraCuu])` dựng thẻ, nay nêu tên (*"Kiem · Số tiền 45.000 đ"*).

**Vì sao tự viết vòng lặp thay vì dùng `generateChatResponseWithTools`:** (a) trần **3 lượt gọi**
phải đúng nghĩa và hết trần phải rơi về L3, không phải "trả lời có thể rỗng" như gói; (b) mỗi lượt cần
một dòng log riêng cho cổng C; (c) chữ phát ở lượt gọi tool (nếu có) phải **bỏ**, không được lẫn vào
câu trả lời; (d) L1 cần biết *"đã có tool nào chạy chưa"* trước khi cho hiện chữ. Vòng lặp của gói
làm bốn việc ấy khó hơn là tự viết ~60 dòng trên giao diện thuần.

### 3.6 Trần, thang lùi, huỷ

**Trần: 3 lời gọi tool** (`kTranGoiCongCu`), tức thường là 4 lượt sinh. Lượt sinh nào có `GoiCongCu`
thì chạy tool và mở lượt kế; một lượt gọi song song nhiều tool đếm **từng** lời gọi; lời gọi nào làm
tổng **vượt** trần → L3 ngay, không chạy tool, không sinh thêm. Tool **bịa tên** cũng tốn một suất
(mô hình nhận `{"loi": …}` kèm danh sách tool thật) để vòng lặp không quay vô hạn.

| # | Khi nào | Làm gì | Tốn thêm |
|---|---|---|---|
| L1 | Lượt đầu mô hình **trả lời thẳng, không gọi tool nào** | **Vứt** câu ấy; rơi về **bậc 1** (sáu gói, đường hôm nay) | +1 lượt sinh |
| L2 | Tool đã chạy, mọi câu cuối trượt kiểm (hoặc rỗng) | Hiện **`GoiSoTraCuu.mauCau()`** — bản liệt kê tất định các hàng vừa tra | 0 |
| L3 | Hết trần 3 lượt mà chưa có câu trả lời | như L2 | 0 |
| L4 | Runtime ném | `_kHong` như hôm nay, kèm `debugPrint` | 0 |

*(Thêm sau spec, bước 1b ngày 2026-09-23: `moPhien` có một lỗi **riêng** không đi L4 —
`BacCongCuDaTat`, ném khi canary đã xác nhận máy này từng sập native ở phiên có tool; vòng lặp bắt
nó và đi **L1** (bậc 1), vì bậc 1 không mở phiên có tool nên vẫn chạy được. Mục **9.15**
`AI_EDGE_FEATURE.md`.)*

⚠️ **L1 là chốt quan trọng nhất.** Ở hướng A prompt không có số, nên câu trả lời thẳng chỉ có thể
là (a) *"không có dữ liệu"* — mà bậc 1 có thể trả lời được — hoặc (b) một câu **bịa không chứa chữ
số** (*"Bạn có một hoá đơn quá hạn là Kiem"*) — thứ `kiemSo` **không bắt được** vì không có số nào
để soát. Luật *"chưa tool nào chạy thì không câu nào của mô hình được hiện"* chặn cả hai bằng một
điều kiện, và là `ToolChoice.required` thi hành ở phía app (mục 2: gói không ép được Gemma 4).

**L2 dùng được vì `mauCau()` của gói tra cứu tự qua bộ kiểm** — mọi số của nó nằm trong chính gói
(ca test cùng tên với mọi gói khác). Đây là lần đầu màn Trợ lý AI có mẫu câu **thật** để rơi về; câu
*"chưa chắc"* chỉ còn khi L1 cũng không có gì. Dạng: *"Hoá đơn đã quá hạn: Kiem (45.000 đ). Còn
phải trả 155.000 đ."* — một câu mỗi tool đã chạy, tên trước số.

**Huỷ.** Người dùng rời màn hoặc hỏi câu mới giữa chừng → `PhienCongCu.huy()` (= `stopGeneration()`
lượt đang sinh) **và** cờ huỷ mà vòng lặp kiểm **giữa hai lượt** — không chạy tool tiếp, không mở
lượt mới. Cùng lý lẽ bẫy 4.15: trượt là huỷ ngay, không để engine giải mã tiếp.

**Chữ trước khi tool nào chạy bị bỏ, chỉ ghi log** — dù lượt ấy có gọi tool hay không, người dùng
không thấy chữ nào khi mô hình chưa có dữ liệu trước mắt. Từ khi đã có hàng, **mọi** chữ của mọi
lượt đi qua `gacTheoCau` (kiểm trên gói tích luỹ) và được hiện — kể cả một lượt vừa viết chữ vừa gọi
tool tiếp, vì câu đã qua kiểm là câu đúng. Câu qua kiểm rồi mới có câu trượt → giữ câu đã hiện,
**không** thay bằng mẫu câu (cùng luật với bậc 1 hôm nay); L2 chỉ khi **chưa** câu nào hiện.

**Giới hạn nói ra, không vá:** sau khi một tool đã chạy, một câu **không chứa chữ số** được hiện dù
tool trả 0 hàng (*"Bạn không có hoá đơn quá hạn"* — đúng và mong muốn). Câu bịa **tên** mà không có
số thì không lớp chắn nào canh — cùng giới hạn của bậc 1 hôm nay (`kiemSo` chỉ soát số); L1 thu hẹp
nó về đúng ca "đã có dữ liệu thật trước mắt mô hình".

**Log cho cổng C** — một dòng mỗi sự kiện, dùng `print` (bẫy 8.6: `debugPrint` bị tiết lưu):
`[SLM][tool] mở phiên: 4 tool, tools_json 2.310 ký tự, hệ thống 412 ký tự` ·
`[SLM][tool] lượt 1: gọi danh_sach_hoa_don {trang_thai: qua_han} → 1 hàng, 412 ms` ·
`[SLM][tool] lượt 2: trả lời, token đầu 8.120 ms` · `[SLM][tool] L1: không gọi tool → bậc 1`.

### 3.7 Prompt và trần token

Chỉ dẫn đi bằng `systemInstruction` native (tham số `createChat` đã có), ngắn: vai trợ lý tài chính;
*chưa tra cứu thì gọi công cụ*; *chỉ dùng tên và số do công cụ trả về, chép nguyên chuỗi*; *không
có thì nói rõ là không có*; *trả lời tiếng Việt, dưới 60 từ*. Tin người dùng = câu hỏi trần. **Không
few-shot** ở bậc tool. Bậc 1 (nhánh lùi) giữ nguyên `promptHoiDap`.

**Token — đo trước, nới sau.** Ước lượng (chưa đo): bốn khai báo tool ~400–600 token (runtime dựng
từ `tools_json`), mỗi hàng ~30–40, trả lời ≤ 300 (`tranToken`). Dưới trần 2048 **trên giấy**. Task 1
đo thật: độ dài `serializeToolsForSdk(tools)`, độ dài `heThong + cauHoi`, `chat.currentTokens` sau
mỗi lượt. Vượt → nới `maxTokens` lên 4096 và đo lại RAM/nạp — quyết bằng số đo (bẫy 4.29).

### 3.8 Giao diện — không khối mới

Hàng chỉ báo `_dangSoan()` hiện có (vòng xoay + *"Đang nghĩ…"*) đổi chữ theo `DangTraCuu(ten)`:
*"Đang tra cứu hoá đơn…"* (bảng tên tool → nhãn người đọc, một chỗ), mô hình bắt đầu viết câu thì
về *"Đang nghĩ…"*. Rơi về bậc 1 **im lặng** (H3) — người dùng chỉ thấy chờ lâu hơn. Người dùng chốt
**không đưa lên Stitch** (chỉ đổi chữ, không khối mới).

---

## 4. Những gì lát này KHÔNG làm

- `duBaoMucTieu`, `goiYHanMuc`; nhóm D (so sánh / trừ giữa hai nguồn) — lát sau, bằng hàm domain.
- Ngày tháng trong hàng (`LoaiSo.ngayThang`); khoảng thời gian tuỳ chọn cho `chi_tieu_theo_ky`.
- **Tool ghi** — bất biến ④; tool tái phân bổ (M3 mở).
- Đổi sáu khối Nhận xét (lối B giữ), đổi `kiemSo` / `kiemNhan` / `kiemGiong` / `gacTheoCau`.
- Đổi schema (v24), thêm trường đồng bộ, chạm `SyncEntityType`, thêm gói `pubspec`.
- `flutter_gemma_agent` (SKILL.md + vòng lặp của gói) — không cần cho bốn tool đọc.

---

## 5. Ra cổng C — đo trên máy thật

Realme RMX2205 (CPU) **bắt buộc**; OnePlus 13R nếu cắm. Tài khoản 10, dữ liệu thật. Gõ bằng
`adb shell input text` (không dấu, bẫy 4.28 với tên riêng), chờ **90 s** mỗi câu.

| Nhóm | Câu (số theo bảng 5.6) | Đạt khi |
|---|---|---|
| A còn hỏng | 8 danh mục nào · 13 hoá đơn nào · 15 ví nào · (3 ngân sách nào — canh hồi quy) | trả lời bằng **tên**, **≥ 3/4** |
| C tool phủ | 2 còn bao nhiêu tiền ngân sách · 9 tháng trước chi bao nhiêu | trả lời được |
| Đối chứng | một câu **không tool nào có** (*"lãi suất tiết kiệm của tôi"*) · một câu đang ✅ (6 hoặc 19) | câu đầu → L1/bậc 1 hoặc *"không có"*, **SAI = 0**; câu sau không tụt |

Mỗi câu ghi: tool + args (logcat `[SLM][tool]`), số lượt, token đầu, tổng thời gian, ô kết quả bốn
cột như 5.6. **Đạt** khi cả ba dòng đạt **và** logcat cho thấy đúng tool được gọi ở từng câu đúng.
Trượt thì lát này **không đóng**: ghi bảng, phân tích, quyết tiếp bằng số.

---

## 6. Bẫy đã biết trước, phải canh

| # | Bẫy | Hỏng thế nào |
|---|---|---|
| 1 | Cho hiện câu khi chưa tool nào chạy | câu bịa không số lọt qua `kiemSo` (mục 3.6, L1) — **im lặng** |
| 2 | Hàng mang ngày tháng | `trichSo` đọc `20/09` là số, câu đúng bị chặn (`kiem_so.dart`, giới hạn cố ý) |
| 3 | Tin `ToolChoice.required` | gói bỏ qua với Gemma 4, mô hình vẫn trả lời thẳng (mục 2) |
| 4 | Prompt + tool_json + hàng vượt 2048 | lỗi **cứng**, câu rỗng (bẫy 4.29) — Task 1 đo, không đoán |
| 5 | Chữ ở lượt gọi tool lẫn vào câu trả lời | người dùng thấy chữ chưa qua kiểm |
| 6 | Dùng `debugPrint` cho log đo | bị tiết lưu, mất dòng (bẫy 8.6) — dùng `print`, mỗi sự kiện một dòng |
| 7 | Tham số enum lạ | tool đoán thay vì từ chối → số của kỳ khác trả về với nhãn kỳ đúng |
| 8 | Ca test xanh ngay từ đầu | **thử bản sai có chủ ý** — luật dự án, vấp ba lần trong hai ngày |
| 9 | `adb shell input text` hỏng chữ hoa giữa từ | `MuaXe` → `Mũae` (4.28); câu có tên riêng chụp màn kiểm chữ đã vào |
| 10 | Dùng chung `Dio` của dự án | không liên quan lát này — nhắc vì P3 đã vấp |

---

## 7. Test

- **TDD** từng task; bản sai có chủ ý cho ca xanh ngay.
- Thuần: `hang_*_test` (hàng đúng tên / trạng thái / chuỗi, thứ tự đáng chú ý, trần 4, từ chối enum
  lạ), `goi_so_tra_cuu_test` (tích luỹ; `mucTongHop`; *"mẫu câu tự qua bộ kiểm số ở mọi nhánh"*),
  `vong_lap_cong_cu_test` với `PhienCongCuGia` chạy kịch bản: gọi tool → hàng vào gói → câu cuối kiểm
  trên gói · L1 · L2 · L3 · huỷ giữa lượt · chữ ở lượt tool bị bỏ · hai bất biến mới (*tool đã chạy thì
  mọi số trong câu hiện ra đều có trong hàng*; *chưa tool nào chạy thì không câu nào được hiện*).
- Widget: `ai_chat_page_test` — `DangTraCuu` đổi dòng chỉ báo; đường bậc 1 khi L1.
- Bản thật `SlmRuntimeThat.moPhien` chỉ đo trên máy — như `sinhDan` hôm nay.
- **Không** thêm test quét; test quét 14 và 16 giữ nguyên và phải xanh. Schema v24, payload, `pubspec`
  không đổi. Mức nền trước lát: `flutter test` **3470/3470** (3 skip); `flutter analyze` **26**, 0 error.

## 8. Phác kế hoạch (viết chi tiết bằng `writing-plans`)

*(Thứ tự chốt khi viết kế hoạch 2026-09-23: spike cần `moPhien` thật, mà `moPhien` cần kiểu thuần
— nên ba task kiểu/giao diện đi trước spike; spike vẫn đứng **trước** bốn tool và vòng lặp.)*

1. `HangSoLieu` · `KetQuaCongCu` (domain, thuần).
2. `GoiSoTraCuu` (+ `mauCau`, `muc`) và ghép với `kiemCauTraLoi` / `theCuaCau`.
3. `CongCu` · `KhaiBaoCongCu` · hằng tên tool · `cauDangTraCuu` (domain) · `SuKienLuot` ·
   `PhienCongCu` + `PhienCongCuGia` (`data/phien_cong_cu.dart`) · `DangTraCuu` / `KhongTraCuu` ở
   `gac_cau.dart` · `kPromptHeThongCongCu` · `SlmRuntime.moPhien` (giao diện + bản giả trong test).
4. **`moPhien` bản thật + Spike Realme**: một tool khai tay + một câu qua móc tạm `/spike` (không
   commit) → logcat có `GoiCongCu`; đo `tools_json`, độ trễ hai lượt. Chưa thấy lời gọi thì **chưa
   dựng tầng** — báo và quyết.
5. Bốn hàm dựng hàng (domain): `hangNganSach` · `hangHoaDon` · `hangVi` · `hangChiTieu`.
6. Bốn adapter data + `BoCongCu` + tách hai hàm dùng chung khỏi `NguonGoiSo` + DI.
7. Vòng lặp `hoiBangCongCu` + thang lùi + huỷ + log.
8. Nối `ai_chat_page` (+ `DangTraCuu`, dòng chỉ báo, `onHoiBac1`), bậc 1 làm nhánh lùi.
9. Đo cổng C + tài liệu (`AI_EDGE_FEATURE.md` 9.13, `AI_AGENT_ARCHITECTURE.md` 5.6 / 11 / 12,
   `PROJECT_CONTEXT.md` mục 14, `CLAUDE.md` hàng AI, banner spec này).
