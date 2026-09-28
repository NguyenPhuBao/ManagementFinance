# Mở rộng bộ tool của Trợ lý AI — bốn nhóm còn thiếu sau cổng E — thiết kế

**Ngày:** 2026-09-27 (đêm), sau cổng E lần 1 và hai vòng sửa (mục 9.32 `AI_EDGE_FEATURE.md`). **Người dùng duyệt** cả bốn
phần trong chat, và chọn lối **gộp vào tool có sẵn, ít tool mới** vì trần `tools_json` / `maxTokens`.

## 1. Vì sao — lỗ hổng phủ đo được

Đối chiếu 6 tool hiện có với 66 hàm domain thuần, 13 mảng, hai bộ câu đo (34 + 22) và bảng 20 câu chặng 3
(`AI_AGENT_ARCHITECTURE.md` 5.6). Mười ba loại câu **không trả lời được**, xếp theo mức người dùng gặp:

| # | Câu hỏi | Hàm domain đã có | Nhóm |
|---|---|---|---|
| 1 | *Còn tiêu được bao nhiêu? Ví có đủ trả hoá đơn không? Trả hết hoá đơn còn bao nhiêu?* (câu 16–17 chặng 3 — đòi phép trừ mô hình không được làm) | `duBaoCua` | A |
| 2 | *So với tháng trước / cùng kỳ năm trước chi nhiều hơn hay ít hơn?* (E13 ✗) | `tongThuChi` hai kỳ, `phanTramSoVoi`, `nenSoSanh` | A |
| 3 | Kỳ nêu **cụ thể**: *tháng 8, tuần 35, từ 1/9 đến 15/9, 3 tháng gần nhất, năm ngoái* — `ky` chỉ 9 mã cố định | `Ky.thang/tuan/quy/nam/tuyChon`, `lui` | A |
| 4 | *Thu nhập thật / tỉ lệ tiết kiệm / dòng tiền tự do* — E1 trả tổng thu gồm cả tiền thu nợ | `thuNhapCua`, `tyLeTietKiem`, `dongTienTuDo` | B |
| 5 | *Tôi có những danh mục nào?* — không tool nào liệt kê danh mục | `CategoryDao.getAll` | B |
| 6 | *Hoá đơn nào đến hạn tháng tới? Hoá đơn nào tự trả? Cố định mỗi tháng bao nhiêu?* | `kyKeTiepCua`, `Bills.autoPayEnabled` | C |
| 7 | *Ví đủ tiền trích tự động không? Kỳ trích tiếp là khi nào, bao nhiêu?* | `kyKeTiep`, `quyetDinhTrich`, `canhBaoViKhongDu` | C |
| 8 | *Nên chuyển bớt ngân sách từ đâu sang đâu?* | `taiPhanBoCua` + `TaiPhanBoNguon` | C |
| 9 | *Chi trung bình mỗi ngày? Ngày nào chi nhiều nhất? Khoản lớn nhất?* | `soLieuNhanhCua` | D (gộp vào B) |
| 10 | *Còn ai nợ tôi / tôi còn nợ bao nhiêu (ròng)?* | `vaiVayNoCua`, `chuoiVayNo` | D (gộp vào B) |
| 11 | *Tổng tài sản tăng hay giảm so với đầu kỳ?* | `tongTaiSanCua`, `thayDoiTaiSan` | D (gộp vào B) |
| 12 | Câu ngoài phạm vi (giá vàng, tỷ giá, thời tiết) bị ép vào tool (E22) | `chuDeBiChan` | D |
| 13 | *Có thông báo gì mới?* | bảng cục bộ `AppNotifications` | **không làm** (ưu tiên thấp, người dùng không chọn) |

Hạng 1 và 2 là đúng chỗ bất biến *"lớp AI không tính"* chặn — chỉ giải được bằng tool trả **con số đã trừ sẵn**. Hạng 3 là
lỗ hổng rộng nhất: mọi câu nêu tháng / khoảng cụ thể hiện rơi về *tháng này* hoặc *mọi thời gian*.

## 2. Ràng buộc khoá

- Bốn bất biến `AI_AGENT_ARCHITECTURE.md` §6 giữ nguyên: **không tool nào ghi**; mọi số từ hàm domain đã có; mô hình chỉ
  điền tham số; câu hiện ra phải qua bốn lớp chắn.
