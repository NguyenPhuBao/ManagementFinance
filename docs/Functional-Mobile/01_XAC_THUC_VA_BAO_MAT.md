# 🔐 PHÂN HỆ 01: XÁC THỰC & BẢO MẬT TÀI KHOẢN (AUTH & SECURITY)

> **Mã phân hệ:** `AUTH`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/auth`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/auth) & [`src/Client-app/lib/features/profile`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/profile)  
> **Quản lý trạng thái:** `AuthBloc` (`BlocProvider<AuthBloc>`)  
> **Cơ chế lưu trữ:** `flutter_secure_storage` (Tokens) & `SharedPreferences` (Offline cache)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/login` | [`login_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/auth/presentation/pages/login_page.dart) | Đăng nhập tài khoản | Form nhập Username/Email & Mật khẩu; Nút Đăng nhập; Nút Sinh trắc học; Quên mật khẩu; Đăng ký mới |
| `/register` | [`register_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/auth/presentation/pages/register_page.dart) | Đăng ký tài khoản | Nhập Họ tên, Username, Email, Mật khẩu, Xác nhận mật khẩu; Kiểm tra độ mạnh mật khẩu; Nút Tiếp tục |
| `/register/verify-otp` | [`register_otp_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/auth/presentation/pages/register_otp_page.dart) | Xác thực Email qua mã OTP | 6 ô nhập mã OTP; Đồng hồ đếm ngược 60s; Nút Gửi lại mã qua Brevo API; Tự động kích hoạt tài khoản |
| `/forgot-password` | [`forgot_password_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/auth/presentation/pages/forgot_password_page.dart) | Yêu cầu khôi phục mật khẩu | Ô nhập Email đã đăng ký; Kiểm tra email hợp lệ; Gửi mã OTP khôi phục |
| `/otp` | [`otp_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/auth/presentation/pages/otp_page.dart) | Xác thực OTP quên mật khẩu | Nhập mã OTP xác minh danh tính; Nhận Reset Token bảo mật |
| `/reset-password` | [`reset_password_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/auth/presentation/pages/reset_password_page.dart) | Thiết lập mật khẩu mới | Ô nhập Mật khẩu mới & Xác nhận mật khẩu; Gửi kèm Reset Token lên Backend |
| `/settings/change-password` | [`change_password_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/profile/presentation/pages/change_password_page.dart) | Đổi mật khẩu trong ứng dụng | Nhập Mật khẩu hiện tại, Mật khẩu mới và Nhập lại mật khẩu mới |
| `/settings/delete-account` | [`delete_account_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/profile/presentation/pages/delete_account_page.dart) | Vòng đời Xóa tài khoản (30 ngày) | Hiển thị cảnh báo pháp lý; Xác nhận xóa; Đếm ngược 30 ngày ân hạn; Nút Hủy xóa phục hồi tài khoản |

---

## 2. LUỒNG NGHIỆP VỤ CHI TIẾT (BUSINESS LOGIC FLOWS)

### 2.1. Luồng Đăng ký & Kích hoạt qua Email OTP (Brevo HTTPS REST API)
1. Người dùng điền thông tin: Họ tên, Username, Email, Mật khẩu $\rightarrow$ Bấm "Tiếp tục".
2. Client-app gọi `POST /api/auth/register` lên Backend.
3. Backend tạo bản ghi tạm và gửi email chứa mã OTP 6 số qua kênh Brevo API (cổng 443 HTTPS an toàn, phản hồi siêu tốc 2.5s).
4. Client chuyển hướng sang màn hình `/register/verify-otp`.
5. Người dùng nhập đủ 6 chữ số:
   - Hệ thống tự động submit mà không cần bấm nút phụ.
   - Gửi `POST /api/auth/verify-registration-otp`.
   - Nếu đúng: Server trả về Access Token + Refresh Token $\rightarrow$ Client lưu SecureStorage và điều hướng thẳng vào `/home`.
   - Đếm ngược 60 giây trước khi cho phép bấm nút "Gửi lại mã OTP".

