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
              (t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Stream theo dõi realtime theo idaccount
  Stream<List<Transaction>> watchAll(int idaccount) {
    return (select(transactions)
          ..where(
              (t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Stream tất cả giao dịch chưa xóa realtime (dùng cho fallback/Home)
  Stream<List<Transaction>> watchAllNonDeleted() {
    return (select(transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Stream giao dịch theo pattern ghi chú (dùng cho Mục tiêu tiết kiệm)
  Stream<List<Transaction>> watchByNotePattern(int idaccount, String pattern) {
    return (select(transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.idaccount.equals(idaccount) &
              t.note.like('%$pattern%'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Lọc theo ví
  Future<List<Transaction>> getByWallet(String walletId) {
    return (select(transactions)
          ..where(
              (t) => t.walletId.equals(walletId) & t.deletedAt.isNull())
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
              t.deletedAt.isNull() &
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
              t.deletedAt.isNull() &
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
    return (select(transactions)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null
                  ? const Constant(true)
                  : t.idaccount.equals(idaccount))))
        .get();
  }

  // ── WRITE ─────────────────────────────────────────────────────────────────

  Future<void> insert(TransactionsCompanion entry) async {
    await into(transactions).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markSynced(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      const TransactionsCompanion(
        syncStatus: Value('synced'),
        // Đẩy thành công thì xoá sạch dấu vết thất bại cũ — nếu không, bản ghi
        // vẫn mang syncBlockedUntil của lần hỏng trước và bị chặn oan.
        syncRetryCount: Value(0),
        syncError: Value(null),
        syncBlockedUntil: Value(null),
      ),
    );
  }

  /// Chặn bản ghi khỏi hàng đợi đẩy cho tới [until] sau một lần đẩy thất bại.
  ///
  /// KHÔNG bỏ trạng thái 'pending': hết hạn chặn là bản ghi tự quay lại hàng
  /// đợi. Xem chú thích ở định nghĩa bảng để biết vì sao không dùng
  /// syncStatus = 'failed'.
  Future<void> markSyncBlocked(String id, DateTime until, String error) async {
    final current =
        await (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }

  /// Ghi dữ liệu pull về — chỉ cập nhật cột có trong companion (xem chú thích
  /// ở CategoryDao.upsertAll). Tránh việc pull xoá mất walletTransfer,
  /// bankTranId, status, provider, images... vì mapper pull không gán chúng.
  Future<void> upsertAll(List<TransactionsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(transactions, entries);
    });
  }

  /// Cập nhật categoryId của transaction (dùng khi repair cat_food → UUID)
  Future<void> updateCategoryId(String transactionId, String? newCategoryId) async {
    await (update(transactions)..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        categoryId: Value(newCategoryId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Repair: cập nhật categoryId từ local seed (cat_food) sang UUID từ backend,
  /// sau đó mark pending để re-push.
  ///
  /// Truyền vào [resolveUuid]: hàm async nhận categoryId cũ → trả về UUID hợp lệ (hoặc null).
  /// Gọi sau khi categories được pull về đầy đủ từ backend.
  Future<int> repairPendingTransactionsCategoryId(
    Future<String?> Function(String? categoryId) resolveUuid,
  ) async {
    // Lấy tất cả PENDING transactions có categoryId dạng non-UUID (local seed)
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    final pending = await (select(transactions)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              t.categoryId.isNotNull() &
              t.deletedAt.isNull()))
        .get();

    int repaired = 0;
    for (final tx in pending) {
      if (tx.categoryId == null) continue;
      if (uuidRegex.hasMatch(tx.categoryId!)) continue; // đã là UUID → bỏ qua
      // categoryId là dạng 'cat_food' → resolve sang UUID
      final uuid = await resolveUuid(tx.categoryId);
      if (uuid == null) continue;
      await updateCategoryId(tx.id, uuid);
      repaired++;
    }
    return repaired;
  }
}