- Trần: `tools_json` hiện **6.031** ký tự, `maxTokens` **4.096** (trần TỔNG input + output; từng vỡ ở 2.048 — bẫy 4.29/4.39).
  Ước sau ba lát ≈ **7.600**. Spike Realme **sau mỗi lát**; vỡ trần (`FAILED_PRECONDITION`) thì đề xuất nâng 4.096 → 6.144
  kèm đo RAM đỉnh và **hỏi người dùng trước khi nâng** (họ chọn lối này, không cho phép nâng sẵn).
- Test quét 14: không chuỗi `'chi'` / `'thu'` trần trong `ai_edge/`; test quét 16: chỉ `slm_runtime.dart` import gemma.
- `kToiDaMucMoiGoi` = 4 hàng giữ cho mọi tool **trừ** `danh_sach_danh_muc` (trần riêng 20, hàng không số).
- Mọi số trong `chuThem` bị cấm (câu chép sẽ bị chặn) — chữ so sánh *"nhiều hơn" / "ít hơn"* đi `chuThem`, con số đi `tongHop`.
- Nhãn mới phải tự qua `kiemNhan` với câu tự nhiên: mỗi nhãn có test *"mẫu câu của gói tự qua kiemSo + kiemNhan"* như các
  `hang_*_test` hiện có.

## 3. Phần 1 — mở rộng `truy_van_giao_dich`

### 3.1 Kỳ tự do: `tu_ngay`, `den_ngay`, mã `tuy_chon`

- Khai báo thêm `tu_ngay`, `den_ngay` (chuỗi `dd/mm/yyyy`; `den_ngay` **bao gồm** ngày ấy — tool cộng một ngày để thành biên
  mở `[from, to)`); `ky` thêm mã `tuy_chon` = *"khoảng nêu bằng tu_ngay/den_ngay"*. Mô tả: *"câu nêu tháng, quý, năm cụ thể
  hay hai mốc ngày thì ky=tuy_chon và điền hai mốc; câu không nêu kỳ thì moi_luc"*.
- **Bộ chỉnh là nguồn chính** (`chinhThamSoTimGiaoDich`, luật 11 — hàm thuần mới `kyTuCauHoi(String q, DateTime now) →
  ({DateTime from, DateTime to, String chu})?` ở `ma_ky.dart`): đọc *"tháng 8" / "tháng 8/2026" / "tháng 8 năm 2026"* →
  `Ky.thang`; *"quý 2"* → `Ky.quy`; *"năm ngoái / năm 2025"* → `Ky.nam`; *"tuần 35"* → `Ky.tuan` của thứ Năm tuần ISO ấy;
  *"từ 1/9 đến 15/9" / "từ 1/9/2026 tới 15/9"* → `tuyChon`; *"3 tháng gần nhất / 30 ngày qua / 2 tuần qua"* → `tuyChon`
  lùi từ hôm nay (đóng ở `now`, cùng lý do cửa sổ nhìn lại: không nuốt giao dịch ngày tương lai). Khớp được thì ghi đè
  `ky=tuy_chon` + hai mốc, ghi chú. Tháng nêu **không kèm năm** lấy năm hiện tại; tháng ấy chưa tới thì lùi một năm.
- Thứ tự luật: kỳ tự do xét **trước** luật 5 (*"câu không nêu kỳ → moi_luc"*); các chữ *"tháng", "quý", "năm", "tuần"* kèm số
  là chữ kỳ nên luật 5 không đè.
- `_kyCua` của tool: `tuy_chon` → đọc hai mốc, thiếu hoặc lệch (`tu > den`) → `tuChoiGiaTri`/lời từ chối mới
  `tuChoiKhoangNgay` (`loi_tham_so.dart`, chỗ duy nhất dựng lời từ chối); `chuThem['ky']` = *"từ 1/9 đến 15/9"* (chữ
  có số vào **`boLoc`**, không vào `chuThem` — `chuThem` cấm chữ số; `chuKy` cho mẫu câu lấy từ `boLoc[0]`).
