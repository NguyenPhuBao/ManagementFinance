# P3 — Cắm SLM (Gemma 4 E2B) vào FlowMoney — kế hoạch thi công

> **Cho người thi công:** dùng `superpowers:executing-plans` (người dùng đã chốt lối
> inline ở các lát trước) để làm từng task. Mỗi bước có checkbox `- [ ]`.

**Goal:** Câu ở khối Nhận xét và màn Trợ lý AI do **mô hình trên máy** viết thay vì
mẫu câu — chạy offline, mọi con số vẫn từ tầng tất định, sai một số là rơi về mẫu câu.

> ✅ **NGƯỜI DÙNG CHỐT LỐI B ngày 2026-09-21.** Mô hình phục vụ **một chỗ duy nhất**:
> màn Trợ lý AI (Task 8). Bốn khối Nhận xét **giữ mẫu câu** — Task 7 **không** đăng ký
> `BoDienGiai` vào DI. Lý lẽ và cách đảo ngược ghi ngay tại Task 7 Step 4.
> ⚠️ Task 1–6 **không đổi gì** so với bản viết theo lối A.

**Architecture:** `BoDienGiai` đã là khe cắm sẵn từ P2 (`KhoiNhanXet` đọc
`sl<BoDienGiai>()`, không có thì dùng `const MauCau()`). P3 thêm một bản thi công thứ
hai — `SlmDienGiai` — bọc runtime `flutter_gemma`, đi qua `kiemSo`, và **rơi về
`goi.mauCau()`** ở mọi nhánh hỏng. Không màn nào của P2 phải sửa để dùng mô hình.

**Tech Stack:** `flutter_gemma 1.8.3` + `flutter_gemma_litertlm 1.7.0` (engine riêng,
**bắt buộc** — core không kèm engine nào), Gemma 4 E2B `.litertlm`, `path_provider` và
`connectivity_plus` (đã có trong `pubspec.yaml`).

**Spec:** `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md` mục 4, 5, 6.
**Bảng đo P1:** `docs/AI_EDGE_FEATURE.md` mục 8 — đọc **trước** mục 4.1 của spec, vì
P1 đã lật bậc thang ở đó.

---

## Global Constraints

- **Chỉ sửa `src/Client-app`.** Backend và Admin-web là vùng chỉ đọc.
- **Chỉ `slm_runtime.dart` được import `flutter_gemma`** — test quét `lib/` thứ **16**
  canh, cùng khuôn `realtime_socket.dart`.
- **Lớp `ai_edge/` không tính** — test quét thứ **14** cấm `'thu'`/`'chi'`/`'transfer'`/
  `walletId`/`transactionDao`/`.type ==`/`amount <`/`amount >` trong thư mục ấy.
- **Không đổi schema đồng bộ, không thêm trường payload.** Schema giữ **v24**;
  `sync_payload_contract_test.dart` **không đổi**.
- **Mô hình: Gemma 4 E2B cho MỌI máy** (người dùng chốt 2026-09-20). Tệp
  `gemma-4-E2B-it.litertlm`, **2,41 GB**, URL công khai không token:
  `https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm`
  ⚠️ **Không** dùng biến thể `-gpu.litertlm`: nhẹ hơn 0,6 GB nhưng **không nạp được**
  trên engine FFI Android dù tệp nguyên vẹn (P1 mục 8.2).
- **`ModelType.gemma4`, `ModelFileType.litertlm`**, `maxTokens: 1024`,
  `temperature: 0.2`, trần **120** token cho câu theo màn / **300** cho hỏi đáp tự do.
- **Không `Isolate.run`** — MediaPipe chạy trên luồng native, Dart chỉ `await`
  (spec 4.3; điều kiện 7 kiểm bằng khung hình trên máy thật).
- **Nạp lười**: chỉ nạp ở lần đầu một khối cần, giữ suốt phiên.
- `flutter test` và `flutter analyze` phải ở **mức nền**: 3106 pass / 1 skip, 26 issue
  / 0 error. Mỗi task chạy lại trước khi commit.
- Tệp test mới phải `git add -f` (`.gitignore` có `test/`).
- Kế hoạch và spec ở `docs/superpowers/` cũng bị gitignore → `git add -f`.

### ⚠️ Ba chỗ kế hoạch này CỐ Ý khác spec mục 4.1

| Spec | Kế hoạch này | Vì sao |
|---|---|---|
| Bậc thang E4B (≥ 8 GB) / E2B (4–8 GB) | **E2B cho mọi máy** | P1 đo: trên GPU hai mô hình tốn RAM **bằng nhau** (0,96 vs 0,97 GB), E2B nhanh gấp đôi, nhẹ hơn 1 GB, tiếng Việt không thua. Người dùng chốt 2026-09-20 |
| Đọc RAM bằng `ActivityManager.getMemoryInfo` qua kênh `MainActivity` | **Bỏ hẳn kênh RAM** | Kênh ấy sinh ra để *chọn giữa hai mô hình*; còn một mô hình thì không có gì để chọn. Máy không chạy được đã bị `try/catch` quanh `getActiveModel` bắt, và gói **tự nêu tên ABI** trong thông báo lỗi (P1 mục 8.3). Bỏ kênh = bớt một vùng mù của `flutter test` (bẫy 7.11 `NOTIFICATION_FEATURE.md`) |
| Pin < 15 % thì rơi về mẫu câu | **Bỏ điều kiện pin** | Sinh một câu mất **2,3 giây** (P1) — không phải tác vụ dài. Đọc pin đòi thêm kênh native hoặc gói mới, đổi lấy một phép chặn không ai thấy tác dụng |

Ba thay đổi này **đã ghi vào `docs/AI_EDGE_FEATURE.md` mục 8.5** và spec mục 4.1 đã có
banner 🛑. Đừng "sửa lại cho khớp spec".

---

## Cấu trúc tệp

```
lib/features/ai_edge/
  data/
    slm_runtime.dart        ⭐ tệp DUY NHẤT import flutter_gemma — nạp, sinh câu, đóng
    slm_cache.dart             cache theo dấu vân: bộ nhớ + tệp JSON, LRU 200 mục
    slm_dien_giai.dart         implements BoDienGiai — ghép cache + prompt + kiểm số
    mo_hinh_tai_ve.dart        trạng thái mô hình: có chưa, tải, tiến độ, huỷ, xoá
  domain/
    slm_prompt.dart            hàm THUẦN dựng prompt từ GoiSo (test được không cần máy)
    chu_de_chan.dart           blocklist chủ đề cho hỏi đáp tự do (thuần)
  presentation/pages/
    cai_dat_ai_page.dart       màn Cài đặt AI
lib/features/ai_chat/presentation/pages/
    ai_chat_page.dart       ✏️ thay chữ tĩnh bằng gói số thật, nối 5 handler rỗng (A11)
```

Tách `slm_prompt.dart` và `chu_de_chan.dart` sang `domain/` **có chủ ý**: chúng là hàm
thuần, test trọn vẹn không cần thiết bị; `data/` là nơi duy nhất chạm runtime và tệp.

---

### Task 0: Màn Stitch "Cài đặt AI" + mở tài liệu P3

**Files:**
- Modify: `docs/AI_EDGE_FEATURE.md` — mục 5 (bảng màn Stitch), mục 3 (vị trí mã)

**Interfaces:**
- Produces: id màn Stitch cho Task 6 dựng theo.

- [ ] **Step 1: Vẽ màn Stitch**

Dùng `mcp__stitch__generate_screen_from_text` trên dự án `FlowMoney`, `deviceType: MOBILE`.
Nội dung mô tả cần nêu: trạng thái mô hình (**chưa tải** / **đang tải %** / **đã tải,
2,41 GB**), nút tải chính, dòng cảnh báo *"Cần Wi-Fi — tệp 2,41 GB"*, thanh tiến độ có
nút Huỷ, nút **Xoá mô hình** (kiểu phá huỷ, màu `AppColors.error`), công tắc **"Dùng AI
trên máy"**, và một khối giải thích *"Mô hình chạy hoàn toàn trên máy bạn. Không có số
liệu nào rời khỏi thiết bị."*

⚠️ Lượt gọi có thể trả `timeout` mà màn **vẫn được tạo** — **đừng gọi lại**; chờ rồi
`mcp__stitch__list_screens` kiểm. Kết quả trả về **không chứng minh** công cụ đã làm gì:
hỏi người dùng nhìn giúp trên Stitch là phép đo duy nhất đáng tin.

- [ ] **Step 2: Chờ người dùng nghiệm thu màn**

Không dựng Flutter trước khi người dùng xác nhận (memory `dua-man-moi-len-stitch`).

- [ ] **Step 3: Ghi vào tài liệu**

Thêm một hàng vào bảng mục 5 `docs/AI_EDGE_FEATURE.md`: tên màn, id, ngày, ghi chú
nghiệm thu. Thêm `cai_dat_ai_page.dart` và bốn tệp `data/` vào cây mục 3.

- [ ] **Step 4: Commit**

```bash
git add docs/AI_EDGE_FEATURE.md
git commit -m "docs(ai-edge): mở P3 — màn Stitch Cài đặt AI, vị trí mã"
```

---

### Task 1: `slm_prompt.dart` — dựng prompt từ gói số (hàm thuần)

**Files:**
- Create: `lib/features/ai_edge/domain/slm_prompt.dart`
- Test: `test/features/ai_edge/domain/slm_prompt_test.dart`

**Interfaces:**
- Consumes: `GoiSo`, `SoLieu` từ `goi_so.dart`.
- Produces:
  - `String promptCauTheoMan(GoiSo goi)` — prompt cho một khối Nhận xét.
  - `String promptHoiDap(String cauHoi, List<GoiSo> goi)` — prompt cho màn Trợ lý AI.
  - `const String kPromptHeThong` — prompt hệ thống, dùng lại ở cả hai.

- [ ] **Step 1: Test đỏ**

