# 🎯 PHÂN HỆ 06: NGÂN SÁCH CHI TIÊU & CẢNH BÁO HẠN MỨC (BUDGET MANAGEMENT)

> **Mã phân hệ:** `BUDGET`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/budget`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/budget)  
> **Quản lý trạng thái:** `BudgetBloc`  
> **Cơ sở dữ liệu:** SQLite bảng `budgets` (Đồng bộ 2 chiều qua Entity `budget`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/budget` | [`budget_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/budget/presentation/pages/budget_page.dart) | Tổng quan các ngân sách | Thẻ Tổng ngân sách tháng; Danh sách ngân sách theo danh mục; Thanh tiến độ màu sắc; Nút Tạo mới |
| `/budget/rules` | [`budget_rules_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/budget/presentation/pages/budget_rules_page.dart) | Thiết lập quy tắc ngân sách | Chọn danh mục áp dụng; Hạn mức tiền; Chu kỳ tháng/tuần; Tự động gia hạn chu kỳ sau; Nút Lưu |
| `/budget/detail/:id` | [`budget_detail_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/budget/presentation/pages/budget_detail_page.dart) | Chi tiết & Dự báo ngân sách | Biểu đồ chi tiêu theo ngày; Danh sách giao dịch làm hao hụt ngân sách; Dự báo ngày vỡ hạn mức; Nút Sửa/Xóa |

---

## 2. QUY TẮC PHÂN QUYỀN GÓI CƯỚC (FEATURE GATING)

- **Quy tắc trần gói Basic:** Tài khoản **Basic** được tạo và theo dõi tối đa **3 ngân sách hoạt động đồng thời**.
- **Cơ chế Chặn Router:**
  ```dart
  GoRoute(
    path: '/budget/rules',
    redirect: redirectTaoTheoGoi(LoaiTran.nganSach),
    builder: (_, state) => BudgetRulesPage(...),
  )
  ```
  - Nếu người dùng gói Basic đã có 3 ngân sách và bấm "+ Tạo ngân sách mới" (kể cả từ Trang chủ, Drawer, hay lệnh tạo AI C3): Router tự động chuyển hướng sang `/premium?tran=ngan_sach`.
  - Màn hình Nâng cấp gói hiển thị rõ nguyên nhân: *"Bạn đã dùng hết 3/3 ngân sách miễn phí. Nâng cấp Premium để lập kế hoạch chi tiêu không giới hạn cho mọi danh mục!"*.
  - **Lưu ý kỹ thuật:** Nếu route có kèm tham số `?id=<uuid>` (chế độ Chỉnh sửa ngân sách đã có), router cho phép đi qua bình thường mà không bị chặn.
- **Gói Premium:** Tự do tạo ngân sách không giới hạn cho tất cả các danh mục chi tiêu.

---

## 3. CƠ CHẾ THEO DÕI & TÍNH TOÁN TIẾN ĐỘ THỜI GIAN THỰC

### 3.1. Tính toán Tự động theo Chu kỳ Tháng
- Khi có bất kỳ giao dịch Chi tiêu (`chi`) nào được tạo, sửa hoặc xóa:
  - Hệ thống tự động truy vấn tổng số tiền chi của danh mục đó trong khoảng thời gian từ ngày 1 đến ngày cuối cùng của tháng.
  - Cập nhật số tiền đã dùng (`spentAmount`) và phần trăm tiến độ (`percentage = (spentAmount / limitAmount) * 100`).

### 3.2. Mã Màu Nhận Diện & Hệ Thống Cảnh Báo Nguy Cơ Bội Chi
Thanh tiến độ (Progress Bar) tự động đổi màu trực quan để cảnh giác người dùng:
- 🟢 **Màu Xanh lá (< 70%):** Chi tiêu trong tầm kiểm soát an toàn.
- 🟡 **Màu Vàng / Cam (70% - 99%):** Nguy cơ bội chi. Hệ thống kích hoạt thông báo cảnh báo nhẹ: *"Bạn đã sử dụng hơn 80% ngân sách Ăn uống tháng này"*.
- 🔴 **Màu Đỏ (>= 100%):** Bội chi ngân sách. Thanh tiến độ hiển thị số tiền vượt hạn mức, gửi thông báo cảnh báo đỏ trên Trung tâm thông báo.

### 3.3. Thuật toán Đề xuất Chi tiêu Hàng ngày (Daily Allowance)
Để giúp người dùng không bị "cháy túi" vào cuối tháng, ứng dụng tính toán định mức chi tiêu an toàn:
$$\text{Số tiền được tiêu mỗi ngày} = \frac{\text{Hạn mức còn lại}}{\text{Số ngày còn lại trong tháng}}$$
- **Ví dụ thực tế:** Ngân sách Ăn uống còn `1.500.000 ₫` và tháng còn 10 ngày $\rightarrow$ Màn hình hiển thị: *"Bạn nên chi tối đa 150.000 ₫/ngày để hoàn thành mục tiêu ngân sách"*.

### 3.4. Dự báo Ngày Vỡ Ngân Sách (Burn-Rate Forecast)
Dựa trên tốc độ chi tiêu bình quân của những ngày đã qua trong tháng, thuật toán phân tích xu hướng và đưa ra cảnh báo sớm:
- *"Với tốc độ chi tiêu hiện tại (250.000 ₫/ngày), dự kiến bạn sẽ vượt ngân sách vào ngày 22 tháng này!"*.
- Điều này tạo động lực tâm lý mạnh mẽ giúp người dùng chủ động thắt chặt chi tiêu trước khi quá muộn.
