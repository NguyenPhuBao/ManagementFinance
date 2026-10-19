# 🏆 PHÂN HỆ 08: MỤC TIÊU TIẾT KIỆM & TÍCH LŨY (SAVINGS GOALS)

> **Mã phân hệ:** `GOAL`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/goal`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/goal)  
> **Quản lý trạng thái:** `GoalBloc`  
> **Cơ sở dữ liệu:** SQLite bảng `goals` (Đồng bộ 2 chiều qua Entity `goal`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/goals` | [`goal_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/goal/presentation/pages/goal_page.dart) | Quản lý danh sách mục tiêu | Thẻ Tổng tài sản tích lũy; Tab: Đang tích lũy / Đã hoàn thành; Thanh phần trăm; Nút Tạo mới |
| `/goals/add` | [`goal_add_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/goal/presentation/pages/goal_add_page.dart) | Tạo mới & Sửa mục tiêu | Tên mục tiêu; Số tiền đích; Số tiền ban đầu; Ngày hoàn thành dự kiến; Icon & Màu sắc; Nút Lưu |
| `/goals/:id` | [`goal_detail_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/goal/presentation/pages/goal_detail_page.dart) | Chi tiết tiến độ & Nạp/Rút | Vòng tròn phần trăm hoàn thành; Tính toán mức tiết kiệm/tháng; Nút "Nạp tiền"; Nút "Rút tiền"; Lịch sử nạp |

---

## 2. QUY TẮC PHÂN QUYỀN GÓI CƯỚC (FEATURE GATING)

- **Quy tắc trần gói Basic:** Tài khoản **Basic** được theo dõi tối đa **3 mục tiêu tiết kiệm chưa đạt**.
- **Cơ chế Chặn Router:**
  ```dart
  GoRoute(
    path: '/goals/add',
    redirect: redirectTaoTheoGoi(LoaiTran.mucTieu),
    builder: (_, s) => GoalAddPage(...),
  )
  ```
  - Khi người dùng gói Basic có đủ 3 mục tiêu đang tích lũy và bấm "+ Thêm mục tiêu": Router lập tức chuyển hướng sang `/premium?tran=muc_tieu`.
  - Màn hình Nâng cấp gói hiển thị câu giải thích: *"Bạn đã dùng hết 3/3 mục tiêu tiết kiệm miễn phí. Nâng cấp Premium để lập kế hoạch tài chính dài hạn không giới hạn (mua nhà, mua xe, quỹ hưu trí, học vấn con cái...)"*.
  - Chế độ chỉnh sửa `/goals/:id/edit` không bị chặn.
- **Gói Premium:** Không giới hạn số lượng mục tiêu tích lũy tài chính.

---

## 3. CƠ CHẾ VẬN HÀNH NGHIỆP VỤ & TỰ ĐỘNG HÓA TÀI CHÍNH

### 3.1. Thiết lập Kỳ hạn & Tính toán Lộ trình Tiết kiệm
- Khi người dùng nhập Số tiền mục tiêu (ví dụ: `60.000.000 ₫`) và Ngày hoàn thành (sau 12 tháng):
- Thuật toán tự động tính toán định mức tiết kiệm thông minh:
  $$\text{Số tiền cần tích lũy mỗi tháng} = \frac{\text{Số tiền còn thiếu}}{\text{Số tháng còn lại}} = \frac{60.000.000 - \text{Đã có}}{12}$$
- Giúp người dùng phân rã một mục tiêu lớn thành các bước hành động cụ thể, khả thi hàng tháng.

### 3.2. Cơ chế Nạp tiền vào Mục tiêu (Deposit to Goal)
- Khi người dùng có tiền nhàn rỗi muốn cất vào quỹ tiết kiệm:
- Bấm **"Nạp tiền"** trên màn hình chi tiết `/goals/:id`:
  1. Chọn Ví nguồn (Ví dụ: Trừ tiền từ Ví tiền mặt hoặc Ví tài khoản ngân hàng).
  2. Nhập số tiền nạp (Ví dụ: `5.000.000 ₫`).
  3. Hệ thống tự động sinh 1 giao dịch điều chuyển tiền, trừ số dư ví nguồn và tăng số tiền hiện có trong mục tiêu.
  4. Thanh tiến độ phần trăm tức thì nhảy lên và cập nhật số tiền còn thiếu.

### 3.3. Cơ chế Rút tiền từ Mục tiêu (Withdraw from Goal)
- Khi mục tiêu hoàn thành (đạt 100%) hoặc khi người dùng có việc khẩn cấp cần dùng đến quỹ:
- Bấm **"Rút tiền"**:
  1. Chọn Ví đích nhận tiền (Ví dụ: Rút tiền về Tài khoản ngân hàng).
  2. Nhập số tiền muốn rút.
  3. Hệ thống tự động giảm số tiền tích lũy của mục tiêu và cộng tiền vào ví nhận.

### 3.4. Điền sẵn Thông minh từ Trợ lý AI (C3 Deep Link)
- Khi người dùng chat với Trợ lý AI Gemini: *"Tôi muốn tiết kiệm 30 triệu mua Macbook trong 6 tháng tới"*.
- AI Chatbot phân tích yêu cầu và trả về một nút hành động kèm liên kết:
  `/goals/add?name=Mua%20Macbook&target=30000000&deadline=2027-04-17`
- Người dùng chỉ cần chạm vào nút: Form tạo mục tiêu tự động mở ra với đầy đủ tên, số tiền và ngày hạn đã được điền sẵn chính xác 100%.
