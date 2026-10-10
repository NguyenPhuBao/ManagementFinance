/// `TaiPhanBoNguon.ghiPhanHoi` — trang Ngân sách thôi truyền `aiFeedbackDao.ghi` (spec bịt điểm rò 2026-10-10, mục 4.5).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/tai_phan_bo_nguon.dart';

class _NganSachGia implements BudgetRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('ghiPhanHoi ghi vào bảng AiRebalancingFeedbacks', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final nguon = TaiPhanBoNguonImpl(db: db, budgets: _NganSachGia());
    final moc = DateTime(2026, 10, 10);
    await nguon.ghiPhanHoi(AiRebalancingFeedbacksCompanion.insert(
      id: 'f1', idaccount: 10, createdAt: moc, deficitBudgetId: 'b1', donorBudgetId: 'b2',
      donorCategoryId: 'c2', suggestedAmount: 100000, actualAmount: 100000, action: 'ap_dung',
      periodFrom: moc, periodTo: moc,
    ));
    expect(await db.aiFeedbackDao.getAll(10), hasLength(1));
  });
}
