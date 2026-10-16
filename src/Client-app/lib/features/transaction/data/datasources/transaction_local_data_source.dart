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

  /// Mọi giao dịch của tài khoản (bỏ hàng `deletedAt`, mới nhất trước) — `transactionDao.getAll`.
  Future<List<TransactionEntity>> getAll(int idaccount);

  /// Như [getAll], dạng stream — `transactionDao.watchAll`.
  Stream<List<TransactionEntity>> watchAll(int idaccount);
  Future<void> addTransaction(TransactionEntity entity);

  /// A5 mục 11.4 — N hàng trong MỘT giao tác: hỏng giữa chừng thì không hàng nào được ghi.
  Future<void> addTransactions(List<TransactionEntity> entities);
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
  Future<List<TransactionEntity>> getAll(int idaccount) async =>
      (await db.transactionDao.getAll(idaccount)).map(TransactionEntity.fromDrift).toList();

  @override
  Stream<List<TransactionEntity>> watchAll(int idaccount) => db.transactionDao
      .watchAll(idaccount)
      .map((list) => list.map(TransactionEntity.fromDrift).toList());

  @override
  Future<void> addTransaction(TransactionEntity entity) async {
    await db.transactionDao.insert(entity.toCompanion());
  }

  @override
  Future<void> addTransactions(List<TransactionEntity> entities) => db.transaction(() async {
        for (final e in entities) {
          await db.transactionDao.insert(e.toCompanion());
        }
      });

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
