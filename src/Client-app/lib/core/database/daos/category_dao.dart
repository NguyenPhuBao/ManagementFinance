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
        .watch()
        .map((list) {
      // Khử trùng lặp theo tên — ưu tiên giữ bản có UUID hợp lệ từ backend
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      final Map<String, Category> uniqueMap = {};
      for (final cat in list) {
        final key = cat.name.trim().toLowerCase();
        final existing = uniqueMap[key];
        if (existing == null) {
          uniqueMap[key] = cat;
        } else if (uuidRegex.hasMatch(cat.id) && !uuidRegex.hasMatch(existing.id)) {
          // Ưu tiên bản UUID (từ backend) hơn bản seed cục bộ
          uniqueMap[key] = cat;
        }
      }
      return uniqueMap.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  Future<List<Category>> getCategoryRows(int accountId, String classify) async {
    final list = await (select(categories)
          ..where((t) =>
              (t.idaccount.equals(0) | t.idaccount.equals(accountId)) &
              t.classify.equals(classify) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.idaccount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();

    // Khử trùng lặp theo tên — ưu tiên giữ bản có UUID hợp lệ từ backend
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    final Map<String, Category> uniqueMap = {};
    for (final cat in list) {
      final key = cat.name.trim().toLowerCase();
      final existing = uniqueMap[key];
      if (existing == null) {
        uniqueMap[key] = cat;
      } else if (uuidRegex.hasMatch(cat.id) && !uuidRegex.hasMatch(existing.id)) {
        uniqueMap[key] = cat;
      }
    }
    return uniqueMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Danh mục do CHÍNH tài khoản này tạo và chưa bị xoá — dùng để xét trùng tên.
  ///
  /// Quy tắc: tên là duy nhất trong phạm vi tài khoản, **bất kể `classify`** và
  /// **bất kể nằm trong nhóm nào**; nhóm và danh mục con dùng chung một không
  /// gian tên. Danh mục mặc định là không gian tên RIÊNG nên bị loại khỏi đây.
  ///
  /// Cố ý KHÔNG dùng `getCategoryRows`: hàm đó lọc sẵn theo `classify` và còn
  /// khử trùng lặp theo tên trước khi trả về — tức chính những hàng cần đối
  /// chiếu lại bị nó loại đi, khiến phép kiểm tra báo "không trùng" nhầm.
  Future<List<Category>> getOwnedForNameCheck(int accountId) {
    return (select(categories)
          ..where((t) =>
              t.idaccount.equals(accountId) &
              t.isDefault.equals(false) &
              t.isDeleted.equals(false) &
              t.deletedAt.isNull()))
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
  /// Không bao gồm category `isLocalOnly` — đó là nhóm danh mục và các danh mục
  /// nằm trong nhóm; chúng mang dữ liệu chỉ có ở client (parentId/isGroup) mà
  /// backend không mô hình hoá, nên không được đẩy lên.
  Future<List<Category>> getSyncableCategories(int accountId) {
    return (select(categories)
          ..where((t) =>
              t.idaccount.equals(accountId) &
              t.syncStatus.equals('pending') &
              t.isLocalOnly.equals(false)))
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

  /// Ghi dữ liệu pull về. Dùng `insertAllOnConflictUpdate` (INSERT ... ON
  /// CONFLICT DO UPDATE) để CHỈ cập nhật những cột có mặt trong companion.
  /// KHÔNG dùng `insertOrReplace`: nó thay cả hàng, nên mọi cột không được gán
  /// (parentId, isGroup, syncStatus, ...) sẽ bị đưa về mặc định — từng làm mất
  /// sạch cấu trúc nhóm danh mục sau mỗi lần pull.
  Future<void> upsertAll(List<CategoriesCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(categories, entries);
    });
  }

  Future<void> markSynced(String id) async {
    await (update(categories)..where((t) => t.id.equals(id))).write(
      const CategoriesCompanion(
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
        await (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        syncRetryCount: Value((current?.syncRetryCount ?? 0) + 1),
        syncError: Value(error),
        syncBlockedUntil: Value(until),
      ),
    );
  }

  Future<List<Category>> getPending([int? idaccount]) {
    return (select(categories)..where((t) => t.syncStatus.equals('pending'))).get();
  }

  Future<Category?> getById(String id) {
    return (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Tìm category cùng tên để ánh xạ category mặc định cục bộ sang UUID server.
  Future<List<Category>> getByName(String name) {
    return (select(categories)
          ..where((t) => t.name.equals(name) & t.deletedAt.isNull()))
        .get();
  }

  /// Xóa các category seed cục bộ (ID dạng 'cat_food') khi đã có bản UUID
  /// tương ứng từ backend (cùng tên + classify + isDefault).
  /// Gọi sau mỗi lần pull để dọn sạch duplicate.
  Future<void> removeDuplicateLocalSeedCategories() async {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    // Lấy tất cả default categories
    final all = await (select(categories)
          ..where((t) => t.isDefault.equals(true) & t.deletedAt.isNull()))
        .get();

    // Nhóm theo key (name + classify)
    final Map<String, List<Category>> groups = {};
    for (final cat in all) {
      final key = '${cat.classify}|${cat.name.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(cat);
    }

    // Với mỗi nhóm có > 1 bản: xóa bản non-UUID, giữ bản UUID
    for (final group in groups.values) {
      if (group.length <= 1) continue;
      final hasUuid = group.any((c) => uuidRegex.hasMatch(c.id));
      if (!hasUuid) continue;

      final toDelete = group.where((c) => !uuidRegex.hasMatch(c.id)).toList();
      for (final old in toDelete) {
        await (delete(categories)..where((t) => t.id.equals(old.id))).go();
      }
    }
  }
}
