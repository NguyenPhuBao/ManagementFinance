# Kiến trúc AI của FlowMoney

> **Tài liệu này là gì.** Bản mô tả kiến trúc của mảng AI — cái đang chạy, cái đã
> lên kế hoạch, và cái mới ở mức đề xuất. Viết ngày **2026-09-21** để trả lời câu
> hỏi *"hệ thống mình làm theo kiến trúc nào"* và để mang vào buổi meeting.
>
> **Tài liệu này KHÔNG phải** đặc tả tính năng (đó là `AI_EDGE_FEATURE.md`), không
> phải kế hoạch thi công (đó là `docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md`),
> và không phải nguồn sự thật — **mọi con số dưới đây phải đối chiếu lại với mã**.
> Mỗi con số đều ghi cách đếm để người sau đếm lại được.
>
> **Mọi số liệu trong tài liệu này đếm bằng máy ngày 2026-09-21.**

---

## 0. Một câu

> **Agent on-device một vòng, tool-calling trên hàm domain thuần, có guardrail số
> bắt buộc.** Không server, không vector database cho dữ liệu cá nhân, không
> multi-agent.

Lõi của nó: **máy tính số, mô hình kể chuyện**. Hệ luật tất định tính ra mọi con
số; mô hình chỉ viết lại thành câu; một bộ kiểm chặn mọi con số mô hình tự nghĩ ra.

---

## 1. Vì sao là kiến trúc này — bảy ràng buộc đã khoá

Kiến trúc này **không được chọn ra từ nhiều phương án tương đương**. Bảy ràng buộc
dưới đây, phần lớn có trước, cộng lại chỉ còn đúng một hình dạng khả dĩ.

| # | Ràng buộc | Nguồn | Loại |
|---|---|---|---|
| 1 | Dữ liệu giao dịch **không rời thiết bị** | F1 đặc tả Edge-SLM + Nghị định 13/2023/NĐ-CP | pháp lý — cứng nhất |
| 2 | Backend là **vùng chỉ đọc** với nhóm client | Quy tắc 1 `CLAUDE.md` | tổ chức |
| 3 | **Gemma 4 E2B cho mọi máy**, bỏ hẳn E4B | người dùng chốt 2026-09-20 sau phép đo P1 | đo được |
| 4 | **Lối B** — mô hình phục vụ **một chỗ**: màn Trợ lý AI. Sáu khối Nhận xét giữ mẫu câu | người dùng chốt 2026-09-20 | sản phẩm |
| 5 | **Lớp AI không tính** — mọi số từ hàm domain đã có | test quét `lib/` thứ **14** | kiến trúc |
| 6 | `kiemSo` là lớp chắn **duy nhất**, **không nới** vì mô hình lớn hơn | spec Edge-SLM mục 4.4 | kiến trúc |
| 7 | Dữ liệu AI là **cục bộ**, không vào `SyncEntityType` | test quét `lib/` thứ **15** | kiến trúc |

Ràng buộc 1 loại bỏ mọi kiến trúc gọi API ngoài. Ràng buộc 2 loại bỏ mọi kiến trúc
đòi backend làm thêm. Ràng buộc 5 và 6 quyết định hình dạng bên trong. Ràng buộc 4
quyết định mô hình được cắm vào **đâu**.

### 1.1 Ba phép đo của phiên 2026-09-21 củng cố nó

| Đo được | Hệ quả kiến trúc |
|---|---|
| `flutter_gemma` 1.8.3 có **tool-calling native cho Gemma 4** — `ModelType.gemma4 => SdkPassthroughFunctionCallFormat()` | Vòng 3 không phải tự chế giao thức tool: khai báo qua `tools_json` lúc tạo hội thoại, SDK lo phần còn lại |
| `flutter_gemma_embeddings` 2.1.1 tồn tại — tokenizer, isolate worker, pooling, normalization | RAG **chạy được on-device**, không cần server |
| Backend **mã hoá `transaction.Note` at-rest** (AES-256-GCM, `sync.repository.js:9` và `:14`) | Vector index trên ghi chú **chỉ làm được ở client**; làm ở server là vô hiệu hoá chính lớp mã hoá ấy |

### 1.2 Edge AI — thuật ngữ ngành vs mô-đun của dự án

| Câu | Đúng? |
|---|---|
| "**Thuật ngữ** Edge AI = học sâu chạy trên thiết bị (LiteRT, CoreML, NPU/GPU), từ thập niên 2010" | ✅ |
| "**Mô-đun** dự án đặt tên `ai_edge` hiện là hệ luật + thống kê mô tả, 0 mạng nơ-ron" | ✅ (đo 2026-09-21: 0 gói mô hình trong pubspec, 0 tệp `slm_*`, 1 bản `BoDienGiai` là `MauCau`) |

Hai câu cùng đúng vì **tên đi trước ruột**. Sau P3, tầng SLM là Edge AI đúng nghĩa; tầng luật
thì vẫn không, và không cần là. **Edge AI ≠ SLM**: Edge AI trả lời *chạy ở đâu*, SLM trả lời
*mô hình loại gì*; SLM on-device ⊂ Edge AI. Và ở FlowMoney, Edge AI **có điều kiện**: chỉ trên
arm64 đã tải mô hình; máy khác rơi về tầng luật (năm nhánh lùi).

⚠️ Một điểm đo được ngược với kỳ vọng phổ biến "Edge AI = NPU": trên Snapdragon 8 Gen 3, cho
tải sinh token, **GPU nhanh hơn NPU 3,6 lần** (2.329 vs 8.430 ms) và tốn RAM ít hơn 3,4 lần.
Đó là một tải công việc trên một con chip — không bác bỏ NPU nói chung — nhưng là số đo riêng
đáng mang vào báo cáo.

---

## 2. Ba vòng

