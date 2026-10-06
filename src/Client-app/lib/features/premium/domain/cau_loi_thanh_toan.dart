import 'package:dio/dio.dart';

/// Câu lỗi ngắn cho mọi lỗi API của mảng thanh toán (spec Premium 5.5). KHÔNG
/// in URL, mã lỗi, stack — bài học `cauLoiTai`: thông báo lỗi tải mô hình từng
/// in nguyên URL ký hàng nghìn ký tự lên màn.
///
/// Cố ý không nhìn `dart:io` (`SocketException`): app còn chạy trên web.
String cauLoiThanhToan(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.';
    if (code != null && code >= 500) {
      return 'Máy chủ chưa phản hồi. Thử lại sau.';
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Không có kết nối. Thử lại khi có mạng.';
      case DioExceptionType.badResponse:
        return 'Không tạo được đơn thanh toán. Thử lại sau.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return 'Có lỗi xảy ra. Thử lại sau.';
    }
  }
  return 'Có lỗi xảy ra. Thử lại sau.';
}