- Bẫy cần test: tháng 2 năm nhuận, `31/6` không tồn tại (từ chối, không tự cuộn), `den_ngay` trước `tu_ngay`, mốc không
  năm sang năm mới.

### 3.2 So sánh hai kỳ: `so_voi`

- `so_voi` enum `ky_truoc` · `cung_ky_nam_truoc`. Tool gọi `tongThuChi` cho kỳ so sánh (kỳ trước = `lui(ky, 1)`; cùng kỳ
  năm trước = `nenSoSanh(moc: cungKyNamTruoc)` — tuần lùi **52 kỳ**, mục 3.28 `ANALYTICS_FEATURE.md`; `tuy_chon` giữ nguyên
  độ dài) và thêm vào `tongHop`: *Tổng chi kỳ so sánh · Chênh lệch chi · Tỉ lệ đổi chi* (`phanTramSoVoi`, `LoaiSo.phanTram`;
  `null` khi nền 0 → bỏ, câu *"không có dữ liệu kỳ trước"* qua `chuThem['so_sanh']`), và với `chieu` thu / tat_ca thêm bộ
  *Tổng thu…* tương ứng. `chuThem['so_sanh']` = *"nhiều hơn"* / *"ít hơn"* / *"bằng"* / *"không có dữ liệu kỳ so sánh"*;
  `boLoc` thêm *"so với tháng trước"* / *"so với cùng kỳ năm trước"* (chữ kỳ so sánh lấy từ `nenSoSanh(...).nhan`).
- Hàng vẫn là giao dịch **kỳ này** (trần 4). Nhãn *Tổng chi kỳ so sánh* mang `nhanKhac: ['Tổng chi tháng trước', 'Tổng chi kỳ
  trước']`… **không** — nhãn thay thế phải nằm trên `SoLieu` lúc dựng, nên nhãn chính là *"Tổng chi <chữ kỳ so sánh>"*
  (*"Tổng chi tháng trước"*), suy từ `nenSoSanh(...).nhan` lúc chạy; test quét 14 cấm `'chi'` trần nên chuỗi dựng bằng
  nội suy `'Tổng ${...}'` từ hằng có sẵn của `hang_giao_dich.dart`.
- Bộ chỉnh luật 12: *"so với tháng trước / kỳ trước / tháng trước thế nào / nhiều hơn hay ít hơn tháng trước"* → `ky_truoc`;
  *"cùng kỳ năm trước / năm ngoái cùng kỳ / so với năm ngoái"* → `cung_ky_nam_truoc`. Câu có `so_voi` mà mô hình đặt
  `ky=thang_truoc` → sửa `ky=thang_nay` (kỳ gốc là kỳ đang nói).
- Ví dụ định tuyến: *"tháng này chi nhiều hơn hay ít hơn tháng trước" → truy_van với ky=thang_nay, so_voi=ky_truoc*.

## 4. Phần 2 — ba tool mới (chỉ đọc)

### 4.1 `du_bao_dong_tien` — không tham số

Adapter đọc đúng bốn nguồn của khối *Dự báo 30 ngày tới* (hoá đơn, mục tiêu, ngân sách đang chạy tại `now`, ví) → `duBaoCua`.
`hangDuBao(DuBaoDongTien?)`:
- `tongHop`: *Số dư hiện tại* (`soDuHienTai`) · *Cam kết 30 ngày tới* (`tongCamKet`) · *Còn tiêu được* (`soDuHienTai −
  tongCamKet`) · *Nếu tiêu đúng ngân sách còn* (`còn tiêu được − nganSachConLai`) · *Số cam kết* (`camKet.length`) · *Ví
  thiếu* (`viThieu.length`).
- `hang`: 4 cam kết gần nhất theo ngày — tên (`CamKet.ten`), trạng thái *"hoá đơn"* / *"trích tự động"*, `soTien` + `soNgayThang`;
  hàng ví thiếu: tên ví, trạng thái *"không đủ"*, *Thiếu* + *Ngày*.
- `chuThem['tinh_trang']` = *"đủ trả mọi cam kết"* khi `còn tiêu được ≥ 0` và `viThieu` rỗng, ngược lại *"thiếu tiền cho cam
  kết"*. `null` (không ví) → `KetQuaCongCu` rỗng + `chuThem` *"chưa có ví"*.
