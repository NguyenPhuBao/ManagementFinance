import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/budget_entity.dart';
import '../../data/repositories/budget_repository.dart';
import 'budget_state.dart';

export 'budget_state.dart';

/// UI → BudgetCubit → BudgetRepository → BudgetLocalDataSource → Drift
///
/// Không có nhánh nào gọi thẳng API: ngân sách đi lên backend qua `SyncEngine`
/// như mọi thực thể khác.
class BudgetCubit extends Cubit<BudgetState> {
  final BudgetRepository repository;

  /// Nguồn thời gian dùng để phân tab. Tách ra để test không phụ thuộc đồng hồ
  /// máy chạy nó: "hết hạn chưa" là câu hỏi về thời điểm.
  final DateTime Function() clock;

  StreamSubscription<List<BudgetView>>? _subscription;

  BudgetCubit({required this.repository, DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const BudgetInitial());

  /// Theo dõi danh sách ngân sách. Phát lại cả khi có giao dịch mới.
  ///
  /// [idaccount] phải là mã của phiên đăng nhập hiện tại. Nơi gọi truyền `null`
  /// khi chưa đăng nhập thì cubit **không đọc gì cả** thay vì đoán một mã tài
  /// khoản — xem `core/auth/current_account.dart`.
  void watchBudgets(int? idaccount) {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không đọc được ngân sách.'));
      return;
    }
    emit(const BudgetLoading());
    _subscription?.cancel();
    _subscription = repository.watchBudgets(idaccount).listen(
          (views) => emit(_loadedFrom(views)),
          onError: (Object e) => emit(BudgetError(e.toString())),
        );
  }

  Future<void> loadBudgets(int? idaccount) async {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không đọc được ngân sách.'));
      return;
    }
    emit(const BudgetLoading());
    try {
      emit(_loadedFrom(await repository.getBudgets(idaccount)));
    } catch (e) {
      emit(BudgetError(e.toString()));
    }
  }

  /// Chia danh sách thành hai tab và cộng tổng **chỉ trên tab đang hoạt động**.
  BudgetLoaded _loadedFrom(List<BudgetView> views) {
    final now = clock();
    final active = <BudgetView>[];
    final expired = <BudgetView>[];
    var amount = 0.0;
    var spent = 0.0;

    for (final v in views) {
      if (v.budget.isExpired(now)) {
        expired.add(v);
        continue;
      }
      active.add(v);
      amount += v.budget.amount;
      spent += v.budget.spent;
    }

    return BudgetLoaded(
      active: active,
      expired: expired,
      totalAmount: amount,
      totalSpent: spent,
    );
  }

  /// Nạp mọi thứ trang cấu hình cần: danh mục chi, và ngân sách đang sửa nếu
  /// [budgetId] khác null.
  ///
  /// Cố ý dùng một cubit RIÊNG ở trang đó: state này thay thế [BudgetLoaded]
  /// nên gọi nó trên cùng cubit với danh sách sẽ làm trang danh sách trắng xoá.
  Future<void> loadEditor(int? idaccount, {String? budgetId}) async {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không mở được ngân sách.'));
      return;
    }
    emit(const BudgetLoading());
    try {
      final categories = await repository.getExpenseCategories(idaccount);
      final editing = budgetId == null
          ? null
          : (await repository.getBudgetById(budgetId))?.budget;
      if (budgetId != null && editing == null) {
        emit(const BudgetError('Ngân sách này không còn tồn tại.'));
        return;
      }
      emit(BudgetEditorReady(categories: categories, editing: editing));
    } catch (e) {
      emit(BudgetError(e.toString()));
    }
  }

  Future<void> addBudget({
    required int? idaccount,
    required double amount,
    String? categoryId,
    double? thresholdWarningAmount,
    double? thresholdWarningPercent,
    String overSpending = BudgetOverSpending.over,
    DateTime? startDate,
    DateTime? endDate,
    bool recurrence = true,
    String? timeRecurrence = BudgetRecurrence.month,
    DateTime? nextTimeRecurrence,
    String note = '',
  }) async {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không tạo được ngân sách.'));
      return;
    }
    try {
      await repository.addBudget(
        idaccount: idaccount,
        amount: amount,
        categoryId: categoryId,
        thresholdWarningAmount: thresholdWarningAmount,
        thresholdWarningPercent: thresholdWarningPercent,
        overSpending: overSpending,
        startDate: startDate,
        endDate: endDate,
        recurrence: recurrence,
        timeRecurrence: timeRecurrence,
        nextTimeRecurrence: nextTimeRecurrence,
        note: note,
      );
      emit(const BudgetSaved('Đã tạo ngân sách.'));
    } catch (e) {
      emit(BudgetError(_readable(e)));
    }
  }

  Future<void> updateBudget(BudgetEntity budget) async {
    try {
      await repository.updateBudget(budget);
      emit(const BudgetSaved('Đã cập nhật ngân sách.'));
    } catch (e) {
      emit(BudgetError(_readable(e)));
    }
  }

  Future<void> deleteBudget(String id) async {
    try {
      await repository.deleteBudget(id);
      emit(const BudgetSaved('Đã xoá ngân sách.'));
    } catch (e) {
      emit(BudgetError(_readable(e)));
    }
  }

  /// `ArgumentError.toString()` in ra cả tên tham số và giá trị — không phải
  /// thứ để đưa thẳng cho người dùng đọc.
  String _readable(Object e) =>
      e is ArgumentError ? (e.message?.toString() ?? e.toString()) : e.toString();

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
