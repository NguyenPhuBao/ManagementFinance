/// Dòng nhắc hết hạn Trang chủ (spec Premium 9.5): còn 0..3 ngày thì nhắc;
/// hết hạn rồi im (không nhắc người đã về Basic); chưa biết hạn cũng im.
library;

import 'package:flowmoney/features/premium/domain/nhac_het_han.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10);
  TrangThaiGoi premium(DateTime hetHan) =>
      TrangThaiGoi(loai: LoaiGoi.premium, hetHan: hetHan, nhanLuc: now);

  test('còn 3 · 1 · 0 ngày → nhắc với đúng số', () {
    expect(canNhacHetHan(premium(DateTime(2026, 10, 9, 8)), now), 3);
    expect(canNhacHetHan(premium(DateTime(2026, 10, 7, 8)), now), 1);
    expect(canNhacHetHan(premium(DateTime(2026, 10, 6, 23)), now), 0);
  });

  test('còn 4 ngày → im',
      () => expect(canNhacHetHan(premium(DateTime(2026, 10, 10, 8)), now), isNull));

  test('đã hết hạn → im (không nhắc người đã về Basic)',
      () => expect(canNhacHetHan(premium(DateTime(2026, 10, 6, 9)), now), isNull));

  test('Basic / chưa biết hạn → im', () {
    expect(canNhacHetHan(TrangThaiGoi.basicMacDinh(now), now), isNull);
    expect(canNhacHetHan(TrangThaiGoi(loai: LoaiGoi.premium, nhanLuc: now), now),
        isNull);
  });
}
