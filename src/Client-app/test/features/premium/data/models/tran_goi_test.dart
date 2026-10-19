/// Model `TranGoi` — trần theo loại, đọc / ghi `limits` của server và của kho (spec Premium 2026-10-06 mục 5.2;
/// tách khỏi `domain/tran_goi_test.dart` ở G94 lát 1 khi model sang `data/models/`).
library;

import 'package:flowmoney/features/premium/data/models/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranGoi', () {
    test('mặc định 3/3/3/3/5', () {
      expect(TranGoi.macDinh.cua(LoaiTran.vi), 3);
      expect(TranGoi.macDinh.cua(LoaiTran.nganSach), 3);
      expect(TranGoi.macDinh.cua(LoaiTran.mucTieu), 3);
      expect(TranGoi.macDinh.cua(LoaiTran.hoaDon), isNull,
          reason: 'thiếu khoá = không giới hạn (spec phân quyền 2026-10-08 mục 2 #1)');
      expect(TranGoi.macDinh.cua(LoaiTran.danhMucRieng), isNull);
      expect(TranGoi.tuJson({'wallets': 3}).cua(LoaiTran.hoaDon), isNull);
      expect(TranGoi.tuJson({'bills': 3}).cua(LoaiTran.hoaDon), 3);
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
}
