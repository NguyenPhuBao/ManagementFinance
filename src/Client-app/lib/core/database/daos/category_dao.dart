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
              t.idaccount.equals(idaccount) &
              t.idhousehold.isNull() &
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
              t.idaccount.equals(idaccount) &
              t.idhousehold.isNull() &
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

  /// Khử trùng lặp theo tên — ưu tiên bản có UUID hợp lệ từ backend hơn bản seed cục bộ (`cat_food`…), rồi xếp theo tên.
  static List<Category> _khuTrungTheoTen(Iterable<Category> list) {
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
    return uniqueMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Hàng của [accountId] theo [classify] (chưa xoá) **và** MỌI hàng khuôn (kể cả đã xoá) trong MỘT truy vấn — luật *ẩn theo
  /// khuôn* (spec 2026-10-27 mục 4) cần khuôn; một truy vấn để stream phát lại khi khuôn đổi.
  SimpleSelectStatement<$CategoriesTable, Category> _hangKemKhuon(int accountId, String classify) => select(categories)
    ..where((t) =>
        (t.idaccount.equals(accountId) &
            t.idhousehold.isNull() &
            t.classify.equals(classify) &
            t.isDeleted.equals(false)) |
        t.isDefault.equals(true))
    ..orderBy([
      (t) => OrderingTerm.desc(t.idaccount),
      (t) => OrderingTerm.asc(t.name),
    ]);

  ({List<Category> rows, List<Category> khuon}) _tachKhuon(List<Category> list, int accountId, String classify) => (
        rows: _khuTrungTheoTen(
            list.where((c) => c.idaccount == accountId && c.idhousehold == null && c.classify == classify && !c.isDeleted)),
        khuon: [for (final c in list) if (c.isDefault) c],
      );

  /// ⚠️ Chỉ `features/category/data/danh_sach_chon_danh_muc.dart` được gọi (test quét 40) — nơi bỏ bản sao ẩn theo khuôn.
  Stream<({List<Category> rows, List<Category> khuon})> watchCategoryRows(int accountId, String classify) =>
      _hangKemKhuon(accountId, classify).watch().map((list) => _tachKhuon(list, accountId, classify));

  /// ⚠️ Chỉ `features/category/data/danh_sach_chon_danh_muc.dart` được gọi (test quét 40).
  Future<({List<Category> rows, List<Category> khuon})> getCategoryRows(int accountId, String classify) async =>
      _tachKhuon(await _hangKemKhuon(accountId, classify).get(), accountId, classify);

  /// MỌI hàng khuôn (danh mục mặc định toàn cục), KỂ CẢ đã xoá mềm — luật ẩn theo khuôn và phép đếm danh mục riêng (Premium)
  /// cần biết khuôn nào đã xoá. Khác [getBackendDefaults] (chỉ khuôn còn sống — để sao chép).
  Future<List<Category>> getTatCaKhuon() =>
      (select(categories)..where((t) => t.isDefault.equals(true))).get();

  /// **Bảng tra tên danh mục** cho báo cáo và thống kê — định nghĩa DUY NHẤT.
  ///
  /// Khác mọi phép đọc danh sách khác ở hai chỗ, và cả hai đều có chủ đích:
  ///
  /// 1. **Giữ hàng đã xoá mềm.** Giao dịch cũ vẫn trỏ vào danh mục đã xoá, và
  ///    tên thật còn nguyên trong hàng: "Chi khác" có ích hơn "Danh mục đã
  ///    xoá". Vì thế không dùng [watchAll] (hàm ấy lọc `deletedAt`).
  /// 2. ⚠️ **Lọc theo CỜ `isDefault`, không chỉ theo tài khoản.** đường kéo về (`ApDuLieuKeoVe`)
  ///    quy `is_default = true` thành **`idaccount = 0`**
  ///    (`ap_du_lieu_keo_ve.dart`, nhánh kéo danh mục), nên hàng mặc định toàn cục không mang mã tài
  ///    khoản nào. Thiếu vế ấy thì giao dịch trỏ vào chúng **mất tên**.
  /// 3. **Giữ danh mục của NHÀ** (gia đình, schema v32 — spec 2026-10-23 mục 7.2): khoản của nhà phải có tên ở mọi máy
  ///    trong nhà, mà danh mục nhà mang `idaccount` của người tạo (bộ sao: chủ nhà) — thành viên tra bằng tài khoản mình
  ///    sẽ không thấy. Sau `purgeDataForOtherAccounts` trên máy chỉ còn danh mục của nhà đang ở.
  ///
  /// Vế thứ hai vốn thiếu ở **cả hai** repository cho tới 2026-09-15, mỗi nơi
  /// một bản chép tay. Đo trên CSDL dev hôm ấy: tài khoản 10 có hai danh mục
  /// như thế — `Chi khác` và `Làm thêm`, cùng bị backend xoá mềm hôm
  /// 2026-09-07 khi thu bộ khuôn về 13 UUID — và máy ảo hiện **hai chip cùng
  /// mang tên "Danh mục đã xoá"**, hai danh mục khác nhau đội một cái tên.
  ///
  /// ⓘ Đây là bảng **tra**, không phải danh sách để người dùng chọn: nơi gọi
  /// chỉ dùng nó để đổi `categoryId` sang tên/biểu tượng/màu. Thêm hàng mặc
  /// định vào đây **không** làm chúng hiện thêm ở đâu cả.
  SimpleSelectStatement<$CategoriesTable, Category> _bangTraTen(int accountId) =>
      select(categories)
        ..where((t) =>
            t.idaccount.equals(accountId) | t.isDefault.equals(true) | t.idhousehold.isNotNull());

  Future<List<Category>> getBangTraTen(int accountId) => _bangTraTen(accountId).get();

  Stream<List<Category>> watchBangTraTen(int accountId) =>
      _bangTraTen(accountId).watch();

  /// Mọi danh mục đang CHIẾM CHỖ tên trong phạm vi một tài khoản.
  ///
  /// Gồm danh mục do chính tài khoản tạo **và** danh mục mặc định (dùng chung,
  /// `idaccount = 0`): người dùng nhìn thấy cả hai trong cùng một danh sách nên
  /// hai mục trùng tên là không phân biệt được. Hàng đã xoá mềm không chiếm chỗ; danh mục của NHÀ (`idhousehold` khác
  /// `NULL`) cũng không — quy tắc trùng tên cá nhân không đếm chúng.
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
              t.idhousehold.isNull() &
              t.isDeleted.equals(false) &
              t.deletedAt.isNull()))
        .get();
  }

  /// Bộ danh mục **mặc định** do backend sở hữu, đã pull về máy này.
  ///
  /// `sync_engine` quy `is_default = true` thành `idaccount = 0`, nên lọc theo
  /// cờ chứ không theo tài khoản. Đây là **khuôn** để sao chép cho từng tài
  /// khoản (`DefaultCategorySeeder`); hàng đã xoá mềm không còn là khuôn của
  /// ai nữa.
  Future<List<Category>> getBackendDefaults() {
    return (select(categories)
          ..where((t) =>
              t.isDefault.equals(true) &
              t.isDeleted.equals(false) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Danh mục **thuộc về** [accountId], **kể cả hàng đã xoá mềm**.
  ///
  /// ⚠️ Khác [getNamesInUse] ở đúng hai chỗ, và cả hai đều có chủ đích: hàm này
  /// **giữ** hàng đã xoá, và **loại** hàng mặc định.
  ///
  /// Hàng đã xoá mềm là bằng chứng rằng tài khoản **từng** có bản sao ấy. Bỏ nó
  /// ra khỏi phép đếm là tái hiện **G16**: danh mục người dùng vừa xoá sẽ mọc
  /// lại ở mỗi lần mở app, và mỗi lần mọc lại là một thao tác đẩy hỏng vĩnh
  /// viễn. Đọc G16 trong `docs/CLIENT_APP_KNOWN_GAPS.md` trước khi sửa hàm này.
  ///
  /// ⚠️ Ràng `idhousehold IS NULL` (spec gia đình 3.3): danh mục của nhà cùng tên bộ mặc định — đếm nó là bản sao riêng không bao giờ được tạo; và `LanTruyenKhuon` (2026-10-27, cũng đọc hàm này) không đổi tên / biểu tượng danh mục CỦA NHÀ theo khuôn admin — hàng ấy server tạo, mọi máy trong nhà cùng có, sửa cục bộ là đẩy xung đột.
  Future<List<Category>> getOwnedIncludingDeleted(int accountId) {
    return (select(categories)
          ..where((t) =>
              t.idaccount.equals(accountId) & t.idhousehold.isNull() & t.isDefault.equals(false)))
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

  /// Toàn bộ từ khoá của một tài khoản, gom theo `categoryId`, bằng **một** truy vấn.
  ///
  /// Bộ gợi ý cần từ khoá của *mọi* danh mục cùng lúc. Gọi `getKeywords` trong
  /// vòng lặp sinh một truy vấn cho mỗi danh mục, mà bộ gợi ý lại chạy sau mỗi
  /// lần ghi chú thay đổi — số truy vấn nhân lên rất nhanh.
  Future<Map<String, List<String>>> getAllKeywords(int accountId) async {
    final rows = await (select(categoryKeywords)
          ..where((t) => t.idaccount.equals(accountId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final grouped = <String, List<String>>{};
    for (final row in rows) {
      (grouped[row.categoryId] ??= []).add(row.keyword);
    }
    return grouped;
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
              t.idaccount.equals(idaccount) &
              t.idhousehold.isNull() &
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
  /// Dùng ở `resolveCategoryId` (`core/sync/uuid_dong_bo.dart`) để ánh xạ danh mục mặc định cục bộ (id dạng
  /// `cat_food`) sang UUID tương ứng của backend. Trước đây so bằng
  /// `t.name.equals(name)` — phân biệt hoa/thường và không gộp dạng Unicode —
  /// nên chỉ cần lệch một chữ hoa hay một dạng dấu là ánh xạ thất bại,
  /// `resolveCategoryId` trả `null`, và giao dịch bị hoãn đẩy VĨNH VIỄN mà
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
  /// Bản client trước 2026-09-03 tạo 5 danh mục cá nhân **trước** lần pull đầu
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
              t.idhousehold.isNull() &
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
                t.idaccount.equals(idaccount) & t.idhousehold.isNull() & t.parentId.equals(fromId)))
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
