import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';

/// Singleton Dio client dùng chung toàn app.
/// Đã cấu hình:
/// - BaseUrl từ AppConstants
/// - AuthInterceptor: tự động gắn token + refresh khi 401
///
/// Cách dùng trong injection: sl<Dio>() → luôn trả về instance này.
class DioClient {
  final Dio _dio;

  DioClient({required FlutterSecureStorage secureStorage})
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: AppConstants.connectionTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    // Gắn AuthInterceptor
    _dio.interceptors.add(
      AuthInterceptor(secureStorage: secureStorage),
    );
  }

  /// Trả về Dio đã cấu hình — dùng trong các DataSource
  Dio get dio => _dio;
}
