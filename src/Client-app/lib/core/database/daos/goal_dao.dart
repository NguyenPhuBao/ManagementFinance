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
          ..where((t) => t.idaccount.equals(idaccount) & t.idhousehold.isNull() & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .get();
  }

  Stream<List<Goal>> watchAll(int idaccount) {
    return (select(goals)..where((t) => t.idaccount.equals(idaccount) & t.idhousehold.isNull() & t.deletedAt.isNull()))
        .watch();
  }

  /// Mục tiêu chung sống của nhà, do ai đặt cũng vậy (`docs/Family/03`).
  Future<List<Goal>> getCuaNha(int idNha) =>
      (select(goals)..where((t) => t.idhousehold.equals(idNha) & t.deletedAt.isNull())).get();

  Stream<List<Goal>> watchCuaNha(int idNha) =>
      (select(goals)..where((t) => t.idhousehold.equals(idNha) & t.deletedAt.isNull())).watch();

  /// Mục tiêu chung đang sống của ví. Có thể hai hàng khi hai máy Chủ cùng bật offline: lấy hàng mới nhất.
  Future<Goal?> getSongTheoVi(String walletId) => (select(goals)
        ..where((t) => t.walletId.equals(walletId) & t.idhousehold.isNotNull() & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
        ..limit(1))
      .getSingleOrNull();

  /// Hàng đã tắt mà lệnh xoá chưa lên server. Server chạy lệnh tạo trước lệnh xoá trong một lô, nên bật lại phải hồi sinh hàng
  /// này thay vì tạo hàng mới: hàng mới vướng `uq_goal_household_wallet_active`.
  Future<Goal?> getXoaChuaDayTheoVi(String walletId) => (select(goals)
        ..where((t) =>
            t.walletId.equals(walletId) &
            t.idhousehold.isNotNull() &
            t.deletedAt.isNotNull() &
            t.syncStatus.equals('pending'))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
        ..limit(1))
      .getSingleOrNull();

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
    await (update(goals)..where((t) => t.id.equals(entry.id.value))).write(entry);
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

  /// Ghi mục tiêu kéo về, GIỮ thay đổi còn chờ đẩy của hàng thuộc NHÀ (khuôn `TransactionDao.upsertKeoVe`). Chủ bấm *Bỏ mục
  /// tiêu* hay đổi số tiền đúng lúc một lượt kéo đang bay (hoặc lượt đẩy hỏng mà lượt kéo tốt): bản server ghi đè là mục tiêu
  /// sống lại / số cũ quay về, kèm `synced` — lệnh của Chủ mất im lặng. Hàng nhà `pending` ở lại, lượt đẩy sau mang nó đi.
  /// Mục tiêu RIÊNG không đổi hành vi (ghi đè không điều kiện như trước).
  ///
  /// Đọc và ghi cùng một giao tác; giao trong Dart, không `isIn` theo lô (lô dài hơn trần tham số SQLite thì ném). Trả số hàng
  /// được giữ lại.
  Future<int> upsertKeoVe(List<GoalsCompanion> entries) => transaction(() async {
        final nhaChoDay = {
          for (final h in await (select(goals)
                ..where((t) => t.idhousehold.isNotNull() & t.syncStatus.equals('pending')))
              .get())
            h.id,
        };
        final ghi = [
          for (final c in entries)
            if (!nhaChoDay.contains(c.id.value)) c,
        ];
        await upsertAll(ghi);
        return entries.length - ghi.length;
      });

  /// [idhousehold]: nhà đang ở — thêm hàng của nhà do người khác ghi (spec gia đình 2026-11-01 mục 7.1).
  Future<List<Goal>> getPending([int? idaccount, int? idhousehold]) {
    return (select(goals)
          ..where((t) {
            final cuaToi = idaccount == null ? const Constant(true) : t.idaccount.equals(idaccount);
            final phamVi = idhousehold == null ? cuaToi : (cuaToi | t.idhousehold.equals(idhousehold));
            return t.syncStatus.equals('pending') & phamVi;
          }))
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
    final current = await (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }
}
