# Tool truy vấn giao dịch tổng quát có hàng rào — thiết kế (2026-09-27)

**Trạng thái:** đã duyệt từng mục trong chat ngày 2026-09-27 (năm mục), chờ người dùng đọc bản viết.
**Bối cảnh:** `docs/AI_EDGE_FEATURE.md` mục 9.28–9.31. Bộ 22 câu mới (9.29) đo được bốn câu hỏng mà bảy tool hiện có
không phủ: **E3** danh mục ít tiêu nhất, **E5** tổng chi một danh mục cả năm, **E15** cho vay hai chiều, **E18** ngân
sách dưới nửa. Spike 9.30 chứng minh **không** cho Gemma 4 E2B tự viết SQL (0/12 đúng hẳn, 6/12 sai im lặng). 9.31 sửa
hai lỗi dữ liệu nhưng để lại lỗi mô hình: có đủ dữ liệu vẫn không làm phép chọn/lọc mà câu hỏi đòi.
**Nguyên tắc giữ nguyên:** lớp AI không tính (`ai_edge_khong_tinh_test`), mô hình chỉ điền tham số, mọi số từ hàm domain,
ba lớp chắn + `kiemTen` không đổi, không tool nào ghi. Không đổi schema, payload đồng bộ, `pubspec`.

## 0. Quyết định người dùng đã chốt (2026-09-27)

| # | Quyết định | Lý do |
|---|---|---|
| 1 | Phạm vi: **chỉ sổ giao dịch** + gộp theo danh mục / ví; E18 xử lý bằng tham số `chon` thêm cho tool ngân sách sẵn có | Nhỏ, đo được, không phá bảy tool; "mọi đối tượng trong một tool" làm `tools_json` phình và trùng vai năm tool danh sách |
| 2 | Tool mới **thay cả** `tim_giao_dich` lẫn `tong_ket_thu_chi_ky`; bộ tool 7 → 6 | Hai tool trên cùng một sổ là chỗ mô hình chọn nhầm nhiều nhất (E5, C13, sáu câu có điều kiện ở lần đo 4–8) |
| 3 | `chon` là **một** enum dùng chung cho tool giao dịch và tool ngân sách | Một định nghĩa, hàm domain lọc trước khi đưa mô hình |
| 4 | Cổng E: 34 câu cổng D **không tụt** + 22 câu mới **≥ 19** đúng, **E3 · E5 · E15 · E18 phải đúng**, bịa số 0; đo trọn 56 câu một lần rồi chỉ đo lại câu chưa đạt | Thay tool là đổi định tuyến của mọi câu |
| 5 | Lối **A**: một tool phẳng, mô hình thấy cả `gop` lẫn `chon`; bộ chỉnh tham số đọc cả hai từ câu và ghi đè | Mọi tham số có hai đường (mô hình và bộ chỉnh) như thiết kế đã đo ở 9.28 |

## 1. Khai báo tool `truy_van_giao_dich`

Hằng `kTenCongCuTruyVan = 'truy_van_giao_dich'` ở `ai_edge/domain/cong_cu.dart`. Hai hằng tên cũ (`kTenCongCuGiaoDich`,
`kTenCongCuTongKet`) **xoá**; tài liệu và script đo cũ nhắc tên cũ là tên lúc viết, không phải lỗi.

Tham số (phẳng, JSON schema như bảy tool hiện có):

| Tham số | Giá trị | Ghi chú |
|---|---|---|
| `ky` (bắt buộc) | 8 mã `kMaKy` + `moi_luc` | không đổi; `ky` thiếu hay lạ → từ chối (spec 2b) |
| `chieu` | `khoan_chi` · `khoan_thu` · `chuyen_vi` · `tat_ca` | không đổi |
| `so_tien_tu`, `so_tien_den` | số đồng | không đổi |
| `danh_muc`, `vi`, `tu_khoa` | tên / chữ ghi chú | không đổi; giá trị giữ chỗ `tat_ca` = không lọc |
| `sap_xep` | `so_tien` · `moi_nhat` | không đổi |
| **`gop`** | `khong` (mặc định) · `danh_muc` · `vi` | `khong` = liệt kê từng khoản; còn lại = mỗi hàng một nhóm |
| **`chon`** | `nhieu_nhat` · `it_nhat` (trống = không chọn) | `gop=khong`: khoản lớn/nhỏ nhất; `gop≠khong`: nhóm có tổng lớn/nhỏ nhất — kết quả **một hàng** |

