// Exception hierarchy cho FlowMoney client-app.
//
// Sử dụng thay vì throw Exception() raw để:
// 1. BLoC/Cubit có thể catch theo từng loại lỗi
// 2. UI hiển thị message đúng ngữ cảnh
// 3. AuthInterceptor phân biệt lỗi mạng vs server

// ─── Network ──────────────────────────────────────────────────────────────────
/// Lỗi kết nối: không có internet, timeout, DNS fail
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.']);

  @override
  String toString() => message;
}

// ─── Server ───────────────────────────────────────────────────────────────────
/// Lỗi từ server: HTTP 4xx/5xx với message cụ thể từ API
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException($statusCode): $message';
}

// ─── Cache / Local DB ─────────────────────────────────────────────────────────
/// Lỗi đọc/ghi SQLite local (Drift)
class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Lỗi lưu trữ dữ liệu cục bộ.']);

  @override
  String toString() => message;
}

// ─── Auth ─────────────────────────────────────────────────────────────────────
/// Lỗi xác thực: token hết hạn, refresh thất bại, phiên đăng nhập hết hạn
class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.']);

  @override
  String toString() => message;
}

// ─── Validation ───────────────────────────────────────────────────────────────
/// Lỗi validation phía client (form input không hợp lệ)
class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => message;
}
