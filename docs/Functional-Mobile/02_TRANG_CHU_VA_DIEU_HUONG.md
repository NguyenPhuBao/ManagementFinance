# 🏠 PHÂN HỆ 02: TRANG CHỦ & ĐIỀU HƯỚNG NAVIGATION SHELL

> **Mã phân hệ:** `HOME`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/home`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/home) & [`src/Client-app/lib/shared/widgets/main_shell.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/shared/widgets/main_shell.dart)  
> **Kiến trúc điều hướng:** `StatefulShellRoute.indexedStack` (Giữ nguyên trạng thái 4 tabs khi chuyển đổi)

---

## 1. KIẾN TRÚC NAVIGATION SHELL (MAIN SHELL)

Ứng dụng sử dụng cấu trúc điều hướng hiện đại `MainShell` với thanh điều hướng đáy (**Bottom Navigation Bar**) gồm 4 Tab chính:

```
┌──────────────────────────────────────────────────────────┐
│                     NỘI DUNG TRANG                       │
│       (Home / Analytics / Transactions / Profile)        │
├─────────────┬─────────────┬──────────────┬───────────────┤
│ 🏠 Trang chủ │ 📊 Phân tích│ 📖 Sổ GD     │ 👤 Cá nhân    │
│   (/home)   │(/analytics) │(/transactions)│  (/profile)   │
└─────────────┴─────────────┴──────────────┴───────────────┘
```

- **IndexedStack State Preservation:** Khi người dùng chuyển qua lại giữa các tab (ví dụ: từ Trang chủ sang Sổ giao dịch rồi quay lại), vị trí cuộn trang, bộ lọc và trạng thái dữ liệu của từng tab được bảo toàn nguyên vẹn, không bị reload lại từ đầu.

---

## 2. CHI TIẾT GIAO DIỆN & CÁC THÀNH PHẦN TRÊN TRANG CHỦ (`/home`)

### 2.1. Thanh Header & Chuông Thông báo
- **Lời chào cá nhân hóa:** Hiển thị Họ tên người dùng theo thời gian thực (Chào buổi sáng / Buổi chiều / Buổi tối).
- **Chuông thông báo (Notification Bell):**
  - Tích hợp Badge màu đỏ hiển thị số lượng thông báo chưa đọc.
  - Chạm vào chuông sẽ điều hướng thẳng sang Trung tâm thông báo (`/notifications`).

### 2.2. Thẻ Cảnh báo Trạng thái Tài khoản Chờ xóa (`the_cho_xoa_trang_chu.dart`)
- **Điều kiện kích hoạt:** Chỉ xuất hiện khi tài khoản người dùng đang ở trạng thái `PendingDelete` (đã gửi yêu cầu xóa tài khoản).
- **Giao diện:** Thẻ cảnh báo viền cam nổi bật trên đầu trang chủ, hiển thị rõ số ngày ân hạn còn lại (ví dụ: *"Tài khoản sẽ bị xóa vĩnh viễn sau 28 ngày"*).
- **Hành động 1 chạm:** Tích hợp nút **"Hủy yêu cầu xóa"** trực tiếp. Bấm nút sẽ gọi API phục hồi tài khoản về trạng thái `Active` ngay lập tức mà không cần vào sâu Cài đặt.

### 2.3. Thẻ Tổng Tài sản Ròng & Thu Chi Tháng (`the_so_lieu_thang.dart`)
- **Tổng số dư tài sản (Net Worth):** Tự động tính toán tổng số tiền khả dụng trên tất cả các ví đang hoạt động (`active wallets`).
- **Chế độ Riêng tư (Eye Toggle):** Nút icon con mắt cho phép ẩn/hiện số dư (`*** ₫`) giúp bảo vệ thông tin tài chính nhạy cảm khi mở app ở nơi công cộng.
- **Thống kê Thu - Chi trong tháng:**
  - Ô màu xanh lá: Tổng tiền thu nhập thực tế trong tháng.
  - Ô màu đỏ/cam: Tổng tiền chi tiêu thực tế trong tháng.
  - Tỷ lệ chênh lệch dòng tiền (+/-).

