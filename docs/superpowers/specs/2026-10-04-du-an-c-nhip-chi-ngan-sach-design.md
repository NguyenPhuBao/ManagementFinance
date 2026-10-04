# Dự án C, việc thứ hai — dự phóng và nhịp chi ngân sách theo nhịp riêng của từng người — thiết kế

**Ngày:** 2026-10-04. **Trạng thái:** thiết kế người dùng duyệt trong chat (bảy lượt AskUserQuestion: chọn việc, phạm
vi, cách báo sớm, nguồn học, cách dự phóng, ba phần thiết kế); **bản viết chờ người dùng đọc lại** — chưa có kế hoạch,
chưa có mã.

Dự án C (mục 10.3 `docs/AI_EDGE_FEATURE.md`): *app học trên máy của từng người*. Việc đầu — gợi ý danh mục theo số tiền
— xong 2026-10-02 (spec `2026-10-02-du-an-c-goi-y-danh-muc-theo-so-tien-design.md`). Đây là việc thứ hai, người dùng
chọn trong ba việc còn lại; hai việc kia ở mục 9.

Nguồn ý tưởng: mục **11.5 (3)** `AI_EDGE_FEATURE.md` (*ngưỡng cảnh báo 70/90 % cứng cho mọi người — 70 % vào ngày 20 là
bình thường, vào ngày 5 là báo động*) ghép với việc #3 của mục **11.4** (*học nhịp chi theo ngày trong tháng*). Lượt
khảo sát lúc brainstorm **đổi hình dạng** của việc này — mục 1.

## 1. Vì sao

### 1.1 Ngân sách hôm nay cảnh báo ở ba chỗ, mỗi chỗ một luật

| Chỗ người dùng thấy | Luật (mã, 2026-10-04) |
|---|---|
| **Màu thẻ** ngân sách — trang Ngân sách, thẻ Trang chủ, trang chi tiết | cứng 70 % vàng / 90 % đỏ (`budget_visuals.dart`, người dùng chốt 2026-09-04) |
| **Thông báo** *"Sắp vượt ngân sách"* | `isNearLimit`: ngưỡng tiền còn lại hoặc phần trăm người dùng tự đặt ở form, mặc định 90 % |
| **Ô "NHỊP CHI"** trang chi tiết — chip *Nhanh hơn dự kiến · Đúng nhịp · Chậm hơn dự kiến* + dòng *"Theo thời gian đã trôi: X"* | `budgetPaceOf`: so phần đã chi với **phần thời gian đã trôi**, tức giả định **chi đều theo ngày** |
| ⭐ *(lộ ra lúc brainstorm)* **Thẻ *Đề xuất cân đối*** trang Ngân sách + **thông báo** `budgetRebalance` (*"X dự kiến vượt hạn mức…"*) + tool ngân sách `chon=can_doi` của Trợ lý AI | `duPhongCua` (`ai_edge/domain/tai_phan_bo.dart`): dự phóng cuối kỳ = đã chi × số ngày của kỳ ÷ số ngày đã qua (từ ngày thứ 5); trước đó đã chi + mức tháng × phần kỳ còn lại |

### 1.2 ⚠️ Chỗ hỏng đang chạy hôm nay — báo động oan và đề xuất cắt ngân sách khác

Giả định *chi đều* sai với mọi danh mục có khoản lớn cố định ở một ngày trong kỳ. Ví dụ **Nhà ở** hạn mức 5.000.000/tháng,
tiền nhà 4.000.000 trả ngày 1, điện nước ~600.000 rải rác. Trưa 06/11, đã chi 4.100.000:

| | Hôm nay | Theo nhịp riêng (thiết kế này) |
|---|---|---|
| Dự phóng cuối kỳ (`duPhongCua`) | 4.100.000 × 30 / 5 = **24.600.000** → thâm hụt 19,6 triệu → **kế hoạch cân đối + thông báo**, đề xuất **cắt ngân sách khác** | 4.100.000 + ~500.000 mọi khi còn chi = **~4.600.000** → không thâm hụt, không kế hoạch |
| Chip NHỊP CHI | phần đã chi 82 % so với thời gian 18 % → **"Nhanh hơn dự kiến"** | mọi khi tới lúc này đã chi ~89 % của kỳ → 82 % là **"Chậm hơn dự kiến"** |
| *"Theo … : X"* | Theo thời gian đã trôi: ~917.000 | Theo nhịp thường lệ: ~4.460.000 |

