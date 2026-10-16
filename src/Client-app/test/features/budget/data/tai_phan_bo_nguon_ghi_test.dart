/// `TaiPhanBoNguon.ghiPhanHoi` — trang Ngân sách thôi truyền `aiFeedbackDao.ghi` (spec bịt điểm rò 2026-10-10, mục 4.5); từ
/// 2026-10-15 nhận lớp thuần `PhanHoiTaiPhanBo` và là chỗ DUY NHẤT dựng `AiRebalancingFeedbacksCompanion` (spec Entity Danh mục mục 7).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/domain/ap_dung_ke_hoach.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/tai_phan_bo_nguon.dart';

class _NganSachGia implements BudgetRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('ghiPhanHoi dựng Companion đủ 11 cột từ PhanHoiTaiPhanBo và ghi vào bảng', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final nguon = TaiPhanBoNguonImpl(db: db, budgets: _NganSachGia());
    final tu = DateTime(2026, 10, 1);
    final toi = DateTime(2026, 11, 1);
    final luc = DateTime(2026, 10, 15, 9, 30);
    await nguon.ghiPhanHoi(PhanHoiTaiPhanBo(
      id: 'f1',
      idaccount: 10,
      createdAt: luc,
      deficitBudgetId: 'b1',
      donorBudgetId: 'b2',
      donorCategoryId: 'c2',
      suggestedAmount: 100000,
      actualAmount: 70000,
      action: 'modified',
      periodFrom: tu,
      periodTo: toi,
    ));
    expect(db.aiRebalancingFeedbacks.$columns.length, 11,
        reason: 'Thêm cột vào bảng phản hồi thì quyết định: vào PhanHoiTaiPhanBo (và phép dựng ở đây), hay cột tự mặc định.');
    final hang = (await db.aiFeedbackDao.getAll(10)).single;
    expect(hang.id, 'f1');
    expect(hang.idaccount, 10);
    expect(hang.createdAt, luc);
    expect(hang.deficitBudgetId, 'b1');
    expect(hang.donorBudgetId, 'b2');
    expect(hang.donorCategoryId, 'c2');
    expect(hang.suggestedAmount, 100000);
    expect(hang.actualAmount, 70000);
    expect(hang.action, 'modified');
    expect(hang.periodFrom, tu);
    expect(hang.periodTo, toi);
  });
}
