import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart' show ServerException;
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// AuthRepositoryImpl — lớp triển khai duy nhất, kết nối Remote + Local.
///
/// Nguyên tắc:
/// - Login: bắt buộc online → lưu tokens + cache offline
/// - Logout: gọi API revoke token trên server, rồi xóa sạch local token và offline cache
/// - checkAuthStatus: chỉ kiểm tra có accessToken không (offline-safe)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final FlutterSecureStorage secureStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.secureStorage,
  });

  // ─── Login online → lưu token + cache offline credential ──────────────────────────
  @override
  Future<UserModel> login(String username, String password) async {
    final data = await remoteDataSource.login(username, password);

    await localDataSource.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    final userJson = data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);
    await _cacheOfflineCredentials(username, password, userJson);

    // Đính kèm pendingDeleteCancelled vào user trường hợp tài khoản vừa được khôi phục
    final pendingDeleteCancelled =
        data['pendingDeleteCancelled'] as bool? ?? false;
    return user.copyWith(pendingDeleteCancelled: pendingDeleteCancelled);
  }

  // ─── Logout: gọi API revoke token + xóa tất cả local data ───────────────
  @override
  Future<void> logout() async {
    final accessToken = await localDataSource.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        await remoteDataSource.logout(accessToken);
      } catch (_) {
        // Bỏ qua lỗi network — vẫn xóa local token
      }
    }
    await _clearLocalData();
  }

  // ─── Kiểm tra có token không (offline-safe) ─────────────────────────────
  @override
  Future<bool> checkAuthStatus() async {
    final token = await localDataSource.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Xác minh phiên với server ───────────────────────────────────────────
  // Dùng GET /auth/profile vì đây là endpoint DUY NHẤT thật sự truy vấn CSDL.
  // KHÔNG dùng /auth/me: nó chỉ echo lại payload trong JWT nên vẫn trả 200 cho
  // tài khoản đã bị xoá.
  @override
  Future<SessionStatus> verifySession() async {
    final token = await localDataSource.getAccessToken();
    if (token == null || token.isEmpty) return SessionStatus.invalid;
    try {
      await remoteDataSource.getProfile();
      return SessionStatus.valid;
    } on ServerException catch (e) {
      // 401 = token không được chấp nhận; 404 = không còn hồ sơ người dùng
      // (fk_user_account có onDelete: Cascade nên xoá account là mất luôn user).
      final code = e.statusCode;
      if (code == 401 || code == 404) return SessionStatus.invalid;
      return SessionStatus.unknown; // 5xx và các mã khác: coi là tạm thời
    } catch (_) {
      // Bao gồm NetworkException (định nghĩa trong auth_remote_data_source.dart)
      // và mọi lỗi không phân loại được → KHÔNG đăng xuất người dùng offline.
      return SessionStatus.unknown;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final userDataStr =
        await secureStorage.read(key: AppConstants.offlineUserDataKey);
    if (userDataStr != null && userDataStr.isNotEmpty) {
      try {
        final json = jsonDecode(userDataStr) as Map<String, dynamic>;
        return UserModel.fromJson(json);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ─── Đổi mật khẩu (cần Backend: PATCH /auth/change-password) ────────────
  @override
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await remoteDataSource.changePassword(currentPassword, newPassword);
    // Server revoke toàn bộ session → xóa local token, buộc đăng nhập lại
    await _clearLocalData();
  }

  // ─── Quên mật khẩu (cần Backend: POST /auth/forgot-password) ─────────────
  @override
  Future<void> forgotPassword(String email) async {
    await remoteDataSource.forgotPassword(email);
  }

  // ─── Xác minh OTP (cần Backend: POST /auth/verify-otp) ──────────────────
  @override
  Future<String> verifyOtp(String email, String otp) async {
    return remoteDataSource.verifyOtp(email, otp);
  }

  // ─── Đặt lại mật khẩu (cần Backend: POST /auth/reset-password) ──────────
  @override
  Future<void> resetPassword(String resetToken, String newPassword) async {
    await remoteDataSource.resetPassword(resetToken, newPassword);
  }

  // ─── Xóa tài khoản (gửi yêu cầu ân hạn 30 ngày: DELETE /auth/account) ───────────
  @override
  Future<void> deleteAccount(String password) async {
    await remoteDataSource.deleteAccount(password);
    await _clearLocalData();
  }

  // ─── Hủy yêu cầu xóa tài khoản (POST /auth/cancel-delete) ─────────────────────
  @override
  Future<void> cancelDelete() async {
    await remoteDataSource.cancelDelete();
  }

  // ─── Lấy thông tin profile (cần Backend: GET /auth/profile) ─────────────
  @override
  Future<Map<String, dynamic>> getProfile() async {
    return remoteDataSource.getProfile();
  }

  // ─── Cập nhật profile (cần Backend: PATCH /auth/profile) ────────────────
  @override
  Future<void> updateProfile({
    String? fullname,
    String? phone,
    String? address,
    String? location,
  }) async {
    await remoteDataSource.updateProfile(
      fullname: fullname,
      phone: phone,
      address: address,
      location: location,
    );
  }

  // ─── Yêu cầu đổi email (cần Backend: POST /auth/profile/request-email-change) ─
  @override
  Future<void> requestEmailChange(String newEmail) async {
    await remoteDataSource.requestEmailChange(newEmail);
  }

  // ─── Xác nhận đổi email (cần Backend: PATCH /auth/profile/confirm-email-change) ─
  @override
  Future<void> confirmEmailChange(String newEmail, String otp) async {
    await remoteDataSource.confirmEmailChange(newEmail, otp);
  }

  // ─── OTP Register: Bước 1 — Gửi OTP về email ────────────────────────────
  @override
  Future<void> registerSendOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    String? phone,
  }) async {
    await remoteDataSource.registerSendOtp(
      username: username,
      fullname: fullname,
      email: email,
      password: password,
      phone: phone,
    );
  }

  // ─── OTP Register: Bước 2 — Xác thực OTP và tạo tài khoản ───────────────
  @override
  Future<void> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async {
    await remoteDataSource.registerVerifyOtp(
      username: username,
      fullname: fullname,
      email: email,
      password: password,
      otp: otp,
      phone: phone,
    );
  }

  // ─── Private helpers ─────────────────────────────────────────────────────
  Future<void> _clearLocalData() async {
    await localDataSource.deleteTokens();
    await secureStorage.delete(key: AppConstants.offlineUsernameKey);
    await secureStorage.delete(key: AppConstants.offlinePasswordHashKey);
    await secureStorage.delete(key: AppConstants.offlineUserDataKey);
  }

  Future<void> _cacheOfflineCredentials(
    String username,
    String password,
    Map<String, dynamic> userJson,
  ) async {
    await secureStorage.write(
        key: AppConstants.offlineUsernameKey, value: username);
    await secureStorage.write(
        key: AppConstants.offlinePasswordHashKey,
        value: _hashPassword(password));
    await secureStorage.write(
        key: AppConstants.offlineUserDataKey, value: jsonEncode(userJson));
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}
