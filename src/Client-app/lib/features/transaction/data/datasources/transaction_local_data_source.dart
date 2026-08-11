import '../../../../core/database/app_database.dart';
import '../models/transaction_entity.dart';

abstract class TransactionLocalDataSource {
  Future<List<TransactionEntity>> getTransactions(int idaccount);
  Stream<List<TransactionEntity>> watchTransactions(int idaccount);
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month);
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month);
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId});
  Future<void> deleteTransaction(TransactionEntity transaction);
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final AppDatabase db;

  TransactionLocalDataSourceImpl({required this.db});

  @override
  Future<List<TransactionEntity>> getTransactions(int idaccount) async {
    final list = await db.transactionDao.getAll(idaccount);
    return list.map((t) => TransactionEntity.fromDrift(t)).toList();
  }

  @override
  Stream<List<TransactionEntity>> watchTransactions(int idaccount) {
    return db.transactionDao
        .watchAll(idaccount)
        .map((list) => list.map((t) => TransactionEntity.fromDrift(t)).toList());
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByMonth(int idaccount, int year, int month) async {
    final list = await db.transactionDao.getByMonth(idaccount, year, month);
    return list.map((t) => TransactionEntity.fromDrift(t)).toList();
  }

  @override
  Future<Map<String, double>> getSummaryByMonth(int idaccount, int year, int month) {
    return db.transactionDao.getSummaryByMonth(idaccount, year, month);
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction, {String? destinationWalletId}) async {
    await db.transaction(() async {
      await db.transactionDao.insert(transaction.toCompanion());

      final wallet = await db.walletDao.getById(transaction.walletId);
      if (wallet != null) {
        double newBalance = wallet.balance;
        if (transaction.type == 'chi') {
          newBalance -= transaction.amount;
        } else if (transaction.type == 'thu') {
          newBalance += transaction.amount;
        } else if (transaction.type == 'transfer' && destinationWalletId != null) {
          newBalance -= transaction.amount;
          final destWallet = await db.walletDao.getById(destinationWalletId);
          if (destWallet != null) {
            await db.walletDao.updateBalance(
              destinationWalletId,
              destWallet.balance + transaction.amount,
            );
          }
        }
        await db.walletDao.updateBalance(transaction.walletId, newBalance);
      }
    });
  }

  @override
  Future<void> deleteTransaction(TransactionEntity transaction) async {
    await db.transaction(() async {
      await db.transactionDao.softDelete(transaction.id);

      final wallet = await db.walletDao.getById(transaction.walletId);
      if (wallet != null) {
        double newBalance = wallet.balance;
        if (transaction.type == 'chi') {
          newBalance += transaction.amount;
        } else if (transaction.type == 'thu') {
          newBalance -= transaction.amount;
        }
        await db.walletDao.updateBalance(transaction.walletId, newBalance);
      }
    });
  }
}
