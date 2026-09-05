import '../../../../core/database/app_database.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/domain/transaction_lookup.dart';
import '../../domain/budget_history.dart';
import '../models/budget_entity.dart';

abstract class BudgetRepository {
  /// Danh sách ngân sách kèm số đã chi **tính lại từ bảng giao dịch** và thông
  /// tin danh mục để hiển thị.
  Future<List<BudgetView>> getBudgets(int idaccount, {DateTime? now});

  /// Như [getBudgets] nhưng phát lại mỗi khi ngân sách **hoặc** giao dịch đổi —
  /// ghi một khoản chi phải làm thanh tiến trình nhúc nhích ngay.
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now});

  Future<BudgetView?> getBudgetById(String id, {DateTime? now});

  /// Tối đa [count] kỳ gần nhất kèm số đã chi từng kỳ, cũ trước mới sau.
  /// Rỗng khi ngân sách không tồn tại hoặc chưa tới ngày bắt đầu.
  Future<List<BudgetPeriodSummary>> getPeriodHistory(
    String budgetId, {
    int count = 6,
    DateTime? now,
  });

  /// Các khoản chi của danh mục trong kỳ hiện tại, mới nhất trước.
  Future<List<TransactionEntity>> getPeriodTransactions(
    String budgetId, {
    DateTime? now,
  });

  /// Tên ví và danh mục của tài khoản, để vẽ dòng giao dịch trên trang chi
  /// tiết bằng đúng bộ dựng của sổ (`buildTransactionRowContent`).
  Future<TransactionLookup> lookupFor(int idaccount);

  /// Ngân sách **đang chạy** của [categoryId], kèm số đã chi; null nếu không
  /// có. Dùng ở form thêm giao dịch để báo trước khi ghi.
  Future<BudgetView?> activeBudgetForCategory(
    int idaccount,
    String categoryId, {
    DateTime? now,
  });

  /// Gợi ý hạn mức: trung bình chi của [categoryId] trong **ba tháng dương
  /// lịch trước** tháng hiện tại, làm tròn lên bội 10.000. Null khi ba tháng
  /// ấy không có khoản chi nào — không có gì để gợi ý.
  Future<double?> suggestAmount(
    int idaccount,
    String categoryId, {
    DateTime? now,
  });

  /// [categoryId] là **bắt buộc**: một ngân sách thuộc về đúng một danh mục.
  /// Truyền null sẽ bị từ chối — "ngân sách tổng" đã bỏ từ 2026-09-04. Hàng cũ
  /// mang giá trị null vẫn đọc và sửa được, chỉ không tạo mới được nữa.
  ///
  /// [nextTimeRecurrence] là **mốc neo chu kỳ** — xem tài liệu ở trường cùng
  /// tên trong [BudgetEntity].
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
    String? timeRecurrence,
    DateTime? nextTimeRecurrence,
    String note,
  });

  Future<void> updateBudget(BudgetEntity budget);

  Future<void> deleteBudget(String id);

  /// Danh mục chi để chọn khi tạo/sửa ngân sách.
  Future<List<Category>> getExpenseCategories(int idaccount);
}