```dart
// test/features/ai_edge/domain/slm_prompt_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/domain/slm_prompt.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';

class _GoiGia implements GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;

  /// Mức của hệ luật — prompt phải chở nó xuống (dòng MỨC), nên lớp giả phải
  /// đặt được. Mặc định `binhThuong` để mọi ca cũ dựng không đổi.
  final MucNhanXet muc;
  _GoiGia(this.man, this.soLieu, [this.muc = MucNhanXet.binhThuong]);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() => NhanXet(cau: 'mẫu', theSoLieu: soLieu, muc: muc);
  @override
  String get dauVan => 'gia';
}

void main() {
  final goi = _GoiGia('ngan_sach', [
    soTien('Đã chi', 45000),
    soPhanTram('Tỉ lệ', 90),
    soNgay('Còn', 11),
  ]);

  test('prompt chở ĐÚNG chuỗi đã định dạng của gói, không phải số thô', () {
    // `SoLieu.chuoi` là ba thứ cùng lúc: thẻ người dùng thấy, tập cho phép của
    // bộ kiểm số, và phần bơm vào prompt. Bơm `soTho` (45000.0) thì mô hình sẽ
    // chép lại "45000" — một chuỗi mà `kiemSo` vẫn cho qua nhưng người dùng
    // đọc là sai định dạng tiền của app.
    final p = promptCauTheoMan(goi);
    expect(p, contains('Đã chi: 45.000 đ'));
    expect(p, contains('Tỉ lệ: 90,0%'));
    expect(p, contains('Còn: 11 ngày'));
    expect(p, isNot(contains('45000')));
  });

  test('có prompt hệ thống và HAI ví dụ few-shot', () {
    final p = promptCauTheoMan(goi);
    expect(p, contains(kPromptHeThong));
    expect('Ví dụ'.allMatches(p).length, 2,
        reason: 'Spec mục 4.3 chốt hai ví dụ. Một ví dụ thì mô hình hay bịa '
            'thêm câu dẫn; ba thì tốn token vô ích ở trần 1024.');
  });

  test('⚠️ ví dụ few-shot KHÔNG được chứa số ngoài gói của chính nó', () {
    // Bẫy 4.1: bộ kiểm số không phân biệt số trang trí với số bịa. Nếu ví dụ
    // dạy mô hình nói một con số không có trong gói thật, mọi câu sinh ra đều
    // bị `kiemSo` chặn và P3 rơi về mẫu câu — im lặng, trông như mô hình kém.
    final p = promptCauTheoMan(goi);
    // ⚠️ Mốc cắt phải là `lastIndexOf` — chuỗi 'Số liệu:' xuất hiện TRONG chính
    // hai ví dụ, nên `indexOf` cắt ngay giữa ví dụ 1 và khối còn lại chỉ là cái
    // nhãn "Ví dụ 1.". Và bỏ dòng nhãn: số thứ tự của ví dụ không phải số liệu.
    final khoiViDu = p
        .substring(p.indexOf('Ví dụ 1'), p.lastIndexOf('Số liệu:'))
        .split('\n')
        .where((l) => !l.startsWith('Ví dụ '))
        .join('\n');
    for (final m in RegExp(r'\d[\d.,]*').allMatches(khoiViDu)) {
      expect(khoiViDu.split(m.group(0)!).length - 1, greaterThanOrEqualTo(2),
          reason: 'Số "${m.group(0)}" trong ví dụ phải xuất hiện ở CẢ phần số '
              'liệu lẫn phần câu của chính ví dụ ấy — nếu không, ví dụ đang '
              'dạy mô hình bịa.');
    }
  });

  test('prompt mang dòng MỨC đúng với mức của hệ luật', () {
    final canh = _GoiGia('ngan_sach', [soPhanTram('Tỉ lệ', 90)], MucNhanXet.canhBao);
    expect(promptCauTheoMan(canh), contains('MỨC: CẢNH BÁO'));
    expect(promptCauTheoMan(goi), contains('MỨC: BÌNH THƯỜNG'));
  });

  test('hỏi đáp: chở câu hỏi và gói của MỌI màn', () {
    final p = promptHoiDap('Tháng này tôi tiêu nhiều không?', [
      goi,
      _GoiGia('muc_tieu', [soPhanTram('Tiến độ', 55)]),
    ]);
    expect(p, contains('Tháng này tôi tiêu nhiều không?'));
    expect(p, contains('Đã chi: 45.000 đ'));
    expect(p, contains('Tiến độ: 55,0%'));
  });

  test('gói rỗng vẫn cho prompt hợp lệ, không ném', () {
    expect(() => promptCauTheoMan(_GoiGia('trang_chu', const [])),
        returnsNormally);
  });
}
```

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_edge/domain/slm_prompt_test.dart`
Expected: FAIL — `Error: Not found: 'package:flowmoney/features/ai_edge/domain/slm_prompt.dart'`

- [ ] **Step 3: Viết mã**

```dart
// lib/features/ai_edge/domain/slm_prompt.dart
/// Dựng prompt cho SLM từ gói số. Hàm **thuần**: không chạm runtime, không đọc
/// đồng hồ — nên test được trọn vẹn mà không cần thiết bị.
///
/// ⚠️ Bơm `SoLieu.chuoi` chứ **không** bơm `soTho`. Chuỗi ấy là thứ người dùng
/// thấy trên thẻ số liệu; mô hình chép lại nguyên văn thì câu và thẻ nói cùng
/// một con số, và `kiemSo` khớp được.
library;

import 'goi_so.dart';
import 'nhan_xet.dart'; // ⚠️ _dongMuc cần MucNhanXet

/// Chép **nguyên văn** mục 3.2 đặc tả gốc của backend (`docs/AI/AI_Edge-SLM.md/
/// Client-app.md`) — đừng sửa chữ ở đây mà không sửa tài liệu ấy trước.
const String kPromptHeThong =
    'Bạn là trợ lý tài chính. CHỈ sử dụng số liệu trong JSON được cung cấp. '
    'KHÔNG được tự tính toán, suy đoán, hoặc tạo ra con số không có trong dữ liệu. '
    'Nếu thiếu thông tin để trả lời, hãy nói rõ là không có dữ liệu, không bịa.';

/// Hai ví dụ few-shot. ⚠️ Mọi con số ở đây xuất hiện **cả** ở phần số liệu lẫn
/// phần câu của chính ví dụ — xem ca test cùng tên. Một ví dụ dạy mô hình nói
/// con số không có trong gói là làm mọi câu thật bị bộ kiểm số chặn.
const String _viDu = '''
Ví dụ 1.
Số liệu:
Ngân sách: Ăn uống
Đã chi: 400.000 đ
Hạn mức: 500.000 đ
Tỉ lệ: 80,0%
Câu: Ăn uống đã dùng 400.000 đ trên hạn mức 500.000 đ, tức 80,0%.

Ví dụ 2.
Số liệu:
Tổng chi: 1.200.000 đ
Tổng thu: 9.000.000 đ
Câu: Kỳ này chi 1.200.000 đ trên 9.000.000 đ thu.
''';

String _dongSoLieu(GoiSo g) =>
    [for (final s in g.soLieu) '${s.nhan}: ${s.chuoi}'].join('\n');

/// Dòng MỨC: hệ luật đã kết luận, mô hình chỉ diễn đạt. Không có dòng này thì
/// mô hình tự "đánh giá" từ số và có thể nói ngược (kiemGiong là lớp chắn sau).
String _dongMuc(GoiSo goi) => switch (goi.mauCau().muc) {
      MucNhanXet.canhBao =>
        'MỨC: CẢNH BÁO. Câu phải mang giọng cảnh báo, không được trấn an.',
      MucNhanXet.binhThuong =>
        'MỨC: BÌNH THƯỜNG. Câu mang giọng trung tính, không hù doạ.',
      MucNhanXet.thieuDuLieu => 'MỨC: THIẾU DỮ LIỆU.',
    };

String promptCauTheoMan(GoiSo goi) => '$kPromptHeThong\n\n$_viDu\n'
    '${_dongMuc(goi)}\n'
    'Viết MỘT câu tiếng Việt nhận xét, dưới 40 từ, chỉ dùng số dưới đây. '
    'Bỏ qua dòng nào không đáng nhắc với người đọc.\n'
    'Số liệu:\n${_dongSoLieu(goi)}\nCâu:';

String promptHoiDap(String cauHoi, List<GoiSo> goi) => '$kPromptHeThong\n\n$_viDu\n'
    'Trả lời câu hỏi dưới đây bằng tiếng Việt, dưới 80 từ, chỉ dùng số trong '
    'phần Số liệu.\n'
    'Số liệu:\n${goi.map(_dongSoLieu).join('\n')}\n'
    'Câu hỏi: $cauHoi\nTrả lời:';
```

⚠️ Câu *"Bỏ qua dòng nào không đáng nhắc"* có trong prompt vì P1 đo được: **cả hai
mô hình đọc hết mọi dòng của gói**, kể cả dòng vô nghĩa với người đọc — E4B nói
*"nguồn bù 1"*. Đó là lỗi của prompt, không phải của mô hình (mục 8.4).

- [ ] **Step 4: Chạy, xác nhận xanh**

Run: `flutter test test/features/ai_edge/domain/slm_prompt_test.dart`
Expected: PASS (5 ca)

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai_edge/domain/slm_prompt.dart
git add -f test/features/ai_edge/domain/slm_prompt_test.dart
git commit -m "feat(ai-edge): slm_prompt — dựng prompt từ gói số, hàm thuần"
```

---

### Task 2: `chu_de_chan.dart` — blocklist chủ đề (hàm thuần)

**Files:**
- Create: `lib/features/ai_edge/domain/chu_de_chan.dart`
- Test: `test/features/ai_edge/domain/chu_de_chan_test.dart`

**Interfaces:**
- Produces:
  - `bool chuDeBiChan(String cauHoi)`
  - `const String kCauTuChoi` — câu trả lời cố định khi bị chặn.

- [ ] **Step 1: Test đỏ**

```dart
// test/features/ai_edge/domain/chu_de_chan_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/domain/chu_de_chan.dart';

void main() {
  group('chặn chủ đề ngoài phạm vi', () {
    for (final c in [
      'Tôi nên đầu tư vào đâu?',
      'Mua chứng khoán gì bây giờ',
      'Bitcoin có nên mua không',
      'Vay ngân hàng nào lãi thấp',
      'Cách né thuế thu nhập cá nhân',
    ]) {
      test('chặn: "$c"', () => expect(chuDeBiChan(c), isTrue));
    }
  });

  group('không chặn câu hỏi về số liệu của chính người dùng', () {
    for (final c in [
      'Tháng này tôi tiêu nhiều không?',
      'Ngân sách nào sắp vượt?',
      'Tôi còn thiếu bao nhiêu để đạt mục tiêu',
      'Vì sao tiền của tôi hết nhanh vậy',
    ]) {
      test('lọt: "$c"', () => expect(chuDeBiChan(c), isFalse));
    }
  });

  test('⚠️ KHÔNG bỏ dấu khi so — "đầu tư" khác "dau tu"', () {
    // Quy tắc 7 `CLAUDE.md`: bỏ dấu là phép so MẤT thông tin. Ở đây nó còn
    // nguy hiểm hơn chỗ khác: "đấu tố", "đầu tuần", "dấu tích" đều về cùng một
    // chuỗi với "đầu tư" nếu bỏ dấu, và người dùng bị từ chối một câu hỏi
    // hoàn toàn hợp lệ mà không hiểu vì sao.
    // ⚠️ Câu thử phải là câu mà việc bỏ dấu THỬC SỰ làm nó trùng từ khoá:
    // "đầu tuần" → "dau tuan", chứa "dau tu". Câu "Tuần đầu tháng" →
    // "tuan dau thang" KHÔNG chứa "dau tu", nên nó xanh cả trên bản bỏ dấu
    // — tức không canh được gì (đo bằng bản sai 2026-09-22).
    expect(chuDeBiChan('Đầu tuần này tôi tiêu bao nhiêu'), isFalse);
  });

  test('chặn không phân biệt hoa thường', () {
    expect(chuDeBiChan('ĐẦU TƯ gì bây giờ'), isTrue);
  });

  test('câu rỗng thì không chặn', () => expect(chuDeBiChan('  '), isFalse));
}
```

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_edge/domain/chu_de_chan_test.dart`
Expected: FAIL — không tìm thấy `chu_de_chan.dart`

- [ ] **Step 3: Viết mã**

```dart
// lib/features/ai_edge/domain/chu_de_chan.dart
/// Blocklist chủ đề cho hỏi đáp tự do (spec mục 4.4).
///
/// App có số liệu chi tiêu của một người; nó **không** có cơ sở nào để khuyên
/// về đầu tư, chứng khoán, tiền mã hoá, vay ngân hàng hay thuế — và một mô hình
/// 2,3 tỉ tham số chạy trên điện thoại thì càng không. Lời khuyên sai ở những
/// chủ đề ấy gây thiệt hại thật.
///
/// ⚠️ So **có dấu** (quy tắc 7 `CLAUDE.md`): bỏ dấu gộp "đầu tư" với "đầu
/// tuần" và từ chối một câu hỏi hợp lệ.
library;

