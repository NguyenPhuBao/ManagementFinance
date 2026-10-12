/// C4 — luật đọc câu NÓI (spec 2026-10-12 §3.2–3.3, khối 🔧). Luật chỉ CHỌN THÊM trong tập `cachDocSoTien` đã có;
/// số đọc bằng dạng nói mới học mang cờ `soTienCanKiem` để Gemma kiểm chéo.
library;

import 'dart:io';

import 'package:flowmoney/core/category/category_name.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/utils/so_bang_chu.dart';
import 'package:flowmoney/features/transaction/domain/doc_cau_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

final now = DateTime(2026, 10, 1, 9); // thứ Năm
final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt');

KetQuaDocCau doc(String cau, {List<Wallet>? vi, List<Category> chonDuoc = const []}) =>
    docCauGiaoDich(cau, now: now, vi: vi ?? [tienMat], chonDuoc: chonDuoc);

void main() {
  group('N1 — X đơn vị Y, khi Y ở chỗ của tiền', () {
    for (final (cau, so) in [
      ('tiền điện một triệu hai', 1200000.0),
      ('mua đồ năm nghìn hai', 5200.0),
      ('tiền điện một triệu tư', 1400000.0),
      ('tien dien mot trieu hai', 1200000.0),
      ('tiền điện 1 triệu 2', 1200000.0),
      ('tiền nhà 2 tr 5', 2500000.0),
      ('tiền điện một triệu hai hôm qua', 1200000.0),
      ('tiền điện một triệu hai, hôm qua', 1200000.0),
    ]) {
      test('"$cau" → $so, cần kiểm', () {
        final kq = doc(cau);
        expect(kq.soTien, so);
        expect(kq.soTienCanKiem, isTrue);
        expect(
          cachDocSoTien(cau, now: now),
          contains(so),
          reason: 'bất biến kiểm chéo: số luật chọn phải là MỘT cách đọc cachDocSoTien đã liệt kê',
        );
      });
    }

    test('⭐ "1 triệu 2" từng đọc 1.000.000 im lặng (`_mauSoDonVi` khớp "1 triệu", bỏ số 2)', () {
      expect(doc('tiền điện 1 triệu 2').soTien, isNot(1000000.0));
    });

    for (final (cau, so) in [
      ('tiền điện 1,2 triệu', 1200000.0),
      ('ăn phở 45k', 45000.0),
      ('mua sách 120.000', 120000.0),
    ]) {
      test('dạng có đơn vị / chữ số đủ "$cau" → $so, KHÔNG cần kiểm', () {
        final kq = doc(cau);
        expect(kq.soTien, so);
        expect(kq.soTienCanKiem, isFalse);
      });
    }
  });

  group('N1 — Y KHÔNG ở chỗ của tiền: luật y như trước C4 (lối A, người dùng chốt 2026-10-12)', () {
    for (final cau in [
      'chi hai triệu năm nay',
      'nộp hai triệu ba ngày sau',
      'trả hai trăm nghìn tám tháng',
      'một triệu hai tiền sách',
    ]) {
      test('"$cau" → luật không chọn N1', () {
        final kq = doc(cau);
        expect(kq.soTien, isNull, reason: 'dạng chữ: chưa rõ như hôm nay');
        expect(kq.soTienCanKiem, isFalse);
        expect(kq.canhBao, contains(kCanhBaoSoChuChuaRo));
        expect(cachDocSoTien(cau, now: now), isNotEmpty, reason: 'Gemma vẫn chọn được ở chỗ luật bỏ trống');
      });
    }

    test('dạng chữ số: "nộp 2 triệu 3 ngày sau" → 2.000.000 như hôm nay, không cần kiểm', () {
      final kq = doc('nộp 2 triệu 3 ngày sau');
      expect(kq.soTien, 2000000.0);
      expect(kq.soTienCanKiem, isFalse);
    });

    test('"ngày" chỉ là chỗ của tiền khi liền sau là chữ số: "một triệu hai ngày 5/10" → N1', () {
      final kq = doc('tiền điện một triệu hai ngày 5/10');
      expect(kq.soTien, 1200000.0);
      expect(kq.soTienCanKiem, isTrue);
    });
  });

  group('"từ" không phải "tư" (spike câu 19)', () {
    test('⭐ "chuyển năm trăm nghìn từ MB Bank sang tiết kiệm" → 500.000', () {
      final kq = doc('chuyển năm trăm nghìn từ MB Bank sang tiết kiệm');
      expect(
        kq.soTien,
        500000.0,
        reason: '_sauLaChuSoChu so trên chữ BỎ DẤU — "từ" thành tu = tư (4), cả cụm bị gạt là "chưa rõ"',
      );
      expect(kq.soTienCanKiem, isFalse);
    });

    test('cachDocSoTien cùng phép đọc: không có 500.400', () {
      expect(cachDocSoTien('chuyển năm trăm nghìn từ MB Bank', now: now), isNot(contains(500400.0)));
      expect(cachDocSoTien('chuyển năm trăm nghìn từ MB Bank', now: now), contains(500000.0));
    });

    test('gõ không dấu hoàn toàn: "mot trieu tu" vẫn là một triệu tư', () {
      expect(doc('mot trieu tu').soTien, 1400000.0);
    });
  });

  group('"sau" không phải "sáu" khi câu có dấu', () {
    test('"hai triệu sau khi giảm" → 2.000.000, không 2.600.000 (sau · nam · bay không dấu là chữ thật)', () {
      // Tinh chỉnh phán quyết B (điều phối 2026-10-12): trong câu có dấu, "sau" là chữ thật, không mơ hồ.
      final kq = doc('hai triệu sau khi giảm');
      expect(kq.soTien, 2000000.0);
      expect(kq.soTienCanKiem, isFalse);
      expect(cachDocSoTien('hai triệu sau khi giảm', now: now), isNot(contains(2600000.0)));
    });
    test('cả câu không dấu: "hai trieu sau" → 2.600.000', () {
      expect(doc('hai trieu sau').soTien, 2600000.0);
    });
  });

  group('I1 — dấu câu liền sau Y', () {
    for (final cau in ['tiền điện 1 triệu 2, hôm qua', 'tiền điện 1 triệu 2.']) {
      test('"$cau" → 1.200.000, cần kiểm', () {
        final kq = doc(cau);
        expect(kq.soTien, 1200000.0);
        expect(kq.soTienCanKiem, isTrue);
        expect(cachDocSoTien(cau, now: now), contains(1200000.0));
      });
    }
  });

  group('I2 — nhiều số tiền khi trộn cụm chắc và cụm nói', () {
    for (final (cau, so) in [
      ('tiền điện 1 triệu 2 hôm qua và nước 300k', 300000.0),
      ('ăn phở 45k tiền điện 1 triệu 2', 45000.0),
    ]) {
      test('"$cau" → có cảnh báo, cụm chắc thắng', () {
        final kq = doc(cau);
        expect(kq.canhBao, contains(kCanhBaoNhieuSoTien));
        expect(kq.soTien, so);
      });
    }
    test('một mình cụm nói → không cảnh báo', () {
      expect(doc('tiền điện 1 triệu 2').canhBao, isEmpty);
    });
  });

  group('A — hôm / thứ chỉ là chỗ của tiền khi đi với mốc ngày', () {
    test('dạng chữ số: "nộp 2 triệu 3 hôm sau" → 2.000.000 như trước C4', () {
      final kq = doc('nộp 2 triệu 3 hôm sau');
      expect(kq.soTien, 2000000.0);
      expect(kq.soTienCanKiem, isFalse);
    });
    for (final cau in ['trả hai triệu ba hôm trước', 'mua hai triệu ba thứ đồ']) {
      test('"$cau" → luật không chọn N1', () {
        final kq = doc(cau);
        expect(kq.soTien, isNull);
        expect(kq.soTienCanKiem, isFalse);
      });
    }
    test('"mua 2 triệu 3 thứ đồ" (chữ số) → 2.000.000', () {
      expect(doc('mua 2 triệu 3 thứ đồ').soTien, 2000000.0);
    });
    test('"một triệu hai thứ hai" → 1.200.000', () {
      final kq = doc('tiền điện một triệu hai thứ hai');
      expect(kq.soTien, 1200000.0);
      expect(kq.soTienCanKiem, isTrue);
    });
    test('cả câu không dấu: "mot trieu hai hom qua" → 1.200.000', () {
      expect(doc('mot trieu hai hom qua').soTien, 1200000.0);
    });
  });

  group('mốt', () {
    test('"tiền điện một triệu mốt" → 1.100.000, cần kiểm, cachDocSoTien có 1.100.000', () {
      final kq = doc('tiền điện một triệu mốt');
      expect(kq.soTien, 1100000.0);
      expect(kq.soTienCanKiem, isTrue);
      expect(cachDocSoTien('tiền điện một triệu mốt', now: now), contains(1100000.0));
    });
    test('"hai triệu mốt" → 2.100.000', () {
      expect(doc('mua xe hai triệu mốt').soTien, 2100000.0);
    });
    test('mọi chữ số mà `_sauLaChuSoChu` nhận đều đọc được ở mọi dạng có dấu của so_bang_chu.dart', () {
      final nguon = File('lib/features/transaction/domain/doc_cau_giao_dich.dart').readAsStringSync();
      final dong = nguon.split(String.fromCharCode(10)).firstWhere((l) => l.contains('_sauLaChuSoChu = RegExp'));
      final nhan = RegExp(r'\(([a-z|]+)\)').firstMatch(dong)!.group(1)!.split('|').toSet();
      final dangCoDau = {for (final w in chuSoDonCoDau) w};
      final khongDauCua = {for (final w in dangCoDau) removeVietnameseTones(w): w};
      expect(
        nhan.difference(khongDauCua.keys.toSet()),
        isEmpty,
        reason: 'khoá của _sauLaChuSoChu phải là dạng bỏ dấu của một chữ số trong so_bang_chu.dart',
      );
      for (final w in dangCoDau.where((w) => nhan.contains(removeVietnameseTones(w)))) {
        final c = 'tiền điện đã trả một triệu $w';
        expect(
          cachDocSoTien(c, now: now).any((v) => v > 1000000 && v < 2000000),
          isTrue,
          reason: 'cachDocSoTien thiếu cách đọc X,Y cho "$w"',
        );
        expect(doc(c).soTien, isNot(1000000.0), reason: 'dạng có dấu "$w" bị đọc như không phải chữ số');
      }
    });
    for (final (cau, so) in [('tiền điện một triệu bẩy', 1700000.0), ('mua xe hai triệu bẩy', 2700000.0)]) {
      test('"$cau" → $so (bẩy = bảy miền Bắc)', () {
        final kq = doc(cau);
        expect(kq.soTien, so);
        expect(kq.soTienCanKiem, isTrue);
        expect(cachDocSoTien(cau, now: now), contains(so));
      });
    }
  });

  group('B — câu TRỘN dấu: chữ ASCII trong câu có dấu là mơ hồ', () {
    test('"tiền điện một triệu tu" → chưa rõ, Gemma còn chọn 1.400.000', () {
      final kq = doc('tiền điện một triệu tu');
      expect(kq.soTien, isNull);
      expect(kq.canhBao, contains(kCanhBaoSoChuChuaRo));
      expect(cachDocSoTien('tiền điện một triệu tu', now: now), contains(1400000.0));
    });
  });

  group('tỷ và C3', () {
    test('"1 tỷ 2" → 1.200.000.000, cần kiểm', () {
      final kq = doc('mua xe 1 tỷ 2');
      expect(kq.soTien, 1200000000.0);
      expect(kq.soTienCanKiem, isTrue);
    });
    test('chonSoTienTrongCau hưởng N1: "đặt ngân sách ăn uống 2 triệu 5" → 2.500.000', () {
      expect(chonSoTienTrongCau('đặt ngân sách ăn uống 2 triệu 5', now: now)?.giaTri, 2500000.0);
    });
  });

  group('soTienAiHopLe — lưới C2 §2.8, một định nghĩa', () {
    test('số AI là một cách đọc có trong câu → nhận', () {
      expect(soTienAiHopLe('tiền điện một triệu hai', const KetQuaAi(soTien: 1000000), now: now), 1000000.0);
    });
    test('số AI không có trong câu → null', () {
      expect(soTienAiHopLe('tiền điện một triệu hai', const KetQuaAi(soTien: 999999), now: now), isNull);
    });
    test('AI không có số / ≥ 13 chữ số → null', () {
      expect(soTienAiHopLe('ăn phở 45k', null, now: now), isNull);
      expect(soTienAiHopLe('ăn phở 45k', const KetQuaAi(soTien: 1e13), now: now), isNull);
    });
  });

  group('N2 — số 10–999 không đơn vị, đứng chỗ của tiền', () {
    for (final (cau, so) in [
      ('đổ xăng năm chục', 50000.0),
      ('sửa xe ba trăm rưỡi', 350000.0),
      ('ăn phở bốn mươi lăm bằng tiền mặt', 45000.0),
      ('đổ xăng 50', 50000.0),
      ('sửa xe 350', 350000.0),
      ('ăn phở 45, ngon', 45000.0),
      ('cà phê 25 hôm qua', 25000.0),
      ('đổ 2 lít xăng năm chục', 50000.0),
      ('ăn phở 45 ví tiền mặt', 45000.0),
      ('đổ xăng 50 hôm qua', 50000.0),
      ('ăn phở 45 ngày 5/10', 45000.0),
    ]) {
      test('"$cau" → $so, cần kiểm', () {
        final kq = doc(cau);
        expect(kq.soTien, so);
        expect(kq.soTienCanKiem, isTrue);
        expect(kq.oThieu, isNot(contains(OThieu.soTien)));
        expect(cachDocSoTien(cau, now: now), contains(so), reason: 'bất biến kiểm chéo');
      });
    }

    for (final cau in [
      'mua hai mươi quả trứng',
      'mua 2 ly cà phê',
      'đi xe 15 phút',
      'tiền điện tháng 10',
      'ăn phở 45 đồng',
      'ăn phở 45 ở quán',
      'trả 50 ngay',
      'đổ xăng 50 hôm sau',
      'tiền điện tháng mười',
      'cà phê 25 vi vu', // P19: "vi" không dấu chỉ là chữ sau tiền khi CẢ CÂU không dấu
    ]) {
      test('"$cau" → luật không đọc số tiền', () => expect(doc(cau).soTien, isNull));
    }

    for (final (cau, so) in [
      ('do xang nam chuc', 50000.0),
      ('an pho 45 bang tien mat', 45000.0),
      ('chuyển 500 đến ví tiền mặt', 500000.0),
      ('chuyển 500 tới ví tiền mặt', 500000.0),
    ]) {
      test('"$cau" → $so (không dấu hoàn toàn / đến · tới)', () => expect(doc(cau).soTien, so));
    }

    test('luật N2 thắng AI: "cà phê với Nam mất ba chục" → 30.000 do luật, không cần AI', () {
      final kq = docCauGiaoDich(
        'cà phê với Nam mất ba chục',
        now: now,
        vi: [tienMat],
        chonDuoc: const [],
        ai: const KetQuaAi(soTien: 30000),
      );
      expect(kq.soTien, 30000.0);
      expect(kq.quaAi, isFalse);
      expect(kq.oThieu, isNot(contains(OThieu.soTien)));
    });

    for (final cau in ['sửa xe hai mươi ba trăm', 'sửa xe mười ba trăm']) {
      test('bất biến "$cau": nếu luật chọn số thì số ∈ cachDocSoTien', () {
        final kq = doc(cau);
        if (kq.soTien != null) expect(cachDocSoTien(cau, now: now), contains(kq.soTien), reason: 'so luat chon');
      });
    }

    test('⚠️ "quả" bỏ dấu là "qua" — so chữ đứng sau CÓ DẤU', () {
      expect(
        doc('mua hai mươi quả trứng').soTien,
        isNull,
        reason: 'so trên chữ bỏ dấu thì "quả" = "qua" (trả qua ví) và đọc thành 20.000',
      );
    });

    test('có cụm đơn vị thì cụm ấy thắng, không cảnh báo nhiều số tiền', () {
      final kq = doc('mua hai mươi quả trứng ba mươi nghìn');
      expect(kq.soTien, 30000.0);
      expect(kq.soTienCanKiem, isFalse);
      expect(kq.canhBao, isNot(contains(kCanhBaoNhieuSoTien)));
    });

    test('ví vẫn đọc: "bằng tiền mặt" và "ví tiền mặt"', () {
      expect(doc('ăn phở bốn mươi lăm bằng tiền mặt').walletId, 'cash');
      expect(doc('ăn phở 45 ví tiền mặt').walletId, 'cash');
    });
  });

  test('⭐ "ngày năm tháng chín mua sách một trăm hai mươi nghìn" → 05/09 + 120.000, ghi chú "mua sách"', () {
    final kq = doc('ngày năm tháng chín mua sách một trăm hai mươi nghìn');
    expect(kq.ngay, DateTime(2026, 9, 5));
    expect(kq.soTien, 120000.0);
    expect(kq.ghiChu, 'mua sách');
  });

  test('vòng sửa 1: số tiền không bị ngày nuốt, "mung" không dấu không phải mùng', () {
    expect(doc('lam mong hai tram nghin').soTien, 200000.0);
    expect(doc('lam mong hai tram nghin').ngay, isNull);
    final a = doc('ngày năm tháng mười một trăm nghìn');
    expect((a.ngay, a.soTien), (DateTime(2026, 10, 5), 100000.0));
    final b = doc('mùng mười hai trăm nghìn');
    expect((b.ngay, b.soTien), (DateTime(2026, 9, 10), 200000.0));
    final c = doc('đi chơi mùng 2/9 500k');
    expect((c.ngay, c.soTien, c.ghiChu), (DateTime(2026, 9, 2), 500000.0, 'đi chơi mùng')); // y như base: dd/mm không nuốt chữ "mùng"
  });

  test('vòng sửa 2: tháng không nuốt tiền, số liền chữ là tiền, ghi chú sạch', () {
    for (final (cau, ngay, tien) in [
      ('đóng tiền nhà mùng 5 tháng 3 triệu', DateTime(2026, 10, 5), 3000000.0),
      ('tiền nhà mùng năm tháng ba triệu', DateTime(2026, 10, 5), 3000000.0),
      ('mùng 5 tháng 10 triệu', DateTime(2026, 10, 5), 10000000.0),
      ('ngày năm tháng mười hai mươi nghìn', DateTime(2026, 10, 5), 20000.0),
      ('mùng mười hai mươi nghìn', DateTime(2026, 9, 10), 20000.0),
    ]) {
      final kq = doc(cau);
      expect((kq.ngay, kq.soTien), (ngay, tien), reason: cau);
    }
    expect(doc('lì xì mùng 10k').ngay, isNull);
    expect(doc('lì xì mùng 10k').soTien, 10000.0);
    expect(doc('mùng 5k').soTien, 5000.0);
    expect(doc('ngày mùng năm tháng chín mua sách').ghiChu, 'mua sách');
    expect(doc('ngày mùng 5 tháng 9 mua sách').ghiChu, 'mua sách');
  });

  test('vòng sửa 3: số tháng trước lít / xị là tiền (lít: kiểm tiền; xị: chỉ kiểm ngày); tháng sau giữ tiền', () {
    expect(doc('mùng 5 tháng 3 lít').soTien, 300000.0); // lít = 100.000
    expect(
      doc('đóng tiền mùng năm tháng hai xị').ngay,
      DateTime(2026, 10, 5),
      reason: 'chỉ canh NGÀY: bộ đọc tiền vốn không đọc chữ + xị ("hai xị") — tháng không được nuốt "hai"',
    );
    final kq = doc('trả nợ mùng 5 tháng sau 2 triệu');
    expect((kq.ngay, kq.soTien), (null, 2000000.0));
  });

  test('vòng sửa 4: số dính sau "tháng" là tiền — mùng 5 tháng này, tiền đủ, ghi chú không mảnh số', () {
    for (final (cau, ngay, tien) in [
      ('tiền nhà mùng 5 tháng 3tr', DateTime(2026, 10, 5), 3000000.0),
      ('mùng 5 tháng 500k', DateTime(2026, 10, 5), 500000.0),
      ('mùng 5 tháng 300 nghìn', DateTime(2026, 10, 5), 300000.0),
      ('đóng tiền nhà mùng 5 tháng 3.000.000', DateTime(2026, 10, 5), 3000000.0),
      ('mùng 5 tháng 3,5 triệu', DateTime(2026, 10, 5), 3500000.0),
    ]) {
      final kq = doc(cau);
      expect((kq.ngay, kq.soTien), (ngay, tien), reason: cau);
      expect(kq.ghiChu, isNot(matches(RegExp(r'\d'))), reason: '$cau: ghi chú "${kq.ghiChu}" còn mảnh số');
    }
    // "ngày X" không nêu tháng thì không đọc ngày (C2 hỏi AI) — chữ số "5" của ngày còn trong ghi chú là đúng; chỉ cấm
    // mảnh của số tiền.
    final kq = doc('ngày 5 tháng 3.000.000');
    expect((kq.ngay, kq.soTien), (null, 3000000.0));
    expect(kq.ghiChu, isNot(contains('000')), reason: 'ghi chú "${kq.ghiChu}" còn mảnh số tiền');
  });

  test('vòng sửa 4 (a): số ngày của mùng dính . , + chữ số là tiền — không ngày, tiền đọc đủ', () {
    for (final (cau, tien) in [
      ('mùng 5,5 triệu', 5500000.0),
      ('lì xì mùng 2,5 triệu', 2500000.0),
      ('mùng 2.500.000', 2500000.0),
    ]) {
      final kq = doc(cau);
      expect((kq.ngay, kq.soTien), (null, tien), reason: cau);
      expect(kq.ghiChu, isNot(matches(RegExp(r'\d'))), reason: '$cau: ghi chú "${kq.ghiChu}" còn mảnh số');
    }
    final a = doc('mùng 2/9');
    expect(a.ngay, DateTime(2026, 9, 2), reason: 'dd/mm vẫn đọc');
    final b = doc('mùng 5 mua sách 50k');
    expect((b.ngay, b.soTien, b.ghiChu), (DateTime(2026, 10, 5), 50000.0, 'mua sách'));
  });

  group('ví gọi tắt — bỏ chữ "Ví" đầu tên, chỉ ngay sau ví / bằng / qua / từ / sang / vào / đến / tới', () {
    final mb = makeWallet(id: 'mb', name: 'Ví MB Bank').copyWith(type: 'bank');
    final momo = makeWallet(id: 'momo', name: 'Ví MoMo').copyWith(type: 'bank');
    final viTk = makeWallet(id: 'vitk', name: 'Ví tiết kiệm').copyWith(type: 'saving');
    final tk = makeWallet(id: 'tk', name: 'Tiết kiệm').copyWith(type: 'saving');
    final viA = makeWallet(id: 'a', name: 'Ví A').copyWith(type: 'bank');

    test('"mua áo hai trăm nghìn bằng MB Bank" → ví Ví MB Bank, ghi chú "mua áo"', () {
      final kq = doc('mua áo hai trăm nghìn bằng MB Bank', vi: [tienMat, mb]);
      expect(kq.walletId, 'mb');
      expect(kq.ghiChu, 'mua áo');
    });

    test('"trà sữa ba mươi nghìn trả bằng MoMo" → ví Ví MoMo (tên gọi 4 ký tự vẫn nhận sau "bằng")', () {
      expect(doc('trà sữa ba mươi nghìn trả bằng MoMo', vi: [tienMat, momo]).walletId, 'momo');
    });

    test('⚠️ "mua sách tiết kiệm" KHÔNG chọn ví Ví tiết kiệm (không giới từ đứng trước)', () {
      expect(doc('mua sách tiết kiệm', vi: [tienMat, viTk]).walletId, isNull);
    });

    test('⭐ "chuyển năm trăm nghìn từ MB Bank sang tiết kiệm" → chuyển ví MB Bank → Tiết kiệm, 500.000', () {
      final kq = doc('chuyển năm trăm nghìn từ MB Bank sang tiết kiệm', vi: [tienMat, mb, tk]);
      expect(kq.loai, 'transfer');
      expect(kq.walletId, 'mb');
      expect(kq.walletToId, 'tk');
      expect(kq.soTien, 500000.0);
    });

    test('"chuyển 500k từ momo sang MB Bank" → nguồn MoMo, đích MB Bank', () {
      final kq = doc('chuyển 500k từ momo sang MB Bank', vi: [tienMat, mb, momo]);
      expect(kq.walletId, 'momo');
      expect(kq.walletToId, 'mb');
    });

    test('tên gọi dưới 3 ký tự không dùng: "trả bằng a" không chọn ví Ví A', () {
      expect(doc('ăn phở 45k trả bằng a', vi: [tienMat, viA]).walletId, isNull);
    });

    test('tên đầy đủ vẫn như cũ: "bằng ví MB Bank"', () {
      expect(doc('mua áo 200k bằng ví MB Bank', vi: [tienMat, mb]).walletId, 'mb');
    });

    test('⚠️ giới từ so CÓ DẤU khi câu có dấu: "vì" ≠ "ví" — "đi chơi vì MB Bank tặng voucher 50k" không chọn ví', () {
      expect(doc('đi chơi vì MB Bank tặng voucher 50k', vi: [tienMat, mb]).walletId, isNull);
    });

    test('cả câu không dấu thì giới từ dạng không dấu nhận: "mua ao hai tram nghin bang MB Bank"', () {
      expect(doc('mua ao hai tram nghin bang MB Bank', vi: [tienMat, mb]).walletId, 'mb');
    });
  });

  group('ví gọi tắt — vòng sửa 1', () {
    final vcb = makeWallet(id: 'vcb', name: 'Ví VCB').copyWith(type: 'bank');
    final vcbL = makeWallet(id: 'vcbl', name: 'Ví VCB Lương').copyWith(type: 'bank');
    final mb = makeWallet(id: 'mb', name: 'Ví MB Bank').copyWith(type: 'bank');
    final mbTran = makeWallet(id: 'mbt', name: 'MB Bank').copyWith(type: 'bank');
    final momo = makeWallet(id: 'momo', name: 'Ví MoMo').copyWith(type: 'bank');
    final tk = makeWallet(id: 'tk', name: 'Tiết kiệm').copyWith(type: 'saving');

    test('hai tên gọi chung tiền tố: tên dài thắng, ghi chú không sót "lương", loại chi', () {
      final kq = doc('mua áo 200k bằng VCB lương', vi: [tienMat, vcb, vcbL]);
      expect(kq.walletId, 'vcbl');
      expect(kq.loai, isNot('thu'));
      expect(kq.ghiChu, 'mua áo');
    });

    test('"chuyển 500k sang tiết kiệm vì MB Bank tặng voucher" → nguồn không phải Ví MB Bank', () {
      final kq = doc('chuyển 500k sang tiết kiệm vì MB Bank tặng voucher', vi: [tienMat, mb, tk]);
      expect(kq.walletId, isNot('mb'));
    });

    test('"qua" của "hôm qua" không phải giới từ', () {
      expect(doc('hôm qua MoMo giảm giá trà sữa 30k', vi: [tienMat, momo]).walletId, isNull);
      expect(doc('hôm qua trà sữa 30k bằng MoMo', vi: [tienMat, momo]).walletId, 'momo');
    });

    test('có cả "Ví MB Bank" lẫn "MB Bank": tên đầy đủ thắng', () {
      expect(doc('mua áo 200k bằng MB Bank', vi: [tienMat, mb, mbTran]).walletId, 'mbt');
    });
  });

  group('"Nam" tên riêng không phải "năm" dương lịch (Task 7)', () {
    test('"Thu nợ anh Nam 500.000" (câu có dấu) → 500.000', () {
      expect(doc('Thu nợ anh Nam 500.000').soTien, 500000);
    });

    test('"anh Nam 500000" CẢ CÂU không dấu → nam = năm, không đọc (kết quả thật, theo luật điều phối)', () {
      expect(doc('anh Nam 500000').soTien, isNull,
          reason: 'cả câu không dấu thì "nam" là năm dương lịch (phán quyết Task 7) — ca này lệch ví dụ ban đầu của điều phối');
    });

    test('"năm 2026" (có dấu) và "nam 2026" (cả câu không dấu) vẫn không là tiền', () {
      expect(doc('tiền học năm 2026 2 triệu').soTien, 2000000);
      expect(doc('tien hoc nam 2026 2 trieu').soTien, 2000000);
      expect(cachDocSoTien('tiền học năm 2026', now: DateTime(2026, 10, 1)), isNot(contains(2026000)));
      expect(cachDocSoTien('tien hoc nam 2026', now: DateTime(2026, 10, 1)), isNot(contains(2026000)));
    });
  });
}
