import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Lấy tất cả danh mục (default + của user)
  Future<List<Category>> getAll(int idaccount) {
    return (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Stream<List<Category>> watchAll(int idaccount) {
    return (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Lọc theo classify: 'thu' | 'chi' | 'vay_no'
  Future<List<Category>> getByClassify(int idaccount, String classify) {
    return (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.classify.equals(classify) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.isDefault)]))
        .get();
  }

  Future<void> insert(CategoriesCompanion entry) async {
    await into(categories).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> softDelete(String id) async {
    await (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertAll(List<CategoriesCompanion> entries) async {
    await batch((b) {
      b.insertAll(categories, entries, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> markSynced(String id) async {
    await (update(categories)..where((t) => t.id.equals(id))).write(
      const CategoriesCompanion(syncStatus: Value('synced')),
    );
  }

  Future<List<Category>> getPending(int idaccount) {
    return (select(categories)
          ..where((t) =>
              t.idaccount.equals(idaccount) & t.syncStatus.equals('pending')))
        .get();
  }
}