const String kCauTuChoi =
    'Mình chỉ nhận xét được trên số liệu của bạn trong app.';

const List<String> _tuKhoaChan = [
  'đầu tư',
  'chứng khoán',
  'cổ phiếu',
  'trái phiếu',
  'tiền mã hoá',
  'tiền mã hóa',
  'tiền ảo',
  'bitcoin',
  'crypto',
  'vay ngân hàng',
  'lãi suất ngân hàng',
  'thuế',
];

bool chuDeBiChan(String cauHoi) {
  final s = cauHoi.toLowerCase();
  return _tuKhoaChan.any(s.contains);
}
```

- [ ] **Step 4: Chạy, xác nhận xanh**

Run: `flutter test test/features/ai_edge/domain/chu_de_chan_test.dart`
Expected: PASS (12 ca)

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai_edge/domain/chu_de_chan.dart
git add -f test/features/ai_edge/domain/chu_de_chan_test.dart
git commit -m "feat(ai-edge): blocklist chủ đề cho hỏi đáp tự do"
```

---

### Task 3: `slm_cache.dart` — cache theo dấu vân

**Files:**
- Create: `lib/features/ai_edge/data/slm_cache.dart`
- Test: `test/features/ai_edge/data/slm_cache_test.dart`

**Interfaces:**
- Consumes: `dauVanCua(GoiSo)` từ `dau_van.dart`.
- Produces:
  - `class SlmCache` với `Future<void> nap()`, `String? doc(String dauVan)`,
    `Future<void> ghi(String dauVan, String cau)`, `Future<void> xoaHet()`.
  - `const int kTranCache = 200`.
  - Hàm dựng `SlmCache({required Future<Directory> Function() thuMuc})` — tiêm
    thư mục để test không cần `path_provider`.

- [ ] **Step 1: Test đỏ**

```dart
// test/features/ai_edge/data/slm_cache_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/slm_cache.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('slmcache'));
  tearDown(() => tmp.deleteSync(recursive: true));

  SlmCache dung() => SlmCache(thuMuc: () async => tmp);

  test('ghi rồi đọc lại trong cùng phiên', () async {
    final c = dung();
    await c.nap();
    await c.ghi('van1', 'Câu một');
    expect(c.doc('van1'), 'Câu một');
  });

  test('dấu vân lạ trả null', () async {
    final c = dung();
    await c.nap();
    expect(c.doc('chua-co'), isNull);
  });

  test('sống qua phiên — bản mới đọc được tệp bản cũ ghi', () async {
    final a = dung();
    await a.nap();
    await a.ghi('van1', 'Câu một');

    final b = dung();
    await b.nap();
    expect(b.doc('van1'), 'Câu một',
        reason: 'Cache chỉ đáng giá khi sống qua lần mở app sau: stream phát '
            'lại sau MỖI chu kỳ đồng bộ, và gọi lại mô hình cho một gói số '
            'không đổi là 2,3 giây mỗi lần.');
  });

  test('⚠️ quá trần thì bỏ mục CŨ NHẤT, giữ đủ trần', () async {
    final c = dung();
    await c.nap();
    for (var i = 0; i < kTranCache + 10; i++) {
      await c.ghi('van$i', 'Câu $i');
    }
    expect(c.doc('van0'), isNull, reason: 'mục cũ nhất phải bị bỏ');
    expect(c.doc('van${kTranCache + 9}'), 'Câu ${kTranCache + 9}');
  });

  test('⚠️ đọc lại một mục làm nó THÀNH MỚI, không bị bỏ ở lượt dọn sau',
      () async {
    // LRU chứ không FIFO: gói số của Trang chủ được đọc mỗi lần mở app, nên nó
    // phải sống sót dù được ghi từ lâu. FIFO thuần sẽ bỏ đúng mục dùng nhiều
    // nhất — và không gì báo, chỉ là mô hình bị gọi lại.
    final c = dung();
    await c.nap();
    await c.ghi('cu', 'Câu cũ');
    for (var i = 0; i < kTranCache - 1; i++) {
      await c.ghi('van$i', 'Câu $i');
    }
    c.doc('cu'); // chạm vào
    await c.ghi('moi', 'Câu mới'); // vượt trần → phải bỏ 'van0', không phải 'cu'
    expect(c.doc('cu'), 'Câu cũ');
    expect(c.doc('van0'), isNull);
  });

  test('tệp JSON hỏng thì nạp thành cache RỖNG, không ném', () async {
    File('${tmp.path}/slm_cache.json').writeAsStringSync('{khong-phai-json');
    final c = dung();
    await expectLater(c.nap(), completes);
    expect(c.doc('bat-ky'), isNull);
  });

  test('xoaHet dọn cả bộ nhớ lẫn tệp', () async {
    final c = dung();
    await c.nap();
    await c.ghi('van1', 'Câu một');
    await c.xoaHet();
    expect(c.doc('van1'), isNull);

    final b = dung();
    await b.nap();
    expect(b.doc('van1'), isNull);
  });
}
```

⚠️ **`xoaHet()` tồn tại vì một lý do ngoài cache**: câu trong đó nói về số liệu tài
chính của **một tài khoản**. Trên máy dùng chung, người sau đăng nhập không được thấy
câu của người trước. Dấu vân gần như chắc chắn khác nhau (gói số khác thì md5 khác),
nhưng "gần như chắc chắn" không phải cơ chế cô lập — cùng lý lẽ đã bắt
`purgeDataForOtherAccounts` phải tồn tại dù SQLite đã lọc theo `idaccount`. Task 7 nối
`xoaHet()` vào đúng chỗ ấy.

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_edge/data/slm_cache_test.dart`
Expected: FAIL — không tìm thấy `slm_cache.dart`

- [ ] **Step 3: Viết mã**

```dart
// lib/features/ai_edge/data/slm_cache.dart
/// Cache câu theo **dấu vân của gói số** (spec mục 4.5).
///
/// Vì sao cần: `KhoiNhanXet` nghe một stream phát lại sau **mỗi** chu kỳ đồng
/// bộ. Không cache thì mỗi lượt phát là 2,3 giây chạy mô hình cho một gói số y
/// hệt lượt trước — và người dùng thấy câu nhấp nháy.
///
/// LRU chứ không FIFO: gói Trang chủ được đọc mỗi lần mở app, nên nó phải sống
/// sót dù ghi từ lâu. `Map` của Dart giữ **thứ tự chèn**, nên "chạm vào" =
/// xoá rồi chèn lại ở cuối.
library;

import 'dart:convert';
import 'dart:io';

const int kTranCache = 200;

class SlmCache {
  final Future<Directory> Function() thuMuc;
  final Map<String, String> _bo = {};
  File? _tep;

  SlmCache({required this.thuMuc});

  Future<void> nap() async {
    _tep = File('${(await thuMuc()).path}/slm_cache.json');
    if (!_tep!.existsSync()) return;
    try {
      final j = jsonDecode(_tep!.readAsStringSync()) as Map<String, dynamic>;
      _bo
        ..clear()
        ..addAll(j.map((k, v) => MapEntry(k, v as String)));
    } catch (_) {
      // Tệp hỏng (ghi dở vì máy tắt giữa chừng) thì bắt đầu lại từ rỗng. Cache
      // là thứ suy lại được — ném ở đây là làm hỏng cả khối Nhận xét vì một
      // tệp phụ.
      _bo.clear();
    }
  }

  String? doc(String dauVan) {
    final c = _bo.remove(dauVan);
    if (c != null) _bo[dauVan] = c; // chạm vào → thành mới nhất
    return c;
  }

  Future<void> ghi(String dauVan, String cau) async {
    _bo
      ..remove(dauVan)
      ..[dauVan] = cau;
    while (_bo.length > kTranCache) {
      _bo.remove(_bo.keys.first);
    }
    await _luu();
  }

  Future<void> xoaHet() async {
    _bo.clear();
    await _luu();
  }

  Future<void> _luu() async {
    final t = _tep;
    if (t == null) return;
    try {
      t.writeAsStringSync(jsonEncode(_bo));
    } catch (_) {
      // Đĩa đầy hoặc không ghi được: cache trong bộ nhớ vẫn chạy hết phiên.
    }
  }
}
```

- [ ] **Step 4: Chạy, xác nhận xanh**

Run: `flutter test test/features/ai_edge/data/slm_cache_test.dart`
Expected: PASS (7 ca)

- [ ] **Step 5: Thử bản sai có chủ ý cho ca LRU**

Đổi `doc()` thành `String? doc(String dauVan) => _bo[dauVan];` (bỏ phần chạm vào).
Run lại: ca *"đọc lại một mục làm nó THÀNH MỚI"* phải **đỏ**. Khôi phục.

Nếu ca ấy vẫn xanh thì test không canh gì — sửa test trước khi đi tiếp.

- [ ] **Step 6: Commit**

```bash
git add lib/features/ai_edge/data/slm_cache.dart
git add -f test/features/ai_edge/data/slm_cache_test.dart
git commit -m "feat(ai-edge): cache câu theo dấu vân gói số, LRU 200 mục"
```

---

### Task 4: `slm_runtime.dart` + test quét `lib/` thứ 16

**Files:**
- Modify: `src/Client-app/pubspec.yaml` — thêm `flutter_gemma` và `flutter_gemma_litertlm`
- Create: `lib/features/ai_edge/data/slm_runtime.dart`
- Create: `test/features/ai_edge/chi_mot_noi_import_gemma_test.dart`

**Interfaces:**
- Produces:
  - `abstract class SlmRuntime` — `Future<void> moHinhSan(String duongTep)`,
    `Future<String> sinh(String prompt, {int tranToken})`, `Future<void> dong()`,
    `bool get dangSan`.
  - `class SlmRuntimeThat implements SlmRuntime` — bản duy nhất chạm `flutter_gemma`.

- [ ] **Step 1: Thêm gói**

```yaml
# pubspec.yaml, khối dependencies
  flutter_gemma: 1.8.3
  flutter_gemma_litertlm: ^1.7.0
