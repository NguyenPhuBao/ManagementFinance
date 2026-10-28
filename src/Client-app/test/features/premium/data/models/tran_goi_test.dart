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

    test('tuJson đọc limits của server, ô thiếu / rác về mặc định', () {
      final t = TranGoi.tuJson({'wallets': 5, 'budgets': 'x'});
      expect(t.vi, 5);
      expect(t.nganSach, 3, reason: 'rác → mặc định cho đúng ô ấy');
      expect(t.mucTieu, 3, reason: 'thiếu khoá → mặc định');
      expect(TranGoi.tuJson(null), TranGoi.macDinh);
      expect(TranGoi.tuJson('rac'), TranGoi.macDinh);
    });

    test('⭐ trần 0 (Admin-web bỏ tick ∞) = KHÔNG tạo thêm — ở cả năm ô (người dùng chốt 2026-10-27)', () {
      final t = TranGoi.tuJson(
          const {'wallets': 0, 'budgets': 0, 'goals': 0, 'bills': 0, 'custom_categories': 0});
      for (final l in LoaiTran.values) {
        expect(t.cua(l), 0,
            reason: 'Bản cũ đọc 0 là rác: ví / ngân sách / mục tiêu về 3, hoá đơn / danh mục riêng thành KHÔNG giới '
                'hạn — ngược hẳn ý admin. Ô $l');
      }
    });

    test('trần âm (chỉ lọt qua API) đọc là 0, như Admin-web tự kẹp số âm về 0', () {
      final t = TranGoi.tuJson(const {'goals': -1, 'bills': -5});
      expect(t.mucTieu, 0);
      expect(t.hoaDon, 0);
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

    test('tuJson(khiThieu:) — ô thiếu / rác / không phải Map rơi về mặc định ĐƯỢC TRUYỀN (B1: trần cột Premium)', () {
      expect(TranGoi.tuJson(null, khiThieu: TranGoi.khongGioiHan), TranGoi.khongGioiHan);
      final t = TranGoi.tuJson(const {'wallets': 10, 'budgets': 'x'}, khiThieu: TranGoi.khongGioiHan);
      expect(t.vi, 10);
      expect(t.nganSach, isNull, reason: 'rác ở cột Premium → không giới hạn, không phải 3');
      expect(t.mucTieu, isNull, reason: 'thiếu ở cột Premium → không giới hạn');
      expect(TranGoi.tuJson(const {'wallets': 4}), const TranGoi(vi: 4, nganSach: 3, mucTieu: 3),
          reason: 'mặc định của tham số giữ hành vi cũ');
    });
  });
}