Mô tả (câu "Gọi khi" lên đầu, đúng khuôn lần đo 9): *"Gọi cho MỌI câu về giao dịch, chi tiêu, thu nhập: tổng một kỳ,
tiêu gì, những khoản nào, khoản lớn nhất, danh mục hay ví nào chi nhiều/ít nhất, có điều kiện hay không. Liệt kê từng giao
dịch (ghi chú, số tiền, ngày, danh mục, ví) kèm tổng, hoặc gộp theo danh mục / ví khi câu hỏi nói về danh mục hay ví nói
chung. gop: khong = từng giao dịch; danh_muc / vi = mỗi hàng một danh mục / ví với tổng chi, tổng thu, số giao dịch. chon:
nhieu_nhat / it_nhat = chỉ trả hàng lớn nhất / nhỏ nhất."* Mô tả `ky`, `chieu`, ngưỡng, tên, `tu_khoa`, `sap_xep` chép nguyên.

Giá trị lạ của `gop` / `chon` → `tuChoiGiaTri` như mọi enum (spec 2b: lượt bị từ chối không phải dữ liệu).

## 2. Luồng chạy và hàm domain

**Tệp:** `ai_edge/data/cong_cu_truy_van.dart` (thay `cong_cu_giao_dich.dart` + `cong_cu_chi_tieu.dart`),
`transaction/domain/gop_giao_dich.dart` (mới), `ai_edge/domain/hang_nhom_giao_dich.dart` (mới), `ai_edge/domain/ma_ky.dart`
(`kMaKy`, `kMaKyMoiLuc`, `kyTuMa` chuyển từ `hang_chi_tieu.dart` — `danh_sach_hoa_don`/`goi_y_han_muc` không dùng nhưng
`cong_cu_truy_van` và test dùng), `ai_edge/domain/chon.dart` (mục 4). Xoá `hang_chi_tieu.dart`, `hangChiTieu`.

1. `CongCuTruyVan.chay` lặp phần đầu của `tim_giao_dich` hôm nay: bộ chỉnh tham số (mục 3) → kiểm `ky`, `chieu`, `sap_xep`,
   ngưỡng, `tu_khoa` → `TieuChiTim` → `timGiaoDich(trongKy: watchKhoang(kỳ), …)`. Khác hai chỗ: `toiDa` là **trần lớn**
   (toàn bộ khớp) khi `gop ≠ khong` **hoặc** `chon` có giá trị; sau đó rẽ theo `gop`.
2. **`gop = khong`**: `hangGiaoDich(kq, …)` như hôm nay. `chon = nhieu_nhat` → giữ hàng đầu sau khi xếp theo tiền;
   `it_nhat` → hàng cuối; mỗi trường hợp **một hàng** với trạng thái `khoản lớn nhất` / `khoản nhỏ nhất`. `Số giao dịch`,
   `Tổng chi`, `Tổng thu` đếm trên **trọn tập khớp** (`kq.soKhop`, `kq.tongChi`…), không trên hàng hiện.