- Mô tả: *"Gọi khi hỏi còn tiêu được bao nhiêu, tiền có đủ trả hoá đơn / trích mục tiêu sắp tới không, trả hết cam kết
  thì còn bao nhiêu, 30 ngày tới phải chi gì"*. Ví dụ định tuyến: câu 16, 17 chặng 3.
- ⚠️ Hàm hiện có `_camKetHoaDon`, `_dauNgay` là private của `du_bao_dong_tien.dart` — tool chỉ gọi `duBaoCua`, không chép.

### 4.2 `tong_quan_tai_chinh` — tham số `ky` (+ `tu_ngay`, `den_ngay`) cùng bộ với truy_van

Nguồn: `AnalyticsRepository.watchKy(idaccount, ky:)` (đã dựng `ThongKeKy`: `tong`, `tongTruoc`, `tongNamTruoc`, chuỗi, ví,
vay/nợ), cộng `soLieuNhanhCua`, `tongTaiSanCua`/`thayDoiTaiSan`, `chuoiVayNo`. `hangTongQuan(...)` chỉ `tongHop` (~11 số,
**không hàng**), thứ tự cố định:
1. *Thu nhập* = `thuNhapCua(tong, vayNo)` — nhãn thay thế *"thu nhập thật"*; mô tả tool nói rõ *"thu nhập không gồm tiền đi
   vay, thu nợ"*.
2. *Tổng thu* · *Tổng chi* (chính `tong`).
3. *Tỉ lệ tiết kiệm* (`tyLeTietKiem`, `LoaiSo.phanTram`; `null` → bỏ).
4. *Dòng tiền tự do* (`thu nhập − chi − trả nợ`, đúng `dongTienTuDo` của kỳ).
5. *Chi trung bình mỗi ngày* · *Ngày chi nhiều nhất* (`soNgayThang`) · *Chi ngày nhiều nhất* · *Khoản chi lớn nhất* (số, `ten`
   = tiêu đề khoản — đúng khuôn `hangGiaoDich`, để `kiemNhan` đòi câu nêu tên).
6. *Tổng tài sản* (`viTinhVaoTong`, cùng số Trang chủ) · *Thay đổi tài sản trong kỳ* (`thayDoiTaiSan`; `null` → bỏ).
7. *Đang cho vay chưa thu về* = Σ `choVay − thuNo` **mọi thời gian**; *Đang nợ* = Σ `diVay − traNo` mọi thời gian (âm →
   0; `chuThem` ghi rõ *"vay nợ tính mọi thời gian"*). Hai số này **không** theo `ky` — mô tả tool nói thẳng.
