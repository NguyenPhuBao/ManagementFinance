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

  int? _currentIdAccount;

  Future<void> _onLoadTransactions(
    LoadTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    _currentIdAccount = event.idaccount;
    emit(TransactionLoadingState());
    final now = DateTime.now();
    _subscribeMonth(event.idaccount, now.year, now.month);
  }

  void _subscribeMonth(int idaccount, int year, int month) {
    _subscription?.cancel();
    _subscription = transactionRepository
        .watchTransactionsByMonth(idaccount, year, month)
        .listen((list) {
      add(TransactionsUpdatedEvent(list, year: year, month: month));
    });
  }

  void _onTransactionsUpdated(
    TransactionsUpdatedEvent event,
    Emitter<TransactionState> emit,
  ) {
    _emitLoadedState(event.transactions, event.year, event.month, emit);
  }

  void _onFilterMonth(
    FilterMonthEvent event,
    Emitter<TransactionState> emit,
  ) {
    if (_currentIdAccount != null) {
      _subscribeMonth(_currentIdAccount!, event.year, event.month);
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
          transactions: const [],
          monthlyTransactions: const [],
          totalIncome: 0,
          totalExpense: 0,
          selectedYear: now.year,
          selectedMonth: now.month,
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
          transactions: const [],
          monthlyTransactions: const [],
          totalIncome: 0,
          totalExpense: 0,
          selectedYear: now.year,
          selectedMonth: now.month,
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
