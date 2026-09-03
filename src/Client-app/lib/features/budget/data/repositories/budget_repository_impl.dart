import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/budget_local_data_source.dart';
import '../models/budget_entity.dart';
import 'budget_repository.dart';

/// Ghi vào SQLite trước, đẩy lên backend sau — theo cam kết offline-first của
/// dự án.
///
/// ## Số đã chi được tính ở đâu
///
/// Cột `Spent` tồn tại ở cả hai phía nhưng **không bên nào cập nhật nó**:
/// backend không có tác vụ nền tính lại, còn giao dịch thì người dùng ghi được
/// khi offline. Vì vậy repository này tự cộng từ bảng `transactions` mỗi lần
/// đọc, rồi ghi kết quả xuống cột `spent` bằng `cacheSpent` để lần đẩy sau gửi
/// đúng con số. `cacheSpent` cố ý **không** đánh dấu bản ghi `pending`: nếu có
/// thì mỗi lần mở trang ngân sách lại sinh một thao tác đẩy mới.
class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetLocalDataSource localDataSource;
  final SyncEngine? syncEngine;

  BudgetRepositoryImpl({
    required this.localDataSource,
    this.syncEngine,
  });

  // ── Đọc ─────────────────────────────────────────────────────────────────────

  @override
  Future<List<BudgetView>> getBudgets(int idaccount, {DateTime? now}) async {
    final budgets = await localDataSource.getBudgets(idaccount);
    return _decorate(idaccount, budgets, now);
  }

  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) {
    // Hai nguồn thay đổi độc lập: sửa ngân sách, và ghi giao dịch. Thiếu nguồn
    // thứ hai thì thanh tiến trình chỉ nhúc nhích khi người dùng mở lại trang.
    final controller = StreamController<List<BudgetView>>.broadcast();
    List<BudgetEntity> latest = const [];
    var hasBudgets = false;

    Future<void> push() async {
      if (!hasBudgets || controller.isClosed) return;
      try {
        controller.add(await _decorate(idaccount, latest, now));
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    final budgetSub = localDataSource.watchBudgets(idaccount).listen(
      (rows) {
        latest = rows;
        hasBudgets = true;
        push();
      },
      onError: controller.addError,
    );
    final txSub = localDataSource
        .watchTransactionChanges(idaccount)
        .listen((_) => push(), onError: controller.addError);

    controller.onCancel = () async {
      await budgetSub.cancel();
      await txSub.cancel();
    };
    return controller.stream;
  }

  @override
  Future<BudgetView?> getBudgetById(String id, {DateTime? now}) async {
    final budget = await localDataSource.getBudgetById(id);
    if (budget == null) return null;
    final views = await _decorate(budget.idaccount, [budget], now);
    return views.isEmpty ? null : views.first;
  }

  /// Tính số đã chi và gắn tên/biểu tượng danh mục.
  Future<List<BudgetView>> _decorate(
    int idaccount,
    List<BudgetEntity> budgets,
    DateTime? now,
  ) async {
    if (budgets.isEmpty) return const [];

    // Một lượt đọc danh mục cho cả danh sách thay vì mỗi ngân sách một lượt.
    final categories = await localDataSource.getAllCategories(idaccount);
    final byId = {for (final c in categories) c.id: c};

    final views = <BudgetView>[];
    for (final b in budgets) {
      final period = b.currentPeriod(now);
      final spent = await localDataSource.sumExpenses(
        idaccount: idaccount,
        categoryId: b.categoryId,
        from: period.from,
        to: period.to,
      );

      // Chỉ ghi khi thật sự lệch — tránh một lượt ghi SQLite cho mỗi lần vẽ
      // lại giao diện. Ngưỡng 0,005 đồng: nhỏ hơn đơn vị tiền nhỏ nhất, đủ để
      // bỏ qua sai số dấu phẩy động khi cộng dồn.
      if ((b.spent - spent).abs() > 0.005) {
        await localDataSource.cacheSpent(b.id, spent);
      }

      final category = b.categoryId == null ? null : byId[b.categoryId];
      views.add(BudgetView(
        budget: b.copyWith(spent: spent),
        categoryName: category?.name,
        categoryIcon: category?.icon,
        categoryColour: category?.colour,
      ));
    }
    return views;
  }

  // ── Ghi ─────────────────────────────────────────────────────────────────────

  @override
  Future<BudgetEntity> addBudget({
    required int idaccount,
    required double amount,
    String? categoryId,
    double? thresholdWarningAmount,
    double? thresholdWarningPercent,
    String overSpending = BudgetOverSpending.over,
    DateTime? startDate,
    DateTime? endDate,
    bool recurrence = true,
    String timeRecurrence = BudgetRecurrence.month,
    String note = '',
  }) async {
    // `idaccount` CHỈ đến từ phiên đăng nhập. Không suy ra từ dữ liệu SQLite và
    // không mặc định về 1 — đó là tài khoản admin thật.
    if (idaccount <= 0) {
      throw ArgumentError.value(
        idaccount,
        'idaccount',
        'Chưa có phiên đăng nhập hợp lệ — không được tạo ngân sách',
      );
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Hạn mức phải lớn hơn 0');
    }

    final now = DateTime.now();
    final budget = BudgetEntity(
      // UUID v4 vì backend khai báo `Idbudget VarChar(36)` và đường `/sync/push`
      // từ chối id không đúng dạng.
      id: const Uuid().v4(),
      idaccount: idaccount,
      categoryId: categoryId,
      amount: amount,
      spent: 0.0,
      thresholdWarningAmount: thresholdWarningAmount,
      thresholdWarningPercent: thresholdWarningPercent,
      overSpending: overSpending,
      startDate: startDate ?? DateTime(now.year, now.month, 1),
      endDate: endDate,
      recurrence: recurrence,
      timeRecurrence: timeRecurrence,
      note: note,
      isDeleted: false,
      syncStatus: 'pending',
      updatedAt: now,
    );

    await localDataSource.addBudget(budget);
    syncEngine?.scheduleSync();
    return budget;
  }

  @override
  Future<void> updateBudget(BudgetEntity budget) async {
    if (budget.amount <= 0) {
      throw ArgumentError.value(
          budget.amount, 'amount', 'Hạn mức phải lớn hơn 0');
    }
    await localDataSource.updateBudget(
      budget.copyWith(updatedAt: DateTime.now(), syncStatus: 'pending'),
    );
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> deleteBudget(String id) async {
    await localDataSource.deleteBudget(id);
    syncEngine?.scheduleSync();
  }

  @override
  Future<List<Category>> getExpenseCategories(int idaccount) {
    return localDataSource.getExpenseCategories(idaccount);
  }
}
