import 'package:equatable/equatable.dart';
import '../../../analytics/domain/pham_vi_ky.dart';
import '../../data/models/transaction_entity.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactionsEvent extends TransactionEvent {
  final int idaccount;
  const LoadTransactionsEvent({required this.idaccount});

  @override
  List<Object?> get props => [idaccount];
}

class TransactionsUpdatedEvent extends TransactionEvent {
  final List<TransactionEntity> transactions;

  /// Kỳ mà [transactions] thuộc về. Đi kèm danh sách chứ không đọc lại từ
  /// state: stream cũ có thể phát nốt một lần sau khi người dùng đã đổi kỳ, và
  /// khi ấy danh sách phải mang theo kỳ của **chính nó**.
  final Ky ky;

  const TransactionsUpdatedEvent(this.transactions, {required this.ky});

  @override
  List<Object?> get props => [transactions, ky];
}

class AddTransactionEvent extends TransactionEvent {
  final TransactionEntity transaction;
  final String? destinationWalletId;

  const AddTransactionEvent({
    required this.transaction,
    this.destinationWalletId,
  });

  @override
  List<Object?> get props => [transaction, destinationWalletId];
}

class UpdateTransactionEvent extends TransactionEvent {
  final TransactionEntity before;
  final TransactionEntity after;

  const UpdateTransactionEvent({required this.before, required this.after});

  @override
  List<Object?> get props => [before, after];
}

class DeleteTransactionEvent extends TransactionEvent {
  final TransactionEntity transaction;
  const DeleteTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

/// Người dùng đổi kỳ đang xem — bằng mũi tên ‹ › hoặc bằng bộ chọn kỳ.
///
/// Thay `FilterMonthEvent(year, month)` ngày 2026-09-21, khi trang Sổ giao dịch
/// bỏ phép buộc-theo-tháng.
class ChonKyEvent extends TransactionEvent {
  final Ky ky;

  const ChonKyEvent(this.ky);

  @override
  List<Object?> get props => [ky];
}