⚠️ **Đính chính trong chính lượt brainstorm:** câu đầu tôi viết cho người dùng nói ca *Ăn uống ngày 5 đã chi 70 %* "chưa
có thông báo vì chờ tới 90 %". Sai — thông báo *Đề xuất cân đối* (P2, 2026-09-20) đã là một **thông báo báo sớm**: nó
bắn khi dự phóng vượt hạn mức. Việc này vì thế **không** thêm thông báo mới mà sửa phép dự phóng của nó (quyết định 3).

## 2. Quyết định người dùng chốt

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Làm việc nào trong ba việc còn lại của dự án C | **Ngưỡng / nhịp ngân sách** trước; thứ tự khối Phân tích và tần suất thông báo làm sau |
| 2 | Nhịp học được đổi chỗ nào | **Nhịp chi + báo sớm.** Màu thẻ **giữ 70/90** (màu = đã dùng bao nhiêu); thông báo *Sắp vượt* giữ nguyên |
| 3 | "Báo sớm" làm cách nào | **Sửa dự phóng sẵn có** — không thêm loại thông báo; thẻ + thông báo *Đề xuất cân đối* và ô NHỊP CHI cùng đọc một phép dự phóng |
| 4 | Học từ kỳ nào | **Cả kỳ trước ngày tạo ngân sách** — giao dịch cũ của cùng danh mục, cắt theo cùng chu kỳ; bỏ kỳ bắt đầu trước giao dịch đầu tiên của tài khoản |
| 5 | Dự phóng tính cách nào | **Đã chi + phần mọi khi còn chi** từ thời điểm này tới cuối kỳ (không nhân tốc độ kỳ này) |
| 6 | Phạm vi phần 1 | Gồm cả **Trợ lý AI** (tool ngân sách nói *nhanh / chậm hơn dự kiến* theo cùng phép) |
| 7 | Kỳ không chi | **Không tính** — cả hai phép (mục 4.2) chỉ lấy trung vị trên kỳ **có chi** |

## 3. Hành vi

### 3.1 Khi nào app "đã biết nhịp" của một ngân sách

- Ngân sách **có chu kỳ** (`timeRecurrence` là Tuần / Tháng / Quý / Năm) và **đang chạy**. Ngân sách *Ngày cụ thể* chỉ có
  một kỳ — không có gì để học, luôn đi đường hôm nay.
- App xét **tối đa 6 kỳ đã đóng gần nhất** (`kSoKyHocToiDa = 6`), cắt đúng như kỳ của ngân sách và lùi cả về trước ngày tạo
  (mục 4.1). Kỳ nào **bắt đầu trước giao dịch đầu tiên** của tài khoản bị bỏ — kỳ ấy thiếu dữ liệu, không phải "không chi".
- Trong các kỳ ấy, kỳ **có ít nhất một khoản chi** là kỳ học được. Đủ **3** kỳ như thế (`kSoKyHocToiThieu = 3`) thì đã biết
  nhịp; thiếu thì **im hẳn** — mọi con số y như hôm nay, đến từng đồng (luật chung mục 11.4: *dưới ngưỡng mẫu thì im*).

### 3.2 Đã biết nhịp — ba chỗ đổi

1. **Dự phóng cuối kỳ** (`duPhongCua`) = đã chi + `conChiMoiKhi(x)`. Thẻ *Đề xuất cân đối*, thông báo `budgetRebalance`
   và tool `can_doi` đều đi qua `keHoachTaiPhanBoTu` nên **tự theo** — kể cả dư địa của ngân sách **nguồn bù**
   (`amount − duPhong`) cũng tính bằng phép mới.