```
┌─ VÒNG 1 — TẤT ĐỊNH ──────────────────────── ✅ ĐANG CHẠY ──────────┐
│                                                                     │
│   72 tệp domain thuần                                               │
│   (tongThuChi · budgetPaceOf · duBaoCua · thongKeMucTieu …)          │
│              │                                                       │
│              ▼                                                       │
│   6 × GoiSo  ──►  List<SoLieu>   (nhãn · soTho · chuoi · loai)      │
│              │                                                       │
│              ├──►  tai_phan_bo.dart   (luật B–C–G)  ──► KeHoach     │
│              │                                                       │
│              └──►  mau_cau.dart       ──► NhanXet                    │
│                                                                      │
│   ↳ 6 khối Nhận xét · offline · tức thì · test phủ trọn             │
└──────────────────────────────────────────────────────────────────────┘
                     │
                     │  abstract class BoDienGiai { Future<NhanXet> dienGiai(GoiSo); }
                     │
┌─ VÒNG 2 — KỂ CHUYỆN ──────────────── ✅ P3 XONG 22/09, CỔNG A QUA ─┐
│                                                                     │
│   Gemma 4 E2B   (GPU → canary → CPU → mẫu câu)                      │
│        nhận GoiSo ĐÃ TÍNH  ──► sinh câu ──► kiemCauTraLoi()         │
│                                     │      = kiemSo + kiemNhan      │
│                                     │        + kiemGiong            │
│                              qua ───┴─── trượt ──► goi.mauCau()     │
│                                                                      │
│   ↳ chặn THEO CÂU: đủ một câu mới kiểm, trượt thì huỷ sinh          │
│   ↳ CHỈ màn Trợ lý AI (lối B — BoDienGiai KHÔNG đăng ký vào DI)     │
└──────────────────────────────────────────────────────────────────────┘

┌─ VÒNG 3 — AGENT ──────────────────── ⬜ ĐỀ XUẤT, CHƯA CHỐT ────────┐
│                                                                     │
│   tools_json native (SdkPassthrough)                                │
│     9 tool trỏ vào hàm domain ĐÃ CÓ + 1 tool tra cứu kiến thức      │
│        │                                                             │
│        ▼                                                             │
│   mỗi tool TRẢ List<SoLieu>  ──►  gói số TÍCH LUỸ  ──►  kiemSo      │
│                                                                      │
│   🛑 vector index phía CLIENT: BỎ (đo 22/09, mục 5.5)               │
│      kiến thức chung → backend RAG; số cá nhân → function-calling   │
└──────────────────────────────────────────────────────────────────────┘
```

**Ba vòng, một hợp đồng.** `BoDienGiai` là interface hai dòng; vòng 2 và vòng 3 đều
là bản thi công của nó. Vòng 1 không biết vòng nào đang chạy phía trên.

---

## 3. Vòng 1 — tầng tất định

### 3.1 Tầng số

Không có tầng số riêng của AI. Nó **là** các hàm domain đã có của từng mảng, đã có
test, đã dùng cho giao diện: `budgetPaceOf`, `thuNhapCua`, `duBaoHoanThanh`,
`viTinhVaoTong`, `tongThuChi`…

Đếm bằng máy: **72** tệp dưới `lib/features/*/domain/`.

⚠️ **Đây là ràng buộc số 5, và nó được thi hành bằng test.**
`test/features/ai_edge/ai_edge_khong_tinh_test.dart` quét thư mục `ai_edge/` và cấm
mọi phép so chiều tiền, mọi truy cập bảng giao dịch. Lý do ghi thẳng trong docstring
của `goi_so.dart`: một bản định nghĩa thứ hai chính là thứ đã sinh ra bẫy *"thu nhập
gồm cả tiền đi vay"* — im lặng, không exception, không log.

### 3.2 Gói số — hợp đồng trung tâm

```dart
enum LoaiSo { tien, phanTram, soNgay, soDem }

class SoLieu {
  final String nhan;     // "Đã chi"
  final double soTho;    // 45000.0
  final String chuoi;    // "45.000 đ"  ← đã qua CurrencyFormatter
  final LoaiSo loai;
}

abstract class GoiSo {
  String get man;              // 'ngan_sach' | 'phan_tich' | …
  List<SoLieu> get soLieu;
  bool get thieuDuLieu;
  NhanXet mauCau();            // luôn có — là thứ SLM rơi về
  String get dauVan;
}
```

🔑 **`SoLieu.chuoi` mang ba vai cùng lúc.** Đây là chỗ tinh nhất của thiết kế:

1. **thẻ số liệu** người dùng nhìn thấy dưới câu văn,
2. **tập cho phép** của bộ kiểm số,
3. **phần bơm vào prompt** để mô hình chép nguyên.

Vì ba vai là **một chuỗi duy nhất**, không tồn tại trạng thái mà thẻ nói một đằng và
câu nói một nẻo. Đó không phải kỷ luật lập trình — đó là **cấu trúc dữ liệu**.

⚠️ Hệ quả phải nhớ khi viết prompt: bơm `soTho` (`45000.0`) thay vì `chuoi`
(`"45.000 đ"`) thì mô hình chép lại `"45000"` — một chuỗi mà `kiemSo` **vẫn cho qua**
nhưng người dùng đọc là sai định dạng tiền của app.

**Sáu gói số** (đếm: `ls lib/features/ai_edge/domain/goi_so_*.dart`):
`goi_so_ngan_sach` · `goi_so_phan_tich` · `goi_so_trang_chu` · `goi_so_muc_tieu` ·
`goi_so_hoa_don` · `goi_so_vi`.

### 3.3 Tầng luật

`tai_phan_bo.dart` (278 dòng) thi công **nhóm B–C–G** của 39 luật A–H trong đặc tả:
tìm ngân sách thâm hụt lớn nhất, xếp hạng nguồn bù theo dư địa, cắt tối đa 25 %
(15 % nếu đã cắt hai kỳ liền), làm tròn bội 10.000.

⚠️ **Ba điều tệp ấy tự thú nhận** — đáng nêu khi trình bày, vì chúng cho thấy hệ luật
được soát chứ không chép mù:

