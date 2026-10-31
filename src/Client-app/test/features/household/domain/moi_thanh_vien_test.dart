import 'package:flowmoney/features/household/domain/moi_thanh_vien.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conChoMoi: thành viên + lời mời còn hiệu lực phải dưới trần (đơn 50 C.2)', () {
    expect(conChoMoi(soThanhVien: 3, soLoiMoiConHieuLuc: 2, toiDa: 6), isTrue);
    expect(conChoMoi(soThanhVien: 3, soLoiMoiConHieuLuc: 3, toiDa: 6), isFalse,
        reason: 'lời mời còn hiệu lực cũng chiếm chỗ — server sẽ trả HOUSEHOLD_FULL');
    expect(conChoMoi(soThanhVien: 6, soLoiMoiConHieuLuc: 0, toiDa: 6), isFalse);
  });

  test('emailHopLeSoBo: chỉ lọc sơ bộ, server thi hành lại', () {
    for (final e in ['an@gmail.com', ' an@x.vn ', 'a.b+c@d.co']) {
      expect(emailHopLeSoBo(e), isTrue, reason: e);
    }
    for (final e in ['', 'an', 'an@', '@x.vn', 'an@x', 'a n@x.vn']) {
      expect(emailHopLeSoBo(e), isFalse, reason: e);
    }
  });

  test('tenNhaHopLe: 1–100 ký tự sau khi cắt trắng, đếm theo code point', () {
    expect(tenNhaHopLe('Nhà An'), isTrue);
    expect(tenNhaHopLe('   '), isFalse);
    expect(tenNhaHopLe('a' * 100), isTrue);
    expect(tenNhaHopLe('a' * 101), isFalse);
    expect(tenNhaHopLe('😀' * 100), isTrue, reason: 'cột đếm ký tự, không đếm UTF-16');
  });

  test('cauChiaSeMaMoi nêu tên nhà, mã, hạn giờ địa phương; thiếu hạn thì im vế ấy', () {
    final c = cauChiaSeMaMoi(tenNha: 'Nhà An', ma: 'ABCD2345', hetHan: DateTime(2026, 11, 2, 20, 30).toUtc());
    expect(c, contains('Nhà An'));
    expect(c, contains('ABCD2345'));
    expect(c, contains('02/11/2026 20:30'));
    expect(cauChiaSeMaMoi(tenNha: 'Nhà An', ma: 'ABCD2345'), isNot(contains('hạn')));
  });
}
