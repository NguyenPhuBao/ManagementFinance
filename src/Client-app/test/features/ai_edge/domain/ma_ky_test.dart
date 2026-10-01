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

  group('kyTuCauHoi (spec mở rộng tool §3.1)', () {
    final now = DateTime(2026, 9, 27, 10);
    test('"thang 8" → tháng 8 năm nay; chữ kỳ có số cho boLoc', () {
      final k = kyTuCauHoi('thang 8 toi chi bao nhieu', now)!;
      expect((k.from, k.to), (DateTime(2026, 8, 1), DateTime(2026, 9, 1)));
      expect(k.chu, 'tháng 8/2026');
    });
    test('"thang 8/2025", "thang 8 nam 2025" → đúng năm; "thang 11" (chưa tới) → năm trước', () {
      expect(kyTuCauHoi('chi thang 8/2025', now)!.from, DateTime(2025, 8, 1));
      expect(kyTuCauHoi('chi thang 8 nam 2025', now)!.from, DateTime(2025, 8, 1));
      expect(kyTuCauHoi('thang 11 toi chi gi', now)!.from, DateTime(2025, 11, 1),
          reason: 'tháng chưa tới trong năm nay là tháng của năm trước');
    });
    test('"quy 2" → Q2 năm nay; "nam ngoai" / "nam 2025" → cả năm', () {
      expect(kyTuCauHoi('quy 2 toi tieu bao nhieu', now)!.from, DateTime(2026, 4, 1));
      final ngoai = kyTuCauHoi('nam ngoai toi chi bao nhieu', now)!;
      expect((ngoai.from, ngoai.to), (DateTime(2025, 1, 1), DateTime(2026, 1, 1)));
      expect(kyTuCauHoi('nam 2025', now)!.chu, 'năm 2025');
    });
    test('"tu 1/9 den 15/9" → [1/9, 16/9) — den_ngay BAO GỒM; "tu 1/9/2026 toi 15/9"', () {
      final k = kyTuCauHoi('cac khoan chi tu 1/9 den 15/9', now)!;
      expect((k.from, k.to), (DateTime(2026, 9, 1), DateTime(2026, 9, 16)));
      expect(k.chu, 'từ 1/9 đến 15/9/2026');
      expect(kyTuCauHoi('tu 1/9/2026 toi 15/9', now)!.to, DateTime(2026, 9, 16));
    });
    test('"3 thang gan nhat", "30 ngay qua", "2 tuan qua" → lùi từ hôm nay, đóng ở đầu ngày mai', () {
      final k = kyTuCauHoi('3 thang gan nhat toi chi bao nhieu', now)!;
      expect((k.from, k.to), (DateTime(2026, 6, 27), DateTime(2026, 9, 28)));
      expect(k.chu, '3 tháng gần nhất');
      expect(kyTuCauHoi('30 ngay qua', now)!.from, DateTime(2026, 8, 28));
      expect(kyTuCauHoi('2 tuan qua', now)!.from, DateTime(2026, 9, 13));
    });
    test('⚠️ lùi N tháng từ ngày 31 KẸP về ngày cuối tháng ngắn — năm thường và năm nhuận', () {
      expect(kyTuCauHoi('1 thang gan nhat', DateTime(2026, 3, 31, 9))!.from, DateTime(2026, 2, 28),
          reason: 'DateTime(2026, 2, 31) tự cuộn sang 3/3 — cửa sổ hụt ba ngày, im lặng');
      expect(kyTuCauHoi('1 thang gan nhat', DateTime(2028, 3, 31, 9))!.from, DateTime(2028, 2, 29));
      expect(kyTuCauHoi('2 thang gan nhat', DateTime(2026, 1, 31, 9))!.from, DateTime(2025, 11, 30),
          reason: 'lùi qua biên năm');
    });
    test('"tuan 35" → tuần ISO 35 của năm nay (thứ Hai 24/8)', () {
      final k = kyTuCauHoi('tuan 35 toi tieu gi', now)!;
      expect((k.from, k.to), (DateTime(2026, 8, 24), DateTime(2026, 8, 31)));
    });
    test('⚠️ ngày không tồn tại / mốc ngược → null (tool từ chối, không tự cuộn)', () {
      expect(kyTuCauHoi('tu 31/6 den 5/7', now), isNull);
      expect(kyTuCauHoi('tu 15/9 den 1/9', now), isNull);
      expect(kyTuCauHoi('thang 13', now), isNull);
      expect(kyTuCauHoi('tu 29/2/2026 den 5/3/2026', now), isNull, reason: '2026 không nhuận');
      expect(kyTuCauHoi('tu 29/2/2028 den 5/3/2028', now), isNotNull, reason: '2028 nhuận');
    });
    test('mã kỳ có sẵn ("thang nay", "hom qua") và "500k" KHÔNG phải kỳ tự do', () {
      expect(kyTuCauHoi('thang nay toi chi bao nhieu', now), isNull);
      expect(kyTuCauHoi('hom qua toi chi gi', now), isNull);
      expect(kyTuCauHoi('cac khoan chi tren 500k', now), isNull);
      expect(kyTuCauHoi('5 khoan chi gan day nhat', now), isNull, reason: '"5 khoan" không phải "5 tuan"');
    });
    test('tháng 2 năm nhuận: "thang 2/2024" → [1/2, 1/3)', () {
      final k = kyTuCauHoi('thang 2/2024', now)!;
      expect((k.from, k.to), (DateTime(2024, 2, 1), DateTime(2024, 3, 1)));
    });
  });

  group('tên gọi của kỳ và khoangTuThamSo', () {
    final now = DateTime(2026, 9, 27, 10);
    test('kyTuCauHoi mang TÊN kỳ cho bộ kiểm: tháng / quý / năm / tuần / N kỳ gần nhất', () {
      expect(kyTuCauHoi('thang 8 toi chi gi', now)!.ten, containsAll(<String>['tháng 8', 'tháng 8/2026']));
      expect(kyTuCauHoi('quy 2', now)!.ten, contains('quý 2'));
      expect(kyTuCauHoi('nam ngoai', now)!.ten, contains('năm 2025'));
      expect(kyTuCauHoi('tuan 35', now)!.ten, contains('tuần 35'));
      expect(kyTuCauHoi('3 thang gan nhat', now)!.ten, containsAll(<String>['3 tháng gần nhất', '3 tháng qua']));
      expect(kyTuCauHoi('tu 1/9 den 15/9', now)!.ten, isEmpty,
          reason: 'hai mốc ngày đã là số liệu ngày của gói, không cần tên');
    });
    test('khoangTuThamSo: dd/mm/yyyy, den BAO GỒM; sai dạng / không tồn tại / ngược → null', () {
      expect(khoangTuThamSo('01/09/2026', '15/09/2026'), (from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 16)));
      expect(khoangTuThamSo('1/9/2026', '1/9/2026'), (from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 2)));
      expect(khoangTuThamSo('31/12/2026', '01/01/2027')!.to, DateTime(2027, 1, 2));
      for (final (tu, den) in <(String?, String?)>[
        (null, '15/09/2026'), ('01/09/2026', null), ('', ''), ('2026-09-01', '2026-09-15'),
        ('31/06/2026', '05/07/2026'), ('15/09/2026', '01/09/2026'), ('01/09', '15/09'), ('29/02/2026', '01/03/2026'),
      ]) {
        expect(khoangTuThamSo(tu, den), isNull, reason: '$tu – $den');
      }
    });
  });
}