- **Essentiality = 0,5 cho mọi danh mục** (chưa có thống kê), nên phép xếp hạng C6
  `dư địa × (1 − essentiality)` **quy về xếp theo dư địa**. Cờ "Cố định" do người
  dùng bật là lớp bảo vệ duy nhất, và nó thắng tuyệt đối.
- **Luật C4 đã bị C5 nuốt trọn**, không còn tự loại được nguồn nào. Giữ lại vì nó là
  một luật của đặc tả và vì nới `kTranCat` sẽ làm nó sống lại — nhưng *"đừng viết ca
  test hành vi cho nó, ca ấy sẽ xanh vì lý do khác"*.
- **Luật D5 bỏ được** vì tái phân bổ giữ tổng hạn mức không đổi — và đó là tính chất
  **kiểm được bằng test thuần**, nhờ tách `hanMucMoi` ra khỏi widget.

### 3.4 Mẫu câu — sàn của hệ thống, không phải bản tạm

```dart
class MauCau implements BoDienGiai {
  const MauCau();
  @override
  Future<NhanXet> dienGiai(GoiSo goi) async => goi.mauCau();
}
```

Mười ba dòng. Chạy tức thì, offline, test được trọn vẹn.

⚠️ **Mọi mẫu câu phải tự qua được `kiemSo`** — có ca test ở từng gói số. Nếu không,
vòng 2 sẽ rơi về một câu mà chính bộ kiểm cũng chặn, tức **không có đường lùi**.

---

## 4. Vòng 2 — SLM kể chuyện

### 4.1 Mô hình và bậc thang

| Điều kiện | Mô hình | Backend |
|---|---|---|
| arm64-v8a, GPU dựng được | **E2B** | GPU |
| arm64-v8a, GPU hỏng, RAM ≥ 4 GB | E2B | CPU |
| còn lại (x86_64, RAM thấp, chưa tải, lỗi runtime) | **mẫu câu** | — |

🛑 **Spec mục 4.1 vẫn ghi bậc thang cũ "E4B ≥ 8 GB → E2B 4–8 GB"** — chính spec ấy
nói *"P1 có thể đổi con số ngưỡng"*, và P1 đã đổi. Đọc spec mà bỏ qua mục 8
`AI_EDGE_FEATURE.md` là lặng lẽ cài lại E4B.

### 4.2 Vì sao E2B, đo trên máy thật

OnePlus 13R / Snapdragon 8 Gen 3, mười câu mỗi lượt:

| Mô hình | Tệp | Backend | Nạp | 10 câu, TB | RAM đỉnh |
|---|---|---|---|---|---|
| E4B | 3,41 GB | GPU | 9.944 ms | **4.668 ms** | 0,97 GB |
| **E2B** | **2,41 GB** | **GPU** | 9.131 ms | **2.329 ms** | **0,96 GB** |
| E2B | nt | CPU | 4.516 ms | 3.313 ms | 1,73 GB |
| E2B | nt | NPU | 8.626 ms | 8.430 ms | 3,24 GB |

Lý do chốt E2B: **trên GPU hai mô hình tốn RAM bằng nhau** (0,96 vs 0,97 GB) nên
ngưỡng RAM không phân biệt được gì, trong khi E2B **nhanh gấp đôi**, tệp nhẹ hơn
**1 GB**, và tiếng Việt không thua. NPU tệ hơn cả GPU lẫn CPU.

### 4.3 Lối B — mô hình phục vụ đúng một chỗ

Người dùng chốt 2026-09-20: mô hình chỉ dùng ở **màn Trợ lý AI**; sáu khối Nhận xét
**giữ mẫu câu**.

**Lý lẽ đo được**: P1 cho thấy câu mô hình sinh cho khối Nhận xét **gần bằng mẫu câu**
— khác giọng văn chứ không khác thông tin, mà mẫu câu còn gọn hơn — trong khi giá là
**2,3 giây mỗi khối + 2,41 GB** tải về. Mô hình chỉ hơn hẳn ở **hỏi đáp tự do**.

**Thi hành bằng mã, không bằng lời**: Task 7 của P3 cố ý **không đăng ký `BoDienGiai`
vào DI**, nên `KhoiNhanXet` luôn rơi về `const MauCau()`.

⚠️ Đảo sang lối A là **một commit** (bỏ dấu chú thích khối đăng ký). Đừng làm nếu
người dùng chưa đổi ý.

### 4.4 ⚠️ Vòng 2 KHÔNG phải agent

`promptHoiDap(String cauHoi, List<GoiSo> goi)` nhét sẵn **cả sáu gói số** vào prompt
rồi để mô hình viết một câu. Mô hình **không quyết định gì, không gọi gì, không lặp**.

Đây là **data-to-text**. Làm xong trọn P3 thì hệ thống ở **bậc 1**, chưa phải agent.

---

## 5. Vòng 3 — agent (đề xuất, chưa chốt)

### 5.1 Mười tool

Chín cái đầu **đã tồn tại và đã có test** — chữ ký lấy từ mã ngày 2026-09-21:

| Tool | Hàm thật | Tệp |
|---|---|---|
| `tongThuChi` | `TongThuChi tongThuChi(…)` | `analytics/domain/thong_ke_thang.dart:93` |
| `chiTheoDanhMuc` | `List<ChiTheoDanhMuc> chiTheoDanhMuc(…)` | `analytics/domain/thong_ke_thang.dart:153` |
| `budgetPaceOf` | `BudgetPace budgetPaceOf(BudgetEntity, DateTime)` | `budget/domain/budget_pace.dart:72` |
| `duBaoCua` | `DuBaoDongTien? duBaoCua({…})` | `analytics/domain/du_bao_dong_tien.dart:181` |
| `thongKeMucTieu` | `ThongKeMucTieu? thongKeMucTieu({…})` | `goal/domain/goal_stats.dart:42` |
| `summarizeBills` | `BillSummary summarizeBills(List<Bill>, DateTime)` | `bill/domain/bill_status.dart:131` |
| `dongTienTuDo` | `List<DiemTuDo> dongTienTuDo(…)` | `analytics/domain/dong_tien_tu_do.dart:88` |
| `thuNhapCua` | `double thuNhapCua({…})` | `analytics/domain/dong_tien_tu_do.dart:57` |
| `topKhoanChi` | `List<DongGiaoDich> topKhoanChi(…)` | `analytics/domain/bao_cao_xuat.dart:403` |
| `traCuuKienThuc` | **phải viết mới** | — |

