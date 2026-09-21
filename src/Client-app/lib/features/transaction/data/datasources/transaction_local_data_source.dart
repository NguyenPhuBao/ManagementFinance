import '../../../../core/database/app_database.dart';
import '../models/transaction_entity.dart';

abstract class TransactionLocalDataSource {
  /// Giao dịch trong khoảng `[from, to)`. Biên `to` **mở** — xem
  /// `TransactionDao.watchKhoang`.
  Stream<List<TransactionEntity>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  );
  Future<void> addTransaction(TransactionEntity entity);
  Future<void> updateTransaction(TransactionEntity entity);
  Future<void> deleteTransaction(String id);
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final AppDatabase db;

  TransactionLocalDataSourceImpl(this.db);

  @override
  Stream<List<TransactionEntity>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  ) {
    return db.transactionDao.watchKhoang(idaccount, from, to).map(
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
