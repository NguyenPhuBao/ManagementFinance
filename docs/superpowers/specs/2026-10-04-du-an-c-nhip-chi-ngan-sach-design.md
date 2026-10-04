# Dự án C, việc thứ hai — dự phóng và nhịp chi ngân sách theo nhịp riêng của từng người — thiết kế

**Ngày:** 2026-10-04. **Trạng thái:** thiết kế người dùng duyệt trong chat (bảy lượt AskUserQuestion: chọn việc, phạm
vi, cách báo sớm, nguồn học, cách dự phóng, ba phần thiết kế); bản viết người dùng cho đi tiếp cùng ngày (*"tiếp tục"*);
**kế hoạch 12 task (Task 0–11)** `docs/superpowers/plans/2026-10-04-du-an-c-nhip-chi-ngan-sach.md` (gitignore) — **chưa có
mã**. Người dùng dặn dừng sau kế hoạch và viết bàn giao; Task 0 của kế hoạch hỏi thứ tự **G66** trước khi code — ✅
phiên sau người dùng chọn sửa G66 **trước** (`02d46ca`); việc nhịp chi bắt đầu ở Task 1.

> ✅ **THI CÔNG XONG 2026-10-04** (`3e827dc` → `8eb5b93`, nghiệm thu Realme 360 dp cùng ngày; mục 11.5 (3)
> `AI_EDGE_FEATURE.md`). **Ba chỗ bản thi công khác bản viết:**
> 1. `mocKy` có từ G66 với thân nhảy từ `startDate` — mục 4.1 bản viết tả nó nhảy từ mốc neo (chính lưới G66), đã sửa tại chỗ.
> 2. **Mục 7.3 đoán sai "im"**: CSDL Realme có giao dịch từ 10/04/2026 (dữ liệu thử B2/B3 người dùng cho giữ), nên *Ăn uống*
>    học được 5 kỳ — chiều dương của 7.4 nghiệm thu được trên máy **không phải bơm dữ liệu**.
> 3. **Ô NHỊP CHI đổi bố cục** (người dùng chọn lúc nghiệm thu, ngoài phạm vi mục 5): dòng *"Theo …: X"* xuống **hàng riêng
>    dưới chip** vì ở 360 dp chip dài cùng hàng cắt mất con số (lỗi có từ trước). Mục 3.2 / 5 chỉ nói đổi chữ, còn mục 7.2
>    đòi "chip và dòng phụ cùng một hàng" — câu ấy nay **ngược** bản thi công (có đánh dấu tại chỗ).

> 🔧 **Bốn chỗ làm rõ lúc lập kế hoạch (2026-10-04), thắng chỗ tương ứng bên dưới:**
> 1. **Kỳ trước ngày tạo cắt trên LƯỚI mốc neo, không lùi từ `startDate`** (mục 4.1 đã viết lại). Lùi từ `startDate` lệch
>    lưới với kỳ thật khi ngân sách mang `nextTimeRecurrence` riêng (hàng kéo về) hoặc bắt đầu ngày 29–31 (mốc neo bị kẹp).
>    Lưới có **một** định nghĩa mới, `BudgetEntity.mocKy(int s)`, mà `currentPeriod`, `recentPeriods` và `kyDaDongTruoc` cùng
>    gọi (Task 1).
> 2. **Tên tham số là `nhipChi`**, không `nhip` — `duPhongCua` đã có biến cục bộ `nhip` (kiểu `BudgetPace`).
> 3. **Ví dụ mục 1.2 và 3.3 là đúng số của bộ mẫu test** (`test/features/budget/domain/nhip_chi_mau.dart`), cùng một mốc
>    trưa **06/11/2026** cho cả ba ngân sách; bản đầu dùng số tròn ước lượng (`~`).
> 4. **Lộ ra một lỗi CÓ SẴN khi dựng lưới — G66** (`CLIENT_APP_KNOWN_GAPS.md`): ngân sách bắt đầu ngày 29–31 trôi hẳn về ngày
>    đã kẹp từ kỳ thứ hai (đo: bắt đầu 31/01 → kỳ 28/03→28/04, 28/04→28/05…), vì `_anchor` là mốc **đã kẹp**. Không thuộc việc
>    này; memory *sửa lỗi trước, thêm tính năng sau* → Task 0 hỏi người dùng làm G66 trước. Ca canh *"ngày 31"* của Task 1 bảo
>    đảm `kyDaDongTruoc` đi theo bất kỳ bản sửa nào của lưới. ✅ **G66 đóng cùng ngày** (`02d46ca`, người dùng chọn làm
>    trước): `mocKy` đã có và nhảy từ `startDate` — lưới không còn trôi về ngày kẹp.

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
các tháng trước: tiền nhà 4.000.000 ngày 1 + 200.000 các ngày 10, 20, 28 (4.600.000 mỗi kỳ). Trưa 06/11, đã chi 4.200.000:

