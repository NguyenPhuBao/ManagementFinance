/// `TrangThaiGoi` — trạng thái gói theo giờ máy truyền vào (spec Premium
/// 2026-10-06 mục 5.1). `hetHan == null` là CHƯA BIẾT, không phải vô hạn;
/// `soNgayConLai` không bao giờ âm — hết hạn thì `null`.
library;

import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10);

  group('laPremium / soNgayConLai', () {
    test('Basic: không Premium, soNgayConLai null', () {
      final g = TrangThaiGoi.basicMacDinh(now);
      expect(g.laPremium(now), isFalse);
      expect(g.soNgayConLai(now), isNull);
    });

    test('Premium hạn tương lai: còn N ngày LỊCH', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.premium,
          hetHan: DateTime(2026, 10, 9, 23, 0),
          nhanLuc: now);
      expect(g.laPremium(now), isTrue);
      expect(g.soNgayConLai(now), 3);
    });

    test('hết hạn 23:00 hôm nay, bây giờ 10:00 → còn 0 ngày, vẫn Premium', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.premium,
          hetHan: DateTime(2026, 10, 6, 23, 0),
          nhanLuc: now);
      expect(g.laPremium(now), isTrue);
      expect(g.soNgayConLai(now), 0);
    });

    test('hạn đã qua theo giờ máy → Basic, soNgayConLai null (không âm)', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.premium,
          hetHan: DateTime(2026, 10, 6, 9, 59),
          nhanLuc: now);
      expect(g.laPremium(now), isFalse);
      expect(g.soNgayConLai(now), isNull);
    });

    test('Premium CHƯA BIẾT hạn (null): là Premium, soNgayConLai null', () {
      final g = TrangThaiGoi(loai: LoaiGoi.premium, nhanLuc: now);
      expect(g.laPremium(now), isTrue);
      expect(g.soNgayConLai(now), isNull,
          reason: 'null = chưa biết, không phải vô hạn');
    });

    test('hạn UTC từ server so đúng với giờ máy', () {
      final hetHanUtc = DateTime.utc(2026, 10, 6, 16, 30); // 23:30 giờ VN
      final g = TrangThaiGoi(
          loai: LoaiGoi.premium, hetHan: hetHanUtc, nhanLuc: now);
      expect(
          g.laPremium(hetHanUtc.subtract(const Duration(minutes: 1))), isTrue);
      expect(g.laPremium(hetHanUtc.add(const Duration(minutes: 1))), isFalse);
    });
  });

  group('trangThaiTuJson', () {
    test('đọc accountType (mã thật) lẫn type (hướng dẫn), không phân biệt hoa thường',
        () {
      final a = trangThaiTuJson({
        'accountType': 'Premium',
        'premiumExpiresAt': '2026-11-04T18:40:15.000Z',
      }, nhanLuc: now);
      expect(a.loai, LoaiGoi.premium);
      expect(a.hetHan, DateTime.utc(2026, 11, 4, 18, 40, 15));
      final b = trangThaiTuJson({'type': 'PREMIUM'}, nhanLuc: now);
      expect(b.loai, LoaiGoi.premium);
      expect(b.hetHan, isNull);
    });

    test('Basic: hạn bỏ qua dù server có gửi', () {
      final g = trangThaiTuJson({
        'accountType': 'Basic',
        'premiumExpiresAt': '2026-11-04T18:40:15.000Z',
      }, nhanLuc: now);
      expect(g.loai, LoaiGoi.basic);
      expect(g.hetHan, isNull);
    });

    test('limits / price / packageDays đè mặc định; thiếu thì mặc định', () {
      final g = trangThaiTuJson({
        'accountType': 'Basic',
        'limits': {'wallets': 4},
        'price': 59000,
        'packageDays': 31,
      }, nhanLuc: now);
      expect(g.tran.vi, 4);
      expect(g.tran.nganSach, 3);
      expect(g.gia, 59000);
      expect(g.soNgayGoi, 31);
      final m = trangThaiTuJson({'accountType': 'Basic'}, nhanLuc: now);
      expect(m.tran, TranGoi.macDinh);
      expect(m.gia, kGiaPremium);
      expect(m.soNgayGoi, kSoNgayGoi);
    });

    test('JSON rỗng / rác không ném → Basic mặc định; hạn rác → chưa biết', () {
      expect(trangThaiTuJson({}, nhanLuc: now).loai, LoaiGoi.basic);
      expect(
          trangThaiTuJson({
            'accountType': 7,
            'premiumExpiresAt': 'hom qua',
            'limits': 'x',
            'price': 'free',
          }, nhanLuc: now).loai,
          LoaiGoi.basic);
      final p = trangThaiTuJson(
          {'accountType': 'Premium', 'premiumExpiresAt': 'hom qua'},
          nhanLuc: now);
      expect(p.hetHan, isNull, reason: 'hạn rác → chưa biết, không ném');
      expect(p.laPremium(now), isTrue);
    });
  });

  group('trangThaiTuLoaiPhien', () {
    test("'Premium' → premium chưa biết hạn; khác / null → Basic", () {
      expect(trangThaiTuLoaiPhien('Premium', nhanLuc: now).laPremium(now),
          isTrue);
      expect(trangThaiTuLoaiPhien('Premium', nhanLuc: now).hetHan, isNull);
      expect(trangThaiTuLoaiPhien('Basic', nhanLuc: now).loai, LoaiGoi.basic);
      expect(trangThaiTuLoaiPhien(null, nhanLuc: now).loai, LoaiGoi.basic);
    });
  });

  group('toJson ↔ tuJsonKho', () {
    test('đi vòng giữ nguyên mọi trường', () {
      final g = TrangThaiGoi(
        loai: LoaiGoi.premium,
        hetHan: DateTime.utc(2026, 11, 5, 1),
        tran: const TranGoi(vi: 4, nganSach: 3, mucTieu: 3),
        nhanLuc: now,
        gia: 59000,
        soNgayGoi: 31,
      );
      final lai = TrangThaiGoi.tuJsonKho(g.toJson())!;
      expect(lai.loai, g.loai);
      expect(lai.hetHan, g.hetHan);
      expect(lai.tran, g.tran);
      // Kho ghi UTC; `DateTime ==` đòi cùng múi giờ nên so theo khoảnh khắc.
      expect(lai.nhanLuc.isAtSameMomentAs(g.nhanLuc), isTrue);
      expect(lai.gia, 59000);
      expect(lai.soNgayGoi, 31);
    });

    test('kho rác → null, không ném', () {
      expect(TrangThaiGoi.tuJsonKho('x'), isNull);
      expect(TrangThaiGoi.tuJsonKho({'loai': 'premium'}), isNull,
          reason: 'thiếu nhanLuc là hàng hỏng');
    });
  });

  group('quyenTinhNang / duocDung', () {
    test('trangThaiTuJson đọc trường features từ backend', () {
      final g = trangThaiTuJson({
        'accountType': 'Basic',
        'features': {
          'ai_assistant': true,
          'ai_quick_input': false,
        },
      }, nhanLuc: now);

      expect(g.duocDung('ai_assistant'), isTrue);
      expect(g.duocDung('ai_quick_input'), isFalse);
    });

    test('duocDung ưu tiên map cấu hình, fallback theo laPremium nếu không có', () {
      final basicCoAi = TrangThaiGoi(
        loai: LoaiGoi.basic,
        nhanLuc: now,
        quyenTinhNang: const {'ai_assistant': true},
      );
      expect(basicCoAi.duocDung('ai_assistant'), isTrue,
          reason: 'Admin bật riêng cho Basic');
      expect(basicCoAi.duocDung('chua_co_trong_map'), isFalse,
          reason: 'Fallback về laPremium = false');

      final premiumBiKhoaAi = TrangThaiGoi(
        loai: LoaiGoi.premium,
        hetHan: DateTime(2026, 11, 5),
        nhanLuc: now,
        quyenTinhNang: const {'ai_assistant': false},
      );
      expect(premiumBiKhoaAi.duocDung('ai_assistant'), isFalse,
          reason: 'Admin chủ động tắt');
    });

    test('tuJsonKho lưu và phục hồi quyenTinhNang', () {
      final g = TrangThaiGoi(
        loai: LoaiGoi.basic,
        nhanLuc: now,
        quyenTinhNang: const {'ai_assistant': true, 'ai_quick_input': false},
      );
      final lai = TrangThaiGoi.tuJsonKho(g.toJson())!;
      expect(lai.duocDung('ai_assistant'), isTrue);
      expect(lai.duocDung('ai_quick_input'), isFalse);
    });
  });
}
