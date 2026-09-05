import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/domain/transaction_lookup.dart';
import '../../data/models/budget_entity.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/budget_history.dart';
import '../../domain/budget_pace.dart';

/// Trạng thái của trang chi tiết một ngân sách.
///
/// Cố ý không kế thừa `Equatable`: mỗi lần giao dịch đổi là một bản mới của
/// cả bốn khối, so bằng nội dung chỉ tốn công mà không bao giờ trùng.
sealed class BudgetDetailState {
  const BudgetDetailState();
}

class BudgetDetailLoading extends BudgetDetailState {
  const BudgetDetailLoading();
}

class BudgetDetailLoaded extends BudgetDetailState {
  final BudgetView view;
  final BudgetPace pace;

  /// Cũ trước mới sau, kỳ cuối là kỳ hiện tại.
  final List<BudgetPeriodSummary> history;

  /// Khoản chi của kỳ hiện tại, mới nhất trước.
  final List<TransactionEntity> transactions;
  final TransactionLookup lookup;

  /// Hết hạn thì trang chỉ đọc — cùng quy tắc với tab "Đã hết hạn".
  final bool expired;

  const BudgetDetailLoaded({
    required this.view,
    required this.pace,
    required this.history,
    required this.transactions,
    required this.lookup,
    required this.expired,
  });
}

class BudgetDetailError extends BudgetDetailState {
  final String message;
  const BudgetDetailError(this.message);
}

/// Gom mọi thứ trang chi tiết cần vào một state, và tự làm mới khi ngân sách
/// hoặc giao dịch đổi (qua `watchBudgets`, stream ấy đã lắng nghe cả hai).
///
/// Là cubit **riêng**, không dùng chung với `BudgetCubit`: state của nó thay
/// thế `BudgetLoaded`, gọi trên cùng cubit là trang danh sách trắng xoá — cùng
/// lý do đã ghi ở `loadEditor`.
class BudgetDetailCubit extends Cubit<BudgetDetailState> {
  final BudgetRepository repository;

  /// Nguồn thời gian cho nhịp chi và phép cắt kỳ. Tách ra để test không phụ
  /// thuộc đồng hồ máy chạy nó.
  final DateTime Function() clock;

  StreamSubscription<List<BudgetView>>? _subscription;

  /// Số thứ tự của lần làm mới gần nhất. Hai lần làm mới có thể chồng lên nhau
  /// (giao dịch đổi liên tiếp); lần cũ về sau không được đè lên lần mới.
  int _generation = 0;

  BudgetDetailCubit({required this.repository, DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const BudgetDetailLoading());

  void watch({required int? idaccount, required String budgetId}) {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetDetailError('Chưa đăng nhập — không mở được ngân sách.'));
      return;
    }
    emit(const BudgetDetailLoading());
    _subscription?.cancel();
    _subscription = repository.watchBudgets(idaccount).listen(
          (views) => _refresh(views, idaccount: idaccount, budgetId: budgetId),
          onError: (Object e) => emit(BudgetDetailError(e.toString())),
        );
  }

  Future<void> _refresh(
    List<BudgetView> views, {
    required int idaccount,
    required String budgetId,
  }) async {
    final generation = ++_generation;
    BudgetView? view;
    for (final v in views) {
      if (v.budget.id == budgetId) {
        view = v;
        break;
      }
    }
    if (view == null) {
      emit(const BudgetDetailError('Ngân sách này không còn tồn tại.'));
      return;
    }

    try {
      final now = clock();
      final history = await repository.getPeriodHistory(budgetId, now: now);
      final transactions =
          await repository.getPeriodTransactions(budgetId, now: now);
      final lookup = await repository.lookupFor(idaccount);
      if (isClosed || generation != _generation) return;
      emit(BudgetDetailLoaded(
        view: view,
        pace: budgetPaceOf(view.budget, now),
        history: history,
        transactions: transactions,
        lookup: lookup,
        expired: view.budget.isExpired(now),
      ));
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(BudgetDetailError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