3. **`gop = danh_muc | vi`**: `gopGiaoDich(List<DongTimThay>, theo: NhomTheo.danhMuc | .vi)` → `List<NhomGiaoDich>` với
   `ten`, `chi`, `thu`, `soKhoan`; khoản không danh mục vào nhóm **"Chưa phân loại"** (tên tổng kết cũ đã dùng); xếp theo
   `chi` giảm dần, hoặc theo `thu` khi `chieu = khoan_thu`. `hangNhomGiaoDich(nhom, …)` → `HangSoLieu(ten: nhóm, trangThai:
   'chi nhiều nhất' / 'chi ít nhất' ở hai đầu (như 9.31; theo `thu` thì 'thu nhiều nhất' / 'thu ít nhất'), soLieu: [Chi,
   Thu nếu > 0, Số giao dịch])`, trần `kToiDaMucMoiGoi` với hàng cuối là nhóm **ít nhất**; `chon` → đúng một hàng. Tổng
   hợp: `Tổng chi`, `Tổng thu`, `Số giao dịch`, `Số danh mục` / `Số ví`. Nhãn `Chi` khai `nhanXungDot: ['Thu']` (bẫy 4.42);
   `Số giao dịch` nhãn thay thế `Số khoản` (bẫy 4.47). Tên nhóm là `ten` của mọi `SoLieu` trong hàng (`kiemNhan` đòi câu
   nêu tên). *"Chưa phân loại"* đưa vào `KetQuaCongCu.tenLienQuan` để `kiemTen` không chặn oan.
4. **Mẫu câu, cờ rỗng, thẻ**: `GoiSoTraCuu`, L1b / L2 / L2b / L2c, `theCuaCau` **không đổi**. 0 khoản khớp ở mọi `gop` →
   `rongTheoBoLoc` như hôm nay; tiền tố mẫu câu thêm chữ *"gộp theo danh mục"* / *"gộp theo ví"* / *"chọn lớn nhất"* khi
   có, để câu *"Tháng này, gộp theo danh mục — không có giao dịch nào khớp"* vẫn là báo cáo về bộ lọc.
5. **Không phép tính mới ngoài cộng nhóm**: lọc, chiều, `khoanVaoThongKe`, tổng chi/thu là của `timGiaoDich`/`tongThuChi`
   hiện có. `gopGiaoDich` chỉ cộng trên tập `timGiaoDich` đã lọc — gộp và liệt kê không bao giờ nói về hai tập khác nhau
   (bài học gói hoá đơn 1.3). ⚠️ Hệ quả cố ý: *"Tổng chi"* của `gop=danh_muc, ky=thang_nay` **bằng** *"Tổng chi"* của
   `gop=khong` cùng kỳ, và bằng thẻ Trang chủ (bước 1a) — có ca test canh.

## 3. Bộ chỉnh tham số theo câu hỏi — ba luật mới (`chinh_tham_so.dart`)

Cùng khuôn sáu luật hiện có: câu hỏi là nguồn sự thật, so trên chữ bỏ dấu trọn từ, mỗi luật đã áp ghi một dòng log, không
đụng giá trị mà câu không nói tới. Từ khoá giữ dạng **chuỗi tách lúc chạy** (test quét 14).

7. **Chọn**: *nhiều nhất / lớn nhất / cao nhất* → `chon = nhieu_nhat`; *ít nhất / nhỏ nhất / thấp nhất* → `chon = it_nhat`;
   ghi đè giá trị mô hình. ⚠️ *"ít nhất"* đã là từ khoá **ngưỡng** ở luật 4 (*"chi ít nhất 200k"* = từ 200k trở lên). Thứ
   tự: sau *ít nhất* là một số tiền (theo chính mẫu số của luật 4) → ngưỡng, luật 4 thắng và luật 7 **không** áp; ngược
   lại mới là chọn. Hai ca test đối nhau.
8. **Gộp**: câu nói về *danh mục* nói chung — *"danh mục nào", "theo danh mục", "vào danh mục nào", "danh mục gì"* — mà
   **không** nêu tên danh mục có thật → `gop = danh_muc`; *"ví nào" / "theo ví"* không nêu tên ví → `gop = vi`. Câu nêu tên
   (E5) → `danh_muc = tên`, `gop` giữ `khong`. *"tiêu bao nhiêu"* một mình không đặt `gop`.
