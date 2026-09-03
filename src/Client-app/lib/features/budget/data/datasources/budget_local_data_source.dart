import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../models/budget_entity.dart';

abstract class BudgetLocalDataSource {
  Future<List<BudgetEntity>> getBudgets(int idaccount);
  Stream<List<BudgetEntity>> watchBudgets(int idaccount);
  Future<BudgetEntity?> getBudgetById(String id);
  Future<void> addBudget(BudgetEntity budget);
  Future<void> updateBudget(BudgetEntity budget);
  Future<void> deleteBudget(String id);

  /// Ghi lại số đã chi mà KHÔNG đánh dấu bản ghi cần đẩy — xem
  /// `BudgetDao.updateSpent`.
  Future<void> cacheSpent(String id, double spent);

  /// Tổng chi trong khoảng [from]–[to].
  ///
  /// [categoryId] null nghĩa là ngân sách tổng → cộng mọi khoản chi.
  Future<double> sumExpenses({
    required int idaccount,
    required String? categoryId,
    required DateTime from,
    required DateTime to,
  });

  /// Phát tín hiệu mỗi khi bảng giao dịch đổi, để lớp trên tính lại số đã chi.
  Stream<void> watchTransactionChanges(int idaccount);

  /// Danh mục chi còn dùng được, để chọn khi tạo ngân sách.
  Future<List<Category>> getExpenseCategories(int idaccount);

  /// Mọi danh mục của tài khoản, để tra tên/biểu tượng cho danh sách ngân sách.
  ///
  /// Tách khỏi [getExpenseCategories] vì hàm kia khử trùng lặp theo tên và lọc
  /// theo `classify` — tra cứu thì cần đủ hàng, kể cả danh mục thu đã từng gắn
  /// vào một ngân sách cũ.
  Future<List<Category>> getAllCategories(int idaccount);
}

class BudgetLocalDataSourceImpl implements BudgetLocalDataSource {
  final AppDatabase db;

  BudgetLocalDataSourceImpl({required this.db});

  @override
  Future<List<BudgetEntity>> getBudgets(int idaccount) async {
    final rows = await db.budgetDao.getAll(idaccount);
    return rows.map(BudgetEntity.fromDrift).toList();
  }

  @override
  Stream<List<BudgetEntity>> watchBudgets(int idaccount) {
    return db.budgetDao
        .watchAll(idaccount)
        .map((rows) => rows.map(BudgetEntity.fromDrift).toList());
  }

  @override
  Future<BudgetEntity?> getBudgetById(String id) async {
    final row = await db.budgetDao.getById(id);
    return row == null ? null : BudgetEntity.fromDrift(row);
  }

  @override
  Future<void> addBudget(BudgetEntity budget) {
    return db.budgetDao.insert(budget.toCompanion());
  }

  @override
  Future<void> updateBudget(BudgetEntity budget) {
    // Chỉ liệt kê những cột người dùng sửa được. Cố ý bỏ `spent` ra ngoài: nó
    // do cacheSpent() ghi, đưa vào đây sẽ đè mất số vừa tính.
    return db.budgetDao.updateBudget(
      budget.id,
      BudgetsCompanion(
        categoryId: Value(budget.categoryId),
        amount: Value(budget.amount),
        thresholdWarningAmount: Value(budget.thresholdWarningAmount),
        overSpending: Value(budget.overSpending),
        startDate: Value(budget.startDate),
        endDate: Value(budget.endDate),
        recurrence: Value(budget.recurrence),
        timeRecurrence: Value(budget.timeRecurrence),
        note: Value(budget.note),
        syncStatus: const Value('pending'),
        updatedAt: Value(budget.updatedAt),
      ),
    );
  }

  @override
  Future<void> deleteBudget(String id) => db.budgetDao.softDelete(id);

  @override
  Future<void> cacheSpent(String id, double spent) =>
      db.budgetDao.updateSpent(id, spent);

  @override
  Future<double> sumExpenses({
    required int idaccount,
    required String? categoryId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await db.transactionDao.getByDateRange(idaccount, from, to);
    return rows
        .where((t) => t.type == 'chi')
        .where((t) => categoryId == null || t.categoryId == categoryId)
        // `amount` được lưu dạng dương ở client (khối Pull gọi `.abs()`), nên
        // cộng thẳng. Đừng đổi dấu ở đây.
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  @override
  Stream<void> watchTransactionChanges(int idaccount) {
    return db.transactionDao.watchAll(idaccount);
  }

  @override
  Future<List<Category>> getExpenseCategories(int idaccount) {
    // `classify` ở SQLite lưu dạng chuẩn hoá chữ thường ('chi'/'thu'/'vay_no'),
    // không phải 'Chi' như backend — xem `SyncPayloadNormalizer`.
    return db.categoryDao.getCategoryRows(idaccount, 'chi');
  }

  @override
  Future<List<Category>> getAllCategories(int idaccount) {
    return db.categoryDao.getAll(idaccount);
  }
}