2. **Ô NHỊP CHI** trang chi tiết: *đáng lẽ đã chi* = hạn mức × `phanDaChiMoiKhi(x)`; chip so phần đã chi với số ấy (biên
   ±5 điểm như hôm nay); dòng phụ đổi chữ thành **"Theo nhịp thường lệ: X"**.
3. **Tool `danh_sach_ngan_sach`** của Trợ lý AI: trạng thái *tiêu nhanh · đúng nhịp · tiêu chậm* của mỗi hàng
   (`chuNhipNganSach`) theo cùng phép với chip.

### 3.3 Ví dụ dùng làm ca test chính (tháng 30 ngày, trưa)

| Ngân sách | Kỳ trước (mọi khi) | Hôm nay | Dự phóng mới | Kế hoạch cân đối |
|---|---|---|---|---|
| **Nhà ở** 5.000.000 | 4.000.000 ngày 1 + ~600.000 rải rác | 06/11, đã chi 4.100.000 | ~4.600.000 | **không** (hôm nay: có, thâm hụt 19,6 triệu) |
| **Ăn uống** 3.000.000 | ~2.800.000 chi đều | 05/11, đã chi 2.100.000 | 2.100.000 + ~2.380.000 ≈ 4.480.000 | **có**, thâm hụt ~1,48 triệu (hôm nay cũng có) |
| **Mua sắm** 2.000.000 | ~1.200.000 rải rác đều | 06/11, một món 1.500.000 | 1.500.000 + ~980.000 ≈ 2.480.000 | **có**, *"dự kiến vượt ~480.000"* (hôm nay: 9.000.000, thâm hụt 7 triệu; lối "giữ tốc độ" bị loại ở quyết định 5: 1.500.000 ÷ 0,183 ≈ 8,2 triệu) |

## 4. Phép học

### 4.1 Kỳ — `kyDaDongTruoc` (`budget/domain/budget_history.dart`, cạnh `recentPeriods`)

Một chỗ cắt kỳ, cạnh phép cắt kỳ sẵn có, để hai phép không lệch nhau một ngày (lý do đứng đầu `budget_history.dart`).

- **Kỳ từ ngày tạo trở đi:** đúng `recentPeriods` (cùng mốc neo `periodAnchor`, cùng `advancePeriodFrom`, cùng cắt ở
  ngày hết hạn).
- **Kỳ trước ngày tạo:** kỳ thứ −k = `[advancePeriodFrom(anchor: startDate, steps: −k), advancePeriodFrom(anchor:
  startDate, steps: −k + 1))`. Luôn tính **từ mốc gốc `startDate`** — lùi dồn từ kết quả đã kẹp làm mốc ngày 31 tụt về 28
  (bẫy ghi ở `budget_period.dart`). Kỳ −1 kết thúc đúng ở `startDate`, nên không hở không chồng với kỳ đầu.
  `advancePeriodFrom` đã nhận `steps` âm (`DateTime` tự quy tháng âm về năm trước; tuần là `add(Duration)` âm).
- **Chỉ kỳ đã đóng:** `to ≤ from` của kỳ hiện tại. Kỳ hiện tại không bao giờ là mẫu.
- **Bỏ kỳ bắt đầu trước giao dịch đầu tiên** của tài khoản (`mocGiaoDichDauTien`, đã bỏ hàng xoá mềm).
- Lấy tối đa **6** kỳ gần nhất thoả các điều trên, **cũ trước mới sau**.

### 4.2 Hai câu hỏi — `NhipChi` (`budget/domain/nhip_chi.dart`, mới)

Mỗi kỳ học được *p* có tổng chi `T_p > 0` và đường cộng dồn `C_p(x)` = tổng các khoản có vị trí trong kỳ `≤ x`, với vị
trí của một khoản = `(ngày − from) / (to − from)` kẹp `[0, 1]` — **cùng phép đo thời gian** với `elapsedFraction` của
`budgetPaceOf`, nên tháng 28 ngày và tháng 31 ngày so được với nhau.

- `phanDaChiMoiKhi(x)` = **trung vị** trên các kỳ học được của `C_p(x) / T_p` — *mọi khi tới thời điểm này đã chi bao
  nhiêu phần của cả kỳ*. Dùng cho chip.
