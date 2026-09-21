import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../analytics/domain/pham_vi_ky.dart';
import '../../data/models/transaction_entity.dart';
import '../../data/repositories/transaction_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository transactionRepository;
  final SyncEngine? syncEngine;
  StreamSubscription<List<TransactionEntity>>? _subscription;

  TransactionBloc({
    required this.transactionRepository,
    this.syncEngine,
  }) : super(TransactionInitialState()) {
    on<LoadTransactionsEvent>(_onLoadTransactions);
    on<TransactionsUpdatedEvent>(_onTransactionsUpdated);
    on<AddTransactionEvent>(_onAddTransaction);
    on<UpdateTransactionEvent>(_onUpdateTransaction);
    on<DeleteTransactionEvent>(_onDeleteTransaction);
    on<ChonKyEvent>(_onChonKy);
  }

  int? _currentIdAccount;

  Future<void> _onLoadTransactions(
    LoadTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    _currentIdAccount = event.idaccount;
    emit(TransactionLoadingState());
    final now = DateTime.now();
    // Mở trang ở tháng hiện tại — giữ nguyên nếp cũ, chỉ khác là nay nó là một
    // kỳ chứ không phải một cặp (năm, tháng).
    _subscribeKy(event.idaccount, Ky.thang(now.year, now.month));
  }

  void _subscribeKy(int idaccount, Ky ky) {
    _subscription?.cancel();
    _subscription = transactionRepository
        .watchKhoang(idaccount, ky.from, ky.to)
        .listen((list) {
      add(TransactionsUpdatedEvent(list, ky: ky));
    });
  }

  void _onTransactionsUpdated(
    TransactionsUpdatedEvent event,
    Emitter<TransactionState> emit,
  ) {
    _emitLoadedState(event.transactions, event.ky, emit);
  }

  void _onChonKy(
    ChonKyEvent event,
    Emitter<TransactionState> emit,
  ) {
    if (_currentIdAccount != null) {
      _subscribeKy(_currentIdAccount!, event.ky);
    }
  }

  Future<void> _onAddTransaction(
    AddTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final currState = state is TransactionLoadedState ? (state as TransactionLoadedState) : null;
    if (currState != null) {
      emit(currState.copyWith(isSubmitting: true, actionSuccess: null));
    }

    try {
      await transactionRepository.addTransaction(
        event.transaction,
        destinationWalletId: event.destinationWalletId,
      );
      syncEngine?.scheduleSync();

      if (state is TransactionLoadedState) {
        final curr = state as TransactionLoadedState;
        emit(curr.copyWith(isSubmitting: false, actionSuccess: true));
      } else {
        final now = DateTime.now();
        emit(TransactionLoadedState(
          giaoDich: const [],
          totalIncome: 0,
          totalExpense: 0,
          ky: Ky.thang(now.year, now.month),
          isSubmitting: false,
          actionSuccess: true,
        ));
      }
    } catch (e) {
      if (state is TransactionLoadedState) {
        final curr = state as TransactionLoadedState;
        emit(curr.copyWith(
          isSubmitting: false,
          actionSuccess: false,
          errorMessage: e.toString(),
        ));
      } else {
        final now = DateTime.now();
        emit(TransactionLoadedState(
          giaoDich: const [],
          totalIncome: 0,
          totalExpense: 0,
          ky: Ky.thang(now.year, now.month),
          isSubmitting: false,
          actionSuccess: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onUpdateTransaction(
    UpdateTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    // Cùng khuôn với thêm: trang sửa nghe `actionSuccess` để pop.
    final currState = state is TransactionLoadedState
        ? (state as TransactionLoadedState)
        : null;
    if (currState != null) {
      emit(currState.copyWith(isSubmitting: true, actionSuccess: null));
    }
    try {
      await transactionRepository.updateTransaction(event.before, event.after);
      syncEngine?.scheduleSync();
      _emitActionResult(emit, success: true);
    } catch (e) {
      _emitActionResult(emit, success: false, error: e.toString());
    }
  }

  void _emitActionResult(
    Emitter<TransactionState> emit, {
    required bool success,
    String? error,
  }) {
    if (state is TransactionLoadedState) {
      final curr = state as TransactionLoadedState;
      emit(curr.copyWith(
        isSubmitting: false,
        actionSuccess: success,
        errorMessage: error,
      ));
      return;
    }
    final now = DateTime.now();
    emit(TransactionLoadedState(
      giaoDich: const [],
      totalIncome: 0,
      totalExpense: 0,
      ky: Ky.thang(now.year, now.month),
      isSubmitting: false,
      actionSuccess: success,
      errorMessage: error,
    ));
  }

  Future<void> _onDeleteTransaction(
    DeleteTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      await transactionRepository.deleteTransaction(event.transaction);
      syncEngine?.scheduleSync();
    } catch (e) {
      if (state is TransactionLoadedState) {
        final curr = state as TransactionLoadedState;
        emit(curr.copyWith(errorMessage: e.toString()));
      }
    }
  }

  /// ⚠️ **Không** lọc lại danh sách theo kỳ ở đây. `watchKhoang` đã trả đúng
  /// `[ky.from, ky.to)`, nên lọc thêm một lần nữa là chép luật biên ra chỗ thứ
  /// hai — và hai bản chép sẽ trôi xa nhau. Bản cũ có phép lọc ấy vì nó nhận
  /// `(year, month)` rời nhau và không có gì bảo đảm chúng khớp truy vấn.
  void _emitLoadedState(
    List<TransactionEntity> giaoDich,
    Ky ky,
    Emitter<TransactionState> emit,
  ) {
    double income = 0;
    double expense = 0;
    for (final t in giaoDich) {
      if (t.type == 'thu') {
        income += t.amount;
      } else if (t.type == 'chi') {
        expense += t.amount;
      }
    }

    emit(TransactionLoadedState(
      giaoDich: giaoDich,
      totalIncome: income,
      totalExpense: expense,
      ky: ky,
    ));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
