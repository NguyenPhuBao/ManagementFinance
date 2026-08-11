import '../../../../core/database/daos/wallet_dao.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/transaction_local_data_source.dart';
import '../models/transaction_entity.dart';

abstract class TransactionRepository {
  Stream<List<TransactionEntity>> watchTransactionsByMonth(
    int idaccount,
    int year,
    int month,
  );
  Future<void> addTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  });
  Future<void> deleteTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  });
}

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDataSource localDataSource;
  final WalletDao walletDao;
  final SyncEngine syncEngine;

  TransactionRepositoryImpl({
    required this.localDataSource,
    required this.walletDao,
    required this.syncEngine,
  });

  @override
  Stream<List<TransactionEntity>> watchTransactionsByMonth(
    int idaccount,
    int year,
    int month,
  ) {
    return localDataSource.watchTransactionsByMonth(idaccount, year, month);
  }

  @override
  Future<void> addTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  }) async {
    // 1. Insert transaction into local SQLite DB
    await localDataSource.addTransaction(transaction);

    // 2. Adjust wallet balances based on transaction type
    if (transaction.type == 'chi') {
      final w = await walletDao.getById(transaction.walletId);
      if (w != null) {
        await walletDao.updateBalance(w.id, w.balance - transaction.amount);
      }
    } else if (transaction.type == 'thu') {
      final w = await walletDao.getById(transaction.walletId);
      if (w != null) {
        await walletDao.updateBalance(w.id, w.balance + transaction.amount);
      }
    } else if (transaction.type == 'transfer' && destinationWalletId != null) {
      final srcW = await walletDao.getById(transaction.walletId);
      final destW = await walletDao.getById(destinationWalletId);
      if (srcW != null) {
        await walletDao.updateBalance(srcW.id, srcW.balance - transaction.amount);
      }
      if (destW != null) {
        await walletDao.updateBalance(destW.id, destW.balance + transaction.amount);
      }
    }

    // 3. Schedule background sync
    syncEngine.scheduleSync();
  }

  @override
  Future<void> deleteTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  }) async {
    // 1. Soft delete transaction in local DB
    await localDataSource.deleteTransaction(transaction.id);

    // 2. Reverse wallet balance adjustment
    if (transaction.type == 'chi') {
      final w = await walletDao.getById(transaction.walletId);
      if (w != null) {
        await walletDao.updateBalance(w.id, w.balance + transaction.amount);
      }
    } else if (transaction.type == 'thu') {
      final w = await walletDao.getById(transaction.walletId);
      if (w != null) {
        await walletDao.updateBalance(w.id, w.balance - transaction.amount);
      }
    } else if (transaction.type == 'transfer' && destinationWalletId != null) {
      final srcW = await walletDao.getById(transaction.walletId);
      final destW = await walletDao.getById(destinationWalletId);
      if (srcW != null) {
        await walletDao.updateBalance(srcW.id, srcW.balance + transaction.amount);
      }
      if (destW != null) {
        await walletDao.updateBalance(destW.id, destW.balance - transaction.amount);
      }
    }

    // 3. Schedule background sync
    syncEngine.scheduleSync();
  }
}
