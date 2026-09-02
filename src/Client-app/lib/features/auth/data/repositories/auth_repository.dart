import '../models/user_model.dart';

/// Kết quả xác minh phiên đăng nhập với server.
enum SessionStatus {
  /// Server xác nhận tài khoản còn tồn tại và token dùng được.
  valid,

  /// Server khẳng định phiên không còn giá trị (401/404) — ví dụ tài khoản đã
  /// bị xoá khỏi CSDL nhưng JWT vẫn còn hạn. BẮT BUỘC đăng nhập lại.
  invalid,

  /// Chưa kết luận được (mất mạng, timeout, lỗi 5xx). Phải giữ phiên để không
  /// phá vỡ cam kết offline-first.
  unknown,
}

abstract class AuthRepository {
  Future<UserModel> login(String username, String password);
  Future<void> logout();
  Future<bool> checkAuthStatus();
  Future<UserModel?> getCurrentUser();

  /// Hỏi server xem phiên hiện tại có còn trỏ tới một tài khoản CÓ THẬT không.
  ///
  /// `checkAuthStatus()` chỉ xem chuỗi token có rỗng hay không, nên không phát
  /// hiện được trường hợp tài khoản đã bị xoá mà JWT vẫn còn hạn — khi đó mọi
  /// thao tác đẩy dữ liệu sẽ vỡ khoá ngoại `fk_*_account` ở phía CSDL.
  ///
  /// Việc phân loại lỗi được làm Ở ĐÂY chứ không phải ở bloc, vì trong dự án có
  /// HAI class `NetworkException` trùng tên; bắt lỗi theo kiểu ở tầng trên rất
  /// dễ import nhầm file và catch không bao giờ khớp.
  Future<SessionStatus> verifySession();

  // Các method mới (cần Backend)
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> forgotPassword(String email);
  Future<String> verifyOtp(String email, String otp);
  Future<void> resetPassword(String resetToken, String newPassword);
  Future<void> deleteAccount(String password);
  Future<void> cancelDelete();
  Future<Map<String, dynamic>> getProfile();
  Future<void> updateProfile(
      {String? fullname, String? phone, String? address, String? location});
  Future<void> requestEmailChange(String newEmail);
  Future<void> confirmEmailChange(String newEmail, String otp);

  // --- OTP Register ---
  Future<void> registerSendOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    String? phone,
  });
  Future<void> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  });
}
