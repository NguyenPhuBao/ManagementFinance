import '../../../../core/database/app_database.dart';
import '../models/transaction_entity.dart';

abstract class TransactionLocalDataSource {
  Stream<List<TransactionEntity>> watchTransactionsByMonth(
    int idaccount,
    int year,
    int month,
  );
  Future<void> addTransaction(TransactionEntity entity);
  Future<void> updateTransaction(TransactionEntity entity);
  Future<void> deleteTransaction(String id);
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final AppDatabase db;

  TransactionLocalDataSourceImpl(this.db);

  @override
  Stream<List<TransactionEntity>> watchTransactionsByMonth(
    int idaccount,
    int year,
    int month,
  ) {
    return db.transactionDao
        .watchByMonth(idaccount, year, month)
        .map(
          (list) => list.map((t) => TransactionEntity.fromDrift(t)).toList(),
        );
  }

  @override
  Future<void> addTransaction(TransactionEntity entity) async {
    await db.transactionDao.insert(entity.toCompanion());
  }

  @override
  Future<void> updateTransaction(TransactionEntity entity) async {
    // `toCompanion()` mang đủ mọi cột kể cả syncStatus/updatedAt — repository
    // đã đặt chúng trước khi gọi tới đây.
    await db.transactionDao.updateRow(entity.id, entity.toCompanion());
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await db.transactionDao.softDelete(id);
  }
}
