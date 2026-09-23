# Bước 2 — ba tool đọc (mục tiêu · gợi ý hạn mức · tìm giao dịch) + phép đo 20 câu lệnh (thiết kế)

**Ngày:** 2026-09-23 · **Nhánh:** `TranQuangDat` @ `a16b3d2` · **Trạng thái:** ✅ **đã duyệt** — thiết kế ba
phần duyệt trong chat cùng ngày, ba quyết định thêm lúc viết duyệt ở phiên sau (mục 1.2, hàng 11–13); chưa có
kế hoạch, chưa dòng mã nào
**Đầu vào:** đơn đặt hàng tool, mục **5.6** `docs/AI_AGENT_ARCHITECTURE.md` (hai tool còn lại: dự báo mục
tiêu — câu 11, gợi ý hạn mức — câu 5); nửa sau mục **2.1** `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`
(tool tìm giao dịch + phép đo 20 câu lệnh); tầng tool của lát 4b (spec
`2026-09-23-chang-4b-tool-calling-vong-lap-design.md`, đo cổng C ở mục **9.14** `docs/AI_EDGE_FEATURE.md`);
bước 1c (mục **9.16**, bẫy **4.38**).
**Khung cố định:** bốn bất biến mục 6 `docs/AI_AGENT_ARCHITECTURE.md` — ① lớp AI không tính · ② mọi tool
trả `List<SoLieu>` (đi theo hàng) · ③ luôn có đường lùi · ④ **không tool nào ghi**. Bước này **không** đổi ④.

---

## 1. Vì sao bước này tồn tại, và đích của nó

### 1.1 Đích

1. **Hoàn tất đơn đặt hàng cổng B**: hai tool đọc 4b để lại — câu 11 (*"khi nào đạt mục tiêu"*) và câu 5
   (*"tháng sau nên đặt ngân sách bao nhiêu"*) của bảng đo 20 câu.
2. **Tool tìm giao dịch** — nửa sau mục 2.1 (*"tháng trước tôi tiêu gì trên 500k"*). Bốn tool 4b chỉ trả
   **tổng hợp** theo danh mục / ngân sách / hoá đơn / ví; chưa tool nào liệt kê **từng giao dịch**.
3. **Phép đo 20 câu lệnh** — **cửa mở chiều ghi** (bước 3, nhập giao dịch bằng câu): tỉ lệ chọn đúng tool và
   đúng tham số quyết định có đi tiếp hay không.

### 1.2 Quyết định đã chốt (2026-09-23, không hỏi lại)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Phạm vi | **Một spec** cho cả ba tool + phép đo — không tách 2a/2b: trần token là của **bảy** khai báo cùng lúc, và chỉ cần **một** buổi cắm điện thoại |
| 2 | Tool mục tiêu mang những số nào | **Đầy đủ, có nhịp** — kèm *Theo nhịp hiện tại cần thêm N ngày* **luôn có khi tính được** (khác khối Nhận xét, nơi vế ấy chỉ hiện khi chậm), *Cần tích mỗi kỳ*, *Đang tích mỗi kỳ* |
| 3 | Tool gợi ý hạn mức liệt kê gì | **Mọi danh mục chi** có gợi ý (tối đa 4) + tham số tuỳ chọn **`danh_muc`** (tên) |
| 4 | Hàng giao dịch có mang ngày | **Có** — thêm **`LoaiSo.ngayThang`** vào bộ kiểm |
| 5 | Khai báo 7 tool vượt trần 2.048 | **Nâng `maxTokens` lên 4.096**, đo RAM + thời gian nạp trên **cả hai** máy trước khi giữ; mô tả tool **không** rút gọn (nó là thứ duy nhất dẫn E2B chọn đúng) |
| 6 | Ngưỡng phép đo | Trên Realme: **≥ 18/20** câu gọi đúng tool, **≥ 16/20** câu đúng **mọi** tham số bắt buộc, **SAI = 0**, nhóm hồi quy **không tụt** → mở bước 3. Dưới ngưỡng → chỉnh mô tả tool / tham số, đo lại |
| 7 | Phác thảo tool tìm giao dịch | Tham số `ky` · `so_tien_tu` · `so_tien_den` · `chieu` · `danh_muc` · `vi` · `tu_khoa` · `sap_xep`; tên hàng = ghi chú (không có thì tên danh mục); loại khoản **điều chỉnh số dư** và khoản **mở sổ**; khoản chuyển chỉ có khi hỏi *chuyển ví* hoặc *tất cả*; tổng là của **mọi** khoản khớp; khoảng tiền đã hiểu được **dội lại** |
| 8 | Ba chỗ chỉnh khi trình phần 2 | Tool mục tiêu thêm **Đã tích** và **Mục tiêu**; tool tìm thêm **`sap_xep`**; tên danh mục/ví của hàng gom vào **`KetQuaCongCu.tenLienQuan`** chứ không ghi ở từng hàng |
| 9 | Tham số tiền | **Số đồng** theo JSON Schema; chuỗi chữ số được nhận; *"500k"* / *"nửa triệu"* thì tool **từ chối** kèm ví dụ — quy đổi là việc của mô hình và chính là thứ phép đo chấm; bảng quy đổi *"k / củ"* để bước 3. `so_tien_tu > so_tien_den` cũng từ chối, không tự hoán đổi |
| 10 | Giao diện | Không khối mới → **không lên Stitch** (tiền lệ mục 1.2 spec 4b); chỉ thêm nhãn cho dòng chỉ báo |
| 11 | Giao dịch ghi ngày tương lai (sau `now`) | Tool tìm giao dịch **bỏ** — CSDL thật có hai khoản trích mục tiêu hẹn trước (10/10, 10/11); không bỏ thì *"lần cuối tôi nạp tiền cho muaxe là ngày nào"* nhận **10/11**, một việc chưa xảy ra. Cùng lý lẽ với `cuaSoNhinLai` (đóng cửa sổ tại `now`). Mục 3.8 bước 4 |
| 12 | Ngưỡng giữ `maxTokens: 4096` | Giữ khi **không sập**, **không bị hệ thống giết**, và RAM đỉnh tăng **≤ 0,5 GB** so với 2.048, đo trên cả hai máy; vượt thì **dừng và báo người dùng**. Mục 3.10 |
| 13 | Luật tiêu đề dòng giao dịch | **Tách** thành hàm thuần `tieuDeGiaoDich` ở `transaction/domain/`; `buildTransactionRowContent` (4 chỗ gọi) gọi lại nó — tool và Sổ giao dịch dùng **một** luật. Mục 3.8 bước 6 |