### 5.2 Chốt giữ vòng 3 không phá vòng 1

🔑 **Mọi tool trả `List<SoLieu>`, không trả văn bản.**

Khi ấy gói số thôi là thứ **dựng sẵn trước** mà thành thứ **tích luỹ dần theo các
lượt gọi tool** — nhưng bất biến *"mọi số trong câu phải có trong gói"* **không đổi
một chữ**. `kiemSo` sống sót nguyên vẹn.

⚠️ Để tool trả JSON thô hay chuỗi tự do là lúc bất biến ấy chết, và khi đó ta có một
agent bịa số như mọi agent khác.

### 5.3 Vector index — chỉ cho kiến thức chung

Corpus là **tĩnh** (quy tắc 50/30/20, định mức tiết kiệm, mẹo cắt giảm), nên nhúng
sẵn lúc build và đóng gói thành một asset. **Không database, không dịch vụ, không
đồng bộ.**

⚠️ **"vector index" ≠ "vector database".** `Standard_RAG.md` §2.3 đặc tả **HNSW** —
cấu trúc để tìm xấp xỉ trong 10⁵–10⁹ vector, đánh đổi độ chính xác lấy tốc độ. Với
vài trăm đoạn, quét tuyến tính cosine trong Dart **chính xác tuyệt đối** và vẫn dưới
một mili giây. Dùng HNSW ở quy mô này là trả giá độ chính xác mà không mua được gì.

### 5.4 Ba cái giá

| | |
|---|---|
| **Độ trễ nhân lên** | 2,33 s mỗi lượt sinh. Agent cần tối thiểu 2 lượt (chọn tool → trả lời) = **~4,7 s**; hai tool = **~7 s**. Chấp nhận được ở màn Trợ lý AI (người dùng chủ động hỏi), **không** được lan sang khối Nhận xét |
| **E2B chọn tool không đáng tin** | Mô hình 2B gọi sai tool hoặc sai tham số là chuyện thường. Cần `ToolChoice.auto`, **trần số vòng lặp**, và rơi về mẫu câu khi hết trần |
| **Chiều ghi không có lưới** | `kiemSo` kiểm **chữ**, không kiểm **hành động** — xem mục 8 |

### 5.5 Đo RAG on-device (spike, 2026-09-22, OnePlus 13R / Snapdragon 8 Gen 3)

App đo vứt đi, ngoài repo. Corpus **30 đoạn kiến thức tài chính chung tiếng Việt**, không dữ
liệu cá nhân; 5 câu hỏi, mỗi câu có một đoạn mong đợi; `topK: 3`.

| Đại lượng | Giá trị |
|---|---|
| `flutter_gemma_rag_sqlite` | **1.3.2** — **tương thích `flutter_gemma` 1.8.3**, không đòi nâng |
| Kho vector | KNN chạy **trong SQLite** qua `sqlite-vec` (bảng ảo `vec0`) — không brute-force Dart, không index trong RAM |
| Mô hình đo được | **Gecko 110M English** — `Gecko_256_quant.tflite` |
| Dung lượng | **114.141.184 B** (109 MiB) + tokenizer **794.346 B** |
| Chiều vector | **768** (đo thật từ `VectorStoreStats`) |
| RAM đỉnh | **533 MB PSS** · 655 MB RSS |
| `FlutterGemma.initialize` | 28 ms |
| `installEmbedder().install()` | 165 ms |
| `createEmbeddingModel()` | 531 ms |
| `rag.initialize` | 34 ms |
| Index 30 đoạn | **7.608 ms** = **253,6 ms/đoạn** |
| Tệp CSDL sau index | 3.203.072 B (~104 KB/đoạn) |
| Truy vấn (TB 5 câu) | **251 ms** |
| Top-3 đúng | **3/5** |
| **Tổng tải nếu ship** | 2,41 GB (Gemma 4 E2B) + 109 MB = **~2,52 GB** (+4,5%) |

**Ngưỡng đặt trước ở lộ trình (M4):** truy vấn < ~200 ms **và** top-3 ≥ 4/5. Đo được **251 ms**
và **3/5** — **không đạt cả hai**.

#### 🛑 Quyết định M4: KHÔNG làm RAG phía client ở dạng hiện tại

Chuyển kiến thức chung sang **backend RAG** (chặng 6); client gọi một endpoint. Câu *"hệ thống có
áp dụng RAG"* vẫn đúng, chỉ là đúng ở phía server. Lý do bằng số:

