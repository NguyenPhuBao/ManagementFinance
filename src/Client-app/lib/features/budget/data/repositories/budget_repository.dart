import '../../../../core/database/app_database.dart';
import '../models/budget_entity.dart';

abstract class BudgetRepository {
  /// Danh sách ngân sách kèm số đã chi **tính lại từ bảng giao dịch** và thông
  /// tin danh mục để hiển thị.
  Future<List<BudgetView>> getBudgets(int idaccount, {DateTime? now});

  /// Như [getBudgets] nhưng phát lại mỗi khi ngân sách **hoặc** giao dịch đổi —
  /// ghi một khoản chi phải làm thanh tiến trình nhúc nhích ngay.
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now});

  Future<BudgetView?> getBudgetById(String id, {DateTime? now});

  Future<BudgetEntity> addBudget({
    required int idaccount,
    required double amount,
    String? categoryId,
    double? thresholdWarningAmount,
    double? thresholdWarningPercent,
    String overSpending,
    DateTime? startDate,
    DateTime? endDate,
    bool recurrence,
    String timeRecurrence,
    String note,
  });

  Future<void> updateBudget(BudgetEntity budget);

  Future<void> deleteBudget(String id);

  /// Danh mục chi để chọn khi tạo/sửa ngân sách.
  Future<List<Category>> getExpenseCategories(int idaccount);
}