*(Hàng 11–13 là ba quyết định spec thêm **lúc viết**, chưa hỏi trong chat; người dùng duyệt cả ba ở phiên sau,
2026-09-23.)*

### 1.3 Dữ liệu nền (đo 2026-09-23 trên CSDL máy ảo, tài khoản 10, chỉ đọc)

- **39** giao dịch sống: **18** chi · **9** thu · **12** chuyển ví. Sớm nhất **02/09/2026**; khoản đã xảy ra
  muộn nhất **20/09**; hai khoản chuyển hẹn trước **10/10** và **10/11**.
- **21** có ghi chú — **12** trong số ấy là ghi chú hệ thống *"Tích lũy mục tiêu: …"*, **5** là *"Thanh toán
  hóa đơn: …"*, **1** là *"Điều chỉnh số dư"*.
- **16** danh mục sống (tên có chữ số: `test1`) · **4** ví (*Tiền mặt*, *Tiết kiệm*, *tiết kiệm mua nhà*,
  *test*) · **2** mục tiêu (*MuaXe* 1.101.000 / 2.000.000, *MuaDT* 400.000 / 3.000.000) · **9** hàng hoá đơn
  (tên có chữ số: *"di h0c"*, *"Kiem thu hoa don 2026-09-04"*).
- Hệ quả cho phép đo: trên dữ liệu này các kỳ *hôm nay · hôm qua · tuần này · tháng trước* cho **0 kết quả**.
  Phép đo chấm **tham số** theo đáp án, còn **kết quả** thì chấm theo dữ liệu **ngày đo** (mục 5.4).

---

## 2. Những gì đã có — dùng lại, không dựng lại

| Mảnh | Ở đâu |
|---|---|
| Tầng tool: `CongCu` · `KhaiBaoCongCu` · `BoCongCu` · vòng lặp `hoiBangCongCu` (trần 3 lời gọi, thang lùi L1–L4) · `GoiSoTraCuu` · `HangSoLieu` / `KetQuaCongCu` · `cauDangTraCuu` · `kPromptHeThongCongCu` · canary 1b | `ai_edge/domain/`, `ai_edge/data/` — lát 4b, bước 1b |
| Chữ số trong tên không phải con số: `trichSoNgoaiTen` · `GoiSo.tenDoiTuong` | `ai_edge/domain/kiem_so.dart`, `goi_so.dart` — bước 1c |
| Mục tiêu: `chiaMucTieu` (thứ tự trang Mục tiêu) · `duBaoHoanThanh` · `tocDoKeHoach` · `tocDoThucTe` · `tenDonViKy` · `GoalEntity.progress / currentAmount / targetAmount / remainingAmount / daysLeft / isBehindSchedule / cycleTakeMoney` | `goal/domain/goal_grouping.dart`, `goal_forecast.dart`, `goal_stats.dart`; `GoalRepository.watchGoals` |
| Gợi ý hạn mức: `suggestAmount` · `soNgayCuaSoNhinLai` · `soNgayCoDuLieu` · `getExpenseCategories` · `watchBudgets` · `soNgayConThieu` · `nganSachDangChay` | `BudgetRepository`; `budget/domain/cua_so_nhin_lai.dart`; `ai_edge/data/nguon_goi_so.dart` |
| Giao dịch: `watchKhoang` (biên `[from, to)`) · `TransactionFilter` + `applyTransactionFilter` (ví khớp **cả** ví đích của khoản chuyển; từ khoá không dấu) · `summarizeTransactions` · `KhoangTien.chua` / `hopLe` · `laKhoanDieuChinh` · `laKhoanMoSo` | `TransactionRepository`; `transaction/domain/transaction_filter.dart`, `khoang_tien.dart`; `wallet/domain/dieu_chinh_so_du.dart`, `so_du_mo_so.dart` |
| Bảng tra tên ví / danh mục (danh mục **kể cả đã xoá mềm** — `getBangTraTen`) · ví và danh mục **còn sống** để khớp tên tham số | `BudgetRepository.lookupFor`; `BaoCaoRepository.watchVi` / `watchDanhMuc` (`LuaChonLoc`) |
| Kỳ: `Ky` · `cacKyGanNhat` · `lui` · `kMaKy` / `kyTuMa` | `analytics/domain/pham_vi_ky.dart`; `ai_edge/domain/hang_chi_tieu.dart` |
| So tên: `normalizeCategoryName` (NFC · chữ thường · gom khoảng trắng) · `removeVietnameseTones` (dành cho **tìm kiếm / gợi ý**) | `core/category/category_name.dart` |

---

## 3. Thiết kế

### 3.1 Một câu

*Vòng lặp của 4b giữ nguyên; `BoCongCu` có bảy tool; ba tool mới trả hàng đầy đủ theo đúng khuôn cũ, và bộ
kiểm học đọc thêm một loại số: ngày.*

```
câu hỏi ──► hoiBangCongCu (không đổi) ──► BoCongCu: 4 tool cũ
                                              + danh_sach_muc_tieu
                                              + goi_y_han_muc
                                              + tim_giao_dich ──► timGiaoDich (transaction/domain, NGOÀI ai_edge)
```

### 3.2 `LoaiSo.ngayThang` — bộ kiểm đọc được ngày

Chú thích đầu `kiem_so.dart` đã chừa sẵn lối này: *"nếu sau này gói số cần ngày thì thêm `LoaiSo.ngayThang`
chứ đừng nới regex"*.

- **`goi_so.dart`**: `enum LoaiSo { tien, phanTram, soNgay, soDem, ngayThang }` và
  `SoLieu soNgayThang(String nhan, DateTime ngay, {String? ten, required DateTime now})` —
  `chuoi` = `dd/MM`, thêm `/yyyy` khi **khác năm của `now`**; `soTho` = `yyyy·10000 + MM·100 + dd`.
