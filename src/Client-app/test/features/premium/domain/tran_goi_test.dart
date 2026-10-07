/// Trần của gói Basic và `conTaoDuoc` — MỘT định nghĩa của "được tạo thêm
/// không" (spec Premium 2026-10-06 mục 5.2). Bằng trần là vượt: 3/3 không tạo
/// cái thứ tư. Premium còn hạn thì không nhìn số đang có.
library;

import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10);
  final basic = TrangThaiGoi.basicMacDinh(now);
  final premium = TrangThaiGoi(
      loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 5), nhanLuc: now);

  group('TranGoi', () {
    test('mặc định 3/3/3/3/5', () {
      expect(TranGoi.macDinh.cua(LoaiTran.vi), 3);
      expect(TranGoi.macDinh.cua(LoaiTran.nganSach), 3);
      expect(TranGoi.macDinh.cua(LoaiTran.mucTieu), 3);
      expect(TranGoi.macDinh.cua(LoaiTran.hoaDon), 3);
      expect(TranGoi.macDinh.cua(LoaiTran.danhMucRieng), 5);
    });

    test('tuJson đọc limits của server, ô thiếu/rác/âm về mặc định', () {
      final t = TranGoi.tuJson({'wallets': 5, 'budgets': 'x', 'goals': -1});
      expect(t.vi, 5);
      expect(t.nganSach, 3, reason: 'rác → mặc định cho đúng ô ấy');
      expect(t.mucTieu, 3, reason: 'không dương → mặc định');
      expect(TranGoi.tuJson(null), TranGoi.macDinh);
      expect(TranGoi.tuJson('rac'), TranGoi.macDinh);
    });

    test('tuJson hỗ trợ giá trị null (không giới hạn / vô hạn)', () {
      final t = TranGoi.tuJson({'wallets': null, 'budgets': 5, 'goals': null});
      expect(t.vi, isNull);
      expect(t.nganSach, 5);
      expect(t.mucTieu, isNull);
    });

    test('toJson ↔ tuJson', () {
      const t = TranGoi(vi: 4, nganSach: 6, mucTieu: 2, hoaDon: 3, danhMucRieng: 5);
      expect(TranGoi.tuJson(t.toJson()), t);
    });
  });

  group('conTaoDuoc', () {
    for (final loai in LoaiTran.values) {
      test('Basic $loai: dưới trần được, BẰNG trần vượt, trên trần vượt', () {
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