| | Hôm nay | Theo nhịp riêng (thiết kế này) |
|---|---|---|
| Dự phóng cuối kỳ (`duPhongCua`) | 4.200.000 × 30 / 5 = **25.200.000** → thâm hụt 20,2 triệu → **kế hoạch cân đối + thông báo**, đề xuất **cắt ngân sách khác** | 4.200.000 + 600.000 mọi khi còn chi = **4.800.000** → không thâm hụt, không kế hoạch |
| Chip NHỊP CHI | phần đã chi 84 % so với thời gian 18,3 % → **"Nhanh hơn dự kiến"** | mọi khi tới lúc này đã chi 4/4,6 ≈ 87 % của kỳ → 84 % là **"Đúng nhịp"** (lệch 3 điểm, trong biên ±5) |
| *"Theo … : X"* | Theo thời gian đã trôi: 916.667 đ | Theo nhịp thường lệ: 4.347.826 đ |

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

### 3.3 Ví dụ dùng làm ca test chính (trưa 06/11/2026 — đã qua 5,5/30 ngày; kỳ học 8–10/2026)

| Ngân sách | Kỳ trước (mọi khi) | Đã chi | Dự phóng hôm nay → mới | Kế hoạch cân đối |
|---|---|---|---|---|
| **Nhà ở** 5.000.000 | 4.000.000 ngày 1 + 200.000 các ngày 10, 20, 28 | 4.200.000 | 25.200.000 → **4.800.000** | hôm nay **có** (thâm hụt 20,2 triệu, báo oan) → **không** |
| **Ăn uống** 3.000.000 | 100.000 mỗi ngày 1–28 (2.800.000, chi đều) | 2.100.000 | 12.600.000 → **4.300.000** | **có** cả hai — thâm hụt 9,6 triệu (thổi phồng) → **1.300.000** |
| **Mua sắm** 2.000.000 | 300.000 các ngày 5, 12, 19, 26 | 1.500.000 (một món) | 9.000.000 → **2.400.000** | **có** cả hai — thâm hụt 7 triệu → *"dự kiến vượt 400.000"* (lối "giữ tốc độ" bị loại ở quyết định 5: 1.500.000 ÷ 0,25 = 6.000.000) |

Ba ngân sách cùng chạy: hôm nay kế hoạch nhắm **nhầm Nhà ở**; theo nhịp riêng nó nhắm **Ăn uống** (1.300.000) và Nhà ở
thành **nguồn bù** (dư địa 5.000.000 − 4.800.000 = 200.000, cắt 25 % = 50.000).

## 4. Phép học

### 4.1 Kỳ — `kyDaDongTruoc` (`budget/domain/budget_history.dart`, cạnh `recentPeriods`)

Một chỗ cắt kỳ, cạnh phép cắt kỳ sẵn có, để hai phép không lệch nhau một ngày (lý do đứng đầu `budget_history.dart`).

