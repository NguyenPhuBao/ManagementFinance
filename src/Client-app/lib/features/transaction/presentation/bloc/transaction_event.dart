import 'package:equatable/equatable.dart';
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
  final int year;
  final int month;
  const TransactionsUpdatedEvent(this.transactions, {required this.year, required this.month});

  @override
  List<Object?> get props => [transactions, year, month];
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

class DeleteTransactionEvent extends TransactionEvent {
  final TransactionEntity transaction;
  const DeleteTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class FilterMonthEvent extends TransactionEvent {
  final int year;
  final int month;

  const FilterMonthEvent({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}
