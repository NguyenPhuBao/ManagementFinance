import 'package:dio/dio.dart';

import '../../../../core/errors/app_exceptions.dart' show ServerException;
import '../../../../core/network/trang_thai_may_chu.dart';

/// Exception riêng cho lỗi mạng (không có internet / timeout).
///
/// CẢNH BÁO: trùng tên với `NetworkException` trong
/// `core/errors/app_exceptions.dart`. File này ném class ĐỊNH NGHĨA Ở ĐÂY.
/// Đừng bắt lỗi theo kiểu ở tầng bloc — dùng `AuthRepository.verifySession()`
/// để repository tự phân loại, tránh import nhầm file rồi catch không khớp.
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Không có kết nối mạng']);
  @override
  String toString() => message;
}

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String username, String password);

  // --- Các method cần Backend endpoint ---
  Future<void> logout(String accessToken);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> forgotPassword(String email);
  Future<String> verifyOtp(String email, String otp);
  Future<void> resetPassword(String resetToken, String newPassword);
  /// `data` của response: `{idaccount, status: 'PendingDelete', countdown: 30, scheduled_delete_at}`.
  Future<Map<String, dynamic>> deleteAccount(String password);

  /// `data` của response: `{idaccount, status: 'Active', countdown: null}`.
  Future<Map<String, dynamic>> cancelDelete();
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
  Future<Map<String, dynamic>> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final DateTime Function() _now;

  AuthRemoteDataSourceImpl({required this.dio, DateTime Function()? now}) : _now = now ?? DateTime.now;

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      if (_thanhCong(response.data)) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(_cauLoi(response.data, 'Đăng nhập thất bại'));
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      // G89 (spec mục 4.3): máy chủ bảo trì / phong toả mạng → câu của client — KHÔNG câu admin gõ (thông báo tối giản).
      final chan = _cauKhiMayChuChan(e.response!, _now());
      if (chan != null) throw Exception(chan);
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<void> logout(String accessToken) async {
    try {
      await dio.post(
        '/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      // Nếu lỗi mạng khi logout → bỏ qua, vẫn xóa local token
      if (!_isNetworkError(e)) {
        final msg = _cauLoi(e.response?.data, 'Lỗi đăng xuất');
        throw Exception(msg);
      }
    }
  }

  @override
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final response = await dio.patch(
        '/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
      if (!_thanhCong(response.data)) {
        throw Exception(_cauLoi(response.data, 'Đổi mật khẩu thất bại'));
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await dio.post('/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<String> verifyOtp(String email, String otp) async {
    try {
      final response = await dio.post(
        '/auth/verify-otp',
        data: {'email': email, 'otp': otp},
      );
      if (_thanhCong(response.data)) {
        // Backend trả về resetToken (camelCase)
        return response.data['data']['resetToken'] as String;
      }
      throw Exception(_cauLoi(response.data, 'OTP không hợp lệ'));
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<void> resetPassword(String resetToken, String newPassword) async {
    try {
      final response = await dio.post(
        '/auth/reset-password',
        data: {'resetToken': resetToken, 'newPassword': newPassword},
      );
      if (!_thanhCong(response.data)) {
        throw Exception(
            _cauLoi(response.data, 'Đặt lại mật khẩu thất bại'));
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> deleteAccount(String password) async {
    try {
      final response = await dio.delete(
        '/auth/account',
        data: {'password': password},
      );
      if (!_thanhCong(response.data)) {
        throw Exception(
            _cauLoi(response.data, 'Yêu cầu xóa tài khoản thất bại'));
      }
      return (response.data['data'] as Map<String, dynamic>?) ?? const {};
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> cancelDelete() async {
    try {
      final response = await dio.post('/auth/cancel-delete');
      if (!_thanhCong(response.data)) {
        throw Exception(
            _cauLoi(response.data, 'Hủy yêu cầu xóa tài khoản thất bại'));
      }
      return (response.data['data'] as Map<String, dynamic>?) ?? const {};
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dio.get('/auth/profile');
      if (_thanhCong(response.data)) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(_cauLoi(response.data, 'Không lấy được thông tin'));
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      // Giữ lại statusCode: 401/404 là dấu hiệu phiên trỏ tới tài khoản không
      // còn tồn tại, cần phân biệt với lỗi 5xx tạm thời. Chỉ khi body là JSON
      // của backend (G97): trang 404 HTML của proxy / Render không nói gì về
      // tài khoản, và `verifySession` đọc 404 là phiên chết → đăng xuất.
      final body = e.response?.data;
      throw ServerException(
        message: _cauLoi(body, 'Lỗi máy chủ'),
        statusCode: body is Map ? e.response?.statusCode : null,
      );
    }
  }

  @override
  Future<void> updateProfile({
    String? fullname,
    String? phone,
    String? address,
    String? location,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullname != null) body['fullname'] = fullname;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (location != null) body['location'] = location;

      final response = await dio.patch('/auth/profile', data: body);
      if (!_thanhCong(response.data)) {
        throw Exception(_cauLoi(response.data, 'Cập nhật thất bại'));
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<void> requestEmailChange(String newEmail) async {
    try {
      final response = await dio.post(
        '/auth/profile/request-email-change',
        data: {'newEmail': newEmail},
      );
      if (!_thanhCong(response.data)) {
        throw Exception(_cauLoi(response.data, 'Không thể gửi OTP'));
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<void> confirmEmailChange(String newEmail, String otp) async {
    try {
      final response = await dio.patch(
        '/auth/profile/confirm-email-change',
        data: {'newEmail': newEmail, 'otp': otp},
      );
      if (!_thanhCong(response.data)) {
        throw Exception(_cauLoi(response.data, 'Xác nhận thất bại'));
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  // ─── OTP Register ─────────────────────────────────────────────────────────

  @override
  Future<void> registerSendOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{
        'username': username,
        'fullname': fullname,
        'email': email,
        'password': password,
      };
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      final response = await dio.post('/auth/register/send-otp', data: body);
      if (!_thanhCong(response.data)) {
        throw Exception(_cauLoi(response.data, 'Không thể gửi OTP'));
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        throw const NetworkException(
            'Không có mạng. Vui lòng thử lại khi có kết nối.');
      }
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{
        'username': username,
        'fullname': fullname,
        'email': email,
        'password': password,
        'otp': otp,
      };
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      final response = await dio.post('/auth/register/verify-otp', data: body);
      if (_thanhCong(response.data)) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(_cauLoi(response.data, 'OTP không hợp lệ'));
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = _cauLoi(e.response?.data, 'Lỗi máy chủ');
      throw Exception(msg);
    }
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.response == null;
  }
}

/// Câu lỗi đọc từ body (G97): `message` khi body là JSON object và `message` là chuỗi có chữ, còn lại [macDinh]. Body
/// không phải JSON (trang HTML của proxy, Render lúc dịch vụ ngủ) thì Dio trả `String` — đọc `body['message']` thẳng là
/// `String[]` với khoá chuỗi → `TypeError`, và câu của nó lọt ra màn Đăng nhập.
String _cauLoi(Object? body, String macDinh) {
  if (body is! Map) return macDinh;
  final cau = body['message'];
  return cau is String && cau.trim().isNotEmpty ? cau : macDinh;
}

/// `success == true` của body JSON; body không phải `Map` (xem [_cauLoi]) là thất bại.
bool _thanhCong(Object? body) => body is Map && body['success'] == true;

/// Câu màn Đăng nhập khi máy chủ chặn (spec G89 mục 4.3); `null` = không phải bảo trì / phong toả → câu của server như cũ.
String? _cauKhiMayChuChan(Response res, DateTime bayGio) {
  final t = phanLoaiPhanHoi(
    status: res.statusCode,
    body: res.data,
    retryAfter: giaTriRetryAfter(res.headers['retry-after']),
    bayGio: bayGio,
  );
  switch (t) {
    case MayChuBaoTri():
      return 'Máy chủ đang bảo trì. Thử lại sau ít phút.';
    case MayChuPhongToa():
      final gio = gioPhongToaConHieuLuc(t, bayGio);
      final toi = gio != null ? ' tới ${chuGioHetHan(gio, bayGio)}' : '';
      return 'Mạng này đang bị máy chủ tạm chặn$toi. Thử lại sau hoặc đổi mạng (Wi-Fi ↔ 4G).';
    case MayChuBinhThuong() || null:
      return null;
  }
}
