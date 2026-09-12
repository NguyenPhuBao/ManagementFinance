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

  /// Đồng hồ ghi mốc nhận `countdown`; test tiêm thẳng.
  final DateTime Function() _now;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.secureStorage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  // ─── Login online → lưu token + cache offline credential ──────────────────────────
  @override
  Future<UserModel> login(String username, String password) async {
    final data = await remoteDataSource.login(username, password);

    await localDataSource.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    // `countdown` là số ngày chờ xoá còn lại LÚC NHẬN; ghi kèm mốc nhận để máy tự
    // đếm tiếp — không endpoint nào trả số mới (spec cưỡng chế đăng xuất §4.2).
    final goc = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    final user = goc.voiTrangThai(
      status: goc.status,
      countdown: goc.countdown,
      countdownNhanLuc: _now(),
    );
    await _cacheOfflineCredentials(username, password, user);
    return user;
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
    final Map<String, dynamic> profile;
    try {
      profile = await remoteDataSource.getProfile();
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
    try {
      await _dongBoTrangThai(profile['status']);
    } catch (_) {
      // Đồng bộ trạng thái chờ xoá là việc phụ: lỗi ghi bộ nhớ đệm không được
      // biến một phiên hợp lệ thành "không rõ", hay làm AuthBloc đăng xuất.
    }
    return SessionStatus.valid;
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

  // ─── Gửi yêu cầu xoá tài khoản (DELETE /auth/account) ────────────────────
  // Tài khoản sang `PendingDelete` và người dùng DÙNG TIẾP 30 ngày: không xoá
  // token, không đăng xuất. Bản trước xoá sạch phiên theo đặc tả 2026-08-17 —
  // backend chạy theo `docs/progress/Client-app.md` mục 12 (G33).
  @override
  Future<void> deleteAccount(String password) async {
    // Giữ người gửi TRƯỚC request: trong lúc chờ server (tới 30 giây) người dùng
    // đăng xuất rồi đăng nhập tài khoản khác được — xem [_cungTaiKhoan].
    final nguoiGui = await getCurrentUser();
    final data = await remoteDataSource.deleteAccount(password);
    final user = await getCurrentUser();
    if (user == null || !_cungTaiKhoan(nguoiGui, user)) return;
    final countdown = data['countdown'];
    await _ghiNguoiDung(user.voiTrangThai(
      status: data['status'] as String? ?? 'PendingDelete',
      countdown: countdown is num ? countdown.toInt() : null,
      countdownNhanLuc: _now(),
    ));
  }

  // ─── Huỷ yêu cầu xoá tài khoản (POST /auth/cancel-delete) ────────────────
  @override
  Future<void> cancelDelete() async {
    final nguoiHuy = await getCurrentUser(); // cùng lý do với [deleteAccount]
    try {
      await remoteDataSource.cancelDelete();
    } catch (_) {
      // Phiên đã đổi trong lúc chờ: lỗi là của tài khoản cũ. Hỏi lại server lúc
      // này là hỏi cho phiên mới, và "tài khoản mới không chờ xoá" không có nghĩa
      // tài khoản cũ đã huỷ được — ném lỗi, không đụng bộ nhớ đệm.
      final hienTai = await getCurrentUser();
      if (hienTai == null || !_cungTaiKhoan(nguoiHuy, hienTai)) rethrow;
      // Không nhận diện lỗi bằng mã hay câu chữ: datasource ném `Exception(msg)`
      // làm mất mã HTTP, và backend dùng 400 cả cho lỗi kiểm tra đầu vào. Hỏi
      // lại server — đã `Active` (huỷ ở máy khác) thì coi như xong.
      await verifySession();
      final user = await getCurrentUser();
      if (user != null && !user.dangChoXoa) return;
      rethrow;
    }
    final user = await getCurrentUser();
    if (user == null || !_cungTaiKhoan(nguoiHuy, user)) return;
    await _ghiNguoiDung(user.voiTrangThai(status: 'Active'));
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
    UserModel user,
  ) async {
    await secureStorage.write(
        key: AppConstants.offlineUsernameKey, value: username);
    await secureStorage.write(
        key: AppConstants.offlinePasswordHashKey,
        value: _hashPassword(password));
    await _ghiNguoiDung(user);
  }

  /// Ghi `user.toJson()` chứ không ghi JSON thô của server: `countdown_nhan_luc`
  /// là trường cục bộ, JSON thô không có. `offlineUserDataKey` chỉ tệp này đọc.
  Future<void> _ghiNguoiDung(UserModel user) async {
    await secureStorage.write(
        key: AppConstants.offlineUserDataKey, value: jsonEncode(user.toJson()));
  }

  /// Bộ nhớ đệm lúc này còn là của tài khoản đã gửi yêu cầu — so `id` (idaccount
  /// của phiên đăng nhập). Yêu cầu xoá/huỷ chờ server tới 30 giây; đăng xuất rồi
  /// đăng nhập tài khoản khác giữa chừng thì kết quả của tài khoản cũ không được
  /// ghi vào tài khoản mới. [truoc] `null`: lúc gửi chưa có người dùng nào, nên
  /// người dùng lúc này thuộc một phiên khác.
  bool _cungTaiKhoan(UserModel? truoc, UserModel sau) =>
      truoc != null && truoc.id == sau.id;

  /// `status` theo server là nguồn sự thật; `countdown` chỉ đến lúc đăng nhập
  /// hoặc gửi yêu cầu xoá. Khớp nhau thì giữ nguyên số ngày đang có.
  Future<void> _dongBoTrangThai(Object? statusServer) async {
    if (statusServer is! String || statusServer.isEmpty) return;
    final user = await getCurrentUser();
    if (user == null) return;
    final serverChoXoa = statusServer.toLowerCase() == 'pendingdelete';
    if (serverChoXoa == user.dangChoXoa) return;
    // Lệch: huỷ ở máy khác (server Active), hoặc yêu cầu gửi từ máy khác (server
    // PendingDelete) — máy này không có số ngày đúng, nên bỏ countdown.
    await _ghiNguoiDung(user.voiTrangThai(status: statusServer));
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}
