import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [
  Categories,
  CategoryKeywords,
  CategoryGroupMemberships,
])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Lấy tất cả danh mục (khử trùng lặp theo tên)
  Future<List<Category>> getAll(int idaccount) async {
    final list = await (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.deletedAt.isNull())
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
              t.deletedAt.isNull())
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

  Stream<List<Category>> watchCategoryRows(int accountId, String classify) {
    return (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(accountId)) &
              t.classify.equals(classify) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.idaccount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<List<Category>> getCategoryRows(int accountId, String classify) {
    return (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(accountId)) &
              t.classify.equals(classify) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.idaccount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Future<List<String>> getKeywords(int accountId, String categoryId) async {
    final rows = await (select(categoryKeywords)
          ..where((t) =>
              t.idaccount.equals(accountId) & t.categoryId.equals(categoryId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map((row) => row.keyword).toList();
  }

  Future<void> replaceKeywords({
    required int accountId,
    required String categoryId,
    required Iterable<String> keywords,
    required DateTime now,
  }) {
    final uniqueKeywords = <String, String>{};
    for (final keyword in keywords) {
      final displayKeyword = keyword.trim();
      final normalizedKeyword = _normalizeKeyword(displayKeyword);
      if (normalizedKeyword.isNotEmpty) {
        uniqueKeywords.putIfAbsent(normalizedKeyword, () => displayKeyword);
      }
    }

    return transaction(() async {
      await (delete(categoryKeywords)
            ..where((t) =>
                t.idaccount.equals(accountId) & t.categoryId.equals(categoryId)))
          .go();
      if (uniqueKeywords.isEmpty) {
        return;
      }
      await batch((batch) {
        batch.insertAll(
          categoryKeywords,
          uniqueKeywords.entries
              .map(
                (entry) => CategoryKeywordsCompanion.insert(
                  id: const Uuid().v4(),
                  idaccount: accountId,
                  categoryId: categoryId,
                  keyword: entry.value,
                  normalizedKeyword: entry.key,
                  createdAt: now,
                  updatedAt: now,
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<List<CategoryGroupMembership>> getGroupMemberships(int accountId) {
    return (select(categoryGroupMemberships)
          ..where((t) => t.idaccount.equals(accountId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> replaceGroupMemberships({
    required int accountId,
    required String groupId,
    required Iterable<String> categoryIds,
    required DateTime now,
  }) async {
    final uniqueCategoryIds = categoryIds.toSet();

    await transaction(() async {
      await (delete(categoryGroupMemberships)
            ..where((t) =>
                t.idaccount.equals(accountId) & t.groupId.equals(groupId)))
          .go();
      if (uniqueCategoryIds.isEmpty) {
        return;
      }
      await (delete(categoryGroupMemberships)
            ..where((t) =>
                t.idaccount.equals(accountId) &
                t.categoryId.isIn(uniqueCategoryIds)))
          .go();
      await batch((batch) {
        batch.insertAll(
          categoryGroupMemberships,
          uniqueCategoryIds
              .map(
                (categoryId) => CategoryGroupMembershipsCompanion.insert(
                  id: const Uuid().v4(),
                  idaccount: accountId,
                  groupId: groupId,
                  categoryId: categoryId,
                  createdAt: now,
                  updatedAt: now,
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<void> removeGroupMemberships(int accountId, String groupId) async {
    await transaction(() async {
      await (delete(categoryGroupMemberships)
            ..where((t) =>
                t.idaccount.equals(accountId) & t.groupId.equals(groupId)))
          .go();
    });
  }

  /// Lấy tất cả category của user cần sync lên backend (syncStatus = 'pending')
  /// Bao gồm cả category đã xóa mềm (để backend cập nhật delete_at).
  /// Không bao gồm category hệ thống (idaccount = 0) vì backend đã có sẵn.
  Future<List<Category>> getSyncableCategories(int accountId) {
    return (select(categories)
          ..where((t) =>
              t.idaccount.equals(accountId) &
              t.syncStatus.equals('pending')))
        .get();
  }


  String _normalizeKeyword(String keyword) {
    return keyword.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Lọc theo classify: 'thu' | 'chi' | 'vay_no' (khử trùng lặp theo tên)
  Future<List<Category>> getByClassify(int idaccount, String classify) async {
    final list = await (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(idaccount)) &
              t.classify.equals(classify) &
              t.deletedAt.isNull())
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
    final now = DateTime.now();
    await (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
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
