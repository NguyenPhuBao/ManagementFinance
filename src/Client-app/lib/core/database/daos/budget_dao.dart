import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/other_tables.dart';

part 'budget_dao.g.dart';

// ─── Budget DAO ───────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Budgets])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  Future<List<Budget>> getAll(int idaccount) {
    return (select(budgets)
          ..where((t) => t.idaccount.equals(idaccount) & t.idhousehold.isNull() & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<Budget>> watchAll(int idaccount) {
    return (select(budgets)
          ..where((t) => t.idaccount.equals(idaccount) & t.idhousehold.isNull() & t.deletedAt.isNull()))
        .watch();
  }

  Future<Budget?> getById(String id) {
    return (select(budgets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insert(BudgetsCompanion entry) async {
    await into(budgets).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Cập nhật một phần: chỉ ghi những cột có mặt trong [entry].
  ///
  /// Cố ý KHÔNG dùng `insert(..., insertOrReplace)` như [insert]: chế độ đó
  /// thay cả hàng nên mọi cột không gán bị đưa về mặc định — chính là cách
  /// cấu trúc nhóm danh mục từng bị xoá sạch sau mỗi lần pull.
  Future<void> updateBudget(String id, BudgetsCompanion entry) async {
    await (update(budgets)..where((t) => t.id.equals(id))).write(entry);
  }

  /// Ghi lại số đã chi tính từ bảng giao dịch.
  ///
  /// Cố ý KHÔNG đụng `syncStatus` lẫn `updatedAt`: giá trị này được suy ra từ
  /// dữ liệu đã có sẵn ở local chứ không phải người dùng sửa. Nếu đánh dấu
  /// `pending` ở đây thì mỗi lần mở trang ngân sách lại sinh một thao tác đẩy
  /// mới, và `updatedAt` nhảy lên sẽ khiến LWW cho client thắng oan trước một
  /// thay đổi thật từ máy khác.
  Future<void> updateSpent(String id, double spent) async {
    await (update(budgets)..where((t) => t.id.equals(id))).write(BudgetsCompanion(spent: Value(spent)));
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Chỉ cập nhật cột có trong companion (xem chú thích ở CategoryDao.upsertAll).
  Future<void> upsertAll(List<BudgetsCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(budgets, entries));
  }

  Future<List<Budget>> getPending([int? idaccount]) {
    return (select(budgets)
          ..where((t) =>
              t.syncStatus.equals('pending') &
              (idaccount == null ? const Constant(true) : t.idaccount.equals(idaccount))))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      const BudgetsCompanion(
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
    final current = await (select(budgets)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }
}