### 2.4. Hàng Phím Tắt Nhanh 1 Chạm (`hang_nut_nhanh.dart`)
Hỗ trợ nhập liệu siêu tốc với 5 thao tác thiết yếu:
1. **Thu tiền (+):** Mở form `/add` với hướng đặt sẵn là `thu` $\rightarrow$ chọn nhanh danh mục Lương, Thưởng, Thu nhập khác.
2. **Chi tiền (-):** Mở form `/add` với hướng đặt sẵn là `chi` $\rightarrow$ chọn danh mục Ăn uống, Mua sắm, Di chuyển...
3. **Chuyển khoản ($\leftrightarrow$):** Mở form `/add` ở chế độ Chuyển tiền giữa các ví (Ví dụ: Chuyển tiền từ Tài khoản ngân hàng sang Ví tiền mặt).
4. **Nói (Voice Input Micro):** Mở `/add?noi=1` $\rightarrow$ Kích hoạt bộ thu âm nhận diện giọng nói On-Device (Whisper), người dùng chỉ cần nói *"Ăn trưa bún bò 45 nghìn"* là hệ thống tự động điền form.
5. **Quét hóa đơn (OCR Camera):** Mở chụp ảnh biên lai / hóa đơn chuyển sang màn hình `/quet` để bóc tách số tiền và danh mục tự động.

### 2.5. Thẻ Tóm tắt Ngân sách Tháng (`home_budget_card.dart`)
- Hiển thị thanh đo tiến độ chi tiêu so với hạn mức ngân sách tổng của tháng.
- Đổi màu động theo ngưỡng cảnh báo:
  - Màu xanh lá: Dưới 70% ngân sách.
  - Màu vàng/cam: Từ 70% đến 99% ngân sách (Nguy cơ bội chi).
  - Màu đỏ: Đã vượt quá 100% hạn mức ngân sách.
- Chạm vào thẻ sẽ điều hướng tới màn hình Quản lý ngân sách (`/budget`).

### 2.6. Thẻ Tiến độ Mục tiêu Tiết kiệm (`home_goal_card.dart`)
- Hiển thị mục tiêu tiết kiệm gần nhất đang tích lũy (Ví dụ: *"Mua xe máy"* hoặc *"Quỹ khẩn cấp"*).
- Thanh phần trăm hoàn thành, số tiền hiện có / số tiền đích.
- Chạm vào thẻ dẫn tới màn hình Mục tiêu tiết kiệm (`/goals`).

### 2.7. Danh sách Giao dịch Gần đây (Recent Transactions)
- Hiển thị 5 giao dịch phát sinh mới nhất.
- Mỗi dòng hiển thị: Icon danh mục, Tên giao dịch/ghi chú, Tên ví thanh toán, Ngày giờ và Số tiền biến động (+/-).
- Nút **"Xem tất cả"** chuyển thẳng sang Tab 3 (Sổ giao dịch `/transactions`).

---

## 3. MENU ĐIỀU HƯỚNG MỞ RỘNG (APP DRAWER)

Trang chủ tích hợp Drawer mở rộng bên trái (`drawer_trang_chu.dart`) cung cấp lối vào toàn diện tới tất cả các tính năng mở rộng của hệ thống:
1. **Thông tin Header:** Ảnh đại diện (Avatar), Họ tên người dùng, Email và **Huy hiệu Gói cước (Badge: Basic hoặc Premium)**.
2. **Nhóm Tính năng Tài chính Chuyên sâu:**
   - 💳 **Quản lý Ví:** Quản lý tài khoản ngân hàng, tiền mặt, ví điện tử (`/wallets`).
   - 🏷️ **Quản lý Danh mục:** Tùy biến cây danh mục thu chi (`/categories`).
   - 🎯 **Ngân sách:** Thiết lập và theo dõi hạn mức chi tiêu (`/budget`).
   - 🧾 **Hóa đơn định kỳ:** Quản lý các khoản chi lặp lại (`/bills`).
   - 🏆 **Mục tiêu tiết kiệm:** Kế hoạch tích lũy tài chính (`/goals`).
3. **Nhóm Tính năng Thông minh & Báo cáo:**
   - 🤖 **Trợ lý AI Tài chính:** Chatbot AI Gemini tư vấn tài chính (`/ai-chat`).
   - 📈 **Xuất Báo cáo:** Tải báo cáo PDF/Excel chuyên nghiệp (`/export-report`).
4. **Nhóm Cài đặt & Hệ thống:**
   - ⚙️ **Cài đặt Ứng dụng:** Bảo mật, Thông báo, Giao diện (`/settings`).
   - 💎 **Nâng cấp Premium:** Mở khóa không giới hạn tính năng (`/premium`).
