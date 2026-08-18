import 'package:dio/dio.dart';

/// Exception riêng cho lỗi mạng (không có internet / timeout).
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Không có kết nối mạng']);
  @override
  String toString() => message;
}

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String username, String password);
  Future<Map<String, dynamic>> register(
      String username, String fullname, String email, String password,
      {String? phone});

  // --- Các method cần Backend endpoint ---
  Future<void> logout(String accessToken);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> forgotPassword(String email);
  Future<String> verifyOtp(String email, String otp);
  Future<void> resetPassword(String resetToken, String newPassword);
  Future<void> deleteAccount(String password);
  Future<Map<String, dynamic>> getProfile();
  Future<void> updateProfile({String? fullname, String? phone, String? address, String? location});
  Future<void> requestEmailChange(String newEmail);
  Future<void> confirmEmailChange(String newEmail, String otp);
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
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['message'] ?? 'Đăng nhập thất bại');
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
      throw Exception(msg);
    }
  }

  @override
  Future<Map<String, dynamic>> register(
    String username,
    String fullname,
    String email,
    String password, {
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
      final response = await dio.post('/auth/register', data: body);
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['message'] ?? 'Đăng ký thất bại');
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        throw const NetworkException('Không có mạng. Vui lòng thử lại khi có kết nối.');
      }
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
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await dio.patch(
        '/auth/change-password',
        data: {'current_password': currentPassword, 'new_password': newPassword},
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
        return response.data['data']['reset_token'] as String;
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
        data: {'reset_token': resetToken, 'new_password': newPassword},
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Đặt lại mật khẩu thất bại');
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
        throw Exception(response.data['message'] ?? 'Xóa tài khoản thất bại');
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
      final msg = e.response?.data?['message'] ?? 'Lỗi máy chủ';
      throw Exception(msg);
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
        data: {'new_email': newEmail},
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
        data: {'new_email': newEmail, 'otp': otp},
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

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.response == null;
  }
}
