/// Enum `chon` — MỘT định nghĩa cho tool giao dịch và tool ngân sách (spec
/// `2026-09-27-tool-truy-van-giao-dich-design.md` mục 4).
library;

import 'package:flowmoney/features/ai_edge/domain/chon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bốn giá trị theo thứ tự; tool giao dịch nhận hai giá trị đầu', () {
    expect(kChon, ['nhieu_nhat', 'it_nhat', 'duoi_nua', 'tren_nua']);
    expect(kChonGiaoDich, ['nhieu_nhat', 'it_nhat']);
  });

  test('chữ cho mô hình phủ đủ bốn mã và KHÔNG có chữ số', () {
    expect(kChuChon.keys.toList(), kChon);
    for (final c in kChuChon.values) {
      expect(RegExp(r'\d').hasMatch(c), isFalse, reason: c);
    }
  });
}