- `conChiMoiKhi(x)` = **trung vị** trên các kỳ học được của `T_p − C_p(x)` — *mọi khi từ thời điểm này tới cuối kỳ còn chi
  bao nhiêu tiền*. Dùng cho dự phóng.
- `soKy` — số kỳ học được (để công cụ đo và chú thích in ra).

Trung vị chứ không trung bình: một tháng bất thường (mua laptop) không kéo lệch nhịp. Số kỳ chẵn → trung bình hai giá trị
giữa.

`hocNhipChi(List<KyChi>) → NhipChi?` trả `null` khi số kỳ có `T_p > 0` dưới `kSoKyHocToiThieu`. **`null` có một nghĩa:
chưa biết** — mọi chỗ dùng phải rơi về phép hôm nay, không `?? NhipChi.deu`.

### 4.3 Chỗ dùng nhận `NhipChi?`, không tự tính

| Hàm | Khi `nhip != null` | Khi `nhip == null` |
|---|---|---|
| `budgetPaceOf(b, now, {NhipChi? nhip})` | `expectedSpent = amount × phanDaChiMoiKhi(x)`; status so `spent/amount` với `phanDaChiMoiKhi(x)` ±5 điểm; `theoNhipRieng = true` | y như hôm nay, `theoNhipRieng = false` |
| `duPhongCua(v, …, {NhipChi? nhip})` | `spent + conChiMoiKhi(x)` | y như hôm nay (nhân tuyến tính từ ngày 5, cộng mức tháng trước đó) |

`daysLeft`, `suggestedPerDay` của `BudgetPace` **không** đổi — dòng *"Nên chi X/ngày · còn N ngày"* vẫn chia đều phần còn
lại, vì đó là lời khuyên chứ không phải dự đoán.

## 5. Vị trí mã

| Tệp | Việc |
|---|---|
| `budget/domain/budget_history.dart` | thêm `kyDaDongTruoc` |
| `budget/domain/nhip_chi.dart` *(mới)* | `KyChi`, `NhipChi`, `hocNhipChi`, `kSoKyHocToiThieu`, `kSoKyHocToiDa` |
| `budget/domain/budget_pace.dart` | tham số `nhip`, trường `theoNhipRieng` |
| `budget/data/repositories/budget_repository(_impl).dart` | `nhipChiTheoNganSach(idaccount, List<BudgetEntity>, {now})` → `Map<String, NhipChi?>` (khoá `budget.id`). Đọc **một lần** khoảng `[from kỳ cũ nhất, now)` qua `getExpenses` — **cùng định nghĩa "đã chi"** với `spent` (chỉ `chi`, đúng danh mục, `categoryId == null` gom mọi danh mục, biên `to` mở) — rồi chia theo ngân sách và theo kỳ. Mọi lớp giả `implements BudgetRepository` trong test phải thêm hàm |
| `budget/data/tai_phan_bo_nguon.dart` | `DuLieuTaiPhanBo.nhipTheoNganSach`; `nap` điền qua repository; `keHoachTaiPhanBoTu` chuyền vào `taiPhanBoCua` |
| `ai_edge/domain/tai_phan_bo.dart` | `duPhongCua(nhip:)`; `taiPhanBoCua(nhipTheoNganSach:)` |
| `budget/presentation/bloc/budget_detail_cubit.dart` | nạp nhịp của ngân sách đang xem, truyền vào `budgetPaceOf` |
| `budget/presentation/pages/budget_detail_view.dart` | `_PaceCard`: *"Theo nhịp thường lệ: X"* khi `pace.theoNhipRieng` |
| `ai_edge/domain/hang_ngan_sach.dart` + `ai_edge/data/cong_cu_ngan_sach.dart` | `hangNganSach(nhipTheoNganSach:)`; tool nạp qua `BudgetRepository` (không qua `TaiPhanBoNguon.nap` — hàm ấy còn tính thu nhập và `suggestAmount`, thừa cho tool) |
| `budget/presentation/widgets/budget_visuals.dart` | sửa chú thích lỗi thời dòng 9 *"ứng dụng không gửi thông báo đẩy"* (sai từ khi có hệ thông báo) |
| `test/tool/do_nhip_chi_test.dart` *(mới, skip)* | công cụ đo trên CSDL thật — mục 7.3 |

