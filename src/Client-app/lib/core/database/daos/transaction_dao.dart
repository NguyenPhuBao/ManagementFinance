import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  // ── READ ──────────────────────────────────────────────────────────────────

  /// Lấy tất cả giao dịch của user (mới nhất trước)
  Future<List<Transaction>> getAll(int idaccount) {
    return (select(transactions)
          ..where(
              (t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Stream theo dõi realtime theo idaccount
  Stream<List<Transaction>> watchAll(int idaccount) {
    return (select(transactions)
          ..where(
              (t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Stream tất cả giao dịch chưa xóa realtime (dùng cho fallback/Home)
  Stream<List<Transaction>> watchAllNonDeleted() {
    return (select(transactions)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Stream giao dịch theo pattern ghi chú (dùng cho Mục tiêu tiết kiệm)
  Stream<List<Transaction>> watchByNotePattern(int idaccount, String pattern) {
    return (select(transactions)
          ..where((t) =>
              t.isDeleted.equals(false) &
              t.note.like('%$pattern%'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Lọc theo ví
  Future<List<Transaction>> getByWallet(String walletId) {
    return (select(transactions)
          ..where(
              (t) => t.walletId.equals(walletId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Lọc theo khoảng thời gian
  Future<List<Transaction>> getByDateRange(
    int idaccount,
    DateTime from,
    DateTime to,
  ) {
    return (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.isDeleted.equals(false) &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Lọc theo tháng (dùng cho trang Home và Analytics)
  Future<List<Transaction>> getByMonth(int idaccount, int year, int month) {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);
    return getByDateRange(idaccount, from, to);
  }

  /// Stream lọc theo tháng realtime
  Stream<List<Transaction>> watchByMonth(int idaccount, int year, int month) {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);
    return (select(transactions)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.isDeleted.equals(false) &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Tổng thu/chi theo tháng
  Future<Map<String, double>> getSummaryByMonth(
    int idaccount,
    int year,
    int month,
  ) async {
    final list = await getByMonth(idaccount, year, month);
    double income = 0, expense = 0;
    for (final t in list) {
      if (t.type == 'thu') {
        income += t.amount;
      } else if (t.type == 'chi') {
        expense += t.amount;
      }
    }
    return {'income': income, 'expense': expense};
  }

  /// Pending sync records
  Future<List<Transaction>> getPending([int? idaccount]) {
    return (select(transactions)..where((t) => t.syncStatus.equals('pending')))
        .get();
  }

  // ── WRITE ─────────────────────────────────────────────────────────────────

  Future<void> insert(TransactionsCompanion entry) async {
    await into(transactions).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> softDelete(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markSynced(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      const TransactionsCompanion(syncStatus: Value('synced')),
    );
  }

  Future<void> upsertAll(List<TransactionsCompanion> entries) async {
    await batch((b) {
      b.insertAll(transactions, entries, mode: InsertMode.insertOrReplace);
    });
  }
}