- **`trichSo`** tách **ngày trước, số sau**: mẫu `dd/mm` hoặc `dd/mm/yyyy` (không có chữ số hay `/` dính hai
  bên; ngày 1–31, tháng 1–12) thành `SoTrich` loại ngày, rồi **bỏ** chúng khỏi câu trước khi chạy regex số —
  nên `12/09` không còn thành hai con số 12 và 9. Dạng không hợp lệ (`45/13`, `12/09/26`) không phải ngày và
  đi tiếp như số — bị chặn nếu không có trong gói (chiều an toàn).
- **`_khop`**: mục `ngayThang` chỉ khớp một `SoTrich` loại ngày có **ngày và tháng trùng**; **năm chỉ so khi
  câu có ghi năm**. Số trần **không bao giờ** khớp mục ngày, và ngày **không bao giờ** khớp mục tiền / phần
  trăm / số ngày / số đếm.
- `kiemNhan`, `theCuaCau` đọc qua cùng `trichSoNgoaiTen` nên tự nhận loại mới; mục ngày của một hàng mang
  `ten` của hàng ấy, nên câu nêu ngày cũng phải nêu tên (luật 4a, không đổi).
- ⚠️ Mô hình viết *"ngày 12 tháng 9"* thay vì `12/09` → 12 và 9 thành số trần → bị chặn → rơi về mẫu câu.
  Hỏng theo chiều an toàn; prompt dặn chép nguyên `12/09` (mục 3.10).

### 3.3 Khớp tên tham số — một hàm, ngoài `ai_edge`

`lib/core/utils/khop_ten.dart` — thuần, dùng chung cho `danh_muc` của `goi_y_han_muc` và `danh_muc` / `vi`
của `tim_giao_dich`:

```dart
sealed class KetQuaKhopTen<T> {}
final class KhopMot<T> extends KetQuaKhopTen<T> { final T muc; }
final class KhopNhieu<T> extends KetQuaKhopTen<T> { final List<T> ds; }
final class KhongKhop<T> extends KetQuaKhopTen<T> {}

KetQuaKhopTen<T> khopTheoTen<T>(String hoi, Iterable<T> ds, String Function(T) tenCua);
```

1. **Trùng chính xác** theo `normalizeCategoryName` → một mục thì `KhopMot`, nhiều mục thì `KhopNhieu`.
2. Không có → **trùng sau khi bỏ dấu** (`removeVietnameseTones` trên tên đã chuẩn hoá) → một mục `KhopMot`,
   nhiều mục `KhopNhieu`, không có `KhongKhop`.
3. **Không** so chuỗi con: *"tiết kiệm"* khớp ví **Tiết kiệm**, không khớp *"tiết kiệm mua nhà"*.

Bỏ dấu ở đây là **đúng chỗ** của `removeVietnameseTones` (tìm kiếm — đoán sai chỉ tốn một lần hỏi lại), và
câu đo gõ không dấu nên phép đo thử luôn nhánh này. Tool gặp `KhongKhop` / `KhopNhieu` thì **từ chối**, lời từ
chối kèm danh sách tên thật để mô hình gọi lại (tốn một suất trong trần 3).

⚠️ **Danh sách đem khớp phải là danh sách của CHÍNH tài khoản**: `BaoCaoRepository.watchDanhMuc` / `watchVi`
(`categoryDao.watchAll(idaccount)` — chỉ hàng của tài khoản, đã khử trùng tên) và
`BudgetRepository.getExpenseCategories` (`getCategoryRows` — đã khử trùng tên). Lẫn **hàng khuôn mặc định
toàn cục** (`idaccount = 0`, quy tắc 8 `CLAUDE.md`) vào là mọi tên danh mục mặc định khớp **hai** hàng →
`KhopNhieu` → tool **luôn** từ chối *"ăn uống"*. Lượt kiểm đáp án của chính spec này vấp đúng chỗ ấy khi
truy vấn thẳng CSDL bằng `idaccount IN (0, 10)`.

### 3.4 `kMaKy` mở rộng — một bảng mã kỳ cho hai tool

`hang_chi_tieu.dart` thêm `hom_nay` · `hom_qua` · `tuan_truoc`; `kyTuMa` dựng: hai mã ngày bằng
`Ky.tuyChon(from: đầu ngày, to: đầu ngày kế)`, `tuan_truoc` bằng `lui(tuần này, 1)`. **Cả** `chi_tieu_theo_ky`
**lẫn** `tim_giao_dich` đọc bảng này — nên *"hôm qua chi bao nhiêu"* cũng trả lời được. ⚠️ Khai báo của tool cũ
đổi (enum dài thêm) → nhóm hồi quy (mục 5.2) phải chạy lại câu 9 và ĐC2.

### 3.5 `KetQuaCongCu.tenLienQuan`

`KetQuaCongCu` thêm `final List<String> tenLienQuan` (mặc định rỗng) — tên xuất hiện trong kết quả mà **không
nằm trên `SoLieu` nào**: tên danh mục / ví trong chữ trạng thái của hàng giao dịch, tên khớp tham số, và danh
sách tên trong lời từ chối. `GoiSoTraCuu.them()` gom chúng; `GoiSoTraCuu.tenDoiTuong` = mặc định **cộng**
danh sách ấy — để bước 1c phủ chữ số trong những tên này (1/16 danh mục thật mang chữ số). JSON gửi mô hình
**không đổi** (tên đã có trong `trang_thai` / `loi`). Bốn tool cũ để rỗng.

### 3.6 Tool `danh_sach_muc_tieu`

**Tham số:** không. **Nguồn:** `GoalRepository.watchGoals(idaccount).first` → `chiaMucTieu` → `dangTheoDuoi`
(đúng thứ tự trang Mục tiêu), lấy **4** mục đầu.

| Phần | Nội dung |
|---|---|
| Tên hàng | `goal.name` |
| Trạng thái | `daysLeft(now) < 0` → *đã quá hạn*; `isBehindSchedule(now)` → *chậm kế hoạch*; còn lại *đúng kế hoạch*. **Cảnh báo** khi quá hạn hoặc chậm |
| Số (đều mang `ten`) | `Tiến độ` (%) · `Đã tích` · `Mục tiêu` · `Còn thiếu` · `Còn` (N ngày — **bỏ** khi quá hạn) · `Theo nhịp hiện tại cần thêm` (N ngày, từ `duBaoHoanThanh`) · `Cần tích mỗi ‹kỳ›` (`tocDoKeHoach`) · `Đang tích mỗi ‹kỳ›` (`tocDoThucTe`) — ‹kỳ› = `tenDonViKy(cycleTakeMoney)` |
| Số `null` | Bỏ hẳn khỏi hàng — `null` là *chưa đủ căn cứ*, không `?? 0` |
| Tổng hợp | `Đang theo đuổi` (đếm) · `Đã hoàn thành` (đếm) |

