/// `kyTuMa` — tám mã kỳ chung, cùng phép dựng với bộ chọn kỳ trang Phân tích.
/// Chuyển nguyên từ `hang_chi_tieu_test.dart` ngày 2026-09-27 (tool tổng kết bị
/// thay bởi `truy_van_giao_dich`); nội dung ca không đổi.
library;

import 'package:flowmoney/features/ai_edge/domain/ma_ky.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 10);

  group('kyTuMa — tám mã, cùng phép dựng với bộ chọn kỳ trang Phân tích', () {
    test('thang_nay / thang_truoc / nam_nay', () {
      expect(kyTuMa('thang_nay', now)!.from, DateTime(2026, 9, 1));
      expect(kyTuMa('thang_truoc', now)!.from, DateTime(2026, 8, 1));
      expect(kyTuMa('thang_truoc', now)!.to, DateTime(2026, 9, 1));
      expect(kyTuMa('nam_nay', now)!.from, DateTime(2026, 1, 1));
    });
    test('tuan_nay chứa hôm nay; quy_nay là quý 3', () {
      expect(kyTuMa('tuan_nay', now)!.chua(now), isTrue);
      expect(kyTuMa('quy_nay', now)!.from, DateTime(2026, 7, 1));
    });
    test('mã lạ → null', () {
      expect(kyTuMa('hom_kia', now), isNull);
      expect(kyTuMa('', now), isNull);
      expect(kyTuMa(kMaKyMoiLuc, now), isNull,
          reason: 'moi_luc là mã riêng của tool giao dịch, không nằm trong kMaKy');
    });
    test('hom_nay / hom_qua là trọn MỘT ngày, biên [from, to)', () {
      expect(kyTuMa('hom_nay', now)!.from, DateTime(2026, 9, 23));
      expect(kyTuMa('hom_nay', now)!.to, DateTime(2026, 9, 24));
      expect(kyTuMa('hom_qua', now)!.from, DateTime(2026, 9, 22));
      expect(kyTuMa('hom_qua', now)!.to, DateTime(2026, 9, 23));
    });
    test('hom_qua qua biên tháng, biên năm, tháng hai năm nhuận và năm thường', () {
      expect(kyTuMa('hom_qua', DateTime(2026, 10, 1, 8))!.from, DateTime(2026, 9, 30));
      expect(kyTuMa('hom_qua', DateTime(2027, 1, 1, 8))!.from, DateTime(2026, 12, 31));
      expect(kyTuMa('hom_qua', DateTime(2028, 3, 1, 8))!.from, DateTime(2028, 2, 29));
      expect(kyTuMa('hom_qua', DateTime(2027, 3, 1, 8))!.from, DateTime(2027, 2, 28));
    });
    test('tuan_truoc là tuần liền trước tuần chứa hôm nay (lui, không trừ 7 ngày tay)', () {
      final nay = kyTuMa('tuan_nay', now)!;
      final truoc = kyTuMa('tuan_truoc', now)!;
      expect(truoc.to, nay.from);
      expect(nay.from.difference(truoc.from).inDays, 7);
    });
    test('kMaKy: tám mã theo thứ tự, chữ kèm KHÔNG có chữ số', () {
      expect(kMaKy.keys.toList(), [
        'hom_nay', 'hom_qua', 'tuan_nay', 'tuan_truoc',
        'thang_nay', 'thang_truoc', 'quy_nay', 'nam_nay',
      ]);
      for (final e in kMaKy.entries) {
        expect(RegExp(r'\d').hasMatch(e.value), isFalse, reason: e.key);
        expect(kyTuMa(e.key, now), isNotNull, reason: 'mọi mã trong bảng phải dựng được kỳ');
      }
    });
  });
}
