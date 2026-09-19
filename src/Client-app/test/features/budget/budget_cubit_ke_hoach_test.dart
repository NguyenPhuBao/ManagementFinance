/// `BudgetCubit` sinh kế hoạch tái phân bổ khi có `TaiPhanBoNguon`; không có
/// thì `keHoach == null` và mọi hành vi cũ giữ nguyên.
library;

import 'dart:async';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/tai_phan_bo_nguon.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements BudgetRepository {
  final StreamController<List<BudgetView>> ctl = StreamController.broadcast();
  final List<BudgetView> ds;
  _Repo(this.ds);
  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) =>
      ctl.stream;
  @override
  Future<List<BudgetView>> getBudgets(int idaccount, {DateTime? now}) async =>
      ds;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _Nguon implements TaiPhanBoNguon {
  int soLan = 0;
  final DuLieuTaiPhanBo du;
  final Duration tre;
  _Nguon({this.du = DuLieuTaiPhanBo.rong, this.tre = Duration.zero});
  @override
  Future<DuLieuTaiPhanBo> nap(
      int idaccount, List<BudgetView> dangChay, DateTime now) async {
    soLan++;
    if (tre > Duration.zero) await Future<void>.delayed(tre);
    return du;
  }
}

class _NguonLoi implements TaiPhanBoNguon {
  @override
  Future<DuLieuTaiPhanBo> nap(
          int idaccount, List<BudgetView> dangChay, DateTime now) async =>
      throw StateError('csdl hỏng');
}

final _now = DateTime(2026, 9, 21);

BudgetView _v(String id, {required double amount, required double duPhong}) =>
    BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: amount,
        spent: duPhong * 20 / 30,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: id,
    );

final _thamHut = [
  _v('an', amount: 3000000, duPhong: 3600000),
  _v('ms', amount: 3000000, duPhong: 1000000),
];

void main() {
  test('không nguồn → keHoach null, phát ĐỒNG BỘ như trước', () async {
    final repo = _Repo(_thamHut);
    final cubit = BudgetCubit(repository: repo, clock: () => _now);
    await cubit.loadBudgets(7);
    final s = cubit.state as BudgetLoaded;
    expect(s.keHoach, isNull);
    expect(s.active, hasLength(2));
    await cubit.close();
  });

  test('có nguồn và thâm hụt → keHoach cho ngân sách hụt', () async {
    final repo = _Repo(_thamHut);
    final nguon = _Nguon();
    final cubit =
        BudgetCubit(repository: repo, clock: () => _now, taiPhanBoNguon: nguon);
    await cubit.loadBudgets(7);
    final s = cubit.state as BudgetLoaded;
    expect(s.keHoach, isNotNull);
    expect(s.keHoach!.thieu.budget.id, 'an');
    expect(s.keHoach!.dong.single.nguon.budget.id, 'ms');
    expect(nguon.soLan, 1);
    await cubit.close();
  });

  test('cờ Cố định từ nguồn được tôn trọng', () async {
    final repo = _Repo(_thamHut);
    final nguon = _Nguon(
        du: const DuLieuTaiPhanBo(
            coDinh: {'c-ms'},
            thuNhap3Thang: 0,
            tb3ThangTheoNganSach: {},
            phanHoi: []));
    final cubit =
        BudgetCubit(repository: repo, clock: () => _now, taiPhanBoNguon: nguon);
    await cubit.loadBudgets(7);
    final s = cubit.state as BudgetLoaded;
    expect(s.keHoach!.dong, isEmpty);
    await cubit.close();
  });

  test('nguồn ném lỗi → vẫn BudgetLoaded, keHoach null (kế hoạch là phần phụ)',
      () async {
    final repo = _Repo(_thamHut);
    final cubit = BudgetCubit(
        repository: repo, clock: () => _now, taiPhanBoNguon: _NguonLoi());
    await cubit.loadBudgets(7);
    expect(cubit.state, isA<BudgetLoaded>());
    expect((cubit.state as BudgetLoaded).keHoach, isNull);
    await cubit.close();
  });

  test('stream phát hai lần, lượt nạp CHẬM của lượt đầu không đè lượt sau',
      () async {
    final repo = _Repo(const []);
    final nguon = _Nguon(tre: const Duration(milliseconds: 30));
    final cubit =
        BudgetCubit(repository: repo, clock: () => _now, taiPhanBoNguon: nguon);
    cubit.watchBudgets(7);
    repo.ctl.add(_thamHut); // lượt 1: có thâm hụt
    repo.ctl.add(const []); // lượt 2: rỗng — phải là trạng thái cuối
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final s = cubit.state as BudgetLoaded;
    expect(s.active, isEmpty);
    expect(s.keHoach, isNull);
    await cubit.close();
    await repo.ctl.close();
  });
}