⚠️ **Khác khối Nhận xét có chủ ý:** `GoiSoMucTieu` chỉ in *"cần thêm N ngày"* khi chậm (lúc đúng kế hoạch nó là
tiếng ồn); tool trả lời một câu **hỏi thẳng** *"bao giờ đạt"*, nên nó luôn mang số ấy. Không đổi `GoiSoMucTieu`.

**Tệp:** `ai_edge/domain/hang_muc_tieu.dart` (thuần) · `ai_edge/data/cong_cu_muc_tieu.dart` (adapter).

**Mô tả cho mô hình (nháp):** *"Liệt kê các mục tiêu tiết kiệm đang theo đuổi theo TÊN, kèm trạng thái (đúng
hay chậm kế hoạch, quá hạn), tiến độ, đã tích, số tiền mục tiêu, còn thiếu, còn bao nhiêu ngày tới hạn, theo
nhịp tích luỹ hiện tại cần thêm bao nhiêu ngày, cần và đang tích mỗi kỳ. Gọi khi hỏi mục tiêu thế nào, bao giờ
đạt, có kịp hạn không, mỗi tháng cần để dành bao nhiêu."*

### 3.7 Tool `goi_y_han_muc`

**Tham số:** `danh_muc` (chuỗi, tuỳ chọn). **Nguồn:** `getExpenseCategories` · `suggestAmount` từng danh mục ·
`soNgayCuaSoNhinLai` · `soNgayCoDuLieu` + `soNgayConThieu` · `nganSachDangChay(watchBudgets(...))`.

| Ca | Kết quả |
|---|---|
| Cửa sổ nhìn lại `null` (dữ liệu < 14 ngày) | 0 hàng · tổng hợp `Cần thêm dữ liệu` (N ngày, khi `soNgayConThieu` có số) · chữ kèm *"chưa đủ dữ liệu để gợi ý hạn mức"* |
| Có cửa sổ, không tham số | Mỗi danh mục chi có gợi ý (`suggestAmount` khác `null` và > 0) một hàng; xếp **giảm dần** theo mức; lấy **4** |
| Có cửa sổ, có `danh_muc` | `khopTheoTen` trên danh mục chi còn sống: `KhopMot` → chỉ hàng ấy (không có gợi ý → 0 hàng + chữ kèm *"không có khoản chi nào cho danh mục này trong cửa sổ"* + tên vào `tenLienQuan`); `KhongKhop` / `KhopNhieu` → **từ chối** kèm danh sách tên |

| Phần của hàng | Nội dung |
|---|---|
| Tên hàng | tên danh mục |
| Trạng thái | *đã có ngân sách* / *chưa có ngân sách* (có ngân sách **đang chạy** cho danh mục ấy) |
| Số | `Chi trung bình mỗi tháng` (= `suggestAmount`, đã làm tròn lên bội 10.000) · `Hạn mức hiện tại` (khi có) |
| Tổng hợp | `Số ngày dữ liệu` (độ dài cửa sổ — mô hình nói được *"suy từ 19 ngày gần nhất"*, đúng luật nhãn form ngân sách ngày 2026-09-21) |

**Tệp:** `ai_edge/domain/hang_goi_y_han_muc.dart` (thuần — nhận danh sách đã có số, xếp và cắt) ·
`ai_edge/data/cong_cu_goi_y_han_muc.dart` (adapter — gọi `suggestAmount` cho từng danh mục; 16 danh mục = 16
truy vấn cộng, chấp nhận được).

**Mô tả (nháp):** *"Gợi ý hạn mức ngân sách MỖI THÁNG cho từng danh mục chi (theo TÊN): mức chi trung bình mỗi
tháng suy từ các ngày gần nhất, kèm hạn mức hiện tại nếu danh mục đã có ngân sách. Gọi khi hỏi nên đặt ngân sách
bao nhiêu, hạn mức có hợp lý không. danh_muc: tên một danh mục (tuỳ chọn)."*

### 3.8 Tool `tim_giao_dich` và hàm thuần `timGiaoDich`

**Tham số** (đều tuỳ chọn):

| Tham số | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| `ky` | enum `kMaKy` (8 mã) | `thang_nay` | mục 3.4 |
| `so_tien_tu`, `so_tien_den` | số đồng | — | chuỗi chữ số nhận; còn lại từ chối kèm ví dụ `500000`; `tu > den` từ chối |
| `chieu` | `khoan_chi` · `khoan_thu` · `chuyen_vi` · `tat_ca` | `tat_ca` | ⚠️ **không** dùng giá trị `'chi'` / `'thu'` trần — test quét 14 cấm hai chuỗi ấy trong `ai_edge/` |
| `danh_muc`, `vi` | tên | — | `khopTheoTen` trên danh mục / ví **còn sống** (`watchDanhMuc` / `watchVi`) |
| `tu_khoa` | chuỗi | — | tìm trong ghi chú, không phân biệt dấu (luật sẵn có của `applyTransactionFilter`) |
| `sap_xep` | `so_tien` · `moi_nhat` | `so_tien` | `moi_nhat` cho *"lần gần nhất / gần đây"* |

**`lib/features/transaction/domain/tim_giao_dich.dart`** — thuần, **ngoài** `ai_edge` (test quét 14 cấm
`walletId` và phép so chiều tiền trong `ai_edge/`, mà lọc theo ví thì không tránh được hai thứ ấy):

