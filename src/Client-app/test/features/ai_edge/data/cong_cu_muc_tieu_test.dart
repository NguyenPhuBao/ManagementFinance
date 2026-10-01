/// Adapter tool mục tiêu: đọc watchGoals đúng tài khoản, không tham số bắt
/// buộc, tham số lạ bỏ qua; đọc ví (lát 3 Task 10) chỉ khi có mục tiêu bật trích
/// tự động. Fake ghi đè noSuchMethod — hàm mới lỡ gọi thêm sẽ ném.
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_muc_tieu.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_muc_tieu.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

GoalEntity _muaXe(int idaccount, {bool trich = false}) => GoalEntity(
      id: 'g1',
      idaccount: idaccount,
      name: 'MuaXe',
      targetAmount: 2000000,
      currentAmount: 1101000,
      startDate: DateTime(2026, 9, 5),
      targetDate: DateTime(2027, 3, 1),
      walletId: 'w-tk',
      timeCycleTakeMoney: trich ? DateTime(2026, 9, 15, 8) : null,
      autoDepositAmount: trich ? 50000 : null,
      autoDepositWalletId: trich ? 'w-tm' : null,
      autoDepositLastRun: trich ? DateTime(2026, 9, 15, 8) : null,
      updatedAt: DateTime(2026, 9, 5),
    );

class _MucTieu implements GoalRepository {
  _MucTieu({this.trich = false, this.coMuaDT = false});
  final bool trich;

  /// Thêm mục tiêu MuaDT KHÔNG bật trích (F14 cổng F).
  final bool coMuaDT;
  final daHoi = <int>[];
  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value([
      _muaXe(idaccount, trich: trich),
      if (coMuaDT)
        GoalEntity(
          id: 'g2', idaccount: idaccount, name: 'MuaDT', targetAmount: 3000000, currentAmount: 500000,
          startDate: DateTime(2026, 9, 5), targetDate: DateTime(2027, 9, 5), updatedAt: DateTime(2026, 9, 5),
        ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Vi implements WalletRepository {
  _Vi(this.soDu, {this.status = 'active', this.daXoa = false});
  final double soDu;
  final String status;
  final bool daXoa;
  final daHoi = <int>[];
  @override
  Stream<List<WalletEntity>> watchAll(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value([
      WalletEntity(
          id: 'w-tm', idaccount: idaccount, name: 'Tiền mặt', type: 'cash', balance: soDu,
          status: status, isDeleted: daXoa, includeInTotal: true, allowNegative: false,
          updatedAt: DateTime(2026, 9, 10)),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);

  test('khai báo: tên, mô tả có "Gọi khi" + câu hỏi trích, chon bốn giá trị, không tham số bắt buộc', () {
    final k = CongCuMucTieu(_MucTieu(), vi: _Vi(0)).khaiBao;
    expect(k.ten, kTenCongCuMucTieu);
    expect(k.moTa, contains('Gọi khi'));
    expect(k.moTa, contains('kỳ trích tiếp'));
    expect(k.moTa, contains('ví nguồn'));
    expect(k.thamSo['required'], isNull);
    expect(((k.thamSo['properties'] as Map)['chon'] as Map)['enum'], kChonMucTieu);
  });

  test('⭐ E11 đầu-cuối: "muc tieu nao dang cham ke hoach" với args rỗng → lọc chậm → 0 hàng, rongTheoBoLoc', () async {
    final kq = await CongCuMucTieu(_MucTieu(), vi: _Vi(0), log: (_) {}).chay({}, idaccount: 10, now: now,
        cauHoi: 'muc tieu nao dang cham ke hoach');
    expect(kq.hang, isEmpty, reason: 'MuaXe 55 % đúng kế hoạch');
    expect(kq.rongTheoBoLoc, isTrue);
    expect(kq.boLoc, ['chậm kế hoạch']);
    expect(kq.json['Đang theo đuổi'], '1');
  });

  test('mô hình điền chon thừa cho câu không nêu trạng thái → gỡ, trả đủ hàng', () async {
    final kq = await CongCuMucTieu(_MucTieu(), vi: _Vi(0), log: (_) {}).chay({'chon': 'cham_ke_hoach'},
        idaccount: 10, now: now, cauHoi: 'khi nao toi dat muc tieu muaxe');
    expect(kq.hang.single.ten, 'MuaXe');
    expect(kq.boLoc, isEmpty);
  });

  test('đọc watchGoals đúng tài khoản; tham số lạ bỏ qua; KHÔNG đọc ví khi không mục tiêu nào trích tự động', () async {
    final repo = _MucTieu();
    final vi = _Vi(0);
    final kq = await CongCuMucTieu(repo, vi: vi).chay({'la': 1}, idaccount: 10, now: now);
    expect(repo.daHoi, [10]);
    expect(vi.daHoi, isEmpty);
    expect(kq.loi, isNull);
    expect(kq.hang.single.ten, 'MuaXe');
  });

  test('⭐ F13 đầu-cuối: "vi co du tien trich cho muc tieu khong" — đọc ví đúng tài khoản, kết luận thiếu', () async {
    final vi = _Vi(20000);
    final kq = await CongCuMucTieu(_MucTieu(trich: true), vi: vi, log: (_) {})
        .chay({}, idaccount: 10, now: now, cauHoi: 'vi co du tien trich cho muc tieu khong');
    expect(vi.daHoi, [10]);
    expect(kq.hang.single.trangThai, 'đúng kế hoạch · ví Tiền mặt không đủ để trích');
    expect(kq.chuThem['ket_qua'], 'có ví nguồn không đủ tiền để trích');
    expect(kq.boLoc, isEmpty, reason: '"có đủ … không" là câu hỏi chung, không lọc');
  });

  test('⭐ G1 cổng F — B1, DC1: câu không nói trích → không chữ trích, KHÔNG đọc ví', () async {
    for (final cau in ['khi nao toi dat muc tieu muaxe', 'Lai suat tiet kiem cua toi la bao nhieu?']) {
      final vi = _Vi(20000);
      final kq = await CongCuMucTieu(_MucTieu(trich: true), vi: vi, log: (_) {})
          .chay({}, idaccount: 10, now: now, cauHoi: cau);
      expect(vi.daHoi, isEmpty, reason: cau);
      expect(kq.hang.single.trangThai, 'đúng kế hoạch', reason: cau);
      expect(kq.chuThem.containsKey('ket_qua'), isFalse, reason: cau);
    }
  });

  test('⭐ G4 cổng F — F14 đầu-cuối: "ky trich tiep theo cua MuaDT" → chỉ MuaDT, nói thẳng không bật trích', () async {
    final kq = await CongCuMucTieu(_MucTieu(trich: true, coMuaDT: true), vi: _Vi(20000), log: (_) {})
        .chay({'chon': 'dung_ke_hoach'}, idaccount: 10, now: now, cauHoi: 'ky trich tiep theo cua MuaDT la khi nao');
    expect(kq.hang.map((h) => h.ten).toList(), ['MuaDT']);
    expect(kq.chuThem['ket_qua'], 'MuaDT không bật trích tự động');
  });

  test('ví nguồn lưu trữ / đã xoá → trích không chạy được (khớp GoalAutoDepositRunner)', () async {
    for (final vi in [_Vi(900000, status: 'inactive'), _Vi(900000, daXoa: true)]) {
      final kq = await CongCuMucTieu(_MucTieu(trich: true), vi: vi, log: (_) {})
          .chay({}, idaccount: 10, now: now);
      expect(kq.hang.single.trangThai, endsWith('trích tự động không chạy được'));
    }
  });
}
