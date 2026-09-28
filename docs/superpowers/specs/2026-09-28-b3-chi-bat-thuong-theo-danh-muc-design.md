# B3 — Chi bất thường theo danh mục — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng mở lại quyết định 17/09** (*"bất thường" là ngưỡng người dùng đặt, không dùng
thống kê*) và duyệt bản thiết kế trong chat cùng ngày, với các lựa chọn: **trung vị + MAD** · ngưỡng **z hiệu chỉnh
> 3,5** · tháng đang chạy **chỉ khi đã vượt thật** · **giữ riêng** với *Khoản chi lớn* · **không** thêm tool cho Trợ lý AI.
Vị trí trong lộ trình 28/09: B1 → B5a → B2 → **B3** → B4 → B5b. **Không đổi schema.**

## 1. Vì sao, và vì sao lần này khác 17/09

*Khoản chi lớn* (17/09) trả lời câu *"một khoản có quá lớn không"*, bằng một ngưỡng người dùng tự đặt. Nó cố ý không
dùng thống kê, vì khi ấy tài khoản mới có 8 ngày dữ liệu: luật thống kê sẽ im hàng tháng rồi nổ bừa khi vừa đủ mẫu.

B3 trả lời một câu **khác**: *"tháng này cả danh mục X có lạ so với chính tôi không"*. Không ngưỡng tay nào làm được việc
này cho mười mấy danh mục. Hai lo ngại của 17/09 được xử lý trực tiếp:

- **Im khi thiếu mẫu:** cần **≥ 4 tháng đã đóng** có phát sinh, không đủ thì **im hẳn**. Tài khoản thật im tới khoảng
  tháng 1/2027, và đó là hành vi đúng.
- **Nổ bừa:** z > 3,5 là ngưỡng chặt, ưu tiên bỏ sót hơn báo nhầm, cộng thêm một ngưỡng tiền tuyệt đối.

*Khoản chi lớn* **không đổi gì**.

## 2. Hàm thuần — `lib/features/analytics/domain/chi_bat_thuong.dart`

**Đầu vào:** `List<KhoanThuChi> khoan` (đúng kiểu `analytics_repository_impl` đang dựng; mang `classify` và `ghiChu`),
tháng đang xét `thang` (`DateTime` bất kỳ trong tháng), `now`, và `double nguong`.

**Chuỗi:** chi theo `categoryId` theo **tháng lịch**, chỉ gồm khoản có `phanLoaiCua(loai:, classifyDanhMuc:) == 'chi'`
**và** `khoanVaoThongKe(...)`. Đây đúng là định nghĩa nhóm *Chi* của donut (mục 3.19 `ANALYTICS_FEATURE.md`), nên vay/nợ,
khoản chuyển, điều chỉnh số dư và mở sổ đều bị loại. Khoản không danh mục thì bỏ qua (không có danh mục để nói).

**Với mỗi danh mục có chi trong tháng đang xét** (`x` = tổng chi của danh mục trong tháng ấy, **tính tới `now`** nếu tháng
chứa `now`; không dự phóng):

1. **Lịch sử** = tổng chi của danh mục trong **tối đa 12 tháng lịch đã đóng** ngay trước `thang`, **chỉ lấy tháng có
   phát sinh** (> 0). Không lấy tháng 0 đồng: danh mục chi thưa (du lịch) sẽ có trung vị 0, và mọi lần chi đều thành bất
   thường.
2. Lịch sử **< 4** tháng → bỏ qua danh mục ấy.
3. `m = trungVi(lichSu)`, `mad = trungVi(|xi − m|)`.
   - `mad > 0` → `z = 0,6745 × (x − m) / mad`.
   - `mad == 0` → `meanAd = trungBinh(|xi − m|)`. Nếu `meanAd > 0` thì `z = (x − m) / (1,2533 × meanAd)` (Iglewicz–Hoaglin).
   - Cả hai bằng 0 (lịch sử y hệt nhau) → `z = x > m ? +∞ : 0`.