9. **Hai chiều**: câu có **cả** từ nhóm chi lẫn từ nhóm thu → `chieu = tat_ca` (luật 3 hôm nay chỉ điền khi trống). Thêm
   *cho vay* vào nhóm chi và *thu về* vào nhóm thu. E15 → `chieu = tat_ca` + `danh_muc = Cho vay` (luật 2): tool trả hai
   hàng 800.000 chi và 500.000 thu.

Mỗi luật: nhóm ca đơn vị + **phản ví dụ** (không từ khoá → tham số mô hình giữ nguyên). Bài học 9.28: ba lỗi của chính bộ
chỉnh lộ ở ba lần đo liên tiếp — luật từ vựng mới là dương tính giả mới.

## 4. `chon` cho `danh_sach_ngan_sach`

- `ai_edge/domain/chon.dart`: `kChon = ['nhieu_nhat', 'it_nhat', 'duoi_nua', 'tren_nua']` + chữ cho mô hình. Tool giao dịch
  nhận hai giá trị đầu, tool ngân sách cả bốn; lạ → `tuChoiGiaTri('chon', …)`.
- Nghĩa với ngân sách theo `rawPercentSpent` (getter sẵn của `BudgetEntity`): `nhieu_nhat` → một hàng căng nhất; `it_nhat`
  → một hàng ít dùng nhất; `duoi_nua` → mọi hàng < 50 %; `tren_nua` → ≥ 50 %. Sau lọc vẫn xếp căng nhất trước, trần 4; tổng
  hợp thêm `Số ngân sách khớp` cạnh `Số ngân sách`. Lọc ra 0 hàng → `rongTheoBoLoc`, mẫu câu *"Ngân sách dưới nửa hạn mức
  — không có ngân sách nào khớp"*.
- Bộ chỉnh cho tool ngân sách (`chinhThamSoNganSach`, cùng tệp): *chưa dùng đến một nửa / dưới nửa / chưa đến nửa* →
  `duoi_nua`; *quá nửa / hơn nửa* → `tren_nua`; *sắp hết / căng nhất / dùng nhiều nhất* → `nhieu_nhat`; *ít dùng nhất /
  còn nhiều nhất* → `it_nhat`; không từ khoá → giữ giá trị mô hình.
- Mô tả tool thêm: *"chon: lọc hoặc chọn theo tỉ lệ đã dùng — hỏi ngân sách nào dưới nửa, sắp hết, ít dùng nhất."*

## 5. Định tuyến, trần, lớp chắn, chỉ báo

- `BoCongCu.macDinh` **6 tool**, `truy_van_giao_dich` đứng **đầu** (thứ tự là tín hiệu định tuyến, lần đo 9), rồi
  `danh_sach_ngan_sach`, `danh_sach_hoa_don`, `danh_sach_vi`, `danh_sach_muc_tieu`, `goi_y_han_muc`.
- `cauDangTraCuu`: tool mới → *"Đang tra cứu giao dịch…"*; bỏ dòng tổng kết.
- `kPromptHeThongCongCu`: mọi ví dụ trỏ `tim_giao_dich`/tổng kết đổi sang tool mới; thêm bốn ví dụ **không chữ số**:
  *"chi nhiều nhất vào danh mục nào"* → `gop=danh_muc, chon=nhieu_nhat`; *"danh mục nào ít tiêu nhất"* → `gop=danh_muc,
  chon=it_nhat`; *"cho vay bao nhiêu và thu về bao nhiêu"* → `chieu=tat_ca` + `danh_muc`; *"ngân sách nào chưa dùng đến
  nửa"* → `danh_sach_ngan_sach chon=duoi_nua`. Độ dài lời hệ thống ghi vào 9.32 (hôm nay 1.318 ký tự).
- **Trần** `tools_json`: dự kiến giảm (bỏ ~600 ký tự khai báo tổng kết, thêm ~400). Trước cổng E chạy **một** câu trên
  Realme, đọc *"mở phiên … tools_json N ký tự"*, đặt lại `kTranToolsJsonDaDo` ở `bo_cong_cu_test`. `maxTokens` 4096 giữ;
  RAM đỉnh chỉ đo lại nếu `tools_json` tăng.
