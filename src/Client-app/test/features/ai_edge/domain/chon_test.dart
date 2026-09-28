/// Enum `chon` — MỘT định nghĩa cho tool giao dịch và tool ngân sách (spec
/// `2026-09-27-tool-truy-van-giao-dich-design.md` mục 4).
library;

import 'package:flowmoney/features/ai_edge/domain/chon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sáu giá trị theo thứ tự (chua_dat thêm 2026-09-27, can_doi 2026-09-28); tool giao dịch nhận hai giá trị đầu', () {
    expect(kChon, ['nhieu_nhat', 'it_nhat', 'duoi_nua', 'tren_nua', 'chua_dat', 'can_doi']);
    expect(kChonGiaoDich, ['nhieu_nhat', 'it_nhat']);
  });

  test('chữ cho mô hình phủ đủ sáu mã và KHÔNG có chữ số', () {
    expect(kChuChon.keys.toList(), kChon);
    for (final c in kChuChon.values) {
      expect(RegExp(r'\d').hasMatch(c), isFalse, reason: c);
    }
  });
}
