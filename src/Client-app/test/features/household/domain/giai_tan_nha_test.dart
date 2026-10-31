import 'package:flowmoney/features/household/domain/giai_tan_nha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('so tên bằng normalizeCategoryName: khác hoa thường, thừa trắng vẫn khớp', () {
    expect(tenGiaiTanKhop('  nhà ĐẠT –  linh ', 'Nhà Đạt – Linh'), isTrue);
  });
  test('giữ dấu tiếng Việt: "Nha Dat" không khớp "Nhà Đạt"', () {
    expect(tenGiaiTanKhop('Nha Dat', 'Nhà Đạt'), isFalse,
        reason: 'bỏ dấu là phép so mất thông tin; hộp này chặn thao tác không hoàn tác được');
  });
  test('ô trống không bao giờ khớp, kể cả tên nhà rỗng', () {
    expect(tenGiaiTanKhop('', ''), isFalse);
    expect(tenGiaiTanKhop('   ', ''), isFalse);
  });
}
