/// C4 — luật đọc câu NÓI (spec 2026-10-12 §3.2–3.3, khối 🔧). Luật chỉ CHỌN THÊM trong tập `cachDocSoTien` đã có;
/// số đọc bằng dạng nói mới học mang cờ `soTienCanKiem` để Gemma kiểm chéo.
library;

import 'package:flowmoney/core/database/app_database.dart';
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
    test('"hai triệu sau khi giảm" → luật KHÔNG điền 2.600.000 (mơ hồ → chưa rõ như trước C4; Gemma còn chọn)', () {
      final kq = doc('hai triệu sau khi giảm');
      expect(kq.soTien, isNot(2600000.0));
      expect(kq.soTien, isNull);
      expect(kq.soTienCanKiem, isFalse);
      expect(kq.canhBao, contains(kCanhBaoSoChuChuaRo));
      expect(cachDocSoTien('hai triệu sau khi giảm', now: now), contains(2600000.0));
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
}