```dart
enum ChieuTim { chi, thu, chuyen, tatCa }
enum SapXepTim { soTien, moiNhat }

class TieuChiTim {
  final ChieuTim chieu; final KhoangTien? khoangTien; final String? tenDanhMuc;
  final String? tenVi; final String tuKhoa; final SapXepTim sapXep;
}

class DongTimThay {        // một giao dịch, đã tra tên — ai_edge chỉ CHÉP
  final String tieuDe;     // = tieuDeGiaoDich(...) — MỘT luật với tiêu đề dòng Sổ giao dịch (bước 6 dưới)
  final String tenDanhMuc; final String tenVi; final String? tenViDich;
  final double soTien; final ChieuTim chieu; final DateTime ngay;
}

class KetQuaTimGiaoDich {
  final List<DongTimThay> dong;        // ≤ toiDa, đã xếp
  final int soKhop;                    // MỌI khoản khớp
  final double tongChi, tongThu, tongChuyen;
  final List<String> tenKhop;          // tên thật đã khớp tham số
  final String? loi;                   // tên không khớp / nhiều khớp
  final List<String> tenGoiY;          // tên thật để mô hình gọi lại
}

KetQuaTimGiaoDich timGiaoDich({
  required List<TransactionEntity> trongKy, required TransactionLookup lookup,
  required List<LuaChonLoc> viSong, required List<LuaChonLoc> danhMucSong,
  required TieuChiTim tieuChi, required DateTime now, int toiDa = kToiDaMucMoiGoi,
});
```

Các bước, theo thứ tự:

1. Khớp `tenDanhMuc` / `tenVi` bằng `khopTheoTen` → id, hoặc trả `loi` + `tenGoiY`.
2. Lọc bằng **`applyTransactionFilter`** với `TransactionFilter(type, walletId, categoryId, query, khoangTien)`
   — định nghĩa duy nhất của bộ lọc Sổ giao dịch (ví khớp **cả** ví đích của khoản chuyển; từ khoá không dấu;
   khoảng tiền qua `KhoangTien.chua`). `chuyen` ⇔ `TransactionTypeFilter.transfer`; `tatCa` ⇔ `all`.
3. **Bỏ** khoản điều chỉnh số dư (`laKhoanDieuChinh`) và khoản mở sổ (`laKhoanMoSo`) — ghi sổ, không phải
   thu chi. Khoản **chuyển** giữ lại khi `chieu` là `chuyen` hoặc `tatCa`.
4. **Bỏ khoản ghi ngày sau `now`** (mục 1.2 hàng 11).
5. `soKhop` và ba tổng tính trên **mọi** khoản còn lại (`summarizeTransactions` cho thu/chi; tổng chuyển cộng ở
   đây — không ở `ai_edge`).
6. Xếp: `soTien` giảm dần, hoặc `moiNhat` theo ngày giảm dần; lấy `toiDa`; dựng `DongTimThay` với tên từ
   `lookup` (danh mục kể cả đã xoá mềm; `null` → *Chưa phân loại* trong chữ trạng thái).
   **Tên hàng** theo đúng luật tiêu đề dòng của Sổ giao dịch: ghi chú → tên danh mục → nhãn loại
   (`transactionTypeLabel`: *Khoản chi · Khoản thu · Chuyển khoản*). Luật ấy hiện nằm **trong**
   `buildTransactionRowContent` (tầng giao diện, **4** chỗ gọi trong `lib/` — đếm bằng máy 2026-09-23; bản
   nháp ghi 5) → **tách** thành hàm thuần `tieuDeGiaoDich` ở
   `transaction/domain/` và cho widget gọi lại nó — một định nghĩa, khuôn `viChoGoiSoTu` của 4b. Chép lại luật
   ở hàm tìm là bản thứ hai, và hai bản sẽ lệch nhau ngày một bên đổi.

**Adapter** `ai_edge/data/cong_cu_giao_dich.dart`: kiểm và dịch tham số → `kyTuMa` →
`watchKhoang(idaccount, ky.from, ky.to).first` · `lookupFor(idaccount)` · `watchVi` / `watchDanhMuc` `.first` →
`timGiaoDich` → `hangGiaoDich`.

**`ai_edge/domain/hang_giao_dich.dart`** (thuần — chỉ chép):

| Phần | Nội dung |
|---|---|
| Tên hàng | `tieuDe` |
| Trạng thái | *"khoản chi · ‹danh mục› · ‹ví›"* / *"khoản thu · …"* / *"chuyển ví · ‹ví› → ‹ví đích›"* |
| Số (đều mang `ten`) | `Số tiền` · `Ngày` (`soNgayThang`) |
| Tổng hợp | `Số khoản` (đếm) · `Tổng chi` (khi chiều gồm chi) · `Tổng thu` (khi gồm thu) · `Tổng chuyển` (khi gồm chuyển) · `Từ` / `Đến` (khoảng tiền đã hiểu, khi có) |
| Chữ kèm | `ky` (chữ kỳ) · `sap_xep` (*lớn nhất trước* / *mới nhất trước*) |
| `tenLienQuan` | mọi tên danh mục / ví trong trạng thái + `tenKhop` + `tenGoiY` |

⚠️ **Tên dài giữ nguyên độ chặt.** Ghi chú hệ thống như *"Tích lũy mục tiêu: MuaXe"* là tên hàng, và `kiemNhan`
đòi câu nêu **đủ** mọi âm tiết của tên; mô hình rút gọn thì câu rơi về mẫu câu (an toàn). Ghi nhận để phép đo
quan sát — **không** nới.

**Mô tả (nháp):** *"Tìm và liệt kê TỪNG giao dịch (ghi chú, số tiền, ngày, danh mục, ví) theo kỳ, khoảng số tiền,
chiều tiền (khoản chi, khoản thu, chuyển ví), danh mục, ví, từ khoá trong ghi chú. Gọi khi hỏi đã tiêu gì,
những khoản nào, khoản trên hay dưới một số tiền, lần gần nhất là khi nào. Tổng chi theo danh mục thì dùng
chi_tieu_theo_ky. so_tien_tu, so_tien_den: số đồng, ví dụ 500000."*

### 3.9 Luật từ chối tham số — chung cho ba tool mới

| Tham số | Từ chối khi | Lời từ chối kèm |
|---|---|---|
| enum (`ky`, `chieu`, `sap_xep`) | giá trị ngoài danh sách | danh sách giá trị đúng (khuôn `loiMaKy` của 4b) |
| tiền | không phải số hay chuỗi chữ số, hoặc âm | *"… phải là số đồng, ví dụ 500000"* |
| khoảng tiền | `so_tien_tu > so_tien_den` (`KhoangTien.hopLe` sai) | nêu hai số đã nhận |
| tên | `KhongKhop` / `KhopNhieu` | danh sách tên thật (vào `tenLienQuan`) |