4. **Bất thường** ⇔ `z > 3,5` **và** `x − m > nguong`.

**Kết quả** `List<ChiBatThuong>`, xếp theo `vuot = x − m` giảm dần: `categoryId`, `chi` (x), `thuongLe` (m), `soThangMau`,
`vuot`. Tên danh mục tra ở tầng repository (bảng tra tên dùng chung `getBangTraTen`, quy tắc 8).

## 3. Ngưỡng có nghĩa — một định nghĩa, không phụ thuộc ngược

`nguong = nguongCoNghia(thuNhapMoiThang)` = `max(1 % thu nhập mỗi tháng, 50.000)`, **cùng** phép neo của luật tái phân bổ.
Hôm nay nó nằm ở `ai_edge/domain/tai_phan_bo.dart`, và phép tính thu nhập mỗi tháng nằm **trong** `TaiPhanBoNguonImpl`
(`budget/data/tai_phan_bo_nguon.dart:137`). Analytics không được import `ai_edge`, nên B3 **dời**:

- `nguongCoNghia` (kèm `_neo` và `kNguongThamHutTuyetDoi` nếu cần) sang `analytics/domain/nguong_co_nghia.dart`.
  `tai_phan_bo.dart` import lại và **giữ nguyên** mọi tên đang dùng (`nguongThamHutTuyetDoi` vẫn là một tên riêng).