- 🔧 **Một lưới cho mọi kỳ:** kỳ thứ s là `[mocKy(s − 1), mocKy(s))` với `BudgetEntity.mocKy(int s)` — định nghĩa DUY NHẤT
  của mốc kỳ (`mocKy(0)` = cuối kỳ đầu; s âm đi lùi về **trước** ngày tạo — `advancePeriodFrom` đã nhận `steps` âm).
  ✅ **Đã có từ G66** (`02d46ca`): `currentPeriod`, `recentPeriods`, `expiresAt` cùng gọi nó; thân nhảy `s + 1` chu kỳ **từ
  `startDate`** (có `nextTimeRecurrence` thì `s` chu kỳ từ mốc ấy) — *bản viết ở đây từng ghi "`advancePeriodFrom(anchor:
  mốc neo, steps: s)`", tức chính lưới G66*. Nên **kỳ đã đóng sau kỳ đầu trùng khít `recentPeriods`** — có ca canh, kể cả
  ngân sách bắt đầu ngày 31.
- Kỳ **đầu** của ngân sách (`[startDate, mốc neo)`) có thể lệch lưới (mốc neo kẹp, hoặc `nextTimeRecurrence` riêng); phép
  học dùng kỳ **trên lưới** chứa nó (`[mocKy(−1), mocKy(0))`) — tức học về **danh mục**, không chép lại lịch sử ngân sách.
- ⚠️ *Bản đầu của mục này lùi từ `startDate` (`[advancePeriodFrom(anchor: startDate, steps: −k), …)`). Bỏ lúc lập kế hoạch:
  lệch lưới với kỳ thật ở đúng hai ca trên — và hai lưới lệch nhau là thứ mục này sinh ra để tránh.*
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

| Hàm | Khi `nhipChi != null` | Khi `nhipChi == null` |
|---|---|---|
| `budgetPaceOf(b, now, {NhipChi? nhipChi})` | `expectedSpent = amount × phanDaChiMoiKhi(x)`; status so `spent/amount` với `phanDaChiMoiKhi(x)` ±5 điểm; `theoNhipRieng = true`; `x` đo bằng `viTriTrongKy` (định nghĩa duy nhất, `BudgetPace.phanThoiGian` mang nó ra) | y như hôm nay, `theoNhipRieng = false` |
| `duPhongCua(v, …, {NhipChi? nhipChi})` | `spent + conChiMoiKhi(BudgetPace.phanThoiGian)` | y như hôm nay (nhân tuyến tính từ ngày 5, cộng mức tháng trước đó) |

`daysLeft`, `suggestedPerDay` của `BudgetPace` **không** đổi — dòng *"Nên chi X/ngày · còn N ngày"* vẫn chia đều phần còn
lại, vì đó là lời khuyên chứ không phải dự đoán.

## 5. Vị trí mã

| Tệp | Việc |
|---|---|
| `budget/data/models/budget_entity.dart` | 🔧 `mocKy(int s)` — định nghĩa duy nhất của mốc lưới kỳ; `currentPeriod` gọi nó |
| `budget/domain/budget_history.dart` | `recentPeriods` gọi `mocKy`; thêm `kyDaDongTruoc` |
| `budget/domain/nhip_chi.dart` *(mới)* | `KyChi`, `NhipChi` (+ `tongTheoKy` cho công cụ đo và test), `hocNhipChi`, `viTriTrongKy`, `kSoKyHocToiThieu`, `kSoKyHocToiDa` |
| `budget/domain/budget_pace.dart` | tham số `nhipChi`, trường `theoNhipRieng` và `phanThoiGian`; phần thời gian đo bằng `viTriTrongKy` |
| `budget/data/datasources/budget_local_data_source.dart` | 🔧 `khoanThuocNganSach` — vế danh mục của `getExpenses` tách ra dùng chung |
| `budget/data/repositories/budget_repository(_impl).dart` | `nhipChiTheoNganSach(idaccount, List<BudgetEntity>, {now})` → `Map<String, NhipChi?>` (khoá `budget.id`). Đọc **một lần** khoảng `[from kỳ cũ nhất, to kỳ mới nhất)` qua `getExpenses(categoryId: null)` — **cùng định nghĩa "đã chi"** với `spent` (chỉ `chi`, biên `to` mở) — rồi chia theo ngân sách bằng `khoanThuocNganSach` và theo kỳ. Lớp giả viết đủ hàm (`budget_cubit_test`) phải thêm hàm; lớp giả `noSuchMethod` thì không |
| `budget/data/doc_nhip_chi.dart` *(mới)* | 🔧 `docNhipChi` — cửa đọc cho ba nơi dùng; đọc hỏng → `{}` (nhịp là phần phụ, rơi về chi đều) |
| `budget/data/tai_phan_bo_nguon.dart` | `DuLieuTaiPhanBo.nhipTheoNganSach`; `nap` điền qua `docNhipChi`; `keHoachTaiPhanBoTu` chuyền vào `taiPhanBoCua` |
| `ai_edge/domain/tai_phan_bo.dart` | `duPhongCua(nhipChi:)`; `taiPhanBoCua(nhipTheoNganSach:)` |
| `budget/presentation/bloc/budget_detail_cubit.dart` | nạp nhịp của ngân sách đang xem, truyền vào `budgetPaceOf` |
| `budget/presentation/pages/budget_detail_view.dart` | `_PaceCard`: *"Theo nhịp thường lệ: X"* khi `pace.theoNhipRieng` |
| `ai_edge/domain/hang_ngan_sach.dart` + `ai_edge/data/cong_cu_ngan_sach.dart` | `hangNganSach(nhipTheoNganSach:)`; tool nạp qua `docNhipChi(BudgetRepository, …)` (không qua `TaiPhanBoNguon.nap` — hàm ấy còn tính thu nhập và `suggestAmount`, thừa cho tool) |
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

- `kyDaDongTruoc`: tháng Hai năm thường **và** năm nhuận, cả 2100 (memory *test lịch tháng ngắn và năm nhuận*); kỳ tuần,
  quý, năm; kỳ trước giao dịch đầu tiên bị bỏ; *Ngày cụ thể* trả rỗng; tối đa 6; kỳ hiện tại không tính; ngân sách có
  `nextTimeRecurrence` khác chuẩn (hàng kéo về); 🔧 ⭐ kỳ đã đóng sau kỳ đầu **trùng `recentPeriods`** — cả ngân sách bắt đầu
  ngày 31 (ca canh G66: sửa lưới ở một chỗ mà chỗ kia không theo thì đỏ).
- `hocNhipChi`: < 3 kỳ có chi → `null`; kỳ `T_p = 0` không tính vào cả hai phép (quyết định 7); trung vị số kỳ lẻ / chẵn;
  một tháng bất thường không kéo lệch.
- `budgetPaceOf` / `duPhongCua` với `nhipChi: null` cho **đúng từng số** như bản trước (ca hồi quy, viết **trước** khi sửa
  hàm); ba ví dụ mục 3.3 qua `taiPhanBoCua` (Nhà ở: không kế hoạch · Ăn uống: có · Mua sắm: thâm hụt ~480.000).
- Mỗi ca xanh ngay từ đầu phải qua một **bản sai có chủ ý** (họ G43).

### 7.2 Repository và nối dây

- `nhipChiTheoNganSach` trên CSDL Drift trong bộ nhớ: bỏ khoản `thu` / `transfer`, bỏ khoản danh mục khác, ngân sách tổng
  gom mọi danh mục, khoản đúng mốc `to` thuộc kỳ sau; ca canh **tổng các kỳ từ ngày tạo = `getPeriodHistory`** (hai phép
  cắt kỳ không lệch).
- `TaiPhanBoNguonImpl.nap` mang `nhipTheoNganSach`; `BudgetDetailCubit` truyền nhịp vào `pace`; tool ngân sách in trạng
  thái theo nhịp.
- Widget test `_PaceCard` ở **360 dp**: cả hai nhãn, không tràn (`takeException`), ~~chip và dòng phụ cùng một hàng~~ ✅ dòng phụ
  ở **hàng riêng dưới chip** và không bị cắt "…" (`didExceedMaxLines`) — đổi lúc nghiệm thu, xem khối ✅ đầu tệp.

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
- 🔧 **Kỳ đầu lệch lưới** (mốc neo kẹp, hoặc `nextTimeRecurrence` riêng): trong chính kỳ đầu ấy, phần thời gian `x` đo trên
  kỳ ngắn/dài hơn một chu kỳ còn nhịp học trên kỳ đầy đủ — lệch nhẹ, chỉ trong kỳ đầu. Không vá.
- 🔧 **Phụ thuộc G66:** ✅ hết — G66 đóng 2026-10-04 (`02d46ca`) trước khi việc này có mã; lưới `mocKy` nhảy từ
  `startDate`, nên ngân sách bắt đầu ngày 29–31 học trên đúng kỳ người dùng đặt. *(Câu cũ: "lưới hôm nay trôi về ngày kẹp…
  nhịp học đi theo đúng lưới ấy" — ảnh chụp trước bản sửa.)*
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
