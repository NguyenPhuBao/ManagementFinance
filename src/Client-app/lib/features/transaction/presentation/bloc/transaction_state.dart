import 'package:equatable/equatable.dart';
import '../../../analytics/domain/pham_vi_ky.dart';
import '../../data/models/transaction_entity.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitialState extends TransactionState {}

class TransactionLoadingState extends TransactionState {}

class TransactionLoadedState extends TransactionState {
  /// Giao dịch của kỳ đang xem. **Một** danh sách, không phải hai.
  ///
  /// Bản cũ có cả `transactions` lẫn `monthlyTransactions`, trong đó cái sau là
  /// bản lọc lại của cái trước theo `(year, month)` — thừa, vì DAO đã trả đúng
  /// tháng. Đo ngày 2026-09-21 trước khi gộp: **không nơi nào đọc
  /// `transactions`**, trang chỉ dùng `monthlyTransactions`.
  final List<TransactionEntity> giaoDich;

  final double totalIncome;
  final double totalExpense;

  /// Kỳ đang xem. Thay cặp `selectedYear` + `selectedMonth` ngày 2026-09-21.
  final Ky ky;

  final bool isSubmitting;
  final bool? actionSuccess;
  final String? errorMessage;

  const TransactionLoadedState({
    required this.giaoDich,
    required this.totalIncome,
    required this.totalExpense,
    required this.ky,
    this.isSubmitting = false,
    this.actionSuccess,
    this.errorMessage,
  });

  TransactionLoadedState copyWith({
    List<TransactionEntity>? giaoDich,
    double? totalIncome,
    double? totalExpense,
    Ky? ky,
    bool? isSubmitting,
    bool? actionSuccess,
    String? errorMessage,
  }) {
    return TransactionLoadedState(
      giaoDich: giaoDich ?? this.giaoDich,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      ky: ky ?? this.ky,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionSuccess: actionSuccess,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        giaoDich,
        totalIncome,
        totalExpense,
        ky,
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
