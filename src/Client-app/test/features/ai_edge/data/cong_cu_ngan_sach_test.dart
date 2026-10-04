/// Tool ngân sách đọc nhịp riêng qua `docNhipChi` (dự án C việc hai, spec mục 3.2.3);
/// đọc hỏng thì trạng thái theo chi đều như trước.
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_ngan_sach.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/tai_phan_bo_nguon.dart';
import 'package:flowmoney/features/budget/domain/nhip_chi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../budget/domain/nhip_chi_mau.dart';

class _NganSach implements BudgetRepository {
  _NganSach({this.nhip = const {}, this.nem = false});
  final Map<String, NhipChi?> nhip;
  final bool nem;

  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) =>
      Stream.value([
        BudgetView(
          budget: BudgetEntity(
            id: 'gd',
            idaccount: idaccount,
            categoryId: 'c-gd',
            amount: 50000,
            spent: 45000,
            startDate: DateTime(2026, 9, 1),
            recurrence: true,
            timeRecurrence: BudgetRecurrence.month,
            updatedAt: DateTime(2026, 9, 1),
          ),
          categoryName: 'Giáo dục',
        ),
      ]);

  @override
  Future<Map<String, NhipChi?>> nhipChiTheoNganSach(
      int idaccount, List<BudgetEntity> budgets,
      {DateTime? now}) async {
    if (nem) throw StateError('hỏng');
    return nhip;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _TaiPhanBo implements TaiPhanBoNguon {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 22);

  test('⭐ có nhịp riêng → hàng nói "đúng nhịp"', () async {
    final cc = CongCuNganSach(_NganSach(nhip: {'gd': nhipGiaoDuc()}),
        taiPhanBo: _TaiPhanBo(), log: (_) {});
    final kq = await cc.chay({}, idaccount: 10, now: now);
    expect(kq.hang.single.trangThai, 'đúng nhịp');
  });

  test('đọc nhịp hỏng → vẫn trả lời, trạng thái theo chi đều ("tiêu nhanh")',
      () async {
    final cc = CongCuNganSach(_NganSach(nem: true),
        taiPhanBo: _TaiPhanBo(), log: (_) {});
    final kq = await cc.chay({}, idaccount: 10, now: now);
    expect(kq.hang.single.trangThai, 'tiêu nhanh');
  });
}