Lớp `ai_edge/` **không** đọc bảng giao dịch (test quét 14): nó chỉ nhận `NhipChi` đã dựng. `NhipChi` nằm ở
`budget/domain/` vì nó là kiến thức về ngân sách, không phải về mô hình.

## 6. Thứ không đổi

- Màu thẻ 70/90 % (`budget_visuals.dart`) — người dùng chốt 2026-09-04, giữ ở quyết định 2.
- Thông báo `budgetNearLimit` / `budgetOverspent`, ngưỡng người dùng tự đặt, `defaultWarningRatio = 0.9`.
- Khoá chống trùng `budgetRebalance:<tuần ISO>` — vẫn tối đa một thông báo cân đối mỗi tuần.
- Dòng *"Nên chi X/ngày · còn N ngày"* (thẻ danh sách, Trang chủ, trang chi tiết); khối Dự báo 30 ngày trang Phân tích
  (`du_bao_dong_tien.dart` chỉ đọc `remaining` / `daysLeft`).
- Khối Nhận xét trang Ngân sách (`GoiSoNganSach` không đọc `status`; phần kế hoạch của nó tự theo mục 3.2.1).
- Schema (vẫn v27), payload đồng bộ, `pubspec`.

## 7. Kiểm thử và đo

### 7.1 Hàm thuần (TDD, ca đỏ trước)

- `kyDaDongTruoc`: kỳ tháng bắt đầu ngày 31 lùi qua tháng 2 năm thường **và** năm nhuận (memory *test lịch tháng ngắn và năm
  nhuận*) — mốc không trôi về 28; kỳ tuần, quý; kỳ trước giao dịch đầu tiên bị bỏ; *Ngày cụ thể* trả rỗng; tối đa 6; kỳ
  hiện tại không tính; kỳ −1 kết thúc đúng `startDate`; ngân sách có `nextTimeRecurrence` khác chuẩn (hàng kéo về).
- `hocNhipChi`: < 3 kỳ có chi → `null`; kỳ `T_p = 0` không tính vào cả hai phép (quyết định 7); trung vị số kỳ lẻ / chẵn;
  một tháng bất thường không kéo lệch.
- `budgetPaceOf` / `duPhongCua` với `nhip: null` cho **đúng từng số** như bản trước (ca hồi quy, viết **trước** khi sửa
  hàm); ba ví dụ mục 3.3 qua `taiPhanBoCua` (Nhà ở: không kế hoạch · Ăn uống: có · Mua sắm: thâm hụt ~480.000).
- Mỗi ca xanh ngay từ đầu phải qua một **bản sai có chủ ý** (họ G43).

### 7.2 Repository và nối dây

- `nhipChiTheoNganSach` trên CSDL Drift trong bộ nhớ: bỏ khoản `thu` / `transfer`, bỏ khoản danh mục khác, ngân sách tổng
  gom mọi danh mục, khoản đúng mốc `to` thuộc kỳ sau; ca canh **tổng các kỳ từ ngày tạo = `getPeriodHistory`** (hai phép
  cắt kỳ không lệch).
- `TaiPhanBoNguonImpl.nap` mang `nhipTheoNganSach`; `BudgetDetailCubit` truyền nhịp vào `pace`; tool ngân sách in trạng
  thái theo nhịp.
- Widget test `_PaceCard` ở **360 dp**: cả hai nhãn, không tràn (`takeException`), chip và dòng phụ cùng một hàng.

### 7.3 Công cụ đo trên CSDL thật