- Phần **thuần** của `_thuNhapMoiThang` (từ danh sách `KhoanThuChi` và cửa sổ ra số tiền) sang
  `analytics/domain/thu_nhap_moi_thang.dart`: `double thuNhapMoiThangTu(List<KhoanThuChi> khoan, CuaSoNhinLai cuaSo)`.
  `TaiPhanBoNguonImpl` gọi lại hàm ấy. Chép thêm một bản là để luật *"thu nhập không gồm tiền đi vay"* (bẫy A8 #8) có
  hai định nghĩa.
- Hai phép dời **không đổi hành vi**. Toàn bộ test của `tai_phan_bo` và `tai_phan_bo_nguon` phải xanh nguyên.

## 4. Nguồn — `ThongKeKy.chiBatThuong`

- Trường mới `final List<DongChiBatThuong>? chiBatThuong;` (`DongChiBatThuong` = `ChiBatThuong` + `ten`). `null` khi đơn vị
  **không** phải Tháng: B3 không xét tuần / quý / năm / tuỳ chọn. Danh sách rỗng nghĩa là *đã xét, không có gì lạ*.
- Tính trong `AnalyticsRepositoryImpl.watchKy`, trên chính danh sách `khoan` repository đã dựng từ **toàn bộ** giao dịch.
  Không thêm stream. `thuNhapMoiThang` dùng `cuaSoNhinLai(now, mốc đầu tiên)` như `TaiPhanBoNguonImpl`; cửa sổ `null` thì
  `nguong` = sàn 50.000.
- ⚠️ `watchKy` phát lại sau **mọi** chu kỳ đồng bộ. Phép tính O(số giao dịch), ổn với vài nghìn hàng, nhưng **không**
  được đọc CSDL lần nữa bên trong.

## 5. Hiện — khối Nhận xét trang Phân tích

`GoiSoPhanTich.tu(tk)` đọc `tk.chiBatThuong`:

- Có ≥ 1 dòng → thêm hai `SoLieu` cho dòng **đầu**: `soTien('Chi bất thường', chi, ten: ten)` và
  `soTien('Thường lệ', thuongLe, ten: ten)`. Nếu > 1 dòng thì thêm `soDem('Số danh mục bất thường', n)`.
- `mauCau()` nối thêm: *"Riêng {ten} kỳ này đã chi {Chi bất thường}, cao hơn hẳn mức thường lệ {Thường lệ}."* và, nếu
  n > 1, *" Thêm {n − 1} danh mục khác cũng cao bất thường."* (con số ấy đi qua `soDem` riêng, không ghép tay). Mức
  nhận xét thành `canhBao`.
- ⚠️ Câu mở đầu bằng *"Kỳ này"* của gói không nêu tên tháng (chữ số của nhãn kỳ sẽ bị `kiemSo` chặn). Câu B3 theo cùng
  nếp: nói *"kỳ này"*, không nói *"tháng 9"*.
- `kyCua`: *Chi bất thường* thuộc `{chuKy}` (số của kỳ); *Thường lệ* và *Số danh mục bất thường* trả `null` (không thuộc
  kỳ nào). Thiếu vế này thì lớp chắn thứ sáu `kiemKy` có thể chặn câu đúng.
- Nhãn *Chi bất thường* chứa chữ *"chi"*: kiểm với `kiemNhan` (bẫy 4.42, `nhanXungDot`) bằng ca *"mẫu câu tự qua sáu
  lớp chắn"*.
- Bậc 1 của Trợ lý AI (`NguonGoiSo`) đọc cùng gói nên tự có. **Không** thêm tool (người dùng chốt; trần `tools_json`).

## 6. Không làm

Không thông báo. Không đụng *Khoản chi lớn*. Không dự phóng tháng đang chạy. Không xét đơn vị khác Tháng. Không đổi
schema, không thêm trường đồng bộ.

## 7. Kiểm thử

- **`chi_bat_thuong` (hàm thuần):** sáu tháng *Ăn uống* quanh 900.000 và tháng xét 2.400.000 → bất thường; 1.100.000 → không;
  3 tháng lịch sử → im; lịch sử có tháng 0 đồng → tháng ấy không tính mẫu; **MAD = 0** (bốn tháng đúng 500.000) và tháng
  xét 800.000 với ngưỡng 50.000 → bất thường (nhánh meanAd = 0 → z = +∞); cùng dữ liệu, ngưỡng 400.000 → không (vế tiền
  chặn); khoản chuyển / điều chỉnh / vay-nợ không vào chuỗi; tháng đang chạy dùng số tới `now`; xem **tháng đã qua** thì
  lịch sử là các tháng **trước nó**; xếp theo phần vượt; tháng 12 → lịch sử lùi qua năm trước; **tháng 2 năm nhuận** không
  làm lệch biên tháng.
- **Phép dời (§3):** toàn bộ test hiện có của `tai_phan_bo` / `tai_phan_bo_nguon` xanh không sửa kỳ vọng; một ca mới canh
  `thuNhapMoiThangTu` trả **đúng** số `TaiPhanBoNguonImpl` từng trả trên cùng dữ liệu.
- **Repository:** đơn vị Tháng → `chiBatThuong` không `null`; đơn vị Tuần → `null`; tên tra được cho danh mục mặc định
  (`idaccount = 0`, G41).
- **Gói số:** câu có tên + hai số, qua **sáu** lớp chắn; > 1 dòng có câu *"Thêm … danh mục khác"*; không có dòng nào thì
  câu cũ y nguyên (mọi ca `goi_so_phan_tich` cũ xanh).
- **Máy ảo:** ghi lùi ngày chi *Ăn uống* 5 tháng liền (tháng 4–8/2026) quanh 900.000, tháng 9 thêm cho đủ 2.400.000; xem
  Phân tích tháng 9 → khối Nhận xét có câu B3; chuyển sang Tuần → câu biến mất. Đo trên máy ảo vì dữ liệu ghi lùi ngày
  phải là dữ liệu **thử**, không đẩy lên tài khoản thật.

## 8. Tài liệu đi kèm

`ANALYTICS_FEATURE.md` thêm một mục *Chi bất thường theo danh mục* (luật, vì sao trung vị, vì sao khác 17/09, giới hạn).
`NOTIFICATION_FEATURE.md` mục *Khoản chi lớn*: một câu *"B3 (2026-09-xx) trả lời câu khác, không thay luật này"*.
`AI_EDGE_FEATURE.md`: nhãn mới của `GoiSoPhanTich`. `CLAUDE.md` hàng *Đụng vào trang Phân tích*.
