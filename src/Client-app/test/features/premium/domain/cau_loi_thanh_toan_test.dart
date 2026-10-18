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

  test('cauTuChoi chỉ thay câu 4xx — 401, 5xx, mất mạng giữ câu của chúng', () {
    DioException loi(int code) => DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: code));
    const cau = 'Không xác nhận được đơn này. Thử lại sau.';
    expect(cauLoiThanhToan(loi(400), cauTuChoi: cau), cau,
        reason: 'confirm-upgrade trả 400 khi đơn không còn chờ xác nhận — "Không tạo được đơn" là sai');
    expect(cauLoiThanhToan(loi(404), cauTuChoi: cau), cau);
    expect(cauLoiThanhToan(loi(401), cauTuChoi: cau),
        'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.');
    expect(cauLoiThanhToan(loi(500), cauTuChoi: cau),
        'Máy chủ chưa phản hồi. Thử lại sau.');
    expect(
        cauLoiThanhToan(
            DioException(
                requestOptions: req, type: DioExceptionType.connectionError),
            cauTuChoi: cau),
        'Không có kết nối. Thử lại khi có mạng.');
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