```

⚠️ **Hai gói, không phải một.** `flutter_gemma` core **không kèm engine nào**; thiếu
`flutter_gemma_litertlm` thì `getActiveModel()` ném *"add the engine package"*. Đây là
điều P1 lật (mục 8.5). Ghim `flutter_gemma` **cứng** `1.8.3` như `fl_chart` — nâng gói
chạy mô hình là việc phải đo lại, không phải việc `pub upgrade` tự làm.

Run: `flutter pub get`

- [ ] **Step 2: Test đỏ — test quét thứ 16**

```dart
// test/features/ai_edge/chi_mot_noi_import_gemma_test.dart
/// Test quét `lib/` thứ MƯỜI SÁU: chỉ `slm_runtime.dart` được import
/// `flutter_gemma`.
///
/// Cùng khuôn `realtime_socket.dart` và cùng lý do: gói chạy mô hình có API
/// riêng, đổi bản là đổi chữ ký. Một chỗ import là một chỗ phải sửa khi nâng
/// gói — và một chỗ nữa không ai nhớ ra khi P4 đổi mô hình.
///
/// Nó cũng giữ đúng hình dạng kiến trúc: mọi thứ ngoài tệp ấy nói chuyện với
/// `SlmRuntime` (giao diện thuần), nên test dựng được bản giả mà không cần
/// thiết bị arm64.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chỉ slm_runtime.dart import flutter_gemma', () {
    const duocPhep = 'lib/features/ai_edge/data/slm_runtime.dart';
    final pham = <String>[];

    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final duong = f.path.replaceAll(r'\', '/');
      if (duong == duocPhep) continue;
      final dong = f.readAsLinesSync();
      for (var i = 0; i < dong.length; i++) {
        final l = dong[i].trim();
        if (l.startsWith('//') || l.startsWith('///')) continue;
        if (l.contains("package:flutter_gemma")) {
          pham.add('$duong:${i + 1}: ${l.trim()}');
        }
      }
    }

    expect(pham, isEmpty,
        reason: 'Chỉ `$duocPhep` được import flutter_gemma. Chỗ khác cần mô '
            'hình thì nhận `SlmRuntime` qua tham số.\nVi phạm:\n'
            '${pham.join('\n')}');
  });
}
```

- [ ] **Step 3: Chạy, xác nhận đỏ đúng lý do**

Run: `flutter test test/features/ai_edge/chi_mot_noi_import_gemma_test.dart`
Expected: PASS ngay (chưa tệp nào import) — **ca này xanh từ đầu**, nên Step 6 phải
thử bản sai có chủ ý.

- [ ] **Step 4: Viết `slm_runtime.dart`**

```dart
// lib/features/ai_edge/data/slm_runtime.dart
/// Tệp **DUY NHẤT** của dự án được import `flutter_gemma` — test quét thứ 16
/// canh (cùng khuôn `realtime_socket.dart`).
///
/// Mọi chỗ khác nhận [SlmRuntime], một giao diện thuần, nên test dựng được bản
/// giả mà không cần máy arm64 — và `flutter test` chạy trên x86_64 của máy
/// phát triển.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

/// Runtime mô hình. Ba trạng thái: chưa nạp, đang sẵn, đã đóng.
abstract class SlmRuntime {
  bool get dangSan;

  /// Nạp mô hình từ [duongTep]. Ném khi máy không chạy được — người gọi bắt và
  /// rơi về mẫu câu.
  Future<void> moHinhSan(String duongTep);

  Future<String> sinh(String prompt, {int tranToken});

  Future<void> dong();
}

class SlmRuntimeThat implements SlmRuntime {
  InferenceModel? _model;
  bool _daKhoiTao = false;

  @override
  bool get dangSan => _model != null;

  @override
  Future<void> moHinhSan(String duongTep) async {
    if (_model != null) return;

    // `initialize` đăng ký engine — gọi một lần trong đời tiến trình.
    if (!_daKhoiTao) {
      await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
      _daKhoiTao = true;
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(duongTep).install();

    // ⚠️ Máy không chạy được hỏng ở ĐÂY, không ở `install()` — P1 đo được:
    // `install()` xong trong 265 ms trên máy ảo x86_64 rồi `getActiveModel`
    // mới ném "require an arm64-v8a Android device (got android_x64)". Gói tự
    // nêu tên ABI, nên không cần tự đọc ABI ở tầng nào cả.
    //
    // GPU trước, CPU sau: P1 đo GPU nhanh gấp rưỡi và tốn 1,73 → 0,96 GB RAM.
    // Gói tự lùi về backend khác khi một backend hỏng, nhưng nêu rõ ý định thì
    // đọc mã ra được vì sao.
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 120}) async {
    final m = _model;
    if (m == null) throw StateError('Mô hình chưa nạp');

    // Mỗi câu một phiên chat mới: khối Nhận xét không có hội thoại, và giữ
    // phiên cũ là để câu trước ảnh hưởng câu sau — thứ làm bộ kiểm số khó lần.
    final chat = await m.createChat(temperature: 0.2);
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final r = await chat.generateChatResponse();
    return (r is TextResponse ? r.token : r.toString()).trim();
  }

  @override
  Future<void> dong() async {
    try {
      await _model?.close();
    } catch (e) {
      debugPrint('[SLM] đóng mô hình hỏng: $e');
    }
    _model = null;
  }
}
```

- [ ] **Step 5: Chạy cả bộ, xác nhận không đỏ chỗ nào**

Run: `flutter test test/features/ai_edge/`
Expected: PASS — trong đó test quét 16 vẫn xanh (chỉ `slm_runtime.dart` import).

- [ ] **Step 6: ⚠️ Thử bản sai có chủ ý — BẮT BUỘC**

Thêm vào cuối `lib/features/ai_edge/domain/goi_so.dart`:

```dart
// BẢN SAI CÓ CHỦ Ý — xoá ngay sau khi kiểm
// ignore: unused_import
```
rồi thêm dòng `import 'package:flutter_gemma/flutter_gemma.dart';` ở đầu tệp ấy.

Run: `flutter test test/features/ai_edge/chi_mot_noi_import_gemma_test.dart`
Expected: **FAIL**, nêu đúng `lib/features/ai_edge/domain/goi_so.dart:<dòng>`.

Gỡ dòng ấy, chạy lại → PASS. Ca này xanh từ đầu nên không có bước này thì không
biết nó canh được gì.

- [ ] **Step 7: `flutter analyze` + commit**

Run: `flutter analyze` — phải ở **26 issue, 0 error**. Gói mới có thể thêm cảnh báo;
nếu lên quá mức nền thì sửa trước khi commit.

```bash
git add src/Client-app/pubspec.yaml src/Client-app/pubspec.lock lib/features/ai_edge/data/slm_runtime.dart
git add -f test/features/ai_edge/chi_mot_noi_import_gemma_test.dart
git commit -m "feat(ai-edge): slm_runtime — tệp duy nhất chạm flutter_gemma, test quét thứ 16"
```

---

### Task 5: `mo_hinh_tai_ve.dart` — trạng thái và tải mô hình

**Files:**
- Create: `lib/features/ai_edge/data/mo_hinh_tai_ve.dart`
- Test: `test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`

**Interfaces:**
- Produces:
  - `enum TrangThaiMoHinh { chuaTai, dangTai, daTai, loi }`
  - `class MoHinhTaiVe` — `Stream<TienDoTai> get tienDo`, `Future<bool> daCo()`,
    `Future<String> duongTep()`, `Future<void> tai()`, `void huy()`,
    `Future<void> xoa()`.
  - `typedef TienDoTai = ({TrangThaiMoHinh trangThai, double phanTram, String? loi})`
  - `const String kUrlMoHinh` và `const int kCoTepByte = 2588147712`.

- [ ] **Step 1: Test đỏ**

```dart
// test/features/ai_edge/data/mo_hinh_tai_ve_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mohinh'));
  tearDown(() => tmp.deleteSync(recursive: true));

  MoHinhTaiVe dung({
    Future<void> Function(String url, File dich, void Function(double))? taiGia,
  }) =>
      MoHinhTaiVe(
        thuMuc: () async => tmp,
        taiTep: taiGia ??
            (url, dich, bao) async {
              bao(0.5);
              dich.writeAsBytesSync(List.filled(1024, 0));
              bao(1.0);
            },
      );

  test('chưa tải thì daCo() false', () async {
    expect(await dung().daCo(), isFalse);
  });

  test('tải xong thì daCo() true và tệp nằm đúng chỗ', () async {
    final m = dung();
    await m.tai();
    expect(await m.daCo(), isTrue);
    expect(File(await m.duongTep()).existsSync(), isTrue);
  });

  test('phát tiến độ từ dangTai tới daTai', () async {
    final m = dung();
    final thu = <TrangThaiMoHinh>[];
    final sub = m.tienDo.listen((t) => thu.add(t.trangThai));
    await m.tai();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(thu.first, TrangThaiMoHinh.dangTai);
    expect(thu.last, TrangThaiMoHinh.daTai);
  });

  test('⚠️ tải hỏng giữa chừng thì XOÁ tệp dở, không để lại bản cụt', () async {
    // Tệp cụt 1,2 GB trông y hệt tệp đủ với `existsSync()`, và lần mở app sau
    // sẽ nạp nó rồi ném "Model may be invalid" — đúng thông báo mà P1 đã mất
    // hàng giờ vì nó (mục 8.2). Xoá ngay lúc hỏng là chỗ rẻ nhất để chặn.
    final m = dung(taiGia: (url, dich, bao) async {
      dich.writeAsBytesSync(List.filled(512, 0));
      throw const SocketException('mất mạng');
    });
    await expectLater(m.tai(), throwsA(isA<Exception>()));
    expect(await m.daCo(), isFalse);
    expect(File(await m.duongTep()).existsSync(), isFalse);
  });

  test('trạng thái sau khi hỏng là loi, kèm câu lỗi', () async {
    final m = dung(taiGia: (url, dich, bao) async {
      throw const SocketException('mất mạng');
    });
    final thu = <TienDoTai>[];
    final sub = m.tienDo.listen(thu.add);
    try {
      await m.tai();
    } catch (_) {}
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(thu.last.trangThai, TrangThaiMoHinh.loi);
    expect(thu.last.loi, isNotNull);
  });

  test('xoa() gỡ tệp và đưa daCo() về false', () async {
    final m = dung();
    await m.tai();
    await m.xoa();
    expect(await m.daCo(), isFalse);
  });

  test('gọi tai() hai lần chồng nhau chỉ chạy MỘT lượt', () async {
    var soLan = 0;
    final m = dung(taiGia: (url, dich, bao) async {
      soLan++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      dich.writeAsBytesSync(List.filled(16, 0));
    });
    await Future.wait([m.tai(), m.tai()]);
    expect(soLan, 1,
        reason: 'Người dùng bấm hai lần, hoặc màn dựng lại giữa chừng — hai '
            'lượt tải 2,41 GB song song vào cùng một tệp là hỏng tệp.');
  });
}
```

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`
Expected: FAIL — không tìm thấy `mo_hinh_tai_ve.dart`

