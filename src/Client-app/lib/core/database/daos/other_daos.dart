import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/other_tables.dart';

part 'other_daos.g.dart';

// ─── Budget DAO ───────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Budgets])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  Future<List<Budget>> getAll(int idaccount) {
    return (select(budgets)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Stream<List<Budget>> watchAll(int idaccount) {
    return (select(budgets)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false)))
        .watch();
  }

  Future<void> insert(BudgetsCompanion entry) async {
    await into(budgets).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> softDelete(String id) async {
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertAll(List<BudgetsCompanion> entries) async {
    await batch((b) => b.insertAll(budgets, entries, mode: InsertMode.insertOrReplace));
  }

  Future<List<Budget>> getPending(int idaccount) {
    return (select(budgets)
          ..where((t) => t.idaccount.equals(idaccount) & t.syncStatus.equals('pending')))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(budgets)..where((t) => t.id.equals(id))).write(
      const BudgetsCompanion(syncStatus: Value('synced')),
    );
  }
}

// ─── Bill DAO ─────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Bills])
class BillDao extends DatabaseAccessor<AppDatabase> with _$BillDaoMixin {
  BillDao(super.db);

  Future<List<Bill>> getAll(int idaccount) {
    return (select(bills)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .get();
  }

  Stream<List<Bill>> watchAll(int idaccount) {
    return (select(bills)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch();
  }

  /// Lấy hoá đơn sắp đến hạn (trong N ngày)
  Future<List<Bill>> getUpcoming(int idaccount, {int days = 7}) {
    final now = DateTime.now();
    final limit = now.add(Duration(days: days));
    return (select(bills)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.isDeleted.equals(false) &
              t.isPaid.equals(false) &
              t.dueDate.isSmallerOrEqualValue(limit)))
        .get();
  }

  Future<void> insert(BillsCompanion entry) async {
    await into(bills).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> markPaid(String id) async {
    await (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        isPaid: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    await (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertAll(List<BillsCompanion> entries) async {
    await batch((b) => b.insertAll(bills, entries, mode: InsertMode.insertOrReplace));
  }

  Future<List<Bill>> getPending(int idaccount) {
    return (select(bills)
          ..where((t) => t.idaccount.equals(idaccount) & t.syncStatus.equals('pending')))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(bills)..where((t) => t.id.equals(id))).write(
      const BillsCompanion(syncStatus: Value('synced')),
    );
  }
}

// ─── Goal DAO ─────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Future<List<Goal>> getAll(int idaccount) {
    return (select(goals)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]))
        .get();
  }

  Stream<List<Goal>> watchAll(int idaccount) {
    return (select(goals)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false)))
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

  Future<void> softDelete(String id) async {
    await (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertAll(List<GoalsCompanion> entries) async {
    await batch((b) => b.insertAll(goals, entries, mode: InsertMode.insertOrReplace));
  }

  Future<List<Goal>> getPending(int idaccount) {
    return (select(goals)
          ..where((t) => t.idaccount.equals(idaccount) & t.syncStatus.equals('pending')))
        .get();
  }

  Future<void> markSynced(String id) async {
    await (update(goals)..where((t) => t.id.equals(id))).write(
      const GoalsCompanion(syncStatus: Value('synced')),
    );
  }
}
