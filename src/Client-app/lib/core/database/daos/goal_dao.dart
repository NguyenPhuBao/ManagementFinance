import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/other_tables.dart';

part 'goal_dao.g.dart';

// ─── Goal DAO ─────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Future<List<Goal>> getAll(int idaccount) {
    return (select(goals)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .get();
  }

  Future<List<Goal>> getAllNonDeleted() {
    return (select(goals)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .get();
  }

  Stream<List<Goal>> watchAll(int idaccount) {
    return (select(goals)
          ..where((t) => t.idaccount.equals(idaccount) & t.deletedAt.isNull()))
        .watch();
  }

  Stream<List<Goal>> watchAllNonDeleted() {
    return (select(goals)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .watch();
  }

  Future<Goal?> getById(String id) {
    return (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insert(GoalsCompanion entry) async {
    await into(goals).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateAmount(String id, double newAmount) async {
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        currentAmount: Value(newAmount),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Cập nhật CHỈ những cột có mặt trong [entry] — cùng lý do với
  /// `BillDao.updateFields`: [insert] là `insertOrReplace`, thay nguyên hàng.
  /// Nơi gọi: `GopViService` (G63) đổi ví của mục tiêu.
  Future<void> updateFields(GoalsCompanion entry) async {
    if (!entry.id.present) {
      throw ArgumentError('GoalsCompanion phải có id để biết cập nhật hàng nào');
    }
    await (update(goals)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Chỉ cập nhật cột có trong companion (xem chú thích ở CategoryDao.upsertAll).
  Future<void> upsertAll(List<GoalsCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(goals, entries));
  }

  Future<List<Goal>> getPending([int? idaccount]) {
    return (select(goals)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null ? const Constant(true) : t.idaccount.equals(idaccount))))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(goals)..where((t) => t.id.equals(id))).write(
      const GoalsCompanion(
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
        await (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }
}