- [ ] **Step 3: Viết mã**

```dart
// lib/features/ai_edge/data/mo_hinh_tai_ve.dart
/// Trạng thái và vòng đời tệp mô hình trên máy (spec mục 4.2).
///
/// Mô hình **không** đóng vào APK: 2,41 GB, và người không dùng AI thì không
/// nên trả dung lượng ấy. Tải chỉ khi người dùng bấm ở màn Cài đặt AI.
///
/// Phép tải tiêm qua [taiTep] để test không chạm mạng — bản thật ở
/// `injection_container.dart` dùng `Dio` đã có sẵn của dự án.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum TrangThaiMoHinh { chuaTai, dangTai, daTai, loi }

typedef TienDoTai = ({
  TrangThaiMoHinh trangThai,
  double phanTram,
  String? loi,
});

/// Gemma 4 E2B, bản `.litertlm` **chuẩn**.
///
/// ⚠️ **Không** đổi sang `gemma-4-E2B-it-gpu.litertlm`: nhẹ hơn 0,6 GB nhưng
/// **không nạp được** trên engine FFI Android dù tệp nguyên vẹn từng byte, và
/// lỗi nó ném (*"Model may be invalid"*) dẫn người đọc đi kiểm tra tải hỏng —
/// P1 mục 8.2 `docs/AI_EDGE_FEATURE.md`.
const String kUrlMoHinh = 'https://huggingface.co/litert-community/'
    'gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

const String kTenTep = 'gemma-4-E2B-it.litertlm';

/// Cỡ tệp thật, đo 2026-09-20. Dùng để hiện dung lượng trước khi tải.
const int kCoTepByte = 2588147712;

class MoHinhTaiVe {
  final Future<Directory> Function() thuMuc;
  final Future<void> Function(
    String url,
    File dich,
    void Function(double phanTram) bao,
  ) taiTep;

  final _phat = StreamController<TienDoTai>.broadcast();
  Future<void>? _dangChay;
  bool _huy = false;

  MoHinhTaiVe({required this.thuMuc, required this.taiTep});

  Stream<TienDoTai> get tienDo => _phat.stream;

  Future<String> duongTep() async => '${(await thuMuc()).path}/$kTenTep';

  Future<bool> daCo() async => File(await duongTep()).existsSync();

  /// Tải mô hình. Gọi lần hai khi lượt đầu chưa xong thì **dùng chung** lượt
  /// đang chạy — hai lượt ghi vào cùng một tệp là hỏng tệp.
  Future<void> tai() {
    return _dangChay ??= _tai().whenComplete(() => _dangChay = null);
  }

  Future<void> _tai() async {
    _huy = false;
    final dich = File(await duongTep());
    _phat.add((trangThai: TrangThaiMoHinh.dangTai, phanTram: 0, loi: null));
    try {
      await taiTep(kUrlMoHinh, dich, (p) {
        if (_huy) return;
        _phat.add(
          (trangThai: TrangThaiMoHinh.dangTai, phanTram: p, loi: null),
        );
      });
      if (_huy) throw const _HuyTai();
      _phat.add((trangThai: TrangThaiMoHinh.daTai, phanTram: 1, loi: null));
    } catch (e) {
      // ⚠️ Xoá tệp dở NGAY. Một tệp cụt trông y hệt tệp đủ với `existsSync()`,
      // và lần mở app sau sẽ nạp nó rồi ném "Model may be invalid".
      if (dich.existsSync()) {
        try {
          dich.deleteSync();
        } catch (_) {}
      }
      _phat.add(
        (trangThai: TrangThaiMoHinh.loi, phanTram: 0, loi: e.toString()),
      );
      debugPrint('[SLM] tải mô hình hỏng: $e');
      rethrow;
    }
  }

  void huy() => _huy = true;

  Future<void> xoa() async {
    final f = File(await duongTep());
    if (f.existsSync()) f.deleteSync();
    _phat.add((trangThai: TrangThaiMoHinh.chuaTai, phanTram: 0, loi: null));
  }

  Future<void> dong() async => _phat.close();
}

class _HuyTai implements Exception {
  const _HuyTai();
  @override
  String toString() => 'Đã huỷ tải';
}
```

- [ ] **Step 4: Chạy, xác nhận xanh**

Run: `flutter test test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`
Expected: PASS (8 ca)

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai_edge/data/mo_hinh_tai_ve.dart
git add -f test/features/ai_edge/data/mo_hinh_tai_ve_test.dart
git commit -m "feat(ai-edge): tải và quản lý vòng đời tệp mô hình trên máy"
```

---

### Task 6: `slm_dien_giai.dart` — bản `BoDienGiai` thứ hai

**Files:**
- Create: `lib/features/ai_edge/data/slm_dien_giai.dart`
- Test: `test/features/ai_edge/data/slm_dien_giai_test.dart`

**Interfaces:**
- Consumes: `SlmRuntime` (Task 4), `SlmCache` (Task 3), `promptCauTheoMan` (Task 1),
  `kiemSo` (P2), `MoHinhTaiVe` (Task 5).
- Produces: `class SlmDienGiai implements BoDienGiai`, hàm dựng
  `SlmDienGiai({required SlmRuntime runtime, required SlmCache cache, required MoHinhTaiVe moHinh})`.

- [ ] **Step 1: Test đỏ**

```dart
// test/features/ai_edge/data/slm_dien_giai_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/slm_dien_giai.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/data/slm_cache.dart';
import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';

class _RuntimeGia implements SlmRuntime {
  final String Function(String prompt) traLoi;
  int soLanSinh = 0;
  int soLanNap = 0;
  bool napHong;
  bool _san = false;

  _RuntimeGia(this.traLoi, {this.napHong = false});

  @override
  bool get dangSan => _san;
  @override
  Future<void> moHinhSan(String duongTep) async {
    soLanNap++;
    if (napHong) throw Exception('không nạp được');
    _san = true;
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 120}) async {
    soLanSinh++;
    return traLoi(prompt);
  }

  @override
  Future<void> dong() async => _san = false;
}

class _Goi implements GoiSo {
  @override
  final String man = 'ngan_sach';
  @override
  final List<SoLieu> soLieu = [soTien('Đã chi', 45000), soPhanTram('Tỉ lệ', 90)];

