/// Cờ ✕ của dòng nhắc hết hạn Trang chủ (spec Premium 9.5): ẩn tới hết NGÀY,
/// theo tài khoản — khuôn `AnNhacViTrungTen`.
library;

import 'package:flowmoney/features/premium/presentation/an_nhac_het_han.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('✕ ẩn tới hết NGÀY, theo tài khoản', () {
    final an = AnNhacHetHan();
    final now = DateTime(2026, 10, 6, 10);
    expect(an.daAn(10, now), isFalse);
    an.an(10, now);
    expect(an.daAn(10, DateTime(2026, 10, 6, 23, 59)), isTrue);
    expect(an.daAn(10, DateTime(2026, 10, 7, 0, 1)), isFalse,
        reason: 'qua ngày hiện lại');
    expect(an.daAn(11, now), isFalse,
        reason: 'tài khoản khác không thừa hưởng');
  });
}