- `ky` bắt buộc như truy_van (mặc định của bộ chỉnh: không nêu kỳ → `thang_nay`, **khác** truy_van, vì "tổng quan mọi thời
  gian" vô nghĩa với thu nhập).
- Mô tả: *"Gọi khi hỏi thu nhập, để dành / tiết kiệm bao nhiêu phần trăm, dòng tiền tự do, chi trung bình mỗi ngày, ngày nào
  chi nhiều nhất, khoản chi lớn nhất, tổng tài sản đổi thế nào, đang cho vay hay đang nợ bao nhiêu"*.

### 4.3 `danh_sach_danh_muc` — tham số `loai` (`chi` · `thu` · `vay_no` · `tat_ca`, mặc định `tat_ca`)

- Nguồn `CategoryDao.getAll(idaccount)` (đã lọc xoá mềm, khử trùng tên) + ngân sách đang chạy để gắn trạng thái. Hàng: tên,
  trạng thái *"chi · có ngân sách"* / *"chi"* / *"thu"* / *"vay nợ"*, **không `soLieu`**; trần riêng `kToiDaDanhMuc = 20`
  (ghi lý do: tài khoản thật 16 danh mục; hàng không số nên rẻ). Tổng hợp *Số danh mục chi · Số danh mục thu · Số danh mục
  vay nợ · Số có ngân sách*.
- `kiemTen` phải nhận tên từ gói: `GoiSoTraCuu.tenDoiTuong` gom `hang.ten` — kiểm bằng test *"câu liệt kê 16 tên qua kiemTen"*.
- Mô tả: *"Gọi khi hỏi có những danh mục nào, bao nhiêu danh mục, danh mục nào chưa có ngân sách"*. ⚠️ Câu *"danh mục chưa
  đặt ngân sách"* đã có đường `danh_sach_ngan_sach chon=chua_dat` (kèm số tiền) — mô tả tool này chỉ nhận vế *"danh mục
  nào"*, mô tả tool ngân sách giữ vế *"chưa đặt ngân sách"*; ví dụ định tuyến tách hai câu.

## 5. Phần 3 — mở rộng ba tool sẵn có

### 5.1 `danh_sach_hoa_don`: `ky` (`ky_nay` mặc định · `ky_toi` · `tat_ca`), tự trả, cố định mỗi tháng

> ✅ **Thi công 2026-09-28** (mục 9.35 `AI_EDGE_FEATURE.md`). ⚠️ Khác chữ bên dưới ở hai chỗ: kỳ *dự kiến* chiếu từ hàng
> **còn phải trả** ở cuối chuỗi (trả tiền là sinh luôn hàng kỳ sau, nên hàng đã trả không còn gì để chiếu), và chữ kỳ đi
> `chuThem['ky']` thay vì `boLoc`.

- `ky_toi`: hoá đơn có `dueDate` trong tháng dương lịch kế tiếp **cộng** kỳ kế tiếp **dự kiến** của hoá đơn lặp đã trả kỳ này
  (`kyKeTiepCua(bill)` — không sinh hàng, chỉ tính; trạng thái *"dự kiến"*). `tat_ca`: mọi hoá đơn chưa đóng bất kể tháng
  (đúng tab *Cần thanh toán* — mục 12 `AI_EDGE_FEATURE.md` ghi thẻ tổng và tab đếm hai tập khác nhau; tool **nói rõ** bằng
  `boLoc`).
- Trạng thái hàng thêm hậu tố *" · tự trả"* khi `autoPayEnabled`; tổng hợp thêm *Tự trả* (đếm) và *Cố định mỗi tháng* (Σ
  `amount` của hoá đơn `isRecurrence` chu kỳ tháng, **kỳ này**, kể cả đã trả).
- Bộ chỉnh `chinhThamSoHoaDon`: *"tháng tới / tháng sau / kỳ tới / sắp tới tháng sau"* → `ky_toi`; *"tất cả / mọi hoá đơn"* →
  `tat_ca`; *"tự trả / tự động thanh toán"* không đổi tham số (số đã có trong tổng hợp).

### 5.2 `danh_sach_muc_tieu`: kỳ trích tiếp, ví không đủ

> ✅ **Thi công 2026-09-28** (mục 9.35 `AI_EDGE_FEATURE.md`). ⚠️ Khác chữ bên dưới: *"ví không đủ để trích"* là **hậu
> tố** trạng thái (không thay) để mục tiêu vừa chậm vừa thiếu tiền khớp cả hai `chon`; tool nhận tên + số dư +
> trạng thái ví nguồn (không chỉ số dư) để nói được *"trích tự động không chạy được"*; nhãn đếm là *Không đủ tiền
> trích*. Câu về trích cho mục tiêu được **định tuyến** sang tool này (người dùng chốt).

- Hàng có `autoDepositAmount > 0` mang thêm *Kỳ trích tiếp* (`kyKeTiep(mocNeo, lanChayGanNhat, chuKy, now)`, `soNgayThang`;
  `null` → bỏ) và *Trích mỗi kỳ* (`autoDepositAmount`); `quyetDinhTrich(soTienCai, conThieu, soDuViNguon)` = `viKhongDu` → trạng
  thái *"ví không đủ để trích"* (thay *"đúng kế hoạch"*; `canhBao: true`). Tổng hợp *Ví thiếu để trích* (đếm).
- Cần số dư ví nguồn: adapter đọc thêm `WalletRepository.watchAll(idaccount).first` (bảng tra — đúng phân loại của
  `wallet_picker_sources_test.dart`, ghi lý do khi test quét đòi).
- `chon` thêm mã `vi_khong_du` (trạng thái thứ tư), `chinhThamSoMucTieu` đọc *"ví không đủ / thiếu tiền trích"*.

### 5.3 `danh_sach_ngan_sach`: `chon=can_doi` — kế hoạch tái phân bổ

> ✅ **Thi công 2026-09-28** (mục 9.35 `AI_EDGE_FEATURE.md`). Thêm so với chữ bên dưới: hàng thâm hụt mang cả *Hạn mức*;
> *Tổng chuyển*; `ghi_chu` "chỉ là gợi ý"; và phép ghép `nap → taiPhanBoCua` nay là **một** hàm `keHoachTaiPhanBoTu` dùng
> chung với thẻ cân đối và thông báo.

- Nguồn `TaiPhanBoNguon.nap(idaccount, dangChay, now)` (đã có trong DI: `sl<TaiPhanBoNguon>()`) → `taiPhanBoCua(...)` —
  **cùng kế hoạch** với thẻ *Đề xuất cân đối* và thông báo `budgetRebalance` (bộ luật nhận kế hoạch, không tự tính).
- `hangCanDoiNganSach(KeHoachTaiPhanBo?)`: hàng đầu = ngân sách thiếu (`thieu.displayName`, trạng thái *"thâm hụt"*, *Thâm
  hụt* = `thamHut`, *Dự phóng* = `duPhong`); các hàng sau = nguồn bù (`dong[i].nguon.displayName`, trạng thái *"giảm bớt"*,
  *Chuyển* = `soTien`, *Dư địa* = `duDia`); tổng hợp *Số ngân sách cần bù* (1 hay 0), *Còn thiếu sau khi bù* (`soThieu`,
  chỉ khi `thieuNguonBu`); `chuThem['ket_qua']` = *"đủ nguồn bù"* / *"thiếu nguồn bù"*. `null` → `rongTheoBoLoc`, `doiTuongRong`
  *"ngân sách"*, mẫu câu *"Cần cân đối — không có ngân sách nào khớp"*. ⚠️ *Đổi 2026-09-28 (`f1a5bd1`, mục 9.37
  `AI_EDGE_FEATURE.md`, câu F15 cổng F): `null` nay là `ket_qua` "không ngân sách nào cần cân đối" + `chiMauCau`,
  **thôi** `rongTheoBoLoc` — mẫu câu cũ đọc như một lỗi tìm kiếm.*
- `chinhThamSoNganSach`: *"cân đối / chuyển bớt / bù / dồn ngân sách / lấy từ ngân sách nào"* → `can_doi`, xét trước tỉ lệ.
- ⚠️ Tool **không** áp dụng kế hoạch (bất biến ④); mô tả nói *"chỉ gợi ý, áp dụng ở trang Ngân sách"*.

## 6. Phần 4 — blocklist, trần token, cổng F

- `chuDeBiChan` thêm: *giá vàng, giá xăng, tỷ giá, thời tiết, tin tức, xổ số, kết quả bóng đá, chứng khoán hôm nay* — so có
  dấu như cũ; câu bị chặn không gọi mô hình. Không chặn *"hôm nay ngày bao nhiêu"* (E21 đã đúng: không bịa).
- Ba lát thi công, mỗi lát: TDD → `flutter test` bộ liên quan → build release → spike Realme (`tools_json`, không
  `FAILED_PRECONDITION`) → đặt lại `kTranToolsJsonDaDo` → đo **câu đích của lát** → docs + commit.
- **Cổng F** (sau lát 3): 56 câu cũ (`congE_all.sh`) **không tụt** theo từng câu, trừ dao động đã ghi (C16, E19, E22) + bộ mới
  **F1–F16** (hai câu mỗi việc, soạn ở kế hoạch) **≥ 13/16 đúng**, bịa 0, và câu 16–17 chặng 3 đúng. Chấm theo màn, bảng ba
  cột, ba nguyên nhân.

## 7. Cố ý không làm

- Tool thông báo (hạng 13). Tool *"dư nợ theo người"* (cần đọc tên từ ghi chú — chưa có mô hình dữ liệu). Tool ghi bất kỳ.
- Không nâng `maxTokens` trước khi vỡ. Không thêm tool cho tỉ lệ tiết kiệm riêng — nó nằm trong `tong_quan_tai_chinh`.
- Không đổi `kToiDaMucMoiGoi` chung; trần 20 chỉ cho danh mục.
