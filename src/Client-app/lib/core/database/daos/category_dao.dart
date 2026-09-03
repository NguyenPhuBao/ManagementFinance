import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../../category/category_name.dart';
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
      final key = '${cat.classify}_${normalizeCategoryName(cat.name)}';
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
        final key = '${cat.classify}_${normalizeCategoryName(cat.name)}';
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
        final key = normalizeCategoryName(cat.name);
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
      final key = normalizeCategoryName(cat.name);
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

  /// Mọi danh mục đang CHIẾM CHỖ tên trong phạm vi một tài khoản.
  ///
  /// Gồm danh mục do chính tài khoản tạo **và** danh mục mặc định (dùng chung,
  /// `idaccount = 0`): người dùng nhìn thấy cả hai trong cùng một danh sách nên
  /// hai mục trùng tên là không phân biệt được. Hàng đã xoá mềm không chiếm chỗ.
  ///
  /// Quy tắc: tên là duy nhất trong phạm vi này, **bất kể `classify`** và
  /// **bất kể nằm trong nhóm nào**; nhóm và danh mục con dùng chung không gian
  /// tên.
  ///
  /// Cố ý KHÔNG dùng `getCategoryRows`: hàm đó lọc sẵn theo `classify` và còn
  /// khử trùng lặp theo tên trước khi trả về — tức chính những hàng cần đối
  /// chiếu lại bị nó loại đi, khiến phép kiểm tra báo "không trùng" nhầm.
  Future<List<Category>> getNamesInUse(int accountId) {
    return (select(categories)
          ..where((t) =>
              (t.idaccount.equals(accountId) | t.isDefault.equals(true)) &
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
      final key = normalizeCategoryName(cat.name);
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

  /// Tìm danh mục theo TÊN, so khớp qua [normalizeCategoryName].
  ///
  /// Dùng ở `_resolveCategoryId` để ánh xạ danh mục mặc định cục bộ (id dạng
  /// `cat_food`) sang UUID tương ứng của backend. Trước đây so bằng
  /// `t.name.equals(name)` — phân biệt hoa/thường và không gộp dạng Unicode —
  /// nên chỉ cần lệch một chữ hoa hay một dạng dấu là ánh xạ thất bại,
  /// `_resolveCategoryId` trả `null`, và giao dịch bị hoãn đẩy VĨNH VIỄN mà
  /// không có lỗi nào báo ra. Đúng lớp lỗi 11.4 / 11.6 trong PROJECT_CONTEXT.
  ///
  /// Lọc trong Dart chứ không trong SQL vì phép chuẩn hoá có bước NFC mà
  /// SQLite không có sẵn. Bảng danh mục chỉ cỡ vài chục dòng nên không đáng kể.
  Future<List<Category>> getByName(String name) async {
    final target = normalizeCategoryName(name);
    final rows =
        await (select(categories)..where((t) => t.deletedAt.isNull())).get();
    return rows
        .where((c) => normalizeCategoryName(c.name) == target)
        .toList();
  }

  /// Xóa các category seed cục bộ (ID dạng 'cat_food') khi đã có bản UUID
  /// tương ứng từ backend (cùng tên + classify + isDefault).
  /// Gọi sau mỗi lần pull để dọn sạch duplicate.
  /// Gộp danh mục **người dùng** bị trùng tên: bản cục bộ chưa từng lên server
  /// được nhập vào bản mà server đã có, rồi xoá hẳn.
  ///
  /// ## Vì sao cần (G14)
  ///
  /// Bản client trước 2026-09-04 tạo 5 danh mục cá nhân **trước** lần pull đầu
  /// tiên. Trên một máy mới, SQLite còn rỗng nên phép kiểm trùng không thấy gì
  /// và nó sinh ra bản trùng tên với bản tài khoản đã có trên backend. Đẩy lên
  /// thì vi phạm quy tắc trùng tên, `/sync/push` trả `failed` kèm message rỗng,
  /// client xếp vào `transient` và **thử lại vĩnh viễn** — mọi chu kỳ đồng bộ
  /// kết thúc hỏng và giãn cách luỹ tiến kéo chậm mọi thay đổi khác.
  ///
  /// Bản vá ở `PersonalDefaultCategories` chỉ ngăn phát sinh mới. Hàm này dọn
  /// nốt cho máy đã lỡ tạo, để nó tự thoát mà không phải cài lại app.
  ///
  /// ## Ba ràng buộc an toàn
  ///
  /// - **Chỉ xoá bản `pending`.** Bản `synced` đã tồn tại ở nơi khác; xoá nó là
  ///   xoá dữ liệu thật của người dùng.
  /// - **Phải có đúng một bản `synced` làm nơi nhập vào.** Cả nhóm đều `pending`
  ///   thì không có bằng chứng bản nào là bản thật — để nguyên.
  /// - **Repoint TRƯỚC, xoá SAU.** Đảo lại thì giao dịch trỏ vào một hàng không
  ///   còn tồn tại — đúng lỗi 11.6.
  ///
  /// Xoá **vật lý** chứ không xoá mềm: bản này chưa từng lên server nên không có
  /// gì để đồng bộ, còn xoá mềm sẽ để lại một thao tác đẩy vô nghĩa.
  ///
  /// Trả về số bản đã gộp.
  Future<int> mergeDuplicatePersonalCategories(int idaccount) async {
    if (idaccount <= 0) return 0;

    final rows = await (select(categories)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.isDefault.equals(false) &
              t.isDeleted.equals(false) &
              t.deletedAt.isNull()))
        .get();

    // Gom theo tên đã chuẩn hoá — KHÔNG tính `classify`. Quy tắc trùng tên của
    // dự án không có `classify` trong khoá, nên gom theo cặp (tên, classify) sẽ
    // bỏ sót đúng những bản backend từ chối.
    final byName = <String, List<Category>>{};
    for (final c in rows) {
      byName.putIfAbsent(normalizeCategoryName(c.name), () => []).add(c);
    }

    var merged = 0;
    for (final group in byName.values) {
      if (group.length <= 1) continue;

      Category? keeper;
      for (final c in group) {
        if (c.syncStatus == 'synced') {
          keeper = c;
          break;
        }
      }
      if (keeper == null) continue;

      // Có từ hai bản `synced` trở lên nghĩa là dữ liệu backend tự nó đã trùng
      // — chuyện của backend, client xoá bên nào cũng là xoá dữ liệu thật.
      final syncedCount = group.where((c) => c.syncStatus == 'synced').length;
      if (syncedCount > 1) continue;

      for (final victim in group) {
        if (victim.id == keeper.id) continue;
        if (victim.syncStatus != 'pending') continue;
        await _absorbCategory(idaccount, victim.id, keeper.id);
        merged++;
      }
    }
    return merged;
  }

  /// Chuyển mọi thứ đang trỏ vào [fromId] sang [toId] rồi xoá hẳn [fromId].
  Future<void> _absorbCategory(int idaccount, String fromId, String toId) async {
    // Giao dịch / ngân sách / hoá đơn — dùng lại đường đã có.
    await attachedDatabase.repointCategoryReferences(
      idaccount: idaccount,
      fromCategoryId: fromId,
      toCategoryId: toId,
    );

    await transaction(() async {
      // Danh mục con đang coi bản bị xoá là nhóm cha. Bỏ sót thì cây danh mục
      // đứt ở giữa vì `parentId` trỏ vào một hàng đã bị xoá vật lý.
      await (update(categories)
            ..where((t) =>
                t.idaccount.equals(idaccount) & t.parentId.equals(fromId)))
          .write(CategoriesCompanion(
        parentId: Value(toId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ));

      // Từ khoá là chữ người dùng gõ tay — chuyển sang chứ không vứt. Bỏ những
      // từ bên đích đã có, vì `(idaccount, categoryId, normalizedKeyword)` là
      // khoá duy nhất và chèn trùng sẽ vỡ.
      final daCo = await (select(categoryKeywords)
            ..where((t) =>
                t.idaccount.equals(idaccount) & t.categoryId.equals(toId)))
          .get();
      final daCoSet = daCo.map((k) => k.normalizedKeyword).toSet();

      final cuaVictim = await (select(categoryKeywords)
            ..where((t) =>
                t.idaccount.equals(idaccount) & t.categoryId.equals(fromId)))
          .get();
      for (final k in cuaVictim) {
        if (daCoSet.contains(k.normalizedKeyword)) continue;
        await (update(categoryKeywords)..where((t) => t.id.equals(k.id)))
            .write(CategoryKeywordsCompanion(
          categoryId: Value(toId),
          updatedAt: Value(DateTime.now()),
        ));
      }
      await (delete(categoryKeywords)
            ..where((t) =>
                t.idaccount.equals(idaccount) & t.categoryId.equals(fromId)))
          .go();

      // Quan hệ nhóm chỉ tồn tại ở máy này (chưa đồng bộ được, xem G10) và bản
      // bị xoá cũng chỉ ở máy này — xoá theo, không có gì để giữ.
      await (delete(categoryGroupMemberships)
            ..where((t) =>
                t.idaccount.equals(idaccount) &
                (t.groupId.equals(fromId) | t.categoryId.equals(fromId))))
          .go();

      await (delete(categories)..where((t) => t.id.equals(fromId))).go();
    });
  }

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
      final key = '${cat.classify}|${normalizeCategoryName(cat.name)}';
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
