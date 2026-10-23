# 🏷️ PHÂN HỆ 05: HỆ THỐNG DANH MỤC THU CHI ĐA CẤP (CATEGORY MANAGEMENT)

> **Mã phân hệ:** `CAT`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/category`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category)  
> **Quản lý trạng thái:** `CategoryBloc`  
> **Cơ sở dữ liệu:** SQLite bảng `categories` (Đồng bộ 2 chiều qua Entity `category`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/categories` | [`category_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category/presentation/pages/category_page.dart) | Quản lý cây danh mục | 2 Tab: Chi tiêu / Thu nhập; Cây danh mục 2 cấp (Nhóm cha $\rightarrow$ Con); Nút Thêm mới |
| `/categories/child/new` | [`category_add_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category/presentation/pages/category_add_page.dart) | Tạo mới danh mục con | Tên danh mục; Chọn nhóm cha; Bảng chọn Icon; Bảng mã màu; Nút Lưu |
| `/categories/child/:id/edit` | [`category_add_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category/presentation/pages/category_add_page.dart) | Chỉnh sửa / Xóa danh mục con | Đổi tên, nhóm cha, icon, màu sắc; Nút Xóa danh mục (bảo vệ ràng buộc) |
| `/categories/group/new` | [`category_group_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category/presentation/pages/category_group_page.dart) | Tạo nhóm danh mục cha | Tên nhóm cha; Chọn loại Thu hoặc Chi; Biểu tượng & Màu nhóm |
| `/categories/group/:id/edit` | [`category_group_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category/presentation/pages/category_group_page.dart) | Chỉnh sửa nhóm danh mục cha | Cập nhật tên nhóm; Quản lý các danh mục con trực thuộc; Nút Xóa nhóm |
| `/categories/:id/keywords` | [`category_add_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/category/presentation/pages/category_add_page.dart) | Từ khóa nhận diện tự động | Danh sách từ khóa gán kèm (Tags); Nhập từ khóa mới; Hỗ trợ AI/OCR tự động gán |

---

## 2. QUY TRÌNH PHÂN CẤP CÂY DANH MỤC 2 TẦNG (2-TIER TAXONOMY)

Hệ thống phân cấp danh mục thành **Nhóm cha (Parent Groups)** và **Danh mục con (Child Categories)** giúp báo cáo tài chính vừa có góc nhìn tổng quan (Macro) vừa chi tiết (Micro):

### 2.1. Cấu trúc Danh mục Chi tiêu (Expenses)
- 🍔 **Nhóm Ăn uống:** Cơm trưa, Cà phê & Đồ uống, Nhà hàng & Tiệc, Đi chợ & Siêu thị.
- 🚗 **Nhóm Di chuyển:** Xăng xe, Gửi xe, Bảo dưỡng & Sửa xe, Taxi / Grab, Vé tàu xe / Máy bay.
- 🏠 **Nhóm Nhà cửa & Tiện ích:** Tiền thuê nhà, Tiền điện, Tiền nước, Internet & Truyền hình, Đồ gia dụng.
- 🛍️ **Nhóm Mua sắm & Tiêu dùng:** Quần áo & Giày dép, Đồ điện tử, Mỹ phẩm & Chăm sóc cá nhân.
- 🩺 **Nhóm Sức khỏe & Y tế:** Thuốc men, Khám chữa bệnh, Bảo hiểm y tế, Phòng gym & Thể thao.
- 🎓 **Nhóm Giáo dục:** Học phí, Sách vở & Dụng cụ, Khóa học kỹ năng.
- 🎮 **Nhóm Giải trí:** Xem phim, Du lịch, Game & Đăng ký dịch vụ (Netflix, Spotify...).

### 2.2. Cấu trúc Danh mục Thu nhập (Incomes)
- 💵 **Lương cố định:** Tiền lương hàng tháng từ công ty.
- 🎁 **Thưởng & Phụ cấp:** Thưởng lễ, thưởng KPI, tiền làm thêm giờ (OT).
- 💻 **Nghề tay trái (Freelance):** Thu nhập từ các dự án ngoài, bán hàng online.
- 📈 **Đầu tư & Sinh lời:** Cổ tức, lãi gửi tiết kiệm ngân hàng, lợi nhuận chứng khoán/bất động sản.
- 🧧 **Khác:** Được tặng, biếu, tiền mừng...

---

## 3. TÍNH NĂNG TỪ KHÓA TỰ ĐỘNG GÁN DANH MỤC (KEYWORD AUTO-TAGGING)

Mỗi danh mục có thể được gắn kèm một tập hợp các từ khóa nhận diện (`keywords`):
- **Ví dụ Danh mục "Cà phê & Đồ uống":** Gắn các từ khóa `highlands`, `starbucks`, `phuclong`, `thecoffeehouse`, `cafe`, `tra sua`, `koi the`, `mixue`.
- **Cơ chế hoạt động:**
  - Khi người dùng **quét hóa đơn OCR** chứa chữ *"Highlands Coffee"* hoặc nhận được tin nhắn biến động số dư *"Thanh toán tai THE COFFEE HOUSE"*:
  - Thuật toán tự động đối soát từ khóa $\rightarrow$ Tự động chọn ngay danh mục "Cà phê & Đồ uống" cho giao dịch mà người dùng không cần phải tìm kiếm và chọn tay.

---

## 4. QUY TẮC PHÂN QUYỀN GÓI CƯỚC (FEATURE GATING)

- **Gói Basic:**
  - Được sử dụng đầy đủ toàn bộ hệ thống danh mục chuẩn quốc tế có sẵn do hệ thống cung cấp (bao phủ 98% nhu cầu thông thường).
  - Khi bấm "+ Tạo danh mục con riêng" hoặc "+ Tạo nhóm cha riêng": Router kích hoạt guard `redirectTaoTheoGoi(LoaiTran.danhMucRieng)` chuyển hướng sang `/premium?tran=danh_muc_rieng`.
- **Gói Premium:**
  - Không giới hạn tạo danh mục cá nhân hóa.
  - Tự do đặt tên, cấu hình biểu tượng icon và màu sắc theo sở thích cá nhân.