Tham số **lạ** (không khai báo) thì bỏ qua, không từ chối. Tool từ chối vẫn **tính là đã chạy** (chốt L1 của
4b không đổi) và vẫn tốn một suất trong trần 3.

### 3.10 Prompt, dòng chỉ báo, trần token

- `kPromptHeThongCongCu`: liệt kê thêm *mục tiêu · gợi ý hạn mức · giao dịch*; dặn **chép nguyên ngày dạng
  `12/09`** như đã dặn chép nguyên chuỗi số.
- `cauDangTraCuu`: *"Đang tra cứu mục tiêu…"* · *"Đang tính gợi ý hạn mức…"* · *"Đang tìm giao dịch…"*.
- **Trần token** — `maxTokens: 2048` ở `slm_runtime.dart:110` là trần **tổng** (vào + ra; bẫy 4.29). Bốn khai
  báo hiện là **1.798** ký tự `tools_json`. **Task 3 đo trước khi dựng tool**: bảy khai báo + phiên dài nhất (ba
  lời gọi, mỗi lời một tool nặng). Vượt → `maxTokens: 4096`, đo **RAM đỉnh** và **thời gian nạp** trên cả hai
  máy so với 2.048. **Giữ 4.096** khi không sập, không bị hệ thống giết, và RAM đỉnh tăng **≤ 0,5 GB**; vượt
  mức ấy thì **dừng và báo người dùng**.

---

## 4. Những gì bước này KHÔNG làm

- **Tool ghi** — bất biến ④ nguyên vẹn; đổi ④ là việc của bước 3–4, có spec riêng.
- **Bảng quy đổi *"k / củ / lít"*** — bước 3.
- **Ngày cho sáu gói số cũ** — `LoaiSo.ngayThang` chỉ dùng ở hàng giao dịch.
- Nới luật *"câu nêu đủ tên"* của `kiemNhan` cho tên dài.
- Tổng theo danh mục trong `tim_giao_dich` — việc của `chi_tieu_theo_ky`.
- Khối giao diện mới, Stitch; đổi schema (v24), payload đồng bộ, `pubspec`. `maxTokens` là hằng của client.
- Đổi `GoiSoMucTieu` / khối Nhận xét.

---

## 5. Ra cổng D — đo trên máy thật

### 5.1 Điều kiện

APK **release**, tài khoản 10, **Realme RMX2205 bắt buộc** (CPU, máy yếu hơn — ngưỡng chấm trên máy này);
OnePlus 13R nếu cắm được (ghi thêm, không chấm ngưỡng). Gõ bằng `adb shell input text`, **không dấu, chữ
thường** cho tên riêng (bẫy 4.28 làm hỏng chữ hoa giữa từ); chụp màn kiểm chữ đã vào. Ghi logcat **thẳng ra
tệp** trong lúc chạy (bẫy của 9.13).

**Ghi mỗi câu:** tool + tham số của **từng** lời gọi (dòng `[SLM][tool]`), số lượt, token đầu, tổng thời gian,
ô kết quả bốn cột như bảng 5.6 (✅ · MẪU · SAI · LỆCH). **Ghi mỗi phiên:** độ dài `tools_json`; lỗi *"too
long"* nếu có. Nếu đã nâng 4.096: RAM đỉnh và thời gian nạp.

### 5.2 Nhóm A — hồi quy cổng C (8 câu, mục 9.14)

13 · 15 · 8 · 3 · 2 · 9 · ĐC1 · ĐC2, gõ đúng như 9.14. **Đạt:** nhóm *"cái nào"* (13, 15, 8, 3) Realme **4/4**
như 9.14; câu 2 và 9 đúng; ĐC1 **không bịa số**; ĐC2 không tụt.

### 5.3 Nhóm B — hai tool đọc mới (4 câu) + câu bước 1c

| # | Câu gõ | Tool đúng | Tham số |
|---|---|---|---|
| B1 | `khi nao toi dat muc tieu muaxe` | `danh_sach_muc_tieu` | — |
| B2 | `moi thang toi can de danh bao nhieu cho muaxe` | `danh_sach_muc_tieu` | — |
| B3 | `thang sau toi nen dat ngan sach bao nhieu` | `goi_y_han_muc` | — |
| B4 | `ngan sach an uong nen dat bao nhieu` | `goi_y_han_muc` | `danh_muc` khớp **Ăn uống** |
| 1c | `hoa don di h0c con phai tra bao nhieu` | `danh_sach_hoa_don` | tuỳ |

**Đạt:** B1–B4 **≥ 3/4** trả lời đúng tên + số, SAI = 0. Câu 1c: câu trả lời nêu *"di h0c"* **được hiện** (logcat
không có dòng *"trượt kiểm → mẫu câu (L2)"*).

### 5.4 Nhóm C — 20 câu lệnh tìm giao dịch

**Chấm theo lời gọi ĐẦU TIÊN** của mỗi câu (ở chiều ghi, lời gọi đầu là thứ người dùng thấy trên form); lời gọi
sau (nếu có) ghi lại để phân tích. **Đúng tool** = gọi `tim_giao_dich`. **Đúng tham số** = mọi tham số **bắt
buộc** đúng theo đáp án; tham số đánh dấu *tuỳ* thì bỏ trống hay đặt giá trị mặc định đều được. Tên so như
`khopTheoTen` (không dấu cũng đúng); `tu_khoa` đúng khi bỏ dấu + chữ thường vẫn chứa từ lõi của đáp án. Cột
*kết quả mong đợi* là của dữ liệu **ngày 2026-09-23** — ngày đo đọc lại Sổ giao dịch cùng kỳ để chấm câu trả lời.
Cột ấy **đếm bằng script** trên CSDL máy ảo, áp đúng luật mục 3.8 (không đếm tay) — và chéo được một con số:
tổng thu tháng 9 của C10 ra **15.135.000**, đúng số trang Phân tích sau bước 1a.