`test/tool/do_nhip_chi_test.dart` (skip; chạy tay với `FLOWMONEY_DB` + `FLOWMONEY_IDACCOUNT`, khuôn
`do_goi_y_so_tien_test.dart`; ⚠️ chép bản gốc ra mỗi lần chạy — SQLite checkpoint và xoá `-wal`): với từng ngân sách đang
chạy in chu kỳ, số kỳ đã đóng xét được, số kỳ có chi, có học được không, và **dự phóng cũ ↔ mới** tại `now`. Dữ liệu thật
bắt đầu 02/09/2026 → ngân sách tháng có tối đa **1** kỳ đã đóng xét được (tháng 9 — và **không** được xét nếu kỳ của
ngân sách bắt đầu 01/09, vì kỳ ấy bắt đầu trước giao dịch đầu tiên), nên kết quả dự kiến là **im**; báo đúng như số đo,
**không** coi im là đạt. Ngưỡng 3 kỳ giữ nguyên tới khi có dữ liệu để đo lại.

### 7.4 Nghiệm thu máy thật (máy đang cắm — Realme RMX2205)

- **Chiều hồi quy, đo được ngay:** nhịp chưa học → ô NHỊP CHI vẫn *"Theo thời gian đã trôi"*, thẻ cân đối và dự phóng y
  như bản trước (so với công cụ 7.3).
- **Chiều dương** cần ≥ 3 kỳ dữ liệu. Lúc nghiệm thu **hỏi người dùng** có cho bơm thử giao dịch các tháng cũ rồi xoá (khuôn
  lượt B5b, `NOTIFICATION_FEATURE.md` mục 5i) — không tự làm. Không được duyệt thì chiều dương chỉ được phủ bởi test.

### 7.5 Cổng ra

`flutter test` xanh hết, `flutter analyze` không vượt mức nền 26; công cụ 7.3 chạy được trên CSDL Realme; nghiệm thu 7.4.

## 8. Rủi ro và giới hạn đã biết

- **Lệch tối đa một ngày ở đầu kỳ.** Vị trí đo theo **giờ**: khoản ghi 00:00 ngày 1 của các tháng trước được coi là đã chi
  ngay từ sáng ngày 1 tháng này, dù hôm nay chưa trả — trong ngày đầu dự phóng có thể **thiếu** đúng khoản ấy. Ghi lại,
  không vá: vá bằng cắt theo ngày đẻ lỗi đếm đôi chính ngày hôm nay.
- **Học cả thời chưa đặt ngân sách** (quyết định 4): tháng chưa kiềm chế có thể chi nhiều hơn → `conChiMoiKhi` cao hơn →
  báo sớm nhiều hơn. Chấp nhận để học được sớm.
- **Danh mục thỉnh thoảng mới chi** (quyết định 7): trung vị trên kỳ có chi cho dự phóng cao hơn *"trung bình mọi tháng"*
  → báo sớm nhiều hơn với danh mục kiểu Giải trí 3/6 tháng. Người dùng chọn điều này.
- **Đổi danh mục / ngày bắt đầu của ngân sách** → nhịp học lại theo cấu hình mới (vì nó suy từ giao dịch, không lưu).
  Không có gì để vỡ.
- **Chi phí đọc:** `nap` chạy sau mỗi thay đổi giao dịch (`BudgetCubit`) và mỗi lượt quét thông báo — thêm **một** truy vấn
  khoảng ≤ 6 kỳ + kỳ hiện tại; số ngân sách của một tài khoản nhỏ.
- **Im trên dữ liệu hiện tại** (mục 7.3) — đúng ý người dùng (*xây cho tương lai, dưới ngưỡng thì im*).

## 9. Ngoài phạm vi

- Hai việc còn lại của dự án C: **thứ tự khối trang Phân tích** (phần rẻ — khối tự ẩn khi rỗng — xong 2026-09-21, mục 3.34
  `ANALYTICS_FEATURE.md`; còn phần học) và **tần suất thông báo theo phản ứng** (phần lớn đã có ở B5b — đề xuất tắt nhóm bị
  lờ; còn phần *tự* giảm, đi ngược lựa chọn *chỉ đề xuất* của B5b). Mỗi việc một spec khi tới lượt.
- Đổi màu thẻ theo nhịp; thêm loại thông báo *"Dự kiến vượt"* riêng; đưa *Ngân sách tổng* vào kế hoạch cân đối — người dùng
  không chọn.
- Học `essentiality` (mục 11.4) — dù cùng chạm `tai_phan_bo.dart`.
