/// Một câu lỗi ngắn cho mọi lỗi API của mảng thanh toán (spec Premium 5.5) — không URL, không mã, không stack.
/// Phân loại lỗi HTTP ở `data/datasources/payment_api.dart` (`loaiLoiThanhToanTu`); tệp này chỉ còn câu theo loại
/// (spec G94 2026-10-18 mục 4.1 — `domain/` không import Dio).
library;

import 'package:flowmoney/features/premium/domain/cau_loi_thanh_toan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mỗi loại một câu — đúng từng chữ như trước khi tách', () {
    expect(cauLoiThanhToan(LoaiLoiThanhToan.phienHetHan), 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.');
    expect(cauLoiThanhToan(LoaiLoiThanhToan.mayChu), 'Máy chủ chưa phản hồi. Thử lại sau.');
    expect(cauLoiThanhToan(LoaiLoiThanhToan.matMang), 'Không có kết nối. Thử lại khi có mạng.');
    expect(cauLoiThanhToan(LoaiLoiThanhToan.biTuChoi), 'Không tạo được đơn thanh toán. Thử lại sau.');
    expect(cauLoiThanhToan(LoaiLoiThanhToan.khac), 'Có lỗi xảy ra. Thử lại sau.');
  });

  test('cauTuChoi chỉ thay câu bị từ chối (4xx) — loại khác giữ câu của chúng', () {
    const cau = 'Không xác nhận được đơn này. Thử lại sau.';
    expect(cauLoiThanhToan(LoaiLoiThanhToan.biTuChoi, cauTuChoi: cau), cau,
        reason: 'confirm-upgrade trả 400 khi đơn không còn chờ xác nhận — "Không tạo được đơn" là sai');
    for (final l in LoaiLoiThanhToan.values.where((l) => l != LoaiLoiThanhToan.biTuChoi)) {
      expect(cauLoiThanhToan(l, cauTuChoi: cau), cauLoiThanhToan(l), reason: '$l');
    }
  });

  test('KHÔNG câu nào chứa URL / http / token; câu ngắn', () {
    for (final l in LoaiLoiThanhToan.values) {
      final c = cauLoiThanhToan(l);
      expect(c.toLowerCase(), isNot(contains('http')));
      expect(c, isNot(contains('token')));
      expect(c.length, lessThan(80));
    }
  });

  test('loaiLoiCua: LoiThanhToan → loại của nó; lỗi khác → khac', () {
    expect(loaiLoiCua(const LoiThanhToan(LoaiLoiThanhToan.matMang)), LoaiLoiThanhToan.matMang);
    expect(loaiLoiCua(StateError('x')), LoaiLoiThanhToan.khac);
  });
}
