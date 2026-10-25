import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../network/trang_thai_may_chu.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/may_chu_interceptor.dart';

/// Singleton Dio client dùng chung toàn app.
/// Đã cấu hình:
/// - BaseUrl từ AppConstants
/// - AuthInterceptor: tự động gắn token + refresh khi 401
/// - MayChuInterceptor (G89): ghi trạng thái máy chủ — bảo trì / phong toả
///
/// Cách dùng trong injection: `sl<DioClient>().dio` — GetIt chỉ đăng ký `DioClient`, không đăng ký `Dio` trần.
class DioClient {
  final Dio _dio;

  /// [authInterceptor] được tiêm từ DI để cả app dùng chung ĐÚNG MỘT instance:
  /// PhienDieuPhoiThat nghe (rồi chuyển cho AuthBloc quyết định) `sessionExpiredStream` của nó, và tín hiệu đó chỉ có nghĩa
  /// khi phát ra từ chính interceptor đang nằm trên đường request.
  ///
  /// Cố ý KHÔNG lộ interceptor thành thuộc tính public: nơi cần nó đã lấy qua
  /// `sl<AuthInterceptor>()`, còn thêm thành viên vào giao diện này sẽ bắt bảy
  /// lớp giả `implements DioClient` trong bộ test phải khai báo theo.
  DioClient({
    required FlutterSecureStorage secureStorage,
    AuthInterceptor? authInterceptor,
    TrangThaiMayChu? trangThaiMayChu,
    Future<void> Function()? khiBiTatQuyen,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: AppConstants.connectionTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      authInterceptor ?? AuthInterceptor(secureStorage: secureStorage),
    );
    // G89: trạng thái máy chủ (bảo trì / phong toả) — đứng SAU AuthInterceptor, lý do ở đầu `may_chu_interceptor.dart`.
    // Chỉ chỗ này được dựng nó (test quét 36). Không truyền → không gắn (test cũ dựng DioClient không đổi).
    if (trangThaiMayChu != null) {
      _dio.interceptors.add(MayChuInterceptor(trangThai: trangThaiMayChu, khiBiTatQuyen: khiBiTatQuyen));
    }
  }

  /// Trả về Dio đã cấu hình — dùng trong các DataSource
  Dio get dio => _dio;
}