- Ba lớp chắn + `kiemTen` **không đổi mã**. Trạng thái hàng (*chi nhiều nhất*, *khoản lớn nhất*…) là chữ không số.

## 6. Kiểm thử

TDD, mỗi hàm một tệp, ca xanh-ngay phải thử bằng bản sai có chủ ý:

| Tệp | Canh gì |
|---|---|
| `transaction/domain/gop_giao_dich_test` (mới) | gộp theo danh mục / ví; "Chưa phân loại"; xếp theo `chi`, theo `thu` khi chiều thu; `soKhoan`; tổng nhóm = tổng tập |
| `ai_edge/domain/hang_nhom_giao_dich_test` (mới) | hai đầu mang trạng thái; trần 4 với hàng cuối là nhóm ít nhất; `chon` một hàng; nhãn xung đột; `tenLienQuan` có "Chưa phân loại"; JSON |
| `ai_edge/data/cong_cu_truy_van_test` (mới, thay `cong_cu_giao_dich_test` + `cong_cu_chi_tieu_test`) | rẽ theo `gop`; `toiDa` trần lớn khi gộp/chọn; `chon` ở `gop=khong`; cờ rỗng; từ chối enum lạ; **Tổng chi của hai `gop` cùng kỳ bằng nhau** |
| `ai_edge/domain/chinh_tham_so_test` | +3 luật, phản ví dụ, *"ít nhất 200k"* là ngưỡng |
| `ai_edge/domain/chon_test` (mới) | bốn giá trị, chữ không số |
| `ai_edge/domain/hang_ngan_sach_test` | `chon` bốn giá trị, rỗng, `Số ngân sách khớp` |
| `ai_edge/domain/ma_ky_test` (đổi tên từ phần `kyTuMa` của `hang_chi_tieu_test`) | không đổi nội dung |
| `ai_edge/data/bo_cong_cu_test` | 6 tool, thứ tự, trần `tools_json` mới, mô tả "Gọi cho MỌI câu" |
| `ai_edge/domain/slm_prompt_test` | ví dụ mới, không chữ số, không tên tool cũ |
| `ai_edge/data/vong_lap_cong_cu_test`, `ai_chat/ai_chat_page_test` | đổi tên tool giả / chỉ báo |
| quét | `ai_edge_khong_tinh_test` (14) và `chi_mot_noi_import_gemma_test` (16) phải xanh không sửa |

## 7. Cổng E và cách đo

Một lần trọn **56 câu** trên Realme, bản release từ HEAD, so SHA-1 trước khi cài (bẫy 9.29): `congD13.sh` (34) + `congE.sh`
(22) nối, `hoi.sh` đã vá (bậc 1 chờ *"sinh dần xong"*; Netflix gõ `Netfflix`). Chấm theo màn (ảnh chụp từng câu + `ban_ghi.py`
nếu lịch sử còn), bảng ba cột. Cột "tool đúng" của 34 câu cũ đổi ánh xạ: mọi câu từng đòi `tim_giao_dich` hay tổng kết nay
đòi `truy_van_giao_dich` với `gop`/`chon` tương ứng. Đạt khi: cổng D năm dòng không tụt (A 8/8 · B ≥ 3/4 · C tool ≥ 19/20,
tham số ≥ 16/20 · SAI 0 · trần 0) **và** bộ 22 ≥ 19 đúng với E3 · E5 · E15 · E18 đúng · bịa 0. Sau đó chỉ đo lại câu chưa
đạt. Ghi mục **9.32** `AI_EDGE_FEATURE.md`.

## 8. Cố ý không làm

- Không gộp theo tháng (`gop=thang`): chưa có câu đo nào đòi; thêm khi có.
- Không đưa hoá đơn / mục tiêu / ví vào tool này (quyết định 1).
- Không đổi bất biến ④ (không tool nào ghi).
- Không sửa E22 (câu ngoài phạm vi bị ép tool) ở đây — việc riêng của `chuDeBiChan`, ghi ở 9.29.