| # | Câu gõ | Tham số bắt buộc | Tuỳ | Kết quả mong đợi (dữ liệu 23/09) |
|---|---|---|---|---|
| C1 | `thang nay toi tieu gi tren 500k` | `ky=thang_nay` · `chieu=khoan_chi` · `so_tien_tu=500000` | `sap_xep` | 2 khoản: Cho vay 800.000 (19/09) · *Tích lũy mục tiêu: MuaXe* 500.000 (05/09) |
| C2 | `hom qua toi da chi nhung gi` | `ky=hom_qua` · `chieu=khoan_chi` | — | 0 |
| C3 | `hom nay toi co giao dich nao khong` | `ky=hom_nay` | `chieu` | 0 |
| C4 | `tuan nay co khoan chi nao duoi 100 nghin khong` | `ky=tuan_nay` · `chieu=khoan_chi` · `so_tien_den=100000` | — | 0 |
| C5 | `tuan truoc toi da tieu nhung khoan nao` | `ky=tuan_truoc` · `chieu=khoan_chi` | `sap_xep` | 4 khoản (14–20/09): Cho vay 800.000 · hai khoản hoá đơn 123.000 · Di chuyển 50.000 |
| C6 | `thang truoc toi co khoan chi nao tren 1 trieu khong` | `ky=thang_truoc` · `chieu=khoan_chi` · `so_tien_tu=1000000` | — | 0 — câu phải nói *không có* |
| C7 | `cac khoan chi hon nua trieu trong quy nay` | `ky=quy_nay` · `chieu=khoan_chi` · `so_tien_tu=500000` | — | như C1 |
| C8 | `nam nay toi co khoan thu nao tu 5 trieu tro len khong` | `ky=nam_nay` · `chieu=khoan_thu` · `so_tien_tu=5000000` | — | 2: Lương 9.000.000 · Lương 5.000.000 |
| C9 | `liet ke cac khoan chi tu 200k den 1 trieu thang nay` | `ky=thang_nay` · `chieu=khoan_chi` · `so_tien_tu=200000` · `so_tien_den=1000000` | — | 2: Cho vay 800.000 · MuaXe 500.000 |
| C10 | `thang nay toi nhan duoc nhung khoan thu nao` | `ky=thang_nay` · `chieu=khoan_thu` | `sap_xep` | 8 khoản (bỏ khoản điều chỉnh); 4 lớn nhất: 9.000.000 · 5.000.000 · hai khoản 500.000 |
| C11 | `thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao` | `ky=thang_nay` · `chieu=chuyen_vi` · `vi` khớp **Tiết kiệm** | `sap_xep` | 10 khoản chuyển; lớn nhất 900.000 · 700.000 · 300.000 · 100.000 |
| C12 | `liet ke cac khoan an uong thang nay` | `ky=thang_nay` · `danh_muc` khớp **Ăn uống** | `chieu` | 1: Ăn uống 50.000 (04/09) |
| C13 | `vi tien mat thang nay chi nhung gi` | `ky=thang_nay` · `vi` khớp **Tiền mặt** · `chieu=khoan_chi` | `sap_xep` | 13 khoản; lớn nhất 800.000 · 500.000 · 180.000 · 123.000 |
| C14 | `thang nay toi chi gi cho mua sam tu vi tien mat` | `ky=thang_nay` · `danh_muc` khớp **Mua sắm** · `vi` khớp **Tiền mặt** · `chieu=khoan_chi` | — | 1: Mua sắm 60.000 |
| C15 | `lan gan nhat toi chi cho di chuyen la ngay nao` | `danh_muc` khớp **Di chuyển** · `chieu=khoan_chi` · `sap_xep=moi_nhat` | `ky` | Di chuyển 50.000, **20/09** |
| C16 | `5 khoan chi gan day nhat cua toi` | `chieu=khoan_chi` · `sap_xep=moi_nhat` | `ky` | 4 hàng (trần), mới nhất 20/09 |
| C17 | `tim cac giao dich co ghi chu hoa don` | `tu_khoa` ∋ *hoa don* | `ky` · `chieu` | 5 khoản *Thanh toán hóa đơn: …* |
| C18 | `khoan chi lon nhat thang nay la gi` | `ky=thang_nay` · `chieu=khoan_chi` | `sap_xep=so_tien` | Cho vay 800.000 |
| C19 | `cac khoan chi cho giao duc tu vi test` | `danh_muc` khớp **Giáo dục** · `vi` khớp **test** · `chieu=khoan_chi` | `ky` | 2: *test* 35.000 · Giáo dục 10.000 |
| C20 | `lan cuoi toi nap tien cho muc tieu muaxe la ngay nao` | `tu_khoa` ∋ *muaxe* · `sap_xep=moi_nhat` | `ky` · `chieu` (`tat_ca` / `chuyen_vi`) | **08/09** (100.000) — **không** phải 10/11 (khoản hẹn trước bị bỏ, mục 3.8 bước 4) |

Phủ: 8/8 mã kỳ · bốn cách viết khoảng tiền (*"500k"*, *"100 nghin"*, *"200k den 1 trieu"*, *"nua trieu"*,
*"5 trieu tro len"*) · ba chiều · danh mục và ví theo tên gõ không dấu (C19 thử ví **test** trùng tên một danh
mục) · từ khoá · `sap_xep` (C15, C16, C20) · cột ngày (C15, C20) · câu **0 kết quả** (C2, C3, C4, C6).

### 5.5 Ngưỡng — cổng D ĐẠT khi cả năm dòng đạt

1. Nhóm A không tụt (5.2).
2. Nhóm B ≥ 3/4, câu 1c được hiện (5.3).
3. Nhóm C: **≥ 18/20** đúng tool · **≥ 16/20** đúng mọi tham số bắt buộc.
4. **SAI = 0** trên cả ba nhóm; **0** lần sập (`FATAL` / `SIGSEGV` / `SIGBUS` trong logcat).
5. Không phiên nào lỗi *"too long"*.

Dưới ngưỡng dòng 3 → chỉnh mô tả tool / tham số, đo lại nhóm C; **chưa mở bước 3**. Trượt dòng khác → ghi
bảng, phân tích, quyết tiếp bằng số (khuôn cổng C).

---

## 6. Bẫy đã biết trước, phải canh

