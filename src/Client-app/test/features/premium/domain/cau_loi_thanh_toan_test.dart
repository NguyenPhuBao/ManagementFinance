/// Một câu lỗi ngắn cho mọi lỗi API của mảng thanh toán (spec Premium 5.5) —
/// không URL, không mã, không stack (bài học `cauLoiTai`: thông báo in nguyên
/// URL ký hàng nghìn ký tự).
library;

import 'package:dio/dio.dart';
import 'package:flowmoney/features/premium/domain/cau_loi_thanh_toan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final req = RequestOptions(
      path: 'https://flowmoney.example/api/payment/create-order?token=abc');

  test('mất mạng → câu mạng', () {
    expect(
        cauLoiThanhToan(DioException(
            requestOptions: req, type: DioExceptionType.connectionError)),
        'Không có kết nối. Thử lại khi có mạng.');
    expect(
        cauLoiThanhToan(DioException(
            requestOptions: req, type: DioExceptionType.connectionTimeout)),
        'Không có kết nối. Thử lại khi có mạng.');
  });

  test('401 → câu phiên; 5xx → câu máy chủ; 4xx khác → câu chung', () {
    DioException loi(int code) => DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: code));
    expect(cauLoiThanhToan(loi(401)),
        'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.');
    expect(cauLoiThanhToan(loi(503)), 'Máy chủ chưa phản hồi. Thử lại sau.');
    expect(cauLoiThanhToan(loi(422)),
        'Không tạo được đơn thanh toán. Thử lại sau.');
  });

  test('lỗi khác → câu chung; KHÔNG câu nào chứa URL / http / token', () {
    final cac = [
      cauLoiThanhToan(StateError('x')),
      cauLoiThanhToan(DioException(
          requestOptions: req,
          type: DioExceptionType.unknown,
          error: 'Connection refused http://x')),
    ];
    for (final c in cac) {
      expect(c.toLowerCase(), isNot(contains('http')));
      expect(c, isNot(contains('token')));
      expect(c.length, lessThan(80));
    }
  });
}
