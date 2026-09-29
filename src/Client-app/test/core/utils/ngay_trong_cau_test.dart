/// Ngày nêu trong một câu (C2 task 2, spec `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2.3): *hôm nay / hôm
/// qua / hôm kia*, *thứ 2 … chủ nhật* (ngày gần nhất đã qua hoặc hôm nay), *dd/mm* của năm hiện tại (tương lai quá 7
/// ngày thì lùi một năm). Kèm vị trí để ô Nhập nhanh bỏ đúng đoạn ấy khỏi ghi chú.
library;

import 'package:flowmoney/core/utils/ngay_trong_cau.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thứ Tư 30/9/2026.
  final now = DateTime(2026, 9, 30, 15);
  DateTime? ngay(String cau, [DateTime? luc]) => timNgayTrongCau(cau, luc ?? now)?.ngay;

  test('tiền đề: 30/9/2026 là thứ Tư', () => expect(now.weekday, DateTime.wednesday));

  group('chữ tương đối', () {
    test('hôm nay / sáng · trưa · chiều · tối nay', () {
      for (final c in ['hôm nay', 'sáng nay', 'trưa nay', 'chiều nay', 'tối nay']) {
        expect(ngay(c), DateTime(2026, 9, 30), reason: c);
      }
    });
    test('hôm qua, hôm kia — lùi qua biên tháng', () {
      expect(ngay('hôm qua'), DateTime(2026, 9, 29));
      expect(ngay('hôm kia'), DateTime(2026, 9, 28));
      expect(ngay('hôm qua', DateTime(2026, 10, 1)), DateTime(2026, 9, 30));
      expect(ngay('hôm kia', DateTime(2028, 3, 1)), DateTime(2028, 2, 28),
          reason: '2028 nhuận: 1/3 lùi hai ngày là 28/2');
    });
    test('không dấu như có dấu', () {
      expect(ngay('hom qua an pho'), DateTime(2026, 9, 29));
      expect(ngay('toi nay'), DateTime(2026, 9, 30));
    });
  });

  group('thứ trong tuần — gần nhất đã qua hoặc hôm nay', () {
    test('dạng số', () {
      expect(ngay('thứ 2'), DateTime(2026, 9, 28));
      expect(ngay('thứ 4'), DateTime(2026, 9, 30), reason: 'hôm nay là thứ Tư');
      expect(ngay('thứ 5'), DateTime(2026, 9, 24), reason: 'thứ Năm tuần trước');
      expect(ngay('thứ 7'), DateTime(2026, 9, 26));
    });
    test('dạng chữ', () {
      expect(ngay('thứ hai'), DateTime(2026, 9, 28));
      expect(ngay('thứ ba'), DateTime(2026, 9, 29));
      expect(ngay('thứ tư'), DateTime(2026, 9, 30));
      expect(ngay('thứ năm'), DateTime(2026, 9, 24));
      expect(ngay('thứ sáu'), DateTime(2026, 9, 25));
      expect(ngay('thứ bảy'), DateTime(2026, 9, 26));
    });
    test('chủ nhật / cn', () {
      expect(ngay('chủ nhật'), DateTime(2026, 9, 27));
      expect(ngay('cn đi chợ'), DateTime(2026, 9, 27));
      expect(ngay('chu nhat'), DateTime(2026, 9, 27));
    });
    test('hôm nay là thứ Hai thì "thứ 2" là hôm nay', () {
      expect(ngay('thứ 2', DateTime(2026, 9, 28, 9)), DateTime(2026, 9, 28));
    });
    test('không dấu: "thu 5" nhận, nhưng "thu" + chữ là động từ THU tiền', () {
      expect(ngay('thu 5 an lau'), DateTime(2026, 9, 24));
      expect(ngay('thu hai trieu tien no'), isNull,
          reason: '"thu hai triệu" — thu tiền, không phải thứ Hai');
      expect(ngay('thu 2 trieu'), isNull, reason: 'số kèm đơn vị tiền là số tiền');
      expect(ngay('thu 2tr'), isNull);
      expect(ngay('thu nam 500k'), isNull, reason: '"thu (của anh) Nam" — tên người');
    });
    test('có dấu "thứ" thì chữ số sau là thứ, kể cả khi có số tiền phía sau', () {
      expect(ngay('thứ 2 đổ xăng 50k'), DateTime(2026, 9, 28));
    });
  });

  group('ngày dd/mm', () {
    test('5/9, 05/09, "ngày 5/9" → 5/9 năm nay', () {
      expect(ngay('5/9'), DateTime(2026, 9, 5));
      expect(ngay('05/09'), DateTime(2026, 9, 5));
      expect(ngay('ngày 5/9 mua sách'), DateTime(2026, 9, 5));
    });
    test('ghi năm thì dùng năm ấy', () {
      expect(ngay('5/9/2025'), DateTime(2025, 9, 5));
    });
    test('ngày không tồn tại → null', () {
      expect(ngay('31/2'), isNull);
      expect(ngay('31/6'), isNull);
      expect(ngay('0/5'), isNull);
    });
    test('tương lai quá 7 ngày thì lùi một năm; trong 7 ngày thì giữ', () {
      final dauNam = DateTime(2027, 1, 3);
      expect(ngay('30/12', dauNam), DateTime(2026, 12, 30));
      expect(ngay('5/1', dauNam), DateTime(2027, 1, 5));
    });
    test('29/2: năm thường null, năm nhuận hợp lệ', () {
      expect(ngay('29/2', DateTime(2027, 3, 10)), isNull);
      expect(ngay('29/2', DateTime(2028, 3, 10)), DateTime(2028, 2, 29));
    });
  });

  group('vị trí và ưu tiên', () {
    test('câu không có ngày → null', () {
      expect(ngay('ăn phở 45k'), isNull);
      expect(ngay('mua 2 ly cà phê'), isNull);
    });
    test('vị trí trỏ đúng đoạn ngày, kể cả chữ "ngày" đứng trước', () {
      const cau = 'mua sách ngày 5/9 hết 120k';
      final k = timNgayTrongCau(cau, now)!;
      expect(cau.substring(k.batDau, k.ketThuc), 'ngày 5/9');
      const cau2 = 'Hôm qua ăn phở';
      final k2 = timNgayTrongCau(cau2, now)!;
      expect(cau2.substring(k2.batDau, k2.ketThuc), 'Hôm qua');
    });
    test('nhiều chữ ngày → chữ đứng đầu câu thắng', () {
      expect(ngay('hôm qua mua, 5/9 trả'), DateTime(2026, 9, 29));
    });
    test('không nhầm trong từ khác: "chủ nhật" phải trọn từ, "cn" không nằm trong "cnn"', () {
      expect(ngay('xem cnn'), isNull);
    });
  });

  group('ngayHopLe — dời từ ma_ky.dart', () {
    test('ngày tồn tại / không tồn tại', () {
      expect(ngayHopLe(2026, 2, 28), DateTime(2026, 2, 28));
      expect(ngayHopLe(2026, 2, 29), isNull);
      expect(ngayHopLe(2028, 2, 29), DateTime(2028, 2, 29));
      expect(ngayHopLe(2026, 13, 1), isNull);
      expect(ngayHopLe(2026, 4, 31), isNull);
    });
  });
}
