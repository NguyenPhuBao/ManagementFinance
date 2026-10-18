/// `bocData` / `bocDanhSach` — bóc bao `{success, message, data}` của backend
/// (spec Premium 6.2). Bản Dio mỏng, chỉ phần bóc thân và phần đọc lỗi
/// (`loaiLoiThanhToanTu`, spec G94 2026-10-18 mục 4.1) là có gì để test.
library;

import 'package:dio/dio.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/domain/cau_loi_thanh_toan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bocData bóc `data` khỏi bao {success, message, data}', () {
    expect(
        bocData({
          'success': true,
          'message': 'ok',
          'data': {'accountType': 'Premium'},
        }),
        {'accountType': 'Premium'});
  });

  test('bocData: không có `data` thì coi cả thân là data; không phải Map → {}',
      () {
    expect(bocData({'accountType': 'Basic'}), {'accountType': 'Basic'});
    expect(bocData('x'), isEmpty);
    expect(bocData(null), isEmpty);
    expect(bocData({'success': true, 'data': 'rac'}),
        {'success': true, 'data': 'rac'});
  });

  test('bocDanhSach lấy items, bỏ phần tử không phải Map', () {
    final ds = bocDanhSach({
      'data': {
        'total': 2,
        'items': [
          {'order_code': 1},
          'rac',
          {'order_code': 2},
        ],
      },
    }, 'items');
    expect(ds.map((e) => e['order_code']), [1, 2]);
    expect(bocDanhSach({'data': {}}, 'items'), isEmpty);
    expect(bocDanhSach(null, 'items'), isEmpty);
  });

  group('loaiLoiThanhToanTu — bản đọc lỗi HTTP dời khỏi domain (spec G94 mục 4.1)', () {
    final req = RequestOptions(path: 'https://flowmoney.example/api/payment/create-order?token=abc');
    DioException loi(int code) => DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: code));

    test('mất mạng / hết giờ → matMang', () {
      for (final t in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(loaiLoiThanhToanTu(DioException(requestOptions: req, type: t)), LoaiLoiThanhToan.matMang, reason: '$t');
      }
    });

    test('401 → phienHetHan; 5xx → mayChu; 4xx khác → biTuChoi', () {
      expect(loaiLoiThanhToanTu(loi(401)), LoaiLoiThanhToan.phienHetHan);
      expect(loaiLoiThanhToanTu(loi(503)), LoaiLoiThanhToan.mayChu);
      expect(loaiLoiThanhToanTu(loi(400)), LoaiLoiThanhToan.biTuChoi);
      expect(loaiLoiThanhToanTu(loi(404)), LoaiLoiThanhToan.biTuChoi);
      expect(loaiLoiThanhToanTu(loi(422)), LoaiLoiThanhToan.biTuChoi);
    });

    test('Dio unknown / cancel, lỗi không phải Dio → khac; LoiThanhToan giữ loại', () {
      expect(loaiLoiThanhToanTu(DioException(requestOptions: req, type: DioExceptionType.unknown, error: 'x')),
          LoaiLoiThanhToan.khac);
      expect(loaiLoiThanhToanTu(DioException(requestOptions: req, type: DioExceptionType.cancel)), LoaiLoiThanhToan.khac);
      expect(loaiLoiThanhToanTu(StateError('x')), LoaiLoiThanhToan.khac);
      expect(loaiLoiThanhToanTu(const LoiThanhToan(LoaiLoiThanhToan.mayChu)), LoaiLoiThanhToan.mayChu);
    });

    test('đi vòng Dio → câu: trùng từng chữ với cauLoiThanhToan(DioException) trước khi tách', () {
      expect(cauLoiThanhToan(loaiLoiThanhToanTu(loi(422))), 'Không tạo được đơn thanh toán. Thử lại sau.');
      expect(cauLoiThanhToan(loaiLoiThanhToanTu(loi(401))), 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.');
      expect(cauLoiThanhToan(loaiLoiThanhToanTu(loi(503))), 'Máy chủ chưa phản hồi. Thử lại sau.');
      expect(
          cauLoiThanhToan(loaiLoiThanhToanTu(DioException(requestOptions: req, type: DioExceptionType.connectionError))),
          'Không có kết nối. Thử lại khi có mạng.');
    });
  });
}
