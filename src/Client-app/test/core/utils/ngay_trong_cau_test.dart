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
    test('⭐ "thứ X tuần trước" là ngày của tuần TRƯỚC, không phải thứ X gần nhất', () {
      // Thứ Bảy 3/10: thứ Sáu gần nhất là 2/10 (tuần này) — "tuần trước" là 25/9.
      final thuBay = DateTime(2026, 10, 3, 9);
      expect(ngay('thứ sáu tuần trước ăn lẩu', thuBay), DateTime(2026, 9, 25));
      expect(ngay('thu 6 tuan truoc', thuBay), DateTime(2026, 9, 25));
      expect(ngay('chủ nhật tuần trước', thuBay), DateTime(2026, 9, 27));
      expect(ngay('thứ 2 tuần trước'), DateTime(2026, 9, 21));
      final k = timNgayTrongCau('thứ sáu tuần trước ăn lẩu', thuBay)!;
      expect('thứ sáu tuần trước ăn lẩu'.substring(k.batDau, k.ketThuc), 'thứ sáu tuần trước',
          reason: 'ghi chú phải bỏ cả cụm "tuần trước"');
    });

    test('"thứ X tuần này" là ngày của tuần này', () {
      expect(ngay('thứ 2 tuần này'), DateTime(2026, 9, 28));
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

  // Người dùng chốt 2026-09-30 (spec C2 §8 câu 4): thêm luật cho cụm RÕ NGHĨA để bớt phải nhờ AI (AI sai cả 2 câu ngày đã
  // đo trên Realme); cụm mơ hồ để AI lấp.
  group('đầu tháng · đầu tháng trước · cuối tháng trước', () {
    test('"đầu tháng" (cả "đầu tháng này", cả không dấu) = ngày 1 tháng này; hôm nay là ngày 1 thì là hôm nay', () {
      expect(ngay('đầu tháng đóng học phí 2tr'), DateTime(2026, 9, 1));
      expect(ngay('đầu tháng này'), DateTime(2026, 9, 1));
      expect(ngay('dau thang dong hoc'), DateTime(2026, 9, 1));
      expect(ngay('đầu tháng', DateTime(2026, 10, 1)), DateTime(2026, 10, 1));
    });
    test('"đầu tháng trước" = ngày 1 tháng trước — qua biên năm', () {
      expect(ngay('đầu tháng trước'), DateTime(2026, 8, 1));
      expect(ngay('đầu tháng trước', DateTime(2027, 1, 15)), DateTime(2026, 12, 1));
      expect(ngay('đầu tháng trước 2tr'), DateTime(2026, 8, 1),
          reason: 'số tiền sau "trước" không được làm regex lùi về "đầu tháng" (= tháng NÀY)');
    });
    test('"cuối tháng trước" = ngày cuối tháng trước — tháng 30 ngày, tháng 2 năm thường / nhuận, biên năm', () {
      expect(ngay('cuối tháng trước'), DateTime(2026, 8, 31));
      expect(ngay('cuối tháng trước', DateTime(2026, 10, 5)), DateTime(2026, 9, 30));
      expect(ngay('cuối tháng trước', DateTime(2027, 3, 10)), DateTime(2027, 2, 28));
      expect(ngay('cuối tháng trước', DateTime(2028, 3, 10)), DateTime(2028, 2, 29), reason: '2028 nhuận');
      expect(ngay('cuoi thang truoc', DateTime(2027, 1, 2)), DateTime(2026, 12, 31));
    });
    test('⚠️ mơ hồ → không đọc: "đầu tháng sau / tới", "đầu tháng 10", "cuối tháng", "cuối tháng này", "tuần trước" trơn', () {
      for (final c in [
        'đầu tháng sau đóng học',
        'đầu tháng tới',
        'đầu tháng 10',
        'cuối tháng đóng học',
        'cuối tháng này',
        'tuần trước ăn lẩu',
      ]) {
        expect(ngay(c), isNull, reason: c);
      }
    });
    test('vị trí trỏ trọn cụm', () {
      const cau = 'đóng học phí đầu tháng trước 2tr';
      final k = timNgayTrongCau(cau, now)!;
      expect(cau.substring(k.batDau, k.ketThuc), 'đầu tháng trước');
    });
  });

  // C2, người dùng chốt 2026-09-30: màn chỉ gọi AI cho ngày khi câu CÓ NHẮC một ngày mà luật không đọc được. Nhắc =
  // một CỤM chỉ thời điểm đã qua; chữ lẻ (*tháng, đầu, thứ, trước*) thường mang nghĩa khác và gọi AI oan ~18 s.
  group('cauNhacNgay — câu có nhắc một thời điểm', () {
    test('⭐ có nhắc: cụm chỉ thời điểm đã qua, có dấu hay không dấu', () {
      for (final c in [
        'tối qua ăn lẩu 300k',
        'hôm trước đi chợ 200k',
        'bữa trước ăn phở',
        'tháng trước đóng học 2tr',
        'tuần rồi đi chơi 500k',
        'năm ngoái mua xe',
        'cuối tháng rồi đóng tiền nhà',
        'cuối tháng 9 đóng tiền nhà',
        'cuoi thang truoc dong hoc',
        'đầu tuần đổ xăng 50k',
        'mấy ngày trước mua áo',
        'ngày 15 đóng học phí',
        'mùng 5 đi chùa 100k',
        'hom truoc an lau',
        'thang truoc dong hoc',
        'dau thang dong hoc',
      ]) {
        expect(cauNhacNgay(c), isTrue, reason: c);
      }
    });
    test('⭐ KHÔNG nhắc: chữ thời gian lẻ mang nghĩa khác, cụm chỉ KỲ, cụm tương lai', () {
      for (final c in [
        'vé tháng 2tr',
        'lương tháng 9tr',
        'đầu tư chứng khoán 5tr',
        'mua mấy thứ lặt vặt 200k',
        'trả trước 500k',
        'tiền điện tháng này 450k',
        'tiền điện tháng 9 450k',
        'học phí năm nay 2tr',
        'tuần này đi chợ',
        'tuần sau đóng học 2tr',
        'tháng sau đóng học',
        'tôi ăn phở 45k',
        'trả ngay 5k',
        'đem qua cho mẹ 200k',
        'ăn phở 45k',
      ]) {
        expect(cauNhacNgay(c), isFalse, reason: c);
      }
    });
    test('⭐ "cuối tháng" / "cuối tháng này" / "cuối tháng sau" trơn KHÔNG là nhắc — ngày ấy là hôm nay hoặc tương lai', () {
      for (final c in [
        'cuối tháng đóng tiền nhà 3tr',
        'cuoi thang dong tien nha 3tr',
        'cuối tháng này đóng học 2tr',
        'cuối tháng sau đóng học',
        'tiền nhà cuối tháng',
      ]) {
        expect(cauNhacNgay(c), isFalse,
            reason: '$c — Realme 2026-09-30 câu 11: gọi AI 14 s mà không thêm gì (ngày cuối tháng này là hôm nay hoặc '
                'tương lai, lớp kiểm ngày của AI bỏ hôm nay)');
      }
      expect(cauNhacNgay('cuối tháng đóng tiền nhà, hôm qua quên'), isTrue,
          reason: 'chỉ gỡ đúng cụm "cuối tháng" — cụm nhắc khác trong câu vẫn tính');
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

  group('C4 — ngày X tháng Y, mùng X (câu NÓI)', () {
    final mot10 = DateTime(2026, 10, 1, 9);
    for (final (cau, ngay) in [
      ('ngày năm tháng chín mua sách', DateTime(2026, 9, 5)),
      ('ngày 5 tháng 9 mua sách', DateTime(2026, 9, 5)),
      ('ngày hai mươi mốt tháng chín', DateTime(2026, 9, 21)),
      ('ngày mười lăm tháng mười', DateTime(2025, 10, 15)), // tương lai > 7 ngày → năm trước
      ('ngay nam thang chin', DateTime(2026, 9, 5)),
      ('mùng năm', DateTime(2026, 10, 5)), // 4 ngày tới — trong hạn 7 ngày như dd/mm
      ('mùng mười', DateTime(2026, 9, 10)), // 9 ngày tới → tháng trước
      ('mồng 2', DateTime(2026, 10, 2)),
    ]) {
      test('"$cau" → $ngay', () => expect(timNgayTrongCau(cau, mot10)?.ngay, ngay));
    }

    test('đoạn dùng đúng cụm: "ngày năm tháng chín mua sách" → [0, 19)', () {
      final x = timNgayTrongCau('ngày năm tháng chín mua sách', mot10)!;
      expect((x.batDau, x.ketThuc), (0, 'ngày năm tháng chín'.length));
    });

    for (final cau in ['ngày ba mươi mốt tháng hai', 'ngày năm', 'mừng năm mới', 'trả ngay năm trăm nghìn']) {
      test('"$cau" → không phải ngày', () => expect(timNgayTrongCau(cau, mot10), isNull));
    }

    test('tháng 1 lùi sang tháng 12 năm trước: "mùng hai mươi" hôm 05/01', () {
      expect(timNgayTrongCau('mùng hai mươi', DateTime(2027, 1, 5))?.ngay, DateTime(2026, 12, 20));
    });

    // Vòng sửa 1 (người soát): dd/mm thắng "mùng 2/9"; mùng + tháng; một định nghĩa số chữ; "mung" không dấu không phải mùng.
    for (final (cau, ngay) in [
      ('đi chơi mùng 2/9 500k', DateTime(2026, 9, 2)),
      ('quà mùng 8/3 300k', DateTime(2026, 3, 8)),
      ('ngày mùng 2/9', DateTime(2026, 9, 2)),
      ('ngày mùng năm tháng chín mua sách', DateTime(2026, 9, 5)),
      ('ngày mùng 5 tháng 9 mua sách', DateTime(2026, 9, 5)),
      ('mùng hai tháng chín', DateTime(2026, 9, 2)),
      ('ngày năm tháng tư', DateTime(2026, 4, 5)),
      ('ngày 5 tháng tư', DateTime(2026, 4, 5)),
      ('ngày hai mươi nhăm tháng chín', DateTime(2026, 9, 25)),
      ('ngày năm tháng mười một trăm nghìn', DateTime(2026, 10, 5)), // tháng mười; "một trăm nghìn" là tiền
      ('mùng mười hai trăm nghìn', DateTime(2026, 9, 10)),
    ]) {
      test('vòng sửa 1: "$cau" → $ngay', () => expect(timNgayTrongCau(cau, mot10)?.ngay, ngay));
    }
    for (final cau in [
      'ngày nậm tháng chín',
      'mùng bà',
      'li xi mung nam moi 500k',
      'son mong 2 lop 80k',
      'lam mong hai tram nghin',
    ]) {
      test('vòng sửa 1: "$cau" → không ra ngày', () => expect(timNgayTrongCau(cau, mot10), isNull));
    }
    test('"mùng 31" hôm 02/11: tháng 11 chỉ có 30 ngày → bỏ, không thử tháng trước', () {
      expect(timNgayTrongCau('mùng 31', DateTime(2026, 11, 2)), isNull);
    });

    // Vòng sửa 2: tháng không nuốt tiền; "sau" không phải số tháng; số liền chữ; mười hai mươi.
    test('vòng sửa 2: tháng ngay trước đơn vị tiền → rơi về tháng này', () {
      expect(timNgayTrongCau('đóng tiền nhà mùng 5 tháng 3 triệu', mot10)?.ngay, DateTime(2026, 10, 5));
      expect(timNgayTrongCau('tiền nhà mùng năm tháng ba triệu', mot10)?.ngay, DateTime(2026, 10, 5));
      expect(timNgayTrongCau('mùng 5 tháng 10 triệu', mot10)?.ngay, DateTime(2026, 10, 5));
    });
    test('vòng sửa 2: "tháng sau" không phải tháng 6', () {
      expect(timNgayTrongCau('trả nợ mùng 5 tháng sau 2 triệu', mot10), isNull, reason: 'vòng 3');
      expect(timNgayTrongCau('mùng năm tháng sau', mot10), isNull, reason: 'vòng 3: tháng sau → không đoán, AI hỏi');
      expect(timNgayTrongCau('ngày 5 tháng sau', mot10), isNull);
      expect(timNgayTrongCau('mùng năm tháng sáu', mot10)?.ngay, DateTime(2026, 6, 5));
    });
    test('vòng sửa 2: số liền chữ không phải ngày', () {
      expect(timNgayTrongCau('lì xì mùng 10k', mot10), isNull);
      expect(timNgayTrongCau('mùng 5k', mot10), isNull);
    });
    test('vòng sửa 2: "mười hai mươi nghìn" không phải một số', () {
      expect(timNgayTrongCau('ngày năm tháng mười hai mươi nghìn', mot10)?.ngay, DateTime(2026, 10, 5));
      expect(timNgayTrongCau('mùng mười hai mươi nghìn', mot10)?.ngay, DateTime(2026, 9, 10));
    });

    // Vòng sửa 3: đơn vị tiền dùng chung `_sauLaDonViTien`; tháng trước / này / tới.
    test('vòng sửa 3: tháng ngay trước lít / xị là tiền → tháng này (hoặc không ngày với "ngày …")', () {
      expect(timNgayTrongCau('mùng 5 tháng 3 lít', mot10)?.ngay, DateTime(2026, 10, 5));
      expect(timNgayTrongCau('đóng tiền mùng năm tháng hai xị', mot10)?.ngay, DateTime(2026, 10, 5));
      expect(timNgayTrongCau('ngày 5 tháng 3 lít', mot10), isNull);
      expect(timNgayTrongCau('ngày năm tháng ba lít', mot10), isNull);
    });
    final hai0 = DateTime(2026, 10, 20, 9);
    for (final (cau, ngay) in [
      ('mùng 5 tháng trước', DateTime(2026, 9, 5)),
      ('mùng 5 tháng này', DateTime(2026, 10, 5)),
      ('ngày 5 tháng trước', DateTime(2026, 9, 5)),
    ]) {
      test('vòng sửa 3: "$cau" hôm 20/10 → $ngay', () => expect(timNgayTrongCau(cau, hai0)?.ngay, ngay));
    }
    test('vòng sửa 3: tháng tới / sau → không đọc ngày; mùng 31 tháng trước (tháng 9) → null', () {
      expect(timNgayTrongCau('mùng 5 tháng tới', hai0), isNull);
      expect(timNgayTrongCau('mùng năm tháng sau', hai0), isNull);
      expect(timNgayTrongCau('mùng 31 tháng trước', DateTime(2026, 10, 15)), isNull);
    });

    // Vòng sửa 4 (người dùng chốt 2026-10-12): "tháng này" = tháng HIỆN TẠI, không lùi kể cả tương lai — luật lùi chỉ
    // cho mùng X không nêu tháng; số đứng sau "tháng" mà là tiền (dính chữ, dính . , + chữ số, ≥ 3 chữ số, trước đơn
    // vị tiền) → coi như không nêu tháng.
    for (final (cau, luc, ngay) in [
      ('ngày 30 tháng này', hai0, DateTime(2026, 10, 30)),
      ('mùng 30 tháng này', hai0, DateTime(2026, 10, 30)),
      ('ngày 5 tháng này', hai0, DateTime(2026, 10, 5)),
      ('mùng 31 tháng này', hai0, DateTime(2026, 10, 31)),
      ('ngày 31 tháng này', DateTime(2026, 11, 20, 9), null), // tháng 11 có 30 ngày
      ('mùng 31 tháng này', DateTime(2026, 11, 20, 9), null),
    ]) {
      test('vòng sửa 4: "$cau" hôm ${luc.day}/${luc.month} → $ngay',
          () => expect(timNgayTrongCau(cau, luc)?.ngay, ngay, reason: 'tháng này = tháng hiện tại, không lùi'));
    }
    for (final cau in [
      'tiền nhà mùng 5 tháng 3tr',
      'mùng 5 tháng 500k',
      'mùng 5 tháng 300 nghìn',
      'đóng tiền nhà mùng 5 tháng 3.000.000',
      'mùng 5 tháng 3,5 triệu',
      'ngày mùng 5 tháng 3tr',
    ]) {
      test('vòng sửa 4: "$cau" → 05/10, số sau "tháng" là tiền', () {
        final x = timNgayTrongCau(cau, hai0);
        expect(x?.ngay, DateTime(2026, 10, 5), reason: 'số dính liền sau "tháng" là tiền → như không nêu tháng');
        expect(cau.substring(x!.batDau, x.ketThuc), 'mùng 5', reason: 'đoạn ngày không nuốt "tháng" + tiền');
      });
    }
    for (final cau in ['ngày 5 tháng 3.000.000', 'ngày 5 tháng 3tr', 'ngày 5 tháng 3,5 triệu']) {
      test('vòng sửa 4: "$cau" → không ngày (ngày X, tháng là tiền)', () => expect(timNgayTrongCau(cau, hai0), isNull));
    }
    test('vòng sửa 4: dấu câu không có chữ số theo sau không dính — "mùng 5 tháng 9, mua sách" vẫn là tháng 9', () {
      expect(timNgayTrongCau('mùng 5 tháng 9, mua sách', hai0)?.ngay, DateTime(2026, 9, 5));
      expect(timNgayTrongCau('ngày 5 tháng 9. mua sách', hai0)?.ngay, DateTime(2026, 9, 5));
    });

    // Luật lịch: tháng ngắn và năm nhuận — cùng nếp dd/mm (ngày không tồn tại → bỏ, không kẹp).
    test('tháng 30 ngày: "ngày 31 tháng 9" và "ngày ba mươi mốt tháng chín" → không phải ngày', () {
      expect(timNgayTrongCau('ngày 31 tháng 9', mot10), isNull);
      expect(timNgayTrongCau('ngày ba mươi mốt tháng chín', mot10), isNull);
    });
    test('"mùng 31" hôm 01/10: tương lai > 7 ngày → tháng 9 không có ngày 31 → bỏ', () {
      expect(timNgayTrongCau('mùng 31', mot10), isNull);
    });
    test('"mùng 30" hôm 01/03/2026: lùi về tháng 2 (28 ngày) → bỏ; hôm 01/03/2028 cũng bỏ (nhuận có 29)', () {
      expect(timNgayTrongCau('mùng 30', DateTime(2026, 3, 1)), isNull);
      expect(timNgayTrongCau('mùng 30', DateTime(2028, 3, 1)), isNull);
    });
    test('"mùng 29" hôm 01/03: tháng 2 năm nhuận có 29, năm thường không', () {
      expect(timNgayTrongCau('mùng 29', DateTime(2028, 3, 1))?.ngay, DateTime(2028, 2, 29));
      expect(timNgayTrongCau('mùng 29', DateTime(2026, 3, 1)), isNull);
    });
    test('"ngày 29 tháng 2": năm nhuận đọc được, năm thường không', () {
      expect(timNgayTrongCau('ngày 29 tháng 2', DateTime(2028, 3, 10))?.ngay, DateTime(2028, 2, 29));
      expect(timNgayTrongCau('ngày 29 tháng 2', DateTime(2026, 3, 10)), isNull);
      expect(timNgayTrongCau('ngày hai mươi chín tháng hai', DateTime(2026, 3, 10)), isNull);
    });
  });
}
