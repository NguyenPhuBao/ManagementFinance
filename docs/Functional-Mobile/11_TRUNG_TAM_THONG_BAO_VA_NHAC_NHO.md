# 🔔 PHÂN HỆ 11: TRUNG TÂM THÔNG BÁO & GIÁM SÁT NGÂN HÀNG (NOTIFICATION & BANK REMINDERS)

> **Mã phân hệ:** `NOTIF`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/notification`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/notification) & [`src/Client-app/lib/core/nen`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/nen)  
> **Quản lý trạng thái:** `NotificationBloc`  
> **Cơ chế chạy nền:** `flutter_local_notifications` & Android UsageStatsManager (`PACKAGE_USAGE_STATS`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/notifications` | [`notification_center_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/notification/presentation/pages/notification_center_page.dart) | Trung tâm thông báo | Danh sách thông báo gom nhóm; Bộ lọc Hóa đơn/Ngân sách/Biến động; Nút Đánh dấu đã đọc |
| `/settings/notifications` | [`notification_settings_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/notification/presentation/pages/notification_settings_page.dart) | Cài đặt tùy chỉnh thông báo | Công tắc bật/tắt từng loại nhắc nhở; Đặt giờ nhắc chi tiêu 21:00; Xin quyền Android 13+ |
| — | [`dong_y_nhac_sau_ngan_hang_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/notification/presentation/pages/dong_y_nhac_sau_ngan_hang_page.dart) | Xin phép quyền giám sát ngân hàng | Màn hình giải thích minh bạch lý do xin quyền `PACKAGE_USAGE_STATS`; Nút Đồng ý |
| — | [`dong_y_bien_dong_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/notification/presentation/pages/dong_y_bien_dong_page.dart) | Xác nhận đọc biến động | Màn hình giới thiệu lợi ích tự động hóa ghi chép; Nút Cho phép kích hoạt |

---

## 2. TRUNG TÂM THÔNG BÁO TỔNG HỢP (`/notifications`)

Trung tâm thông báo phân loại thông điệp thành **5 nhóm chuyên biệt** giúp người dùng dễ dàng theo dõi và xử lý:
1. 🧾 **Nhóm Hóa đơn (Bills):** Nhắc hẹn các khoản chi lặp lại sắp đến hạn (trước 3 ngày, 1 ngày, đúng ngày hoặc quá hạn).
2. 🎯 **Nhóm Ngân sách (Budgets):** Cảnh báo khi một danh mục chi tiêu chạm mốc 80% hoặc đã vượt 100% hạn mức tháng.
3. 💳 **Nhóm Biến động số dư & Ngân hàng (D1):** Lời nhắc ghi chép sau khi người dùng thực hiện chuyển khoản trên các ứng dụng ngân hàng.
4. 📈 **Nhóm Báo cáo Tổng kết:** Thông báo tóm tắt tài chính vào 21:00 mỗi tối và bản tin Tổng kết tuần vào sáng Chủ nhật (kèm nút xem báo cáo `/export-report`).
5. 📢 **Nhóm Hệ thống & Bảo trì:** Thông báo lịch bảo trì hệ thống từ Ban Quản trị (`admin.maintenance_changed`) được phát realtime qua Socket.IO.

- **Deep Link thông minh khi chạm vào thông báo:**
  - Chạm thông báo hóa đơn $\rightarrow$ mở thẳng chi tiết hóa đơn `/bills/:id`.
  - Chạm thông báo ngân sách $\rightarrow$ mở biểu đồ ngân sách `/budget/detail/:id`.
  - Chạm thông báo biến động ngân hàng $\rightarrow$ mở thẳng form `/add` đã điền sẵn số liệu.

---

## 3. TÍNH NĂNG ĐỘT PHÁ: GIÁM SÁT ỨNG DỤNG NGÂN HÀNG (D1 BANK SESSION MONITORING)

### 3.1. Nỗi đau của người dùng quản lý tài chính
- Người dùng thường quên ghi chép ngay sau khi chuyển khoản tiền ăn, mua sắm trên app ngân hàng. Đến cuối tuần mới nhớ ra thì đã quên mất số tiền và mục đích tiêu.

### 3.2. Giải pháp Thông minh D1 của FlowMoney
Ứng dụng tích hợp service chạy ngầm theo dõi các ứng dụng ngân hàng phổ biến tại Việt Nam:
- **Danh sách ngân hàng hỗ trợ:** MB Bank, Vietcombank, Techcombank, VPBank, ACB, TPBank, BIDV, VietinBank, MoMo, ZaloPay...
- **Cơ chế hoạt động:**
  1. Khi người dùng mở app MB Bank chuyển tiền: Service ghi nhận bắt đầu phiên ngân hàng.
  2. Khi người dùng chuyển tiền xong và thoát app ngân hàng ra màn hình chính:
  3. FlowMoney nhận diện kết thúc phiên và tức thì bật thông báo nhẹ nhàng:
     *"Bạn vừa chuyển khoản ngân hàng? Chạm vào đây để ghi chép lại trong 3 giây nhé!"*.
  4. Người dùng bấm vào thông báo: Form `/add` mở ra sẵn sàng, người dùng chỉ cần nhập số tiền và bấm "Lưu".

### 3.3. Tuân thủ 100% Nguyên tắc Bảo mật & Quyền Riêng tư (Data_Security.md)
- Tuyệt đối **KHÔNG** đọc mật khẩu, OTP hay màn hình nội dung bên trong app ngân hàng.
- Chỉ đọc sự kiện mở/đóng package name của app ngân hàng thông qua quyền `PACKAGE_USAGE_STATS` đã được người dùng cấp phép rõ ràng.

---

## 4. TÙY CHỈNH THÔNG BÁO LINH HOẠT (`/settings/notifications`)

Người dùng có toàn quyền bật/tắt và cá nhân hóa trải nghiệm thông báo:
- Công tắc bật/tắt độc lập cho từng loại: Hóa đơn, Ngân sách, Ngân hàng, Báo cáo ngày/tuần.
- Bộ chọn giờ thông báo (Time Picker): Đặt giờ thông báo nhắc nhở buổi tối (mặc định 21:00).
- Tương thích hoàn hảo với cơ chế quyền thông báo nghiêm ngặt của **Android 13+ (API 33+)** và tính năng ngủ đông (Doze Mode).
