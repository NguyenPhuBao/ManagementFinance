import 'package:dio/dio.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String username, String password);
  Future<Map<String, dynamic>> register(
      String username, String fullname, String email, String password,
      {String? phone});
}

/// Exception riêng cho lỗi mạng (không có internet / timeout).
/// Login yêu cầu online — NetworkException sẽ được ném ra và hiển thị lỗi cho user.
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Không có kết nối mạng']);
  @override
  String toString() => message;
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
      // Phân biệt: lỗi mạng vs lỗi từ server
      if (_isNetworkError(e)) {
        throw const NetworkException();
      }
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

  /// Trả về true nếu là lỗi mạng (không phải lỗi HTTP từ server)
  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.response == null;
  }
}
