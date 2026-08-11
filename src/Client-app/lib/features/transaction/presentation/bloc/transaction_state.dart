import 'package:equatable/equatable.dart';
import '../../data/models/transaction_entity.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitialState extends TransactionState {}

class TransactionLoadingState extends TransactionState {}

class TransactionLoadedState extends TransactionState {
  final List<TransactionEntity> transactions;
  final List<TransactionEntity> monthlyTransactions;
  final double totalIncome;
  final double totalExpense;
  final int selectedYear;
  final int selectedMonth;
  final bool isSubmitting;
  final bool? actionSuccess;
  final String? errorMessage;

  const TransactionLoadedState({
    required this.transactions,
    required this.monthlyTransactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.selectedYear,
    required this.selectedMonth,
    this.isSubmitting = false,
    this.actionSuccess,
    this.errorMessage,
  });

  TransactionLoadedState copyWith({
    List<TransactionEntity>? transactions,
    List<TransactionEntity>? monthlyTransactions,
    double? totalIncome,
    double? totalExpense,
    int? selectedYear,
    int? selectedMonth,
    bool? isSubmitting,
    bool? actionSuccess,
    String? errorMessage,
  }) {
    return TransactionLoadedState(
      transactions: transactions ?? this.transactions,
      monthlyTransactions: monthlyTransactions ?? this.monthlyTransactions,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionSuccess: actionSuccess,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        transactions,
        monthlyTransactions,
        totalIncome,
        totalExpense,
        selectedYear,
        selectedMonth,
        isSubmitting,
        actionSuccess,
        errorMessage,
      ];
}

class TransactionErrorState extends TransactionState {
  final String message;
  const TransactionErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
