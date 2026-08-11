import '../datasources/transaction_local_data_source.dart';
import '../models/transaction_entity.dart';

abstract class TransactionRepository {
  Future<List<TransactionEntity>> getTransactions(int idaccount);
  Stream<List<TransactionEntity>> watchTransactions(int idaccount);
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month);
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month);
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId});
  Future<void> deleteTransaction(TransactionEntity transaction);
}

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDataSource localDataSource;

  TransactionRepositoryImpl({required this.localDataSource});

  @override
  Future<List<TransactionEntity>> getTransactions(int idaccount) {
    return localDataSource.getTransactions(idaccount);
  }

  @override
  Stream<List<TransactionEntity>> watchTransactions(int idaccount) {
    return localDataSource.watchTransactions(idaccount);
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month) {
    return localDataSource.getTransactionsByMonth(idaccount, year, month);
  }

  @override
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month) {
    return localDataSource.getSummaryByMonth(idaccount, year, month);
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId}) {
    return localDataSource.addTransaction(transaction, destinationWalletId: destinationWalletId);
  }

  @override
  Future<void> deleteTransaction(TransactionEntity transaction) {
    return localDataSource.deleteTransaction(transaction);
  }
}