| # | Bẫy | Hỏng thế nào |
|---|---|---|
| 1 | Viết `'chi'` / `'thu'` / `walletId` trong `ai_edge/` | test quét 14 đỏ — giá trị enum là `khoan_chi` / `khoan_thu`, phép lọc nằm ở `transaction/domain/` |
| 2 | Tự viết lại bộ lọc thay vì gọi `applyTransactionFilter` | bản thứ hai của luật lọc Sổ giao dịch — ví đích của khoản chuyển bị quên, im lặng |
| 3 | Quên bỏ khoản ngày tương lai | *"lần cuối"* trả về 10/11 — việc chưa xảy ra (C20 canh) |
| 4 | Quên bỏ khoản điều chỉnh / mở sổ | *"khoản thu nào"* liệt kê một phép sửa sổ như thu nhập (C10 canh) |
| 5 | `?? 0` cho số `null` của tool mục tiêu / gợi ý | bịa một lời hứa (*"cần thêm 0 ngày"*) |
| 6 | Ngày dạng `dd/mm/yy`, `45/13` được đọc là ngày | mở cửa cho số bịa — chỉ `dd/mm` và `dd/mm/yyyy` hợp lệ |
| 7 | Số trần khớp mục ngày (hay ngược lại) | *"còn 12 ngày"* lọt nhờ ngày `12/09` — loại phải khớp |
| 8 | Khớp tên bằng chuỗi con | *"tiết kiệm"* khớp *"tiết kiệm mua nhà"* — khớp phải là **bằng nhau** sau chuẩn hoá |
| 9 | Đổi `kMaKy` mà không đo lại `chi_tieu_theo_ky` | khai báo tool cũ đổi, độ chọn tool có thể đổi theo (nhóm A canh) |
| 10 | Đếm tổng trên 4 hàng thay vì mọi khoản khớp | C13 có **13** khoản, tổng chi **2.031.000**; tổng của 4 hàng hiện ra chỉ **1.603.000** — sai im lặng |
| 11 | `adb shell input text` với chữ hoa giữa từ | `MuaXe` → `Mũae` (4.28) — câu đo dùng chữ thường |
| 12 | Ca test xanh ngay từ đầu | thử **bản sai có chủ ý** — luật dự án |
| 13 | Gọi thêm một nguồn danh sách ví trực tiếp (DAO) | `wallet_picker_sources_test` đòi phân loại tay — thiết kế này chỉ đi qua `lookupFor` / `watchVi` (đã phân loại) |
| 14 | Danh sách khớp tên lẫn **hàng khuôn mặc định toàn cục** (`idaccount = 0`) | mọi tên danh mục mặc định khớp hai hàng → `KhopNhieu` → tool luôn từ chối *"ăn uống"*, im lặng với người dùng (mục 3.3) |

---

## 7. Test

- **TDD** từng task; bản sai có chủ ý cho mọi ca xanh ngay.
- Thuần: `kiem_so_test` (ngày: tách trước số · khớp ngày/tháng · năm chỉ so khi có · số trần không khớp mục
  ngày · dạng không hợp lệ không là ngày) · `khop_ten_test` (chính xác · bỏ dấu · nhiều · không · không chuỗi
  con) · `hang_chi_tieu_test` (ba mã kỳ mới) · `goi_so_tra_cuu_test` (`tenLienQuan` vào `tenDoiTuong`; mẫu câu
  có ngày tự qua bộ kiểm) · `hang_muc_tieu_test` · `hang_goi_y_han_muc_test` · `hang_giao_dich_test` ·
  `tim_giao_dich_test` (lọc qua `applyTransactionFilter`; bỏ điều chỉnh / mở sổ / ngày tương lai; khoản chuyển
  theo chiều; tổng trên mọi khoản; hai kiểu xếp; trần; tên không khớp / nhiều khớp) · `tieu_de_giao_dich_test`
  (ghi chú → tên danh mục → nhãn loại; khoản chuyển không ghi chú là *Chuyển khoản*) — và ca cũ của
  `buildTransactionRowContent` xanh nguyên sau khi tách.
- Adapter: ba tệp `cong_cu_*_test` với repository giả — từ chối tham số (mục 3.9), tham số lạ bỏ qua.
- `bo_cong_cu_test`: bảy tool, thứ tự khai báo.
- Widget: `ai_chat_page_test` — ba nhãn chỉ báo mới.
- **Không** thêm test quét; test quét 14 và 16 giữ nguyên và phải xanh. Schema v24, payload, `pubspec` không đổi.
- Mức nền trước bước: `flutter test` **3603/3603** (3 skip); `flutter analyze` **26**, 0 error.

## 8. Phác kế hoạch (viết chi tiết bằng `writing-plans`)

1. `LoaiSo.ngayThang` + `soNgayThang`; `trichSo` tách ngày trước số; `_khop` cho ngày.
2. `khopTheoTen` (`core/utils/khop_ten.dart`); `kMaKy` thêm ba mã; `KetQuaCongCu.tenLienQuan` +
   `GoiSoTraCuu.tenDoiTuong`.
3. **Spike trên điện thoại** (móc tạm, **không commit**): khai báo đủ bảy tool, đo `tools_json` và phiên dài
   nhất; vượt trần → `maxTokens: 4096` + RAM / thời gian nạp trên hai máy (mục 3.10). Task 4–7 là Dart thuần,
   không phụ thuộc con số này: chưa cắm được máy thì làm 4–7 trước, quay lại spike **trước** task 8.
4. Tool `danh_sach_muc_tieu` (hàm dựng hàng + adapter).
5. Tool `goi_y_han_muc`.
6. Hàm thuần `timGiaoDich` (`transaction/domain/`) + tách `tieuDeGiaoDich` khỏi `buildTransactionRowContent`
   (widget gọi lại — ca test cũ của dòng giao dịch phải xanh nguyên).
7. Tool `tim_giao_dich` (hàm dựng hàng + adapter) + `BoCongCu` bảy tool + DI + `cauDangTraCuu` + prompt.
8. Nối màn: nhãn chỉ báo; nghiệm thu máy ảo 411dp (nhánh L4 trên x86_64, không sọc `#FFFF00`).
9. **Đo cổng D** (mục 5) + tài liệu (`AI_EDGE_FEATURE.md` mục 9.17 + bẫy; `AI_AGENT_ARCHITECTURE.md` 5.6 /
   11 / 12; `PROJECT_CONTEXT.md` mục 14; `CLAUDE.md` hàng AI; bảng thứ tự; đơn `CAN-LAM` vòng hai nếu nó tả
   số tool của client; banner spec này).
