import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/sync/sync_engine.dart';
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
    on<DeleteTransactionEvent>(_onDeleteTransaction);
    on<FilterMonthEvent>(_onFilterMonth);
  }

  Future<void> _onLoadTransactions(
    LoadTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoadingState());
    await _subscription?.cancel();
    _subscription = transactionRepository
        .watchTransactions(event.idaccount)
        .listen((list) {
      add(TransactionsUpdatedEvent(list));
    });
  }

  void _onTransactionsUpdated(
    TransactionsUpdatedEvent event,
    Emitter<TransactionState> emit,
  ) {
    final now = DateTime.now();
    final year = state is TransactionLoadedState
        ? (state as TransactionLoadedState).selectedYear
        : now.year;
    final month = state is TransactionLoadedState
        ? (state as TransactionLoadedState).selectedMonth
        : now.month;

    _emitLoadedState(event.transactions, year, month, emit);
  }

  void _onFilterMonth(
    FilterMonthEvent event,
    Emitter<TransactionState> emit,
  ) {
    if (state is TransactionLoadedState) {
      final curr = state as TransactionLoadedState;
      _emitLoadedState(curr.transactions, event.year, event.month, emit);
    }
  }

  Future<void> _onAddTransaction(
    AddTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    if (state is TransactionLoadedState) {
      final curr = state as TransactionLoadedState;
      emit(curr.copyWith(isSubmitting: true, actionSuccess: null));
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
      }
    } catch (e) {
      if (state is TransactionLoadedState) {
        final curr = state as TransactionLoadedState;
        emit(curr.copyWith(
          isSubmitting: false,
          actionSuccess: false,
          errorMessage: e.toString(),
        ));
      }
    }
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

  void _emitLoadedState(
    List<TransactionEntity> allTx,
    int year,
    int month,
    Emitter<TransactionState> emit,
  ) {
    final monthly = allTx.where((t) {
      return t.date.year == year && t.date.month == month;
    }).toList();

    double income = 0;
    double expense = 0;
    for (final t in monthly) {
      if (t.type == 'thu') {
        income += t.amount;
      } else if (t.type == 'chi') {
        expense += t.amount;
      }
    }

    emit(TransactionLoadedState(
      transactions: allTx,
      monthlyTransactions: monthly,
      totalIncome: income,
      totalExpense: expense,
      selectedYear: year,
      selectedMonth: month,
    ));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
