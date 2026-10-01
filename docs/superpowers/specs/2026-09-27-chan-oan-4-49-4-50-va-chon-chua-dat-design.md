# Hai ca chắn oan (bẫy 4.49, 4.50) và `chon=chua_dat` cho tool ngân sách — thiết kế

**Ngày:** 2026-09-27, sau cổng E lần 1 (mục 9.32 `AI_EDGE_FEATURE.md`). **Người dùng duyệt** cả ba lối trong chat.

## 1. Vì sao

Cổng E lần 1 và hai câu người dùng tự hỏi ngay sau đó lộ ba lỗi mà bộ 56 câu không đo:

| | Câu | Chuyện gì | Đo |
|---|---|---|---|
| 4.49 | *"Tôi đã cho vay 800.000 đ và thu về 500.000 đ."* (E15, câu đúng) | `kiemNhan` chặn | test tạm: `kiemSo` ✓ `kiemGiong` ✓ `kiemTen` ✓ **`kiemNhan` ✗** — hàng 800.000 mang `nhanXungDot: ['Thu']` (4.42), luật xét **cả câu** thấy "thu" của vế 500.000 mà không thấy "chi" → coi 800.000 bị gán thành thu |
| 4.50 | *"Các danh mục đã đặt ngân sách bao gồm: Giáo dục, Di chuyển, Ăn uống, Mua sắm."* (câu đúng) | `kiemTen` chặn | test tạm: chỉ **`kiemTen` ✗** — cụm sau từ loại *"ngân sách"* là *"bao gồm"*, không khớp tên nào |
| (a) | *"các danh mục chưa đặt ngân sách"* | mô hình nói **SAI** *"Không có danh mục nào…"* | không tool nào trả thứ ấy; `goi_y_han_muc {}` trả bốn danh mục **đã** có ngân sách; câu không số nên bốn lớp chắn im. App đã có phép ấy ở thẻ *Chưa đặt ngân sách* (`chonDeXuat`) |

## 2. Quyết định

### 2.1 Bẫy 4.49 — gán nhãn ngược xét theo VẾ chứa con số

`kiemNhan` tách câu thành vế ở ` và `, ` hoặc `, ` nhưng `, `;` (**không** tách ở dấu hai chấm hay dấu phẩy — C10
*"Các khoản thu bao gồm: Cho vay (800.000 đ), …"* phải **vẫn bị chặn**), rồi:

- vế *"câu nêu tên đối tượng"* (phép nới 4a) vẫn đọc âm tiết của **cả câu** — không đổi;
- `ganNhanNguoc` đọc âm tiết của **vế chứa con số** (đã bỏ tên đối tượng), thay vì cả câu.

Giới hạn cố ý: tên đối tượng chứa ` và ` sẽ bị tách đôi trước khi bỏ tên — chỉ ảnh hưởng phép gán ngược, sai theo chiều
an toàn (chặn). Không có tên như thế trong dữ liệu đo.

### 2.2 Bẫy 4.50 — thêm từ chức năng cho `kiemTen`

Thêm vào `kTuChucNang`: *bao · gồm · nhiêu · tổng · cộng · đặt · tên · các · những · được · hiện · tại · thế · trước* (*sau*
đã có). Chúng không bao giờ là một phần của tên và hay đứng ngay sau từ loại (*"ngân sách bao gồm"*, *"ngân sách bao
nhiêu"*, *"danh mục các"*). Luật *"mọi cụm còn lại phải khớp tên"* **giữ nguyên** — B1 *"mua xe hoặc mua nhà"* vẫn bị chặn.
Lối *chỉ xét cụm viết hoa* bị loại vì B1 viết thường.

### 2.3 `chon=chua_dat` cho `danh_sach_ngan_sach`

- `kChon` thêm mã thứ năm `chua_dat` (*"chưa đặt ngân sách"*); `kChonGiaoDich` không đổi.
- Tool ngân sách: `chon == 'chua_dat'` → **không** qua `hangNganSach` mà qua `hangChuaDatNganSach(GoiDeXuat?, soNganSach:)`:
  mỗi hàng một danh mục chi **đang tiêu mà chưa có ngân sách**, số duy nhất *Chi trung bình mỗi tháng* (chính `suggestAmount`),
  trạng thái *"chưa đặt ngân sách"*; tổng hợp *Số ngân sách* (đang chạy) + *Số danh mục chưa đặt*; `boLoc` *"chưa đặt ngân
  sách"*; 0 ứng viên (hoặc tài khoản quá trẻ, `soNgayCuaSo` null) → `rongTheoBoLoc`, `doiTuongRong` *"danh mục"* → mẫu câu
  *"Chưa đặt ngân sách — không có danh mục nào khớp."*
- Dữ liệu từ **một** nguồn với thẻ *Chưa đặt ngân sách*: phần đọc repository của `BudgetCubit._deXuat` tách ra
  `budget/data/de_xuat_nguon.dart` (`deXuatTuKho`), cubit gọi lại; `chonDeXuat` nhận `toiDa` (thẻ giữ 3, tool
  `kToiDaMucMoiGoi` = 4) và `GoiDeXuat` mang `soUngVien` (số trước khi cắt) để tool đếm đủ.
- Bộ chỉnh `chinhThamSoNganSach`: *"chưa đặt / chưa có ngân sách / không có ngân sách"* → `chua_dat`, xét **trước** các luật
  tỉ lệ; luật 10 (gỡ `chon` không bằng chứng) giữ.
- `tools_json` tăng (mô tả enum) → **đo lại Realme** rồi mới đặt `kTranToolsJsonDaDo`.

## 3. Nghiệm thu

- Test đơn vị từ ba câu thật (E15, câu người dùng, *"ngân sách bao nhiêu"*), ca 4.42 (C10) và 4.48 (B1) **giữ nguyên xanh**.
- Đo lại trên Realme: E15 (chữ mô hình phải **hiện**), *"các danh mục đã đặt ngân sách"* (chữ mô hình hiện), *"các danh
  mục chưa đặt ngân sách"* (tool `chon=chua_dat`, câu nêu Cho vay / Giải trí — không còn "không có").
