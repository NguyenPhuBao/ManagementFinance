/// Adapter tool mục tiêu: đọc watchGoals đúng tài khoản, không tham số bắt
/// buộc, tham số lạ bỏ qua. Fake ghi đè noSuchMethod — hàm mới lỡ gọi thêm sẽ ném.
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_muc_tieu.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_muc_tieu.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MucTieu implements GoalRepository {
  final daHoi = <int>[];
  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value([
      GoalEntity(
        id: 'g1',
        idaccount: idaccount,
        name: 'MuaXe',
        targetAmount: 2000000,
        currentAmount: 1101000,
        startDate: DateTime(2026, 9, 5),
        targetDate: DateTime(2027, 3, 1),
        updatedAt: DateTime(2026, 9, 5),
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);

  test('khai báo: tên, mô tả có "Gọi khi", chon ba trạng thái, không tham số bắt buộc', () {
    final k = CongCuMucTieu(_MucTieu()).khaiBao;
    expect(k.ten, kTenCongCuMucTieu);
    expect(k.moTa, contains('Gọi khi'));
    expect(k.thamSo['required'], isNull);
    expect(((k.thamSo['properties'] as Map)['chon'] as Map)['enum'], kChonMucTieu);
  });

  test('⭐ E11 đầu-cuối: "muc tieu nao dang cham ke hoach" với args rỗng → lọc chậm → 0 hàng, rongTheoBoLoc', () async {
    final kq = await CongCuMucTieu(_MucTieu()).chay({}, idaccount: 10, now: now,
        cauHoi: 'muc tieu nao dang cham ke hoach');
    expect(kq.hang, isEmpty, reason: 'MuaXe 55 % đúng kế hoạch');
    expect(kq.rongTheoBoLoc, isTrue);
    expect(kq.boLoc, ['chậm kế hoạch']);
    expect(kq.json['Đang theo đuổi'], '1');
  });

  test('mô hình điền chon thừa cho câu không nêu trạng thái → gỡ, trả đủ hàng', () async {
    final kq = await CongCuMucTieu(_MucTieu()).chay({'chon': 'cham_ke_hoach'}, idaccount: 10, now: now,
        cauHoi: 'khi nao toi dat muc tieu muaxe');
    expect(kq.hang.single.ten, 'MuaXe');
    expect(kq.boLoc, isEmpty);
  });

  test('đọc watchGoals đúng tài khoản; tham số lạ bỏ qua', () async {
    final repo = _MucTieu();
    final kq = await CongCuMucTieu(repo).chay({'la': 1}, idaccount: 10, now: now);
    expect(repo.daHoi, [10]);
    expect(kq.loi, isNull);
    expect(kq.hang.single.ten, 'MuaXe');
  });
}
