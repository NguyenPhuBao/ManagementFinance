import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String username, String password);
  Future<void> logout();
  Future<bool> checkAuthStatus();
  Future<UserModel?> getCurrentUser();

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
