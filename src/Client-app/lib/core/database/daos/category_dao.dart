import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Lấy tất cả danh mục (khử trùng lặp theo tên)
  Future<List<Category>> getAll(int idaccount) async {
    final list = await (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.idaccount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();

    final Map<String, Category> uniqueMap = {};
    for (final cat in list) {
      final key = '${cat.classify}_${cat.name.trim().toLowerCase()}';
      uniqueMap.putIfAbsent(key, () => cat);
    }
    return uniqueMap.values.toList();
  }

  Stream<List<Category>> watchAll(int idaccount) {
    return (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.idaccount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch()
        .map((list) {
      final Map<String, Category> uniqueMap = {};
      for (final cat in list) {
        final key = '${cat.classify}_${cat.name.trim().toLowerCase()}';
        uniqueMap.putIfAbsent(key, () => cat);
      }
      return uniqueMap.values.toList();
    });
  }

  /// Lọc theo classify: 'thu' | 'chi' | 'vay_no' (khử trùng lặp theo tên)
  Future<List<Category>> getByClassify(int idaccount, String classify) async {
    final list = await (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.classify.equals(classify) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.idaccount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();

    final Map<String, Category> uniqueMap = {};
    for (final cat in list) {
      final key = cat.name.trim().toLowerCase();
      uniqueMap.putIfAbsent(key, () => cat);
    }
    return uniqueMap.values.toList();
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

  Future<List<Category>> getPending([int? idaccount]) {
    return (select(categories)..where((t) => t.syncStatus.equals('pending'))).get();
  }

  Future<Category?> getById(String id) {
    return (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();
  }
}