1. **Mô hình duy nhất tải tự do là English-only.** Gecko cho **3/5** trên câu hỏi tiếng Việt; hai
   câu hỏng là hai câu cần hiểu ngữ nghĩa tiếng Việt tinh hơn (*"Nên trả nợ trước hay đầu tư
   trước?"*, *"Tỉ lệ tiết kiệm tính thế nào?"*). Corpus của FlowMoney là tiếng Việt, nên đây
   không phải hạn chế bên lề mà là hạn chế trúng đích.
2. **Mọi bản đa ngữ đều gated.** `google/embeddinggemma-300m*` **và** `litert-community/embeddinggemma-300m`
   đều trả **401** khi tải không token (đo 2026-09-22) — `gated: manual` / `gated: auto`. Ship một
   mô hình mà mỗi máy phải có token HuggingFace là không ship được.
3. **Độ trễ trên ngưỡng ngay cả khi bỏ qua hai điều trên**: 251 ms một truy vấn, và 253 ms mỗi
   đoạn khi index.

⚠️ **Hai lỗi của gói, đáng nhớ nếu ai đó mở lại hướng này.** (a) `EmbeddingModel.gecko110M` trong
`flutter_gemma-1.8.3/lib/rag/embedding_models.dart` trỏ tới `…/resolve/main/gecko.tflite` — đường
ấy trả **404**; tệp thật mang tên `Gecko_<seqlen>_{quant,f32}.tflite` (`Gecko_256_quant.tflite`
114 MB, `Gecko_1024_quant.tflite` 146 MB, `Gecko_256_f32.tflite` 443 MB). (b) Bảng cùng tệp ghi
Gecko *"110MB"* và EmbeddingGemma 300M *"300MB"*, nhưng cả năm mục đều khai `needsAuth: true` —
đúng với EmbeddingGemma, **sai với Gecko** (repo `litert-community/Gecko-110m-en` có
`gated: false`).

⚠️ **Chữ ký API thật** (kế hoạch spike đoán sai ba chỗ): `RetrievalResult` mang `id` / `content` /
`similarity` — **không** có `document` hay `score`; entry point là `FlutterGemmaPlugin.instance`,
**không** `FlutterGemma.instance`; và `installEmbedder().install()` **đã** tự đặt mô hình làm
active embedder nên không cần bước đặt riêng.

⚠️ Build app spike vấp `Could not close incremental caches` ở `compileDebugKotlin` và **`flutter
clean` không cứu được** — chỉ khỏi khi thêm `kotlin.incremental=false` cùng
`kotlin.compiler.execution.strategy=in-process` vào `android/gradle.properties`.

### 5.6 Bảng đo chặng 3 — bậc 1 hỏng ở đâu ⬜ **CHƯA ĐO**

Mục này là **chỗ đặt kết quả chặng 3**, và nó được tạo sẵn khung ngày 2026-09-22 vì
`plans/2026-09-21-ai-viec-tiep-theo.md:128` đã trỏ tới *"bảng 20 hàng ở mục 5.6"* trong khi mục
ấy **chưa tồn tại** — một con trỏ chết sống qua hai phiên.

**Điều kiện vào:** cổng A đã đóng ✅ (2026-09-22 tối, mục **9.9** `docs/AI_EDGE_FEATURE.md`). Đo
một mô hình còn bịa nhãn thì bảng đo nói dối.

**Cách đo:** 20 câu người dùng thật sẽ hỏi — 5 ngân sách · 5 chi tiêu theo kỳ tuỳ ý · 5 mục
tiêu/hoá đơn · 5 cần **ghép nhiều nguồn** — hỏi từng câu ở màn Trợ lý AI trên máy thật, tài khoản
thật.

| # | Câu hỏi | Kết quả | Con số nào THIẾU trong sáu gói | Tool đặt hàng |
|---|---|---|---|---|
| | *(chặng 3 điền)* | | | |

**Bốn cột, không phải ba.** Cột *Kết quả* nhận một trong **bốn** giá trị, và giá trị thứ tư là
thứ lượt đo cổng A phát hiện nên phải có chỗ riêng:

1. **Trả lời được** — đúng câu hỏi, số thật.
2. **Rơi về mẫu câu** — một chốt chặn, người dùng nhận câu mẫu.
3. **Trả lời sai** — số sai hoặc nhãn sai lọt qua mọi chốt.
4. ⚠️ **Trả lời được nhưng lệch câu hỏi** — mô hình **không nói "không có dữ liệu"** dù few-shot
   có ví dụ ấy; nó chọn con số liên quan thật gần nghĩa nhất rồi trả lời. Mọi số đều đúng, mọi
   chốt đều cho qua, nhưng nó không trả lời điều được hỏi. Đây **chính là tín hiệu đặt hàng
   tool** rõ nhất — đừng gộp nó vào ô "trả lời được".

**Ba điều người đo cần biết trước:**

- **Bậc 1 chỉ thấy ~30 con số của sáu gói** (`NguonGoiSo.tatCa`): phân tích · ngân sách · mục tiêu
  · hoá đơn · ví · trang chủ. Mọi câu hỏi ngoài các nhãn ấy là "hỏng" **theo định nghĩa của
  bảng** — đó là điều muốn đo, không phải lỗi cần sửa tại chỗ.
- Câu hỏi gõ bằng `adb shell input text` **không có dấu**; mô hình vẫn hiểu. Ghi rõ trong bảng.
- `debugPrint` bị tiết lưu nên logcat mất dòng — **số trên màn hình mới là số đủ** (bẫy 8.6
  `AI_EDGE_FEATURE.md`).

🛑 **Nếu 0 câu hỏng thì vòng 3 không có việc** — dừng lộ trình và báo; đó cũng là một kết quả.
Với những gì đo được ngày 2026-09-22, khả năng ấy thấp.

**Ra cổng B:** bảng trên điền đủ 20 hàng + danh sách tool **rút từ bảng**, không phải từ mười tool
ứng viên ở mục 5.1. Dựng 10 tool rồi thấy 7 cái không ai gọi là cùng một lớp lãng phí với lát
"cửa sổ nhìn lại": một hàm đúng từng dòng mà đầu vào chết thì vẫn vô dụng.

---

## 6. Bốn bất biến — đây mới *là* kiến trúc

Sơ đồ chỉ là hình. Thứ định nghĩa hệ thống là bốn luật không được phá. Phá cái nào
cũng hỏng **im lặng**.

### ① Mô hình không bao giờ tính

Mọi con số đến từ hàm domain đã có test. Thi hành bằng **test quét `lib/` thứ 14**.

### ② Mọi tool trả `List<SoLieu>`, không trả văn bản

Chốt giữ `kiemSo` sống khi lên vòng 3. Xem 5.2.

### ③ Luôn có đường lùi về mẫu câu

**Năm nhánh, tất cả IM LẶNG** (không toast, không dialog — H3 của đặc tả):

1. gói thiếu dữ liệu
2. chưa tải mô hình
3. nạp hỏng (x86_64, RAM thấp)
4. mô hình ném giữa chừng
5. câu không qua bộ kiểm số

*(Vòng 3 thêm nhánh thứ sáu: hết trần vòng lặp.)*

⚠️ **Điều kiện pin đã BỎ.** `AI_EDGE_FEATURE.md` mục 8 còn liệt kê *"pin yếu"* trong
bảng bậc thang; kế hoạch P3 bỏ nó **có chủ ý** — sinh một câu mất 2,3 giây, không
phải tác vụ dài, và đọc pin đòi thêm kênh native để đổi lấy một phép chặn không ai
thấy tác dụng. **Kế hoạch P3 mới là hiện trạng.**

### ④ Chiều ghi luôn qua tay người dùng

Xem mục 8.

---

## 7. Bộ kiểm số — cơ chế

`kiem_so.dart`, 57 dòng. Trích **mọi** con số trong câu bằng regex rồi đòi từng số
khớp một `SoLieu` của gói:

```dart
bool kiemSo(String cau, GoiSo goi) =>
    trichSo(cau).every((x) => goi.soLieu.any((s) => _khop(x, s)));
```

**Dung sai theo loại:**

| `LoaiSo` | Dung sai | Vì sao |
|---|---|---|
| `tien` | ≤ 0,5 đ | đuôi lẻ của `double`, cùng ngưỡng với đối soát số dư |
| `phanTram` | ≤ 0,05 | G2 in một chữ số thập phân → sai số làm tròn tối đa 0,05 |
| `soNgay` / `soDem` | **= 0** | không có gì để làm tròn |

⚠️ Regex bắt **cả dấu âm** (`-` và `−`) vì `soPhanTram` giữ dấu (`-8,3%`) — mất dấu
là đảo nghĩa tăng/giảm mà bộ kiểm vẫn cho qua.

**Giới hạn cố ý:** ngày tháng (`12/09`) cũng là số. Mẫu câu của app không in ngày;
nếu sau này gói số cần ngày thì **thêm `LoaiSo.ngayThang`** chứ đừng nới regex.

**Câu không có số nào thì lọt** — không có gì để bịa.

---

## 8. Chiều ghi — bốn tầng hậu quả

🛑 **`kiemSo` KHÔNG dùng được ở chiều ghi.** Nó kiểm được một chuỗi, không kiểm được
một hành động.

| Tầng | Ví dụ | AI được làm gì |
|---|---|---|
| 1 — không hậu quả | gợi ý, sắp xếp, nhận xét | tự do |
| 2 — sửa được dễ | điền sẵn form, chọn sẵn ví | tự do, người dùng thấy trước khi lưu |
| 3 — đổi dữ liệu | `updateBudget` | **chỉ dựng bản nháp**, người dùng tick từng dòng |
| 4 — tự chuyển tiền | `auto_pay`, trích tự động | **AI không chạm** |

Khuôn mẫu của tầng 3 đã có và đang chạy: sheet kế hoạch tái phân bổ. AI đề xuất từng
dòng cắt-bù; người dùng tick; `hanMucMoi()` dựng danh sách `updateBudget`. Hàm ấy
**tách khỏi widget** để tính chất *"tổng hạn mức không đổi"* kiểm được bằng test
thuần — và chính nhờ thế mà luật D5 bỏ được.

---

## 9. Ba thứ kiến trúc này cố ý KHÔNG làm

| Không làm | Vì sao — đo được, không phải quan điểm |
|---|---|
| **Vector DB cho dữ liệu cá nhân** | CSDL dev có **58** giao dịch sống toàn hệ thống, **39** của tài khoản đang dùng. Retrieval sinh ra để giải bài *"ngữ cảnh quá lớn"* — bài ấy không tồn tại ở đây. Với số có cấu trúc, SQL **chính xác hơn** cosine: *"tháng này tiêu bao nhiêu cho ăn uống"* có một đáp án đúng, còn similarity trả về *"những dòng nghe giống ăn uống"* |
| **Multi-agent** | Chỉ có một vai: *đọc số, trả lời*. Agent thứ hai = **+2,3 giây** đổi lấy không gì. Nhiều agent có nghĩa khi có nhiều vai xung đột (nghiên cứu vs phản biện) |
| **Huấn luyện mô hình để cá nhân hoá** | Trọng số không phải nơi chứa hiểu biết về người dùng; và gói **không có API huấn luyện** (đã quét cả `lib/` của nó). Cá nhân hoá nằm ở **tầng số**: neo ngưỡng theo thu nhập, ví hay dùng theo danh mục, cửa sổ nhìn lại cuộn |

### 9.1 Ca duy nhất đáng RAG trên dữ liệu cá nhân — và vì sao nó phải ở client

`transaction.Note` là văn bản tự do. Đo ngày 2026-09-21:

| | |
|---|---|
| Giao dịch sống có ghi chú | **39 / 58** |
| Độ dài bản rõ, trung bình | **39 byte** (≈ 20–25 ký tự tiếng Việt) |
| Dài nhất | **55 byte** |

*(Suy từ định dạng `enc:<iv 24 hex>:<tag 32 hex>:<ct hex>` — 62 ký tự thừa, phần còn
lại là hex nên bằng 2× số byte bản rõ.)*

**Server không làm được sạch**: backend mã hoá `Note` at-rest. Muốn index, phải giải
mã cả bảng rồi lưu embedding — mà **embedding của một văn bản là một biểu diễn của
chính văn bản ấy**, nằm ngoài lớp mã hoá. Dựng vector DB ở đó là **vô hiệu hoá chính
lớp AES-256-GCM** mà backend đã bỏ công làm. Trên máy người dùng thì bản rõ vốn đã
nằm sẵn trong SQLite, nên không có vấn đề ấy.

⚠️ **Nhưng hiện chưa đáng làm.** 39 dòng, mỗi dòng hai chục ký tự — `normalizeCategoryName`
+ `LIKE` vừa đủ vừa chính xác hơn embedding. Embedding chỉ đáng tiền khi ghi chú dài
(câu, đoạn) và nhiều (hàng nghìn). Việc **2.1 "tìm kiếm bằng câu"** nên làm bằng SQL
trước.

---

## 10. Đối chiếu với `Standard_RAG.md`

`docs/AI/Standard_RAG.md` do NPBao viết, thuộc **vùng chỉ đọc** với nhóm client. Chỗ
cần sửa đi qua `docs/superpowers/backend/CAN-LAM/`.

| Chuẩn nêu trong tài liệu ấy | Ở kiến trúc này |
|---|---|
| Chuẩn hoá văn bản tiếng Việt NFC | ✅ đã có — `normalizeCategoryName()`, một định nghĩa duy nhất |
| Strict Grounding | ✅ có, và **mạnh hơn** — `kiemSo` chặn ở tầng cấu trúc |
| Low temperature + structured output | ✅ áp dụng được ở vòng 2/3 |
| U-Shaped Context Reordering | ⬜ backend đã dùng ở tầng 3 classifier; client chưa cần |
| Semantic chunking + **HNSW index** | ⚠️ **không áp** cho dữ liệu cá nhân; với kiến thức chung thì quét tuyến tính đúng hơn ở quy mô này |
| Hybrid Search (BM25 + semantic) + **RRF** | ⚠️ **không áp** — bài toán là truy vấn số có cấu trúc, không phải xếp hạng tài liệu |
| Cross-Encoder Reranker | ⚠️ **không áp** — không có danh sách ứng viên để xếp lại |
| Ragas benchmark | ⬜ đáng cân nhắc cho vòng 3, chưa có |

### 10.1 🛑 Hai mâu thuẫn nhóm phải chốt

**① Dữ liệu cá nhân có được rời thiết bị không?**
Ma trận §6 xếp *Financial Chatbot* cần truy xuất *"toàn bộ dữ liệu tài chính của
User"* — tức index sổ giao dịch lên server. Nhưng **F1** của đặc tả Edge-SLM và Nghị
định 13/2023 nói dữ liệu giao dịch **không được rời thiết bị**. Hai câu này không thể
cùng đúng.

**② Tầng 3 của classifier đã gửi dữ liệu ra ngoài.**
`modules/ai/features/classify/pipeline/llm.classifier.js` gửi chuỗi mô tả giao dịch
sang Gemini/OpenAI. Nó nằm đúng chỗ mâu thuẫn ①, và mâu thuẫn thêm với chính việc
backend **mã hoá `Note` at-rest** — tức backend vừa cam kết bảo vệ ghi chú, vừa có
một đường gửi mô tả giao dịch ra bên thứ ba.

⚠️ Hiện chưa lộ ra vì `GEMINI_API_KEY` và `OPENAI_API_KEY` **đều trống** trên máy dev
(đo 2026-09-21) — tầng 3 **chưa từng chạy**.

Chốt F1 thì phải sửa tầng 3; chốt ma trận §6 thì phải sửa F1. Không thể để cả hai.

---

## 11. Trạng thái thi công

| Bậc | Là gì | Trạng thái | Bằng chứng |
|---|---|---|---|
| **0** | Hệ luật + mẫu câu | ✅ **đang chạy**, 6 màn | `grep -rl 'KhoiNhanXet(' lib/` → 7 tệp (trừ 1 định nghĩa) |
| **1** | SLM kể chuyện | ✅ **đang chạy** từ 2026-09-22 (P3 xong 10/10 task, cổng A qua) | `grep flutter_gemma pubspec.yaml` → **5**; **4** tệp `slm_*` trong `lib/` (`slm_prompt`, `slm_cache`, `slm_runtime`, `slm_dien_giai`); mô hình chạy thật trên OnePlus 13R và Realme RMX2205 — mục **9**, **9.9**, **9.10** `AI_EDGE_FEATURE.md`. *(Ô này ghi "📝 kế hoạch 10 task, 0 dòng mã" cho tới 2026-09-22, với bằng chứng "`grep flutter_gemma pubspec.yaml` → 0; sáu tệp `slm_*` chưa có" — đếm lại bằng máy cùng ngày thì cả hai vế đã đổi. Và lưu ý **bốn** chứ không phải sáu tệp `slm_*`: `slm_dien_giai.dart` cố ý **không** được đăng ký vào DI theo lối B.)* |
| **2** | Agent | ⬜ **chưa có kế hoạch** | `grep -E 'Tool\(\|ToolChoice\|embedding\|cosine'` trong `lib/` → 0 |

✅ **Hết từ 2026-09-22.** *(Câu cũ ở đây: "Gói `flutter_gemma` **có trong pub cache** nhưng đến từ
**app spike P1** ở `D:/flowmoney-spike` … **không một dòng nào của phép đo ấy nằm trong repo**.")*
P3 đã cắm mô hình vào chính app: `pubspec.yaml` khai `flutter_gemma: 1.8.3` và
`flutter_gemma_litertlm: ^1.7.0`, `lib/features/ai_edge/` có **33** tệp test / **294** ca, và mô
hình đã chạy thật **trong app** trên **hai** máy — OnePlus 13R (GPU) và Realme RMX2205 (CPU, sau
khi canary bắt được cú sập native trên Mali).

### 11.1 Câu trung thực nếu được hỏi "đã làm tới đâu"

*(Cập nhật 2026-09-22 — câu dưới đây đã viết lại; bản cũ nói mô hình "**chưa cắm vào app**", đúng
tới sáng hôm ấy.)*

> Hiện có một **hệ luật chạy on-device** (tầng số + luật + guardrail `kiemSo`), phủ
> 6 màn, offline, tức thì. Phần **mô hình** (Gemma 4 E2B, 2,41 GB) **đã cắm vào app và chạy
> thật trên máy thật** — trả lời hoàn toàn trong máy, đo được **0 request đi ra** khi cắt
> mạng, chữ hiện dần theo từng câu, và mọi con số trong câu trả lời đều bị ba lớp chắn
> (`kiemSo`, `kiemNhan`, `kiemGiong`) đối chiếu với gói số trước khi hiện. Phần **agent**
> (tool-calling) thì **chưa có** — bước đo để quyết định cần những tool nào là việc tiếp theo.

Vẫn **không nên nói *"đã có AI Agent"*** — vế "agent" chưa đúng. Hai vế kia thì nay nói được:
*"Edge AI"* đúng từ khi mô hình chạy on-device, và *"RAG"* thì **cố ý không làm ở client** (mục
**5.5** đo được là không khả thi) — nó thuộc backend, cho kiến thức chung, không cho số của
người dùng.

---

## 12. Lộ trình — ba bước, theo đúng thứ tự phụ thuộc

1. ✅ **P3 XONG 2026-09-22** (trọn 10 task) — mô hình đã cắm và chạy trong app thật trên hai
   máy; ba lớp chắn `kiemSo` / `kiemNhan` / `kiemGiong` bắt được câu sai trên máy thật.
   **Cổng A qua** tối cùng ngày.
2. ⬜ **Đo trước, rồi mới tool layer.** Bước đo — *"bậc 1 hỏng ở đâu"*, mục **5.6** — là việc
   **tiếp theo** và là điều kiện vào của tool layer: danh sách tool phải **rút từ bảng đo**,
   không phải từ mười tool ứng viên ở mục 5.1. Sau đó mới khai báo tool trỏ vào hàm domain đã
   có, mỗi tool trả `List<SoLieu>`.
3. ⬜ **Vòng lặp + trần** — trần 3 lượt gọi tool, không tool ghi.

*(Bản cũ của mục này ghi bước 3 là "cộng **vector index tĩnh** cho kiến thức chung" và bước 2 là
"9 tool + `traCuuKienThuc`". Cả hai đã đổi ngày 2026-09-22: RAG phía client **bỏ hẳn** — mục
**5.5** đo được mô hình embedding tải tự do duy nhất là English-only, top-3 đúng 3/5 trên câu
tiếng Việt, truy vấn 251 ms trên ngưỡng 200 ms — nên kiến thức chung chuyển sang **backend RAG**,
và NPBao đã chốt lối ① cùng ngày. Câu "Bước 1 là điều kiện của cả hai bước sau, nên nó vẫn là
việc kế tiếp" cũng đã hết hiệu lực: bước 1 xong rồi.)*

---

## 13. Câu hỏi còn mở

> **Trợ lý AI dừng ở bậc 1 hay đi tới bậc 2?**

| | Bậc 1 — P3 như đã viết | Bậc 2 — thêm vòng 3 |
|---|---|---|
| Công | 10 task đã viết sẵn | +3 task |
| Độ trễ | ~2,3 s | ~4,7–7 s |
| Trả lời được | câu về **6 màn** đã có gói số | câu cần **ghép nhiều nguồn** hoặc kỳ tuỳ ý |
| Rủi ro | thấp — mô hình không chọn gì | E2B chọn sai tool là chuyện thường |
| Nghe khi trình bày | "AI on-device" | "AI Agent" |

⚠️ Người dùng đã chốt ngày 2026-09-21: **ưu tiên giá trị người dùng, không phải phần
dễ gây ấn tượng khi demo**. Bậc 2 nghe hay hơn hẳn, nhưng với 39 giao dịch thì phần
lớn câu hỏi thật đã trả lời được ở bậc 1 — nhanh gấp đôi và không có rủi ro chọn sai
tool.

**Đề xuất**: thi công **P3 trọn vẹn trước**, đo trên máy thật xem câu hỏi nào bậc 1
trả lời không nổi, rồi mới quyết vòng 3 bằng **danh sách câu hỏi hỏng thật** chứ
không bằng phỏng đoán.

✅ **Đề xuất này đã được chấp nhận, và nửa đầu đã làm xong** (2026-09-22): P3 trọn 10 task, cổng A
qua. **Nửa sau — phép đo — là việc tiếp theo**, khung bảng ở mục **5.6**. Câu hỏi của mục 13 vì
thế vẫn **còn mở**, nhưng nay nó có một đường trả lời cụ thể thay vì phải cân nhắc lại từ đầu.
⚠️ Một dữ kiện lượt đo cổng A đã bổ sung sẵn cho nó: mô hình **không nói "không có dữ liệu"** —
hỏi thứ gói số không có thì nó chọn con số liên quan thật gần nghĩa nhất rồi trả lời. Đó chính là
loại câu bậc 1 "trả lời không nổi" mà bảng 5.6 phải đếm, và nó **không** hiện ra dưới dạng câu
mẫu hay câu sai, nên đừng chỉ đếm hai ô ấy.

🛑 Đúng bài học lát *"cửa sổ nhìn lại"* vừa trả giá ngày 2026-09-21: `suggestAmount`
đúng từng dòng suốt từ 2026-09-06 nhưng đầu vào là một cửa sổ mà dữ liệu thật không
lấp đầy, nên nó **chưa từng hiện một con số nào**. Bộ test mù vì nó dựng sẵn dữ liệu.
Thứ bắt được là một phép đo trên **CSDL thật**. Quyết định về vòng 3 cũng phải đi
đường ấy.

---

## 14. Đọc thêm

| Cần biết | Đọc |
|---|---|
| Tính năng, bẫy, bảng đo P1 | `docs/AI_EDGE_FEATURE.md` — mục **8** (đo), **10** (mảng này thực chất là gì), **11** (bản đồ năng lực) |
| Kế hoạch cắm mô hình | `docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md` |
| Đặc tả gốc (backend quản) | `docs/AI/AI_Edge-SLM.md/Client-app.md` · `docs/AI/Standard_RAG.md` |
| Chỗ sai của đặc tả gốc | Vòng **hai** (đang mở): `docs/superpowers/backend/CAN-LAM/AI_EDGE_SLM_SOAT_SAU_B147FEE.md`. Vòng **một** đã đóng ở `b147fee` (2026-09-22): `DA-XONG/AI_EDGE_SLM_SUA_TAI_LIEU.md` và `DA-XONG/EDGE_AI_THUAT_NGU_VA_HAI_MAU_THUAN.md` |
| Việc còn mở của cả dự án | `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md` |
