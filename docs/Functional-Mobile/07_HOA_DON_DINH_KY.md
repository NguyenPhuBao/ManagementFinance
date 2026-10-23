# 🧾 PHÂN HỆ 07: QUẢN LÝ HÓA ĐƠN ĐỊNH KỲ & NHẮC HẸN (RECURRING BILLS)

> **Mã phân hệ:** `BILL`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/bill`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/bill)  
> **Quản lý trạng thái:** `BillBloc`  
> **Cơ sở dữ liệu:** SQLite bảng `bills` (Đồng bộ 2 chiều qua Entity `bill`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/bills` | [`bill_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/bill/presentation/pages/bill_page.dart) | Quản lý danh sách hóa đơn | Thẻ Tổng chi phí định kỳ/tháng; Tab: Sắp tới hạn / Quá hạn / Đã thanh toán; Nút Tạo mới |
| `/bills/add` | [`bill_add_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/bill/presentation/pages/bill_add_page.dart) | Tạo mới hóa đơn định kỳ | Tên hóa đơn; Số tiền; Danh mục; Ví thanh toán; Ngày đến hạn; Chu kỳ lặp; Nhắc hẹn trước |
| `/bills/:id/edit` | [`bill_edit_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/bill/presentation/pages/bill_edit_page.dart) | Sửa thông tin hóa đơn | Cập nhật số tiền, ngày hẹn, chu kỳ lặp hoặc ví mặc định |
| `/bills/:id` | [`bill_detail_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/bill/presentation/pages/bill_detail_page.dart) | Chi tiết & Lịch sử kỳ thanh toán | Thông tin hóa đơn; Lịch sử thanh toán các tháng trước; Nút "Đánh dấu đã thanh toán" |
| — | [`bill_delete_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/bill/presentation/pages/bill_delete_page.dart) | Xóa hóa đơn định kỳ | Tùy chọn dừng theo dõi chu kỳ tương lai; Bảo toàn giao dịch cũ |

---

## 2. QUY TẮC PHÂN QUYỀN GÓI CƯỚC (FEATURE GATING)

- **Quy tắc trần gói Basic:** Tài khoản **Basic** được theo dõi tối đa **5 hóa đơn định kỳ hoạt động đồng thời**.
- **Cơ chế Chặn Router:**
  ```dart
  GoRoute(
    path: '/bills/add',
    redirect: redirectTaoTheoGoi(LoaiTran.hoaDon),
    builder: (_, s) => BillAddPage(...),
  )
  ```
  - Khi người dùng gói Basic có đủ 5 hóa đơn và cố gắng tạo thêm: Hệ thống tự động chuyển hướng sang `/premium?tran=hoa_don`.
  - Màn hình Nâng cấp gói hiển thị câu giải thích: *"Bạn đã dùng hết 5/5 hóa đơn miễn phí. Nâng cấp Premium để quản lý không giới hạn toàn bộ hóa đơn gia đình, tiền nhà, bảo hiểm, trả góp và thuê bao định kỳ!"*.
- **Gói Premium:** Quản lý không giới hạn số lượng hóa đơn định kỳ.

---

## 3. CƠ CHẾ VẬN HÀNH TỰ ĐỘNG HÓA THÔNG MINH

### 3.1. Các Loại Chu kỳ Lặp lại (Recurrence Cycles)
Hỗ trợ linh hoạt mọi chu kỳ thanh toán thực tế:
- 📅 **Hàng tuần (Weekly):** Tiền thuê phòng trọ theo tuần, tiền thể thao, học phí gia sư.
- 📆 **Hàng tháng (Monthly - Phổ biến nhất):** Tiền điện, tiền nước, internet, phí chung cư, tiền thuê nhà, cước điện thoại trả sau.
- 🏢 **Hàng quý (Quarterly - 3 tháng):** Thuế định kỳ, học phí đại học/cao đẳng, tiền bảo hiểm quý.
- 🎂 **Hàng năm (Yearly):** Phí gia hạn tên miền, bảo hiểm nhân thọ, bảo hiểm xe máy/ô tô, phí thẻ ngân hàng thường niên.

### 3.2. Nhắc hẹn Đa tầng (Proactive Notification Alerts)
- Tích hợp lịch nhắc nhở cục bộ trên thiết bị (`local_notifications`):
  - Nhắc trước 3 ngày: *"Hóa đơn Tiền điện (850.000 ₫) sắp đến hạn sau 3 ngày nữa"*.
  - Nhắc trước 1 ngày: *"Ngày mai đến hạn thanh toán Internet (280.000 ₫)"*.
  - Nhắc đúng ngày: *"Hôm nay là hạn chót thanh toán Tiền thuê nhà!"*.
- Giúp người dùng tránh hoàn toàn việc bị cắt dịch vụ hoặc chịu phí phạt trễ hạn.

### 3.3. Tự động hóa Kép khi "Đánh dấu đã thanh toán" (Auto-Bill Settlement)
Khi người dùng bấm nút **"Đánh dấu đã thanh toán"** trên app:
1. **Tự động sinh Giao dịch chi tiêu:** Hệ thống tạo ngay 1 bản ghi `Transaction` trừ số tiền tương ứng khỏi Ví đã chọn, gắn đúng danh mục (ví dụ: "Hóa đơn & Tiện ích").
2. **Tự động tịnh tiến ngày đến hạn:** Ngày hẹn của hóa đơn tự động cộng thêm 1 chu kỳ tiếp theo (ví dụ: từ ngày `15/10/2026` tự động nhảy sang `15/11/2026`) và chuyển trạng thái về `Upcoming`.
3. Nhờ cơ chế này, người dùng không bao giờ phải nhập lại hóa đơn mỗi tháng.

### 3.4. Gợi ý Nhận diện Khoản lặp Tự động (Smart Recurring Suggestion - B2)
- Thuật toán phân tích lịch sử giao dịch: Nếu phát hiện các khoản tiền tương tự lặp lại cùng một thời điểm trong tháng (ví dụ: ngày 5 hàng tháng đều chuyển `3.000.000 ₫` cho chủ trọ):
- Trang chủ sẽ xuất hiện thẻ gợi ý thông minh: *"Có vẻ đây là khoản chi lặp lại hàng tháng. Bạn có muốn tạo hóa đơn định kỳ để tự động theo dõi không?"*.
- Bấm vào thẻ $\rightarrow$ Form `/bills/add` tự động điền sẵn tên, số tiền và chu kỳ tháng.
