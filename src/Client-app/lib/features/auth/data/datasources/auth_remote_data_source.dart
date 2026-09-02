import 'package:dio/dio.dart';

import '../../../../core/errors/app_exceptions.dart' show ServerException;

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

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        // Đính kèm pendingDeleteCancelled từ data nếu backend trả về
        return data;
      }
      throw Exception(response.data['message'] ?? 'Đăng nhập thất bại');
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
        final msg = e.response?.data?['message'] ?? 'Lỗi đăng xuất';
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
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Đổi mật khẩu thất bại');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
      throw Exception(msg);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await dio.post('/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
      if (response.data['success'] == true) {
        // Backend trả về resetToken (camelCase)
        return response.data['data']['resetToken'] as String;
      }
      throw Exception(response.data['message'] ?? 'OTP không hợp lệ');
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
      if (response.data['success'] != true) {
        throw Exception(
            response.data['message'] ?? 'Đặt lại mật khẩu thất bại');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
      throw Exception(msg);
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    try {
      final response = await dio.delete(
        '/auth/account',
        data: {'password': password},
      );
      if (response.data['success'] != true) {
        throw Exception(
            response.data['message'] ?? 'Yêu cầu xóa tài khoản thất bại');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
      throw Exception(msg);
    }
  }

  @override
  Future<void> cancelDelete() async {
    try {
      final response = await dio.post('/auth/cancel-delete');
      if (response.data['success'] != true) {
        throw Exception(
            response.data['message'] ?? 'Hủy yêu cầu xóa tài khoản thất bại');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dio.get('/auth/profile');
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['message'] ?? 'Không lấy được thông tin');
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      // Giữ lại statusCode: 401/404 là dấu hiệu phiên trỏ tới tài khoản không
      // còn tồn tại, cần phân biệt với lỗi 5xx tạm thời.
      throw ServerException(
        message: (e.response?.data?['message'] ?? 'Lỗi máy chủ').toString(),
        statusCode: e.response?.statusCode,
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
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Cập nhật thất bại');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Không thể gửi OTP');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Xác nhận thất bại');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Không thể gửi OTP');
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        throw const NetworkException(
            'Không có mạng. Vui lòng thử lại khi có kết nối.');
      }
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['message'] ?? 'OTP không hợp lệ');
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
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