  /// Mức của hệ luật — `kiemGiong` đối chiếu câu với nó, nên ca "sai giọng"
  /// phải đặt được. Mặc định `binhThuong` để mọi ca cũ dựng không đổi.
  final MucNhanXet muc;
  _Goi([this.muc = MucNhanXet.binhThuong]);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() => NhanXet(
        cau: 'Câu mẫu 45.000 đ.',
        theSoLieu: soLieu,
        muc: muc,
      );
  @override
  String get dauVan => 'van-co-dinh';
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('sdg'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<SlmDienGiai> dung(_RuntimeGia rt, {bool coTep = true}) async {
    if (coTep) File('${tmp.path}/$kTenTep').writeAsBytesSync([1, 2, 3]);
    final cache = SlmCache(thuMuc: () async => tmp);
    await cache.nap();
    return SlmDienGiai(
      runtime: rt,
      cache: cache,
      moHinh: MoHinhTaiVe(
        thuMuc: () async => tmp,
        taiTep: (u, d, b) async {},
      ),
    );
  }

  test('câu hợp lệ đi qua, gắn cờ tuMoHinh', () async {
    final rt = _RuntimeGia((_) => 'Đã chi 45.000 đ, tức 90,0%.');
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Đã chi 45.000 đ, tức 90,0%.');
    expect(nx.tuMoHinh, isTrue);
    expect(nx.theSoLieu, hasLength(2),
        reason: 'Thẻ số liệu luôn là của GÓI, không phải thứ mô hình trả về.');
  });

  test('⚠️ câu BỊA SỐ thì rơi về mẫu câu, không hiện ra', () async {
    final rt = _RuntimeGia((_) => 'Đã chi 99.999 đ, tức 12,3%.');
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
    expect(nx.tuMoHinh, isFalse,
        reason: 'Không gắn nhãn AI cho câu mẫu — nhãn ấy là lời hứa rằng câu '
            'do mô hình viết.');
  });

  test('⚠️ câu ĐỦ SỐ nhưng SAI GIỌNG thì rơi về mẫu câu', () async {
    // Gói ở mức cảnh báo; runtime giả trả một câu trấn an mang đúng mọi số —
    // `kiemSo` cho qua, `kiemGiong` phải chặn.
    final rt = _RuntimeGia((_) => 'Bạn đang kiểm soát tốt: đã dùng 90,0%.');
    final nx = await (await dung(rt)).dienGiai(_Goi(MucNhanXet.canhBao));
    expect(nx.tuMoHinh, isFalse, reason: 'sai giọng phải rơi về mẫu, không hiện');
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
  });

  test('nạp hỏng (máy x86_64, RAM thấp) thì rơi về mẫu câu, KHÔNG ném',
      () async {
    final rt = _RuntimeGia((_) => 'không tới đây', napHong: true);
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
    expect(nx.tuMoHinh, isFalse);
  });

  test('chưa tải mô hình thì rơi về mẫu câu và KHÔNG thử nạp', () async {
    final rt = _RuntimeGia((_) => 'không tới đây');
    final nx = await (await dung(rt, coTep: false)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
    expect(rt.soLanNap, 0,
        reason: 'Nạp lười: người chưa tải mô hình không phải trả RAM nào.');
  });

  test('⚠️ gói số KHÔNG ĐỔI thì không gọi mô hình lần hai', () async {
    // Stream của mọi màn phát lại sau MỖI chu kỳ đồng bộ. Không cache thì mỗi
    // lượt phát là 2,3 giây chạy mô hình cho một gói y hệt — và câu nhấp nháy.
    final rt = _RuntimeGia((_) => 'Đã chi 45.000 đ, tức 90,0%.');
    final bo = await dung(rt);
    await bo.dienGiai(_Goi());
    await bo.dienGiai(_Goi());
    await bo.dienGiai(_Goi());
    expect(rt.soLanSinh, 1);
  });

  test('nạp mô hình đúng MỘT lần dù diễn giải nhiều gói', () async {
    final rt = _RuntimeGia((_) => 'Đã chi 45.000 đ, tức 90,0%.');
    final bo = await dung(rt);
    await bo.dienGiai(_Goi());
    await bo.dienGiai(_Goi());
    expect(rt.soLanNap, 1);
  });

  test('gói thiếu dữ liệu thì dùng mẫu câu, không gọi mô hình', () async {
    final rt = _RuntimeGia((_) => 'không tới đây');
    final bo = await dung(rt);
    await bo.dienGiai(_GoiThieu());
    expect(rt.soLanSinh, 0,
        reason: 'Nhánh thiếu dữ liệu là một câu THẬT đã chốt ở P2 — để mô hình '
            'diễn giải một gói rỗng là mời nó bịa.');
  });

  test('mô hình ném giữa chừng thì rơi về mẫu câu', () async {
    final rt = _RuntimeGia((_) => throw Exception('hết bộ nhớ'));
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
  });
}

class _GoiThieu implements GoiSo {
  @override
  final String man = 'ngan_sach';
  @override
  final List<SoLieu> soLieu = const [];
  @override
  bool get thieuDuLieu => true;
  @override
  NhanXet mauCau() => const NhanXet(
      cau: 'Chưa đủ dữ liệu.', theSoLieu: [], muc: MucNhanXet.thieuDuLieu);
  @override
  String get dauVan => 'van-thieu';
}
```

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_edge/data/slm_dien_giai_test.dart`
Expected: FAIL — không tìm thấy `slm_dien_giai.dart`

- [ ] **Step 3: Viết mã**

```dart
// lib/features/ai_edge/data/slm_dien_giai.dart
/// Bản `BoDienGiai` thứ hai — câu do mô hình trên máy viết.
///
/// Khe cắm đã có từ P2: `KhoiNhanXet` đọc `sl<BoDienGiai>()`, không đăng ký thì
/// dùng `const MauCau()`. Nên P3 **không sửa màn nào** để bật mô hình.
///
/// ## Năm nhánh rơi về mẫu câu, tất cả đều IM LẶNG
///
/// Gói thiếu dữ liệu · chưa tải mô hình · nạp hỏng (x86_64, RAM thấp) · mô hình
/// ném giữa chừng · câu không qua bộ kiểm số. Không toast, không dialog: người
/// dùng vẫn nhận được một câu đúng, chỉ là không "mượt" bằng (H3 của đặc tả).
library;

import 'package:flutter/foundation.dart';

import '../domain/bo_dien_giai.dart';
import '../domain/goi_so.dart';
import '../domain/kiem_giong.dart';
import '../domain/kiem_so.dart';
import '../domain/nhan_xet.dart';
import '../domain/slm_prompt.dart';
import 'mo_hinh_tai_ve.dart';
import 'slm_cache.dart';
import 'slm_runtime.dart';

class SlmDienGiai implements BoDienGiai {
  final SlmRuntime runtime;
  final SlmCache cache;
  final MoHinhTaiVe moHinh;

  /// Nạp hỏng một lần thì thôi thử lại trong phiên này — mỗi lần thử là một
  /// lượt `install()` vài trăm ms cho một kết quả đã biết.
  bool _napHongRoi = false;

  SlmDienGiai({
    required this.runtime,
    required this.cache,
    required this.moHinh,
  });

  @override
  Future<NhanXet> dienGiai(GoiSo goi) async {
    if (goi.thieuDuLieu) return goi.mauCau();

    final sanCo = cache.doc(goi.dauVan);
    if (sanCo != null) return _tuCau(sanCo, goi);

    final cau = await _sinh(goi);
    if (cau == null) return goi.mauCau();

    await cache.ghi(goi.dauVan, cau);
    return _tuCau(cau, goi);
  }

  /// `null` = mọi nhánh hỏng; người gọi rơi về mẫu câu.
  Future<String?> _sinh(GoiSo goi) async {
    if (_napHongRoi) return null;
    try {
      if (!runtime.dangSan) {
        // Nạp LƯỜI: chỉ hỏi tệp khi thật sự cần. Người chưa tải mô hình không
        // phải trả RAM nào, và `daCo()` là một phép `existsSync` rẻ.
        if (!await moHinh.daCo()) return null;
        await runtime.moHinhSan(await moHinh.duongTep());
      }
      final cau = await runtime.sinh(promptCauTheoMan(goi), tranToken: 120);
      if (!kiemSo(cau, goi)) {
        debugPrint('[SLM] câu không qua bộ kiểm số, rơi về mẫu: $cau');
        return null;
      }
      if (!kiemGiong(cau, goi.mauCau().muc)) {
        debugPrint('[SLM] câu sai giọng so với mức của hệ luật, rơi về mẫu: $cau');
        return null;
      }
      return cau;
    } catch (e) {
      debugPrint('[SLM] sinh câu hỏng, rơi về mẫu: $e');
      _napHongRoi = !runtime.dangSan;
      return null;
    }
  }

  NhanXet _tuCau(String cau, GoiSo goi) => NhanXet(
        cau: cau,
        // Thẻ số liệu luôn của GÓI, không bao giờ của mô hình — điều kiện 12.
        theSoLieu: goi.mauCau().theSoLieu,
        muc: goi.mauCau().muc,
        tuMoHinh: true,
      );
}
```

- [ ] **Step 4: Chạy, xác nhận xanh**

Run: `flutter test test/features/ai_edge/data/slm_dien_giai_test.dart`
Expected: PASS (8 ca)

- [ ] **Step 5: ⚠️ Thử bản sai có chủ ý**

Đổi `if (!kiemSo(cau, goi))` thành `if (false)`.
Run lại: ca *"câu BỊA SỐ thì rơi về mẫu câu"* phải **đỏ**. Khôi phục.

- [ ] **Step 6: Commit**

```bash
git add lib/features/ai_edge/data/slm_dien_giai.dart
git add -f test/features/ai_edge/data/slm_dien_giai_test.dart
git commit -m "feat(ai-edge): SlmDienGiai — câu từ mô hình, năm nhánh rơi về mẫu câu"
```

---

### Task 7: Màn Cài đặt AI + nối DI

**Files:**
- Create: `lib/features/ai_edge/presentation/pages/cai_dat_ai_page.dart`
- Modify: `lib/core/di/injection_container.dart` — đăng ký `SlmRuntime`, `SlmCache`,
  `MoHinhTaiVe`, và `BoDienGiai` khi công tắc bật
- Modify: `lib/core/router/app_router.dart` — route `/ai-settings`
- Modify: `lib/features/home/presentation/widgets/drawer_trang_chu.dart` — **KHÔNG**
  thêm mục drawer (vào từ màn Trợ lý AI), chỉ đọc để xác nhận
- Test: `test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`

**Interfaces:**
- Consumes: `MoHinhTaiVe` (Task 5).
- Produces: route `/ai-settings`; khoá `ai_tren_may_bat`. ⚠️ **Đã thi công 2026-09-22 và
  dòng này sai ở một chữ**: khoá nằm trong `flutter_secure_storage` (`data/cong_tac_ai.dart`),
  **không** phải `SharedPreferences` — gói ấy không có trong dự án. Xem mục *"Ba chỗ kế hoạch
  này lệch mã thật"* ở cuối tệp.

- [ ] **Step 1: Test đỏ**

```dart
// test/features/ai_edge/presentation/cai_dat_ai_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/presentation/pages/cai_dat_ai_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  // ⚠️ Theme thật, không `MaterialApp` trần: theme của app ép mọi
  // `ElevatedButton` rộng vô hạn, và nút trần trong `Row` làm trắng cả trang
  // mà không một dòng log nào (bẫy 4.11 `ANALYTICS_FEATURE.md`).
  Widget boc(Widget w) => MaterialApp(theme: AppTheme.lightTheme, home: w);

  testWidgets('chưa tải: hiện dung lượng và nút Tải, KHÔNG có nút Xoá',
      (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: false)));
    expect(find.textContaining('2,41 GB'), findsWidgets);
    expect(find.text('Tải mô hình'), findsOneWidget);
    expect(find.text('Xoá mô hình'), findsNothing);
  });

  testWidgets('đã tải: hiện nút Xoá, KHÔNG còn nút Tải', (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: true)));
    expect(find.text('Xoá mô hình'), findsOneWidget);
    expect(find.text('Tải mô hình'), findsNothing);
  });

  testWidgets('⚠️ luôn nói rõ số liệu KHÔNG rời khỏi máy', (t) async {
    // Đây là lời hứa trung tâm của cả mảng (F1 đặc tả gốc, Nghị định 13). Người
    // dùng sắp tải 2,41 GB về máy mình — họ cần biết đổi lại được gì.
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: false)));
    expect(find.textContaining('không'), findsWidgets);
    expect(find.textContaining('rời khỏi'), findsOneWidget);
  });

  testWidgets('411dp: không tràn bố cục ở cả hai trạng thái', (t) async {
    t.view.physicalSize = const Size(411 * 3, 914 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    for (final co in [false, true]) {
      await t.pumpWidget(boc(CaiDatAiPage(daCoMoHinh: co)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'daCoMoHinh=$co');
    }
  });
}
```

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`
Expected: FAIL — không tìm thấy `cai_dat_ai_page.dart`

- [ ] **Step 3: Dựng màn theo Stitch (id từ Task 0)**

Dựng `CaiDatAiPage` với tham số `daCoMoHinh` để test dựng được cả hai trạng thái mà
không cần DI. Bốn khối theo màn Stitch: trạng thái mô hình · nút tải (kèm
`CurrencyFormatter`-style dung lượng "2,41 GB" và dòng *"Cần Wi-Fi"*) · thanh tiến độ
có nút Huỷ · khối giải thích quyền riêng tư + nút Xoá.

⚠️ Dùng `AppColors.error` cho nút Xoá và bọc `Material(type: MaterialType.transparency)`
quanh cột chứa `ListTile` nếu có — Flutter 3.47 ném assertion *"ink splashes may be
invisible"* khi `ListTile` nằm trong `Container` có màu (khối ⬆️ mục 14
`PROJECT_CONTEXT.md`).

- [ ] **Step 4: Nối DI**

Trong `injection_container.dart`, sau khối `NotificationScanner`:

```dart
  // ── AI trên máy (P3) ──────────────────────────────────────────────────
  sl.registerLazySingleton<SlmRuntime>(SlmRuntimeThat.new);
  sl.registerLazySingleton<MoHinhTaiVe>(() => MoHinhTaiVe(
        thuMuc: getApplicationSupportDirectory,
        taiTep: (url, dich, bao) async {
          await sl<Dio>().download(
            url,
            dich.path,
            onReceiveProgress: (n, t) => bao(t > 0 ? n / t : 0),
          );
        },
      ));
  sl.registerLazySingleton<SlmCache>(
      () => SlmCache(thuMuc: getApplicationSupportDirectory));

  // 🛑 CỐ Ý KHÔNG đăng ký `BoDienGiai` — người dùng chốt LỐI B ngày 2026-09-21.
  //
  // Không đăng ký thì `KhoiNhanXet` tự dùng `const MauCau()`, nên bốn khối Nhận
  // xét (Ngân sách · Phân tích · Mục tiêu · Trang chủ) **giữ mẫu câu**: hiện
  // tức thì, không chờ 2,3 giây, không "nhảy" từ mẫu sang câu mô hình.
  //
  // Vì sao: P1 đo được câu mô hình ở khối Nhận xét **gần bằng mẫu câu** — khác
  // nhau ở giọng văn, không ở thông tin, và mẫu câu còn gọn hơn. Cái giá là
  // 2,3 s mỗi khối cộng 2,41 GB tải. Mô hình chỉ hơn hẳn ở **hỏi đáp tự do**,
  // nên nó phục vụ **một chỗ duy nhất**: màn Trợ lý AI (Task 8), nơi tự dựng
  // `SlmDienGiai` lấy từ `sl<SlmRuntime>()` / `sl<SlmCache>()` / `sl<MoHinhTaiVe>()`.
  //
  // ⚠️ Đổi sang LỐI A (mô hình viết câu ở cả bốn khối) chỉ là bỏ dấu chú thích
  // của khối dưới — một commit, không sửa màn nào. Đừng làm nếu người dùng chưa
  // đổi ý.
  //
  // if ((await SharedPreferences.getInstance()).getBool('ai_tren_may_bat') ??
  //     true) {
  //   sl.registerLazySingleton<BoDienGiai>(() => SlmDienGiai(
  //         runtime: sl<SlmRuntime>(),
  //         cache: sl<SlmCache>(),
  //         moHinh: sl<MoHinhTaiVe>(),
  //       ));
  // }
```

⚠️ **Công tắc "Dùng AI trên máy" ở màn Cài đặt AI vẫn còn nguyên ý nghĩa** — nó gác
việc màn Trợ lý AI có gọi mô hình hay không. Ở lối B, màn ấy đọc khoá
`ai_tren_may_bat` trực tiếp (Task 8) thay vì để DI gác hộ.

- [ ] **Step 5: Thêm route**

Trong `app_router.dart`, thêm `/ai-settings` **ngoài** `StatefulShellRoute` (cùng
nhóm với `/bills`, `/wallets`). ⚠️ Không thêm vào `nhanhThanhTab` của
`notification_deeplink.dart` — route ngoài shell thì `push` chạy tốt, kéo nó vào một
nhánh tab là làm mọi deeplink tới nó chết màn đỏ (bẫy 7.8).

- [ ] **Step 5b: ⚠️ Dọn cache khi đổi tài khoản**

Tìm chỗ gọi `purgeDataForOtherAccounts` (đường đăng nhập, `auth_bloc.dart`) và gọi
`sl<SlmCache>().xoaHet()` cùng chỗ. Thêm ca test:

```dart
test('đổi tài khoản thì cache câu bị dọn', () async {
  // Câu trong cache nói về số liệu tài chính của MỘT tài khoản. Trên máy dùng
  // chung, người sau không được thấy câu của người trước. Dấu vân gần như chắc
  // chắn khác nhau — nhưng "gần như" không phải cơ chế cô lập, và đó đúng là
  // lý do `purgeDataForOtherAccounts` tồn tại dù SQLite đã lọc theo idaccount.
  // Ca này đi cùng ca ấy, ở cùng tệp test.
});
```

⚠️ **Đừng** dọn cache khi chỉ *đăng xuất rồi đăng nhập lại cùng tài khoản* — đó là
vứt đi 200 câu đã trả 2,3 giây mỗi câu để có. Bám đúng điều kiện mà
`purgeDataForOtherAccounts` đang dùng, không viết điều kiện thứ hai.

- [ ] **Step 6: Chạy test + analyze**

Run: `flutter test test/features/ai_edge/` rồi `flutter analyze`
Expected: PASS; analyze ở mức nền.

- [ ] **Step 7: Commit**

```bash
git add lib/features/ai_edge/presentation/pages/cai_dat_ai_page.dart lib/core/di/injection_container.dart lib/core/router/app_router.dart
git add -f test/features/ai_edge/presentation/cai_dat_ai_page_test.dart
git commit -m "feat(ai-edge): màn Cài đặt AI — tải, xoá, công tắc dùng AI trên máy"
```

---

### Task 8: Màn Trợ lý AI — nối 5 handler rỗng (đóng A11)

**Files:**
- Modify: `lib/features/ai_chat/presentation/pages/ai_chat_page.dart`
- Modify: `test/core/ui/khong_co_nut_chet_test.dart` — gỡ mục `ai_chat_page.dart`
  khỏi `conChoChot`
- Test: `test/features/ai_chat/ai_chat_page_test.dart`

**Interfaces:**
- Consumes: `promptHoiDap`, `chuDeBiChan`, `kCauTuChoi`, bốn `GoiSo` của P2.
- ⚠️ **Lối B**: màn này **tự dựng** `SlmDienGiai` từ `sl<SlmRuntime>()`,
  `sl<SlmCache>()`, `sl<MoHinhTaiVe>()` — **không** đọc `sl<BoDienGiai>()`, vì Task 7 cố
  ý không đăng ký nó. Và màn tự đọc khoá `ai_tren_may_bat`: tắt công tắc thì ô nhập khoá
  y như khi chưa tải mô hình.
- ⚠️ **Đọc khoá ấy qua `sl<CongTacAi>().doc()`, KHÔNG qua `SharedPreferences`** — dự án
  không có gói đó; xem mục *"Ba chỗ kế hoạch này lệch mã thật"* ở cuối tệp. Và nút bánh
  răng của màn này (`ai_chat_page.dart:97`) là **lối vào duy nhất** của `/ai-settings`,
  nên nó phải `context.push('/ai-settings')` — route nằm ngoài shell.

- [ ] **Step 1: Test đỏ**

```dart
// test/features/ai_chat/ai_chat_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  Widget boc(Widget w) => MaterialApp(theme: AppTheme.lightTheme, home: w);

  testWidgets('⚠️ KHÔNG còn số liệu bịa của bản mockup', (t) async {
    // Bản cũ in "35% so với tuần trước (chủ yếu là Cafe & ShopeeFood)" — chữ
    // tĩnh, không đến từ dữ liệu nào. Đó là hứa một tính năng không tồn tại,
    // đúng loại lỗi mà A6 (thẻ "Insight AI") đã phải gỡ.
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: false)));
    expect(find.textContaining('ShopeeFood'), findsNothing);
    expect(find.textContaining('35%'), findsNothing);
  });

  testWidgets('chưa có mô hình: ô nhập BỊ KHOÁ và có lối tới Cài đặt AI',
      (t) async {
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: false)));
    final o = t.widget<TextField>(find.byType(TextField));
    expect(o.enabled, isFalse);
    expect(find.textContaining('Cài đặt AI'), findsWidgets);
  });

  testWidgets('có mô hình: ô nhập mở', (t) async {
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('bốn chip gợi ý đúng tên spec', (t) async {
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    for (final s in const [
      'Tình hình ngân sách',
      'Phân tích chi tiêu tháng này',
      'Dự báo tiết kiệm',
      'Gợi ý cắt giảm chi phí',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });

  testWidgets('KHÔNG còn nút ảnh và nút ghi âm', (t) async {
    // Spec mục 4.6: bỏ nút ảnh/mic. Mô hình đa phương thức thật, nhưng app
    // không có việc gì cho ảnh — một nút mở thư viện rồi không làm gì là nút
    // chết có thêm bước.
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNothing);
  });

  testWidgets('⚠️ câu trả lời hiện KÈM thẻ số liệu', (t) async {
    // Điều kiện 12 và guardrail cuối của đặc tả gốc (mục 3.3): "luôn hiển thị
    // kèm số liệu thô bên cạnh câu văn AI sinh ra — không để người dùng chỉ
    // thấy văn bản mà không thấy nguồn số". Một câu trôi chảy không có thẻ bên
    // cạnh là thứ người ta tin mà không kiểm được.
    await t.pumpWidget(boc(const AiChatPage(
      coMoHinh: true,
      traLoiMau: ['Ngân sách Giáo dục đã dùng 90,0%.'],
      theSoLieuMau: ['Tỉ lệ 90,0%', 'Còn 11 ngày'],
    )));
    await t.pumpAndSettle();
    expect(find.textContaining('90,0%'), findsWidgets);
    expect(find.textContaining('Còn 11 ngày'), findsOneWidget);
  });

  testWidgets('chủ đề bị chặn: trả câu cố định, KHÔNG gọi mô hình', (t) async {
    var soLanGoi = 0;
    await t.pumpWidget(boc(AiChatPage(
      coMoHinh: true,
      onHoi: (_) async {
        soLanGoi++;
        return 'không tới đây';
      },
    )));
    await t.enterText(find.byType(TextField), 'Tôi nên đầu tư vào đâu?');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(find.textContaining('chỉ nhận xét được trên số liệu'), findsOneWidget);
    expect(soLanGoi, 0,
        reason: 'Chặn TRƯỚC khi gọi mô hình: 2,3 giây cho một câu chắc chắn '
            'bị vứt đi là lãng phí, và mô hình không nên thấy câu hỏi ấy.');
  });

  testWidgets('411dp không tràn', (t) async {
    t.view.physicalSize = const Size(411 * 3, 914 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(boc(const AiChatPage(coMoHinh: true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
```

⚠️ Ba tham số `traLoiMau` / `theSoLieuMau` / `onHoi` là **khe tiêm cho test**, mặc
định `null` — màn thật đọc từ DI. Không có chúng thì mọi ca trên phải dựng cả chuỗi
`SlmDienGiai` + runtime + bốn gói số, tức test giao diện hoá ra đi kiểm tầng dữ liệu.

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_chat/ai_chat_page_test.dart`
Expected: FAIL — `AiChatPage` chưa có tham số `coMoHinh`, và chữ tĩnh vẫn còn.

- [ ] **Step 3: Sửa màn**

Năm handler rỗng xử lý như sau:

| Dòng cũ | Nút | Làm gì |
|---|---|---|
| ~100 | ⚙️ Cài đặt | `context.push('/ai-settings')` |
| ~314 | "Thiết lập hạn mức ngay" | **gỡ** cùng cả khối chữ tĩnh bịa số |
| ~389 | ➕ thêm | **gỡ** |
| ~396 | 🖼 Chọn ảnh | **gỡ** (spec 4.6) |
| ~417 | 🎤 Ghi âm | **gỡ** (spec 4.6) |

Thay khối chữ tĩnh bằng danh sách hội thoại thật: chạm một chip → dựng gói số tương
ứng → `promptHoiDap` → `runtime.sinh(tranToken: 300)` → `kiemSo` → hiện câu kèm thẻ số
liệu. Câu hỏi tự do đi qua `chuDeBiChan` **trước**; bị chặn thì trả `kCauTuChoi` ngay,
không gọi mô hình.

Không lưu lịch sử qua phiên (spec 4.6).

- [ ] **Step 4: Gỡ khỏi danh sách nút chết**

Xoá mục `'features/ai_chat/presentation/pages/ai_chat_page.dart'` khỏi `conChoChot`
trong `test/core/ui/khong_co_nut_chet_test.dart`.

- [ ] **Step 5: Chạy cả hai bộ**

Run: `flutter test test/features/ai_chat/ test/core/ui/`
Expected: PASS — test quét nút chết phải xanh **sau khi** gỡ mục, tức không còn
handler rỗng nào trong tệp ấy.

- [ ] **Step 6: Commit**

```bash
git add lib/features/ai_chat/presentation/pages/ai_chat_page.dart
git add -f test/features/ai_chat/ai_chat_page_test.dart test/core/ui/khong_co_nut_chet_test.dart
git commit -m "feat(ai-chat): màn Trợ lý AI chạy thật — bốn chip, hỏi đáp có chắn, đóng A11"
```

---

### Task 9: Nghiệm thu máy thật + bảng đo P3 + tài liệu

**Files:**
- Modify: `docs/AI_EDGE_FEATURE.md` — mục 9 (bảng đo P3), mục 2, mục 4, mục 7
- Modify: `docs/PROJECT_CONTEXT.md` mục 14 · `CLAUDE.md` · `docs/CLIENT_APP_KNOWN_GAPS.md` (A11)

- [ ] **Step 1: `flutter analyze` + trọn bộ test**

Run: `flutter analyze` (mức nền 26/0) rồi `flutter test --timeout 60s` (nền, ghi log).
Đếm số ca mới bằng máy: `grep -c "test(" test/features/ai_edge -r`.

- [ ] **Step 2: Máy ảo x86_64 — nhánh mẫu câu**

Cài APK lên `emulator-5554`, bật công tắc AI, mở bốn màn có khối Nhận xét.
Expected: câu **mẫu**, **không** nhãn "AI", **không** toast lỗi nào; logcat có đúng một
dòng `[SLM] sinh câu hỏng` mỗi màn. Đếm pixel vàng **thuần `#FFFF00`** = 0 (bẫy 4.10 —
dải vàng rộng cho dương tính giả với emoji và ô chọn màu).

- [ ] **Step 3: Máy thật — bảng đo P3**

Trên OnePlus 13R: tải mô hình qua màn Cài đặt AI (đo thời gian tải thật), rồi đo:

| Đo | Cách |
|---|---|
| Câu đầu mỗi màn | đồng hồ trong app, ghi logcat |
| Câu thứ hai cùng gói | phải **0 ms** — cache trả về |
| **Khung hình khi sinh câu** | `adb shell dumpsys gfxinfo com.flowmoney.flowmoney framestats` — điều kiện 7, và là lý do spec cấm `Isolate.run` |
| RAM đỉnh | `dumpsys meminfo`, lấy mẫu 3 s/lần |
| Tắt mạng vẫn trả lời | `svc data disable` **và** `svc wifi disable` — ⚠️ máy có dữ liệu di động, tắt mỗi Wi-Fi **không** cắt mạng |
| Không request nào đi ra | `adb logcat` lọc `Dio`/`http` trong lúc sinh câu |

- [ ] **Step 4: Điền mục 9 và cập nhật tài liệu**

`docs/AI_EDGE_FEATURE.md`: mục 9 bảng đo P3; mục 2 các quyết định mới; mục 4 bẫy mới.
`docs/PROJECT_CONTEXT.md` mục 14: khối `### 🤖 AI Edge-SLM — P3`.
`CLAUDE.md`: mốc test mới, hàng "Đụng vào AI Edge-SLM".
`docs/CLIENT_APP_KNOWN_GAPS.md`: **A11 đóng**.

⚠️ Sửa tài liệu bằng **Edit**, không bằng script Python ghi đè cả tệp — `io.open(p,'w')`
cắt tệp về rỗng ngay khi mở rồi mới ném lỗi (ghi chú vận hành `CLAUDE.md`).

- [ ] **Step 5: Lượt soát tài liệu rộng**

```bash
grep -rn "P3 chưa bắt đầu\|mẫu câu\|A11\|BoDienGiai" docs/ CLAUDE.md
```
Mở **từng** tệp có kết quả, sửa mọi chỗ còn tả trạng thái cũ.

- [ ] **Step 6: Commit**

```bash
git commit -m "docs(ai-edge): P3 xong — bảng đo máy thật, A11 đóng"
```

---

## Nhật ký thi công (điền khi làm)

| Task | Commit | Ghi chú |
|---|---|---|
| 0 | `4827124` → `91f0d8e` | id Stitch: `1da347e753964e15a91b10c473975923`. Người dùng xem và xác nhận 2026-09-22 |
| 1 | `a00671b` | `slm_prompt.dart` |
| 2 | `0166ea7` | `chu_de_chan.dart` |
| 3 | `a701f28` | `slm_cache.dart` |
| 4 | `1ab4cf9` | `slm_runtime.dart` + test quét thứ **16** |
| 5 | `cfe2c95` | `mo_hinh_tai_ve.dart` |
| 6 | `075ef8d` | `slm_dien_giai.dart`, sáu nhánh lùi |
| 7 | `4f80f02` | Màn Cài đặt AI + DI + route. **Ba chỗ kế hoạch lệch mã thật** — xem ngay dưới |
| 8 | | |
| 9 | | |

### ⚠️ Ba chỗ kế hoạch này LỆCH MÃ THẬT (đo khi thi công Task 7, 2026-09-22)

Hai chỗ đầu **sẽ tái phát ở Task 8** — đọc trước khi làm tiếp.

1. **`SharedPreferences` không tồn tại trong dự án.** Step 4 và dòng *Produces* của Task 7 đều
   giả định nó có; `pubspec.yaml` không có gói ấy, và dự án **cố ý** không thêm — nơi lưu tuỳ
   chọn là `flutter_secure_storage`, đúng lý lẽ đã ghi ở `SecureStorageNotificationPrefsStore`.
   Bản thi công: `data/cong_tac_ai.dart`, **giữ nguyên tên khoá `ai_tren_may_bat`**, một khoá cho
   cả máy (thứ công tắc gác là *tệp mô hình*, tài sản của máy chứ không của tài khoản). Task 8
   đọc công tắc **qua `CongTacAi`**, không qua `SharedPreferences`.
2. **`sl<Dio>()` là lựa chọn SAI, không chỉ là tên sai.** Dự án không đăng ký `Dio` trần; cái có
   là `sl<DioClient>().dio`, và `AuthInterceptor.onRequest` gắn `Authorization: Bearer <token>`
   vào **mọi** request **không lọc host**. Đích tải là `huggingface.co` — dùng Dio của dự án là
   gửi access token của người dùng cho một bên thứ ba, **im lặng**. Bản thi công dùng `Dio()`
   trần trong closure `taiTep`.
3. **Ca test thứ ba của Step 1 đỏ trên cả bản đúng.** `find.textContaining('không')` phân biệt
   hoa thường, còn câu hứa bắt đầu bằng *"Không có số liệu nào rời khỏi thiết bị."* Ca nay đòi
   thẳng câu hứa (`'rời khỏi thiết bị'`) và đòi ở **cả hai** trạng thái.

**Đã kiểm bằng bản sai có chủ ý** (bẫy *"ca test xanh mà không canh gì"*): bỏ `Expanded` ở khối
riêng tư → ca 411dp đỏ; bỏ phép dọn cache → ca *"đổi tài khoản"* đỏ; dọn vô điều kiện → ca *"cùng
tài khoản"* đỏ.

**Nghiệm thu máy ảo 411dp** (`emulator-5554`, `-gpu swangle`): màn đúng Stitch, **0 sọc tràn**;
công tắc tắt → thoát → vào lại **vẫn tắt**. ⚠️ Lối vào lúc nghiệm thu là **nối tạm** nút bánh răng
của màn Trợ lý AI rồi **gỡ ra, không commit** — nút ấy là việc của Task 8.

### ✅ Một việc Task 7 tìm ra mà kế hoạch không có chỗ nào ghi — ĐÃ SỬA (`f51e2d6`)

**Nút "Huỷ" không dừng được lượt tải.** `MoHinhTaiVe.huy()` chỉ đặt cờ `_huy`; `taiTep` vẫn được
`await` tới khi **xong toàn bộ 2,41 GB**, rồi mới ném `_HuyTai` và xoá tệp. Tức người dùng bấm
Huỷ thì giao diện quay về *"Chưa tải"* trong khi máy **vẫn tải hết** nền — trên dữ liệu di động
thì đó là 2,41 GB họ tưởng đã chặn.

**Đã sửa 2026-09-22** theo yêu cầu của người dùng, và nó **đổi API của Task 5**:

- `DauHuy` — tín hiệu huỷ của **từng lượt** tải (một `Completer`, không phải cờ). Cờ chỉ trả lời
  được khi *có ai hỏi*; `Dio.download` không hỏi, nó cần được **báo**.
- `taiTep` nhận thêm tham số thứ tư `DauHuy`. Mọi chỗ dựng `MoHinhTaiVe` phải sửa theo — gồm cả
  `slm_dien_giai_test.dart`.
- Huỷ nay phát `chuaTai` chứ không `loi`, và **không ném ra ngoài**.
- Phép tải thật tách sang `data/tai_tep_dio.dart` (dùng `CancelToken`) — **để đo được**: bản đầu
  là một closure trong `injection_container.dart`, và đó đúng là lý do không ca test nào với tới
  nó suốt hai task.

⚠️ **Bài học của lượt đo, dùng được cho mọi phép đo mạng:** `HttpResponse.flush()` của `dart:io`
**về trơn tru trên cả kết nối đã chết**, nên một server dựng bằng `HttpServer` để đếm *"còn gửi
thêm bao nhiêu"* báo **vẫn đang chảy** (194 gói ≈ 13 MB trong 2,4 giây) và suýt cho kết luận
ngược hẳn. Phải dùng **`ServerSocket` thô**, nơi `onDone` báo đúng lúc đầu kia gửi FIN — con số
thật là **thêm 0 gói**. Cũng nhờ đó mà `dio.close(force: true)` bị loại: nó chỉ bớt một gói đang
bay (64 KB trên 2,41 GB).