### 2.2. Luồng Đăng nhập & Duy trì Phiên Ngoại tuyến (Offline-First Session)
1. **Đăng nhập Trực tuyến (Online Login):**
   - Người dùng nhập Username/Email + Mật khẩu.
   - Gửi `POST /api/auth/login`.
   - Lưu `accessToken`, `refreshToken` và thông tin người dùng an toàn vào `FlutterSecureStorage`.
2. **Khởi chạy Ngoại tuyến (Offline Session Persistence):**
   - Khi thiết bị không có internet (mất sóng/mạng chập chờn):
   - Client-app đọc token và thông tin người dùng đã được bảo vệ trong `FlutterSecureStorage` để khởi động phiên làm việc Offline (`AuthSuccess` cục bộ), cho phép người dùng truy cập và ghi chép toàn bộ dữ liệu SQLite trên máy.
   - Không lưu băm mật khẩu ra SharedPreferences để tuân thủ tuyệt đối an toàn thông tin (Data Security).

### 2.3. Khóa Ứng Dụng Bằng Mã PIN & Sinh Trắc Học (App Lock)
- Hỗ trợ bảo vệ ứng dụng bằng Mã PIN 6 chữ số và Sinh trắc học (Vân tay / Khuôn mặt qua `BiometricPrompt` gắn Android Keystore / iOS Keychain, không dùng `local_auth`).
- Đây là cơ chế Khóa ứng dụng cục bộ (App Lock) khi mở app hoặc quay lại từ nền, độc lập với luồng xác thực đăng nhập tài khoản.
- Toàn bộ xác thực sinh trắc học và PIN diễn ra 100% tại thiết bị người dùng (On-Device Local Verification), tuyệt đối không gửi lên server (tuân thủ `Data_Security.md`). Chi tiết xem tại `docs/KHOA_APP_FEATURE.md`.

### 2.4. Vòng đời Xóa tài khoản (PendingDelete 30 Ngày Ân Hạn)
Tuân thủ Nghị định 13/2023/NĐ-CP và chính sách Google Play Store / Apple Store:
1. **Yêu cầu xóa:** Người dùng nhập mật khẩu xác nhận tại `/settings/delete-account` $\rightarrow$ Gửi `POST /api/auth/request-delete-account`.
2. **Trạng thái PendingDelete:**
   - Tài khoản được chuyển sang trạng thái chờ xóa với thời gian ân hạn 30 ngày (`deletionCountdown = 30`).
   - Trên đỉnh Trang chủ xuất hiện thẻ cảnh báo màu cam [`the_cho_xoa_trang_chu.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/home/presentation/widgets/the_cho_xoa_trang_chu.dart) thông báo rõ số ngày còn lại.
3. **Hủy xóa tài khoản (Phục hồi tức thì):**
   - Trong vòng 30 ngày, người dùng bấm nút "Hủy xóa tài khoản" ngay trên thẻ trang chủ hoặc trong cài đặt.
   - Gửi `POST /api/auth/cancel-delete-account`.
   - Trạng thái tài khoản lập tức phục hồi về `Active`, thẻ cảnh báo biến mất.
4. **Hết hạn 30 ngày:** Backend tự động ẩn danh hóa (Anonymization Soft-Delete) và thanh lọc dữ liệu.

---

## 3. CƠ CHẾ BẢO VỆ TOKEN & PHIÊN LÀM VIỆC (SESSION SECURITY)

- **JWT Refresh Token Rotation:**
  - Token hết hạn sau 15 phút.
  - Bộ chặn `AuthInterceptor` tự động bắt mã lỗi `401 Unauthorized` $\rightarrow$ tự động gọi `POST /api/auth/refresh-token` ngầm $\rightarrow$ cập nhật Access Token mới và gửi lại request ban đầu mà người dùng không hề bị gián đoạn thao tác.
- **Che bớt thông tin nhạy cảm:**
  - Ẩn/hiện mật khẩu bằng icon con mắt.
  - Không in mật khẩu hoặc token ra console log.
