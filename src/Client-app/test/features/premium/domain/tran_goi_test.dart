/// Trần của gói Basic và `conTaoDuoc` — MỘT định nghĩa của "được tạo thêm
/// không" (spec Premium 2026-10-06 mục 5.2). Bằng trần là vượt: 3/3 không tạo
/// cái thứ tư. Premium còn hạn thì không nhìn số đang có.
library;

import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flowmoney/features/premium/data/models/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flowmoney/features/premium/data/models/trang_thai_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10);
  final basic = TrangThaiGoi.basicMacDinh(now);
  final premium = TrangThaiGoi(
      loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 5), nhanLuc: now);

  group('conTaoDuoc', () {

    test('⭐ G109: Premium hết hạn LÚC OFFLINE (bảng lưu là của Premium) → trần Basic mặc định, không phải "không giới hạn"',
        () {
      final hetLucOffline = TrangThaiGoi(
          loai: LoaiGoi.premium,
          hetHan: DateTime(2026, 10, 6, 12),
          nhanLuc: now, // 10:00 — lúc nhận còn Premium
          tran: const TranGoi()); // trần cột Premium: toàn null
      final kq =
          conTaoDuoc(loai: LoaiTran.vi, dangCo: 3, goi: hetLucOffline, now: DateTime(2026, 10, 6, 13));
      expect(kq, isA<Vuot>(),
          reason: 'G109 — mã cũ đọc goi.tran (trần của Premium, toàn null) → người đã về Basic tạo không giới hạn '
              'tới lượt lamMoi kế.');
      expect((kq as Vuot).tran, 3);
    });

    test('⭐ B1: Premium còn hạn, trần cột Premium 10 ví → 10/10 vượt, 9/10 được', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 5), nhanLuc: now, tran: const TranGoi(vi: 10));
      expect(conTaoDuoc(loai: LoaiTran.vi, dangCo: 10, goi: g, now: now), isA<Vuot>());
      expect(conTaoDuoc(loai: LoaiTran.vi, dangCo: 9, goi: g, now: now), isA<Duoc>());
    });

    test('Premium KHÔNG hạn (bảng không dùng được) mang trần 3 → vẫn được (giữ hành vi cũ tới B4)', () {
      final g = TrangThaiGoi(loai: LoaiGoi.premium, nhanLuc: now, tran: const TranGoi(vi: 3));
      expect(conTaoDuoc(loai: LoaiTran.vi, dangCo: 99, goi: g, now: now), isA<Duoc>());
    });
    // Trần như server trả cho Basic (migration 23): 3/3/3/3/5.
    final basicServer = TrangThaiGoi(
      loai: LoaiGoi.basic,
      nhanLuc: now,
      tran: TranGoi.tuJson(const {
        'wallets': 3, 'budgets': 3, 'goals': 3, 'bills': 3, 'custom_categories': 5,
      }),
    );
    test('trần null (thiếu khoá / không giới hạn) → luôn được', () {
      expect(
          conTaoDuoc(loai: LoaiTran.hoaDon, dangCo: 999, goi: basic, now: now),
          isA<Duoc>());
    });
    for (final loai in LoaiTran.values) {
      test('Basic $loai: dưới trần được, BẰNG trần vượt, trên trần vượt', () {
        final basic = basicServer;
        final tran = basic.tran.cua(loai)!;
        expect(conTaoDuoc(loai: loai, dangCo: tran - 1, goi: basic, now: now),
            isA<Duoc>());
        final bang = conTaoDuoc(loai: loai, dangCo: tran, goi: basic, now: now);
        expect(bang, isA<Vuot>(),
            reason: 'Bằng trần thì không tạo cái tiếp theo — spec 5.2');
        expect((bang as Vuot).tran, tran);
        expect(bang.dangCo, tran);
        expect(bang.loai, loai);
        expect(conTaoDuoc(loai: loai, dangCo: tran + 2, goi: basic, now: now),
            isA<Vuot>(),
            reason: 'người bị hạ cấp đang có nhiều hơn — vẫn chỉ chặn tạo');
      });
    }

    test('Premium còn hạn: luôn được, không nhìn dangCo', () {
      expect(conTaoDuoc(loai: LoaiTran.vi, dangCo: 99, goi: premium, now: now),
          isA<Duoc>());
    });

    test('Premium ĐÃ hết hạn theo giờ máy: chặn như Basic', () {
      final sauHan = DateTime(2026, 12, 1);
      expect(
          conTaoDuoc(loai: LoaiTran.vi, dangCo: 3, goi: premium, now: sauHan),
          isA<Vuot>());
    });

    test('trần server đè: Basic với limits.wallets = 5 tạo được ví thứ 4', () {
      final goi = TrangThaiGoi(
          loai: LoaiGoi.basic,
          nhanLuc: now,
          tran: const TranGoi(vi: 5, nganSach: 3, mucTieu: 3));
      expect(conTaoDuoc(loai: LoaiTran.vi, dangCo: 3, goi: goi, now: now),
          isA<Duoc>());
      expect(
          conTaoDuoc(loai: LoaiTran.nganSach, dangCo: 3, goi: goi, now: now),
          isA<Vuot>());
    });

    test('⭐ server trả trần 0 → Basic chưa có cái nào cũng không tạo được (2026-10-27)', () {
      final goi = TrangThaiGoi(
          loai: LoaiGoi.basic, nhanLuc: now, tran: TranGoi.tuJson(const {'bills': 0}));
      final kq = conTaoDuoc(loai: LoaiTran.hoaDon, dangCo: 0, goi: goi, now: now);
      expect(kq, isA<Vuot>(), reason: 'Trần 0 = không tạo thêm; bản cũ đọc 0 thành không giới hạn cho hoá đơn.');
      expect((kq as Vuot).tran, 0);
    });

    test('trần null (không giới hạn) → luôn được tạo', () {
      final goi = TrangThaiGoi(
          loai: LoaiGoi.basic,
          nhanLuc: now,
          tran: const TranGoi(vi: null, nganSach: 3, mucTieu: 3));
      expect(conTaoDuoc(loai: LoaiTran.vi, dangCo: 999, goi: goi, now: now),
          isA<Duoc>());
    });
  });

  group('mã tran', () {
    test('maTran ↔ loaiTranTuMa, mã lạ → null', () {
      for (final l in LoaiTran.values) {
        expect(loaiTranTuMa(maTran(l)), l);
      }
      expect(loaiTranTuMa('xe'), isNull);
      expect(loaiTranTuMa(null), isNull);
    });

    test('tenTran là chữ tiếng Việt có dấu', () {
      expect(tenTran(LoaiTran.vi), 'ví');
      expect(tenTran(LoaiTran.nganSach), 'ngân sách');
      expect(tenTran(LoaiTran.mucTieu), 'mục tiêu tiết kiệm');
    });
  });
}
