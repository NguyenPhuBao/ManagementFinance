import 'package:flowmoney/features/ban_sao_du_lieu/data/models/yeu_cau_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/domain/trang_thai_ban_sao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data null / không phải Map → null (chưa từng yêu cầu)', () {
    expect(yeuCauBanSaoTuJson(null), isNull);
    expect(yeuCauBanSaoTuJson('x'), isNull);
  });

  test('READY đọc đủ id, hạn (giờ máy), files', () {
    final y = yeuCauBanSaoTuJson({
      'id': 'u-1',
      'status': 'READY',
      'expiresAt': '2026-11-17T03:00:00.000Z',
      'files': ['json', 'csv', 'xml'],
    })!;
    expect(y.id, 'u-1');
    expect(y.trangThai, TrangThaiBanSao.sanSang);
    expect(y.expiresAt, DateTime.utc(2026, 11, 17, 3).toLocal());
    expect(y.files, ['json', 'csv'], reason: 'định dạng lạ bỏ — app chỉ có hai nút');
  });

  test('202 PROCESSING có email che; thiếu ngày / files không ném', () {
    final y = yeuCauBanSaoTuJson({'id': 'u-2', 'status': 'PROCESSING', 'email': 'an***@gmail.com'})!;
    expect(y.trangThai, TrangThaiBanSao.dangTao);
    expect(y.email, 'an***@gmail.com');
    expect(y.expiresAt, isNull);
    expect(y.files, isEmpty);
  });

  test('status không phải chuỗi (số) → loi, không ném', () {
    expect(yeuCauBanSaoTuJson({'id': 'u-3', 'status': 3})!.trangThai, TrangThaiBanSao.loi);
  });
}
