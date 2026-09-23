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

┌─ VÒNG 3 — AGENT ──────────── ✅ LÁT 4b XONG 23/09, CỔNG C ĐẠT ─────┐
│                                                                     │
│   tools_json native — 4 tool ĐỌC trỏ vào hàm domain ĐÃ CÓ          │
│     (ngân sách · hoá đơn · ví · chi tiêu theo kỳ)                   │
│        │                                                             │
│        ▼                                                             │
│   mỗi tool TRẢ hàng (tên + trạng thái + List<SoLieu>)               │
│        ──►  GoiSoTraCuu TÍCH LUỸ  ──►  kiemCauTraLoi()              │
│                                                                      │
│   ↳ hoiBangCongCu: trần 3 lời gọi · L1 chưa tool nào → vòng 2       │
│   🛑 vector index phía CLIENT: BỎ (đo 22/09, mục 5.5)               │
│      kiến thức chung → backend RAG; số cá nhân → function-calling   │
└──────────────────────────────────────────────────────────────────────┘
```

**Ba vòng, một hợp đồng — và hợp đồng ấy là `GoiSo`.** Vòng 2 trên màn Trợ lý AI nhận sáu gói
dựng sẵn, vòng 3 nhận `GoiSoTraCuu extends GoiSo` tích luỹ từ tool; ba lớp chắn và thẻ số liệu
chạy nguyên trên cả hai. Vòng 1 không biết vòng nào đang chạy phía trên. *(Câu cũ ở đây nói hợp
đồng là `BoDienGiai` và "vòng 2 và vòng 3 đều là bản thi công của nó" — sai từ lối B, khi màn
Trợ lý AI tự dựng đường sinh câu và `BoDienGiai` không được đăng ký; vòng 3 là `hoiBangCongCu`.)*

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

## 5. Vòng 3 — agent (✅ thi công ở lát 4b, 2026-09-23 — bốn tool; 5.1–5.4 là bản đề xuất ban đầu, giữ làm lịch sử)

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

### 5.6 Bảng đo chặng 3 — bậc 1 hỏng ở đâu ✅ **ĐO XONG 2026-09-22 (tối muộn)**

> 🛑 **Đọc cả mục "Đo lại sau chặng 4a" ở cuối mục này trước khi dùng bảng.** Lát 4a đã chữa
> được **một** trong bốn câu nhóm A và chứng minh ba câu còn lại **không** chữa được bằng gói số
> — chúng cần tool. Đơn đặt hàng sáu tool bên dưới vì thế **vẫn đứng**, nhưng hình dạng của nó đã
> rõ hơn: tool phải trả **một hàng đầy đủ** (tên + số + trạng thái), không phải nhiều mục rời.

**Máy:** Realme RMX2205 (Dimensity 1100, Mali-G77, Android 13, 360 dp), APK **release**, nạp
**CPU** (canary đã ghi dấu GPU sập từ lượt trước). **Tài khoản:** 10 (`tadd1632004@gmail.com`),
dữ liệu thật. **Nạp mô hình:** 9.196 ms (XNNPack cache đã có sẵn). **Sinh câu:** 4,8–8,9 s mỗi
câu, token đầu 4,5–8,2 s.

**Điều kiện vào đã thoả:** cổng A đóng ✅ (mục **9.9** `docs/AI_EDGE_FEATURE.md`).

**Dữ liệu nền lúc đo** (đọc từ chính app, để chấm được đúng/sai):

- Trang chủ: tổng số dư **13.004.000**, thu nhập **15.145.000**, chi tiêu **2.141.000**
- Ngân sách (4 đang chạy): còn **1.340.000** (72 %), đã dùng 510.000/1.850.000 —
  Giáo dục 45k/50k (**90,0 %**), Ăn uống 50k/500k, Di chuyển 355k/450k, Mua sắm 60k/850k
- Mục tiêu (2): MuaXe **55,0 %** (thiếu 899.000, còn 583 ngày, đúng kế hoạch), MuaDT 13,3 %
- Hoá đơn: còn phải trả **155.000**, đã trả 65.000, chưa trả **3**, quá hạn **1** ("Kiem")
- Ví (4): Tiền mặt 9.903.000 · test **−100.000** · Tiết kiệm 3.201.000 · mua nhà 0

#### Bảng 20 hàng

Ký hiệu cột *Kết quả*: **✅** trả lời được · **MẪU** rơi về mẫu câu · **SAI** số/nhãn sai lọt qua ·
**LỆCH** trả lời được nhưng không trả lời điều được hỏi.

| # | Câu hỏi (gõ không dấu) | Mô hình trả lời | Kết quả | Thiếu gì trong sáu gói |
|---|---|---|---|---|
| 1 | Ngân sách của tôi thế nào | *(bị chặn)* "Ngân sách của bạn đang ở mức 90,0%" | **MẪU** | — nhãn "Tỉ lệ" không khớp câu |
| 2 | Còn bao nhiêu **tiền** ngân sách tháng này | "Ngân sách căng nhất là 90,0%" | **LỆCH** | tổng còn lại 1.340.000 |
| 3 | Ngân sách **nào** sắp hết | "Ngân sách căng nhất là 90,0%" | **LỆCH** | **tên** ngân sách |
| 4 | % ngân sách **Ăn uống** | "Không có dữ liệu để trả lời câu hỏi của bạn" | **MẪU** ✓ | ngân sách tra theo tên |
| 5 | Tháng sau nên đặt ngân sách bao nhiêu | "Ngân sách căng nhất là 90,0%" | **LỆCH** | gợi ý hạn mức |
| 6 | Tháng này tôi chi bao nhiêu | "Chi tiêu tháng này là 2.141.000 đ trên tổng thu 15.135.000 đ" | **✅** | — |
| 7 | **Tuần này** tiêu bao nhiêu | *(bị chặn)* "Hôm nay bạn đã chi 556 đ" | **MẪU** | chi theo kỳ tuỳ ý |
| 8 | Chi nhiều nhất vào **danh mục nào** | "Khoản lớn nhất là 800.000 đ" | **LỆCH** | **tên** danh mục |
| 9 | **Tháng trước** chi bao nhiêu | "**Tháng này** tổng chi là 2.141.000 đ…" | **LỆCH** | kỳ trước |
| 10 | Mục tiêu MuaXe thế nào rồi | "đạt tiến độ 55,0%, còn thiếu 899.000 đ và còn 583 ngày" | **✅** | — |
| 11 | **Khi nào** đạt mục tiêu tiết kiệm | "…không có thông tin cụ thể trong dữ liệu" | **✅** | dự báo ngày đạt |
| 12 | Còn bao nhiêu **hoá đơn chưa trả** | "Đã trả: 65.000 đ" | **LỆCH** | 🛑 **không thiếu** — chọn nhầm |
| 13 | **Hoá đơn nào** quá hạn | "Ngân sách căng nhất là 90,0%" | **LỆCH** | **tên** hoá đơn *(sang hẳn chủ đề khác)* |
| 14 | Tiền trong **ví** còn bao nhiêu | "Còn lại là 12.994.000 đ" | **LỆCH** | 🛑 **không thiếu** — nhầm thu−chi với số dư |
| 15 | **Ví nào** đang âm | "Ví đang âm: 1" *(thẻ hiện sai: "Quá hạn 1")* | **LỆCH** | **tên** ví |
| 16 | Tiền trong ví **có đủ** trả hoá đơn không | "Còn phải trả 155.000 đ cho hóa đơn" | **LỆCH** | phép **so sánh** hai gói |
| 17 | Trả hết hoá đơn thì **còn** bao nhiêu | "Tổng số tiền còn phải trả cho hóa đơn là 155.000 đ" | **LỆCH** | phép **trừ** |
| 18 | Chi tiêu **có vượt** thu nhập không | "Chi tiêu của bạn là 2.141.000 đ trên tổng thu 15.135.000 đ" | **✅** | — |
| 19 | Tháng này để dành bao nhiêu % | "Để dành được 85,4% thu nhập" | **✅** | — |
| 20 | Có tất cả **bao nhiêu ví** | đổ **năm** con số của cả gói, không nêu "4 ví" | **LỆCH** | 🛑 **không thiếu** — "Số ví 4" có sẵn |

**Tổng: ✅ 5 · MẪU 3 · SAI 0 · LỆCH 12.**

#### Bốn điều bảng này nói ra

**1. Bậc 1 không bịa — nó lệch.** `SAI = 0` trên 20 câu: ba lớp chắn làm đúng việc. Nhưng **12/20
lệch câu hỏi**, tức hơn một nửa. Nếu chỉ đếm hai ô "trả lời được / rơi mẫu" như bản kế hoạch đầu
thì bảng này sẽ đọc thành *"8/20 hỏng"*, và **bốn tool quan trọng nhất sẽ không được đặt hàng**.
Cột thứ tư là thứ giữ lại kết luận đúng.

**2. Thứ thiếu nhất không phải con số — là CÁI TÊN.** Bốn câu (3, 8, 13, 15) hỏi *"cái nào"* và
cả bốn đều hỏng theo cùng một kiểu: gói số mang **giá trị** mà không mang **định danh**. Người
dùng hỏi *"ngân sách nào sắp hết"* thì muốn nghe **"Giáo dục"**, không phải **"90,0%"**. Đây là
đơn đặt hàng rõ nhất của cả bảng, và nó **rẻ**: các hàm domain đã trả về entity có tên sẵn, chỉ
là `NguonGoiSo` rút lấy con số rồi bỏ tên lại.

**3. Ba câu hỏng mà KHÔNG cần tool nào** (12, 14, 20): số cần trả lời **đã có trong gói** và mô
hình vẫn chọn nhầm. Câu 14 nguy hiểm nhất — hỏi tiền trong ví (13.004.000), trả lời *"Còn lại
12.994.000 đ"* (= thu − chi của kỳ); hai số **khác nghĩa mà chênh đúng 10.000 đ**, người dùng
không có cách nào nhận ra. Chữa bằng tool là chữa nhầm bệnh: thứ cần sửa là **nhãn trong prompt**
và cách chọn gói, không phải thêm nguồn dữ liệu.

**4. Hai câu đòi vòng lặp chứ không đòi tool** (16, 17): *"có đủ không"* và *"trả xong còn bao
nhiêu"* cần **so sánh** và **trừ** giữa hai gói. Đúng như bất biến đã khoá — **lớp AI không tính**
— nên chúng chỉ giải được ở vòng 3 bằng cách gọi hai tool rồi để **hàm domain** làm phép tính,
không phải để mô hình tự trừ.

#### Đơn đặt hàng tool — rút TỪ BẢNG, không từ mục 5.1

Xếp theo số câu mỗi tool cứu được:

| # | Tool | Cứu câu | Ghi chú |
|---|---|---|---|
| 1 | `danhSachNganSach()` → tên · đã chi · hạn mức · % · còn lại | 2, 3, 4, 5 | **đắt giá nhất**; mang cả tên lẫn tổng |
| 2 | `danhSachHoaDon()` → tên · hạn · số tiền · trạng thái | 12, 13, 16, 17 | gồm cả "hoá đơn nào quá hạn" |
| 3 | `danhSachVi()` → tên · số dư · cờ âm | 14, 15, 20 | chữa luôn cú nhầm 12.994.000 / 13.004.000 |
| 4 | `chiTieuTheoKy(tu, den)` → tổng thu · tổng chi · theo danh mục **có tên** | 7, 8, 9 | kỳ tuỳ ý + tên danh mục |
| 5 | `duBaoMucTieu(id)` | 11 | chỉ có nghĩa khi mục tiêu chậm kế hoạch |
| 6 | `goiYHanMuc(danhMuc)` | 5 | đã có `suggestAmount`, chỉ cần khai |

🛑 **Mục 5.1 đoán MƯỜI tool; bảng đo đặt hàng SÁU**, và **bốn cái đứng đầu đều là "trả về danh
sách có tên"** — một hình dạng mà mục 5.1 không hề dự đoán (nó nghĩ theo hướng "mỗi hàm domain
một tool"). Đây đúng là lý do lộ trình bắt đo trước khi dựng: ba tool của 5.1 (`traCuuKienThuc`
và hai tool phái sinh) **không câu nào trong 20 câu cần tới**.

#### Đo lại sau chặng 4a (2026-09-23) — 🛑 CỔNG CHƯA ĐẠT, nhóm A **1/4**

Lát 4a (spec `specs/2026-09-22-chang-4a-ten-doi-tuong-goi-so-design.md`) cho mỗi con số mang
**tên đối tượng**, rồi đo lại **bốn câu nhóm A** trên cùng máy, cùng tài khoản. Không đo lại trọn
20 câu vì cổng đã trượt ngay ở nhóm A.

| # | Câu hỏi | Trước 4a | Sau 4a |
|---|---|---|---|
| 3 | Ngân sách **nào** sắp hết | "Ngân sách căng nhất là 90,0%" | ⭐ **"…là Giáo dục với tỉ lệ 90,0%"** ✅ |
| 8 | Chi nhiều nhất vào **danh mục nào** | "Khoản lớn nhất là 800.000 đ" | **LỆCH** — vẫn trả lời về ngân sách |
| 13 | **Hoá đơn nào** quá hạn | trả lời về *ngân sách* | **LỆCH** — đúng chủ đề, nhưng lấy mục đếm ("là 1") |
| 15 | **Ví nào** đang âm | LỆCH + thẻ sai nhãn | **MẪU** — bị chặn, an toàn |

**Điều kiện 3 của cổng (SAI = 0) đạt** sau khi đóng một hồi quy; điều kiện 1 (≥ 3/4) **trượt**.

⭐ **Bài học trung tâm: danh sách có tên là CẦN nhưng CHƯA ĐỦ.** Một lượt log gói số thật chứng
minh cả bốn gói mang tên **đúng như thiết kế**:

```
phan_tich > Cho vay / Chi = 800.000 đ          ngan_sach > Giáo dục / Tỉ lệ = 90,0%
hoa_don   > Kiem / Phải trả = 45.000 đ         vi        > test / Số dư = -100.000 đ
```

Nhưng gói nói `Quá hạn: 1` ở một dòng và `Kiem · Phải trả: 45.000 đ` ở dòng khác — **không chỗ
nào nói Kiem LÀ cái quá hạn**. Mô hình phải **nối hai mục rời bằng suy luận**, và E2B không làm
được: nó trả lời bằng con số tổng. Ví y hệt (`Ví đang âm: 1` vs `test · Số dư: -100.000 đ`).

Gắn trạng thái vào nhãn (`Đã quá hạn`, `Đang âm`) **không cứu được** câu 13 — nhưng nó lộ ra một
hồi quy đáng giá hơn, xem dưới.

🛑 **Hệ quả cho chặng 4:** ba câu còn hỏng **không** chữa được bằng cách làm gói số giàu thêm. Mô
hình đã chứng minh là không nối được hai mục rời, nên thứ cần là **tool trả về một hàng đầy đủ**
(tên + số + trạng thái trong cùng một kết quả), tức đúng hình dạng mà bảng 5.6 đặt hàng. Đừng
tinh chỉnh gói số thêm nữa.

#### Hồi quy mà lát 4a suýt để lại — và luật siết ra từ nó

Nhãn `Đang âm` làm câu **"Số ví đang âm: −100.000 đ"** *lọt qua* `kiemNhan`, trong khi bản **trước
chặng 4a vẫn chặn được**. Câu ấy **sai nghĩa** — số ví là 1, không phải −100.000 đ — nhưng nhãn có
từ khoá "đang"/"âm" và câu chứa đủ cả hai.

Gốc: lát 4a bản đầu cho một số hợp lệ khi câu khớp **nhãn HOẶC tên**. Gói nay mang nhiều mục cùng
nhãn (bốn ngân sách cùng `Tỉ lệ`, các ví cùng `Số dư`), nên một câu chỉ nhắc nhãn **không nói được
nó đang nói về cái nào**.

**Luật sau khi siết:** mục **có tên** thì đòi câu nêu **tên**; mục không tên giữ luật cũ. Câu 3 vẫn
lọt vì 90,0% cũng là `Ngân sách căng nhất` của gói trang chủ — một mục **không tên** — nên vế nhãn
vẫn dùng được. Đo lại: câu sai bị chặn trở lại.

#### Hai lỗi thật lượt đo bắt được — ngoài phạm vi chặng 3

- ✅ **Thẻ số liệu gán nhãn của một gói khác khi hai nhãn cùng giá trị** — **đã sửa ở chặng 4a**
  (Task 3, `20bbc05`). Câu 15: câu trả lời là *"Ví đang âm: 1"* nhưng thẻ bên dưới hiện **"Quá hạn
  1"** — nhãn của *hoá đơn quá hạn*. Cả hai cùng bằng **1**, và `theCuaCau` khớp theo **giá trị**
  nên lấy nhầm nhãn. Cùng họ bẫy **4.19** (thẻ so chuỗi con) nhưng nguyên nhân khác: **trùng giá
  trị**, không phải chuỗi con. Thẻ nay ưu tiên mục mà **câu nhắc tới** (cùng phép âm tiết với
  `kiemNhan`) — bẫy **4.27** `AI_EDGE_FEATURE.md`. *(Dòng này từng ghi "Chưa sửa" — đúng lúc đo,
  sai từ tối cùng ngày.)*
- ⚠️ **Tổng thu lệch 10.000 đ giữa Trang chủ và gói số.** Trang chủ hiện *Thu nhập 15.145.000*,
  gói phân tích trả *Tổng thu 15.135.000* (đo cùng lúc, cùng tài khoản). Chênh ấy lan sang mọi
  câu trả lời dùng tổng thu. Chưa rõ bên nào đúng — **đừng sửa bên nào trước khi chốt con số nào
  mới đúng**, cùng lối đã xử lý chỗ lệch "3 hoá đơn / Cần thanh toán (4)".

#### Đo lại sau chặng 4b (2026-09-23 chiều) — ✅ CỔNG C ĐẠT, nhóm A **4/4** Realme · **3/4** OnePlus

Lát 4b (spec `specs/2026-09-23-chang-4b-tool-calling-vong-lap-design.md`) làm đúng thứ 4a chỉ ra:
**tool trả về một hàng đầy đủ**. Bốn tool đọc, prompt không mang số, dữ liệu vào qua tool. Đo trên
APK release, tài khoản 10, cả hai máy. Cột trước 4a và sau 4a là Realme, cùng máy với cột đầu của
cột sau 4b.

| # | Câu hỏi | Trước 4a | Sau 4a | Sau 4b — Realme (CPU) | Sau 4b — OnePlus (GPU) |
|---|---|---|---|---|---|
| 3 | Ngân sách **nào** sắp hết | "…căng nhất là 90,0%" | ✅ "…là Giáo dục với tỉ lệ 90,0%" | ✅ "Ngân sách Giáo dục còn 8 ngày." | **LỆCH** — gộp cả bốn ngân sách vào "sắp hết" |
| 8 | Chi nhiều nhất vào **danh mục nào** | "Khoản lớn nhất là 800.000 đ" | LỆCH | ✅ liệt kê có tên, giảm dần (Cho vay 800.000 đ đầu) | ✅ "…có chi phí **cao nhất** là: Cho vay (800.000 đ), …" |
| 13 | **Hoá đơn nào** quá hạn | trả lời về ngân sách | LỆCH | ✅ "Hoa đơn **Kiem** đã quá hạn với số tiền là 45.000 đ…" | ✅ cùng |
| 15 | **Ví nào** đang âm | LỆCH + thẻ sai | MẪU | ✅ "Ví **test** đang âm với số dư là -100.000 đ." | ✅ cùng |
| 2 | Còn bao nhiêu tiền ngân sách | — | — | ✅ 1.340.000 đ | ✅ |
| 9 | Tháng trước chi bao nhiêu | — | — | ✅ 0 đ (đúng — không có dữ liệu tháng 8) | ✅ |
| ĐC1 | Lãi suất tiết kiệm | — | — | LỆCH, không bịa (tổng chi/thu tháng này) | L3 sau 3 lời gọi, mẫu câu lặp — lỗi thật, đã sửa |
| ĐC2 | Tháng này chi bao nhiêu (câu 6) | ✅ | ✅ | ✅ không tụt | ✅ |

⭐ **Bốn câu *"cái nào"* hỏng suốt chặng 3 và 4a nay trả lời bằng tên.** Mô hình gọi **đúng tool và
đúng tham số ở 8/8 câu** trên mỗi máy, lượt gọi tool luôn phát **0 ký tự** chữ, và câu trả lời chép
tên + số từ đúng một hàng — không còn phải nối hai mục rời. Số câu **bịa số: 0**; lần sập: **0**.
Tổng một câu 10–15 s trên Realme CPU, 4,5–8,6 s trên OnePlus GPU.

⚠️ **Ba lỗi thật, cả ba chỉ OnePlus lộ ra, đều đã sửa cùng ngày** (bẫy 4.34–4.36 `AI_EDGE_FEATURE.md`):
thẻ số liệu gán nhầm đối tượng khi hai hàng cùng giá trị ở hai câu khác nhau; mẫu câu L3 lặp hàng
và mất nhãn kỳ sau ba lời gọi; câu trả lời dạng markdown lộ dấu `*`. ⚠️ Và một điều **không phải
lỗi mà là giới hạn**: ĐC1 vẫn không bao giờ nói *"không có dữ liệu lãi suất"* — mô hình luôn chọn
tool gần nghĩa nhất (Realme) hoặc thử nhiều kỳ cho tới trần (OnePlus). Chốt giữ nó khỏi bịa là
bộ kiểm số và thang lùi, không phải mô hình. Bảng đầy đủ: mục **9.14** `AI_EDGE_FEATURE.md`.

#### Một bẫy đo, sẽ tái phát

⚠️ **`adb shell input text` làm hỏng chữ hoa giữa từ**: gõ `MuaXe` ra **`Mũae`** trên màn hình
(đã chụp lại). Câu hỏi chứa tên riêng phải **chụp màn kiểm lại chữ đã vào** trước khi tin kết quả;
lượt này câu 10 vẫn hợp lệ chỉ vì gói mục tiêu chỉ mang một mục tiêu nên tên không ảnh hưởng.

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
| **2** | Agent | ✅ **đang chạy** từ 2026-09-23 (lát 4b xong 9/9 task, **cổng C đạt** trên hai máy) — bốn tool **đọc**, vòng lặp trần 3 lời gọi, bậc 1 làm nhánh lùi | `grep -E 'Tool\(\|ToolChoice\|embedding\|cosine'` trong `lib/` → **3 dòng, 1 tệp** (`slm_runtime.dart`: `Tool(` · `ToolChoice.auto`; embedding/cosine vẫn **0** — RAG client cố ý bỏ, mục 5.5); vòng lặp ở `ai_edge/data/vong_lap_cong_cu.dart`; đo máy thật mục **9.14** `AI_EDGE_FEATURE.md`. *(Ô này ghi "⬜ chưa có kế hoạch … → 0" cho tới 2026-09-23.)* |

✅ **Hết từ 2026-09-22.** *(Câu cũ ở đây: "Gói `flutter_gemma` **có trong pub cache** nhưng đến từ
**app spike P1** ở `D:/flowmoney-spike` … **không một dòng nào của phép đo ấy nằm trong repo**.")*
P3 đã cắm mô hình vào chính app: `pubspec.yaml` khai `flutter_gemma: 1.8.3` và
`flutter_gemma_litertlm: ^1.7.0` *(nâng lên 1.9.0 / 1.8.0 ngày 2026-09-23 — bản cũ sập native ở
mọi phiên có tool, mục 9.13 `AI_EDGE_FEATURE.md`)*, `ai_edge` + `ai_chat` có **44** tệp test / **424** ca
(đếm 2026-09-23 sau lát 4b; mốc *"`ai_edge` 33 tệp / 294 ca"* từng ghi ở đây là của 2026-09-22), và mô
hình đã chạy thật **trong app** trên **hai** máy — OnePlus 13R (GPU) và Realme RMX2205 (CPU, sau
khi canary bắt được cú sập native trên Mali).

### 11.1 Câu trung thực nếu được hỏi "đã làm tới đâu"

*(Cập nhật 2026-09-23 sau cổng C — viết lại lần hai; bản 2026-09-22 nói phần agent "**chưa có**",
đúng tới trưa 23/09; bản trước nữa nói mô hình "**chưa cắm vào app**".)*

> Hiện có một **hệ luật chạy on-device** (tầng số + luật + guardrail `kiemSo`), phủ
> 6 màn, offline, tức thì. Phần **mô hình** (Gemma 4 E2B, 2,41 GB) **đã cắm vào app và chạy
> thật trên máy thật** — trả lời hoàn toàn trong máy, đo được **0 request đi ra** khi cắt
> mạng, chữ hiện dần theo từng câu, và mọi con số trong câu trả lời đều bị ba lớp chắn
> (`kiemSo`, `kiemNhan`, `kiemGiong`) đối chiếu với dữ liệu trước khi hiện. Màn Trợ lý AI là
> một **agent tối thiểu**: mô hình tự chọn một trong **bốn tool chỉ đọc** (ngân sách · hoá đơn ·
> ví · chi tiêu theo kỳ), app chạy hàm domain có sẵn và trả về từng hàng có tên, mô hình viết câu
> từ đúng những hàng ấy — trần 3 lời gọi, không tool nào ghi dữ liệu. Đo trên hai máy thật: bốn
> câu hỏi *"cái nào"* từng hỏng nay trả lời **bằng tên** (Realme 4/4, OnePlus 3/4), 0 câu bịa số.

Nay **nói được *"là AI Agent"*** — đúng mốc cổng C của lộ trình — nhưng nói kèm hai giới hạn thật:
tool **chỉ đọc** (chiều ghi vẫn qua tay người dùng, bất biến ④), và hỏi thứ không tool nào có thì
mô hình **không nói "không có"** mà chọn tool gần nghĩa nhất (mục 5.6, *"Đo lại sau chặng 4b"*).
*"Edge AI"* đúng từ khi mô hình chạy on-device; *"RAG"* thì **cố ý không làm ở client** (mục
**5.5** đo được là không khả thi) — nó thuộc backend, cho kiến thức chung, không cho số của
người dùng.

---

## 12. Lộ trình — ba bước, theo đúng thứ tự phụ thuộc

1. ✅ **P3 XONG 2026-09-22** (trọn 10 task) — mô hình đã cắm và chạy trong app thật trên hai
   máy; ba lớp chắn `kiemSo` / `kiemNhan` / `kiemGiong` bắt được câu sai trên máy thật.
   **Cổng A qua** tối cùng ngày.
2. ✅ **Đo xong 2026-09-22 (tối muộn)** — *"bậc 1 hỏng ở đâu"*, bảng 20 hàng ở mục **5.6**, đo
   trên Realme RMX2205 với tài khoản thật. Kết quả: **✅ 5 · rơi mẫu 3 · sai 0 · lệch câu hỏi
   12**. Đơn đặt hàng là **sáu** tool, bốn cái đứng đầu đều có hình dạng *"trả về danh sách có
   **tên**"* — thứ mười tool ứng viên ở mục 5.1 không hề dự đoán. **Cổng B qua.**
3. 🛑 **Lát 4a — phần "sửa prompt và nhãn" — XONG MÃ 2026-09-23, cổng chưa đạt** (nhóm A **1/4**).
   Nó chữa được câu 3 và sửa hai lỗi đang chạy, nhưng chứng minh **danh sách có tên là CẦN nhưng
   CHƯA ĐỦ**: mô hình không nối được hai mục rời. Xem "Đo lại sau chặng 4a" ở mục **5.6**.
4. ✅ **Lát 4b — tool layer + vòng lặp: XONG 9/9 task, CỔNG C ĐẠT trên hai máy (2026-09-23).**
   Màn Trợ lý AI đi bậc tool từ `863c4cd`; đo tám câu trên Realme và OnePlus, nhóm A 4/4 · 3/4
   trả lời bằng tên, 0 câu bịa số, 0 lần sập — mục 5.6 *"Đo lại sau chặng 4b"* và mục **9.14**
   `AI_EDGE_FEATURE.md`. Lượt đo bắt ba lỗi thật, sửa cùng ngày (bẫy **4.34–4.36**). Trước đó:
   với `flutter_gemma_litertlm` 1.7.0 engine **sập native** ở mọi phiên có tool trên **cả hai
   máy**; nâng lên `flutter_gemma` 1.9.0 + `flutter_gemma_litertlm` 1.8.0 (người dùng duyệt) thì
   hết (mục **9.13**, bẫy **4.33**). Spec `docs/superpowers/specs/2026-09-23-chang-4b-tool-calling-vong-lap-design.md`. Người
   dùng chốt **bốn** tool (không phải sáu) cho lát này — `danh_sach_ngan_sach` · `danh_sach_hoa_don`
   · `danh_sach_vi` · `chi_tieu_theo_ky`; `duBaoMucTieu`, `goiYHanMuc`, nhóm D để lát sau. Trần **3
   lời gọi**, không tool ghi, hướng **A** (tool THAY gói số trong prompt).
   ⚠️ Hình dạng đã đổi sau 4a: tool trả **một hàng đầy đủ** (tên + số + trạng thái trong cùng
   kết quả) — `HangSoLieu`, tích luỹ vào `GoiSoTraCuu extends GoiSo`. Bất biến ② *"mọi tool trả
   `List<SoLieu>`"* (mục 5.2, 6) vẫn đúng: `SoLieu` đi **theo hàng** chứ không rời, và ba lớp chắn
   nhận `[goiTraCuu]` y như sáu gói cũ.

*(Bản cũ của bước 3 ghi ba câu 12, 14, 20 "không cần tool nào, sửa ở prompt và nhãn, nên làm
trước khi dựng tool". Vế "làm trước" đã làm — đó là lát 4a. Vế "không cần tool nào" thì **chỉ
đúng một phần**: sửa nhãn cứu được câu 3, còn 8, 13, 15 vẫn cần tool.)*

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

✅ **Đề xuất này đã làm TRỌN VẸN trong ngày 2026-09-22** — P3 trọn 10 task và cổng A qua (nửa
đầu), rồi phép đo 20 câu và cổng B qua (nửa sau, bảng ở mục **5.6**). **Câu hỏi của mục 13 nay
ĐÃ TRẢ LỜI ĐƯỢC bằng số đo, không còn phải cân nhắc**: bậc 1 để lọt **12/20** câu *"trả lời được
nhưng lệch câu hỏi"* — quá nửa — nên đi tiếp bậc 2 là **có cơ sở**, và bảng đo còn nói luôn cần
**sáu** tool nào. ⚠️ Nhưng bảng cũng nói ba câu trong số ấy **không cần tool** (mô hình chọn nhầm
số đã có sẵn) — nên bậc 2 **không** phải là toàn bộ câu trả lời, và phần rẻ nhất là sửa
prompt/nhãn trước.

⚠️ Dữ kiện mà lượt đo cổng A bổ sung cho mục này — *"mô hình không nói không có dữ liệu, nó chọn
số liên quan thật gần nghĩa nhất"* — **đúng một nửa**: chặng 3 đo được **hai** câu mô hình nói
thẳng là không có (câu 4 và 11), nên nó là **không đáng tin cậy** chứ không phải **không bao
giờ**. Phần còn lại của câu ấy thì đúng và là lý do bảng 5.6 có **bốn** cột: loại câu này
**không** hiện ra dưới dạng câu mẫu hay câu sai, nên đếm hai ô ấy là bỏ sót quá nửa kết quả.

🛑 Đúng bài học lát *"cửa sổ nhìn lại"* vừa trả giá ngày 2026-09-21: `suggestAmount`
đúng từng dòng suốt từ 2026-09-06 nhưng đầu vào là một cửa sổ mà dữ liệu thật không
lấp đầy, nên nó **chưa từng hiện một con số nào**. Bộ test mù vì nó dựng sẵn dữ liệu.
Thứ bắt được là một phép đo trên **CSDL thật**. Quyết định về vòng 3 cũng phải đi
đường ấy.

✅ **Bậc 2 đã làm (lát 4b, 2026-09-23) — đối chiếu bảng dự đoán trên với số đo cổng C:** độ trễ
đoán *"~4,7–7 s"* — đo được **4,5–8,6 s** trên OnePlus GPU, **10–15 s** trên Realme CPU (sau khi
nạp); rủi ro đoán *"E2B chọn sai tool là chuyện thường"* — đo được mô hình chọn **đúng tool và
đúng tham số ở 8/8 câu trên mỗi máy**, lỗi thật lại nằm ở phía **app** (thẻ, mẫu câu, markdown —
bẫy 4.34–4.36 `AI_EDGE_FEATURE.md`); công đoán *"+3 task"* — thực tế **9 task**, trong đó một nửa
là tầng dữ liệu (bốn hàm dựng hàng + bốn adapter).

---

## 14. Đọc thêm

| Cần biết | Đọc |
|---|---|
| Tính năng, bẫy, bảng đo P1 | `docs/AI_EDGE_FEATURE.md` — mục **8** (đo), **10** (mảng này thực chất là gì), **11** (bản đồ năng lực) |
| Kế hoạch cắm mô hình | `docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md` |
| Đặc tả gốc (backend quản) | `docs/AI/AI_Edge-SLM.md/Client-app.md` · `docs/AI/Standard_RAG.md` |
| Chỗ sai của đặc tả gốc | Vòng **hai** (đang mở): `docs/superpowers/backend/CAN-LAM/AI_EDGE_SLM_SOAT_SAU_B147FEE.md`. Vòng **một** đã đóng ở `b147fee` (2026-09-22): `DA-XONG/AI_EDGE_SLM_SUA_TAI_LIEU.md` và `DA-XONG/EDGE_AI_THUAT_NGU_VA_HAI_MAU_THUAN.md` |
| Việc còn mở của cả dự án | `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md` |
