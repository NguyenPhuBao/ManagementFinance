import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/category/category_classify.dart';
import '../../../../core/category/category_name.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../models/category_tree.dart';

class CategoryValidationException implements Exception {
  const CategoryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class CategoryManagementRepository {
  Stream<CategoryTree> watchTree({
    required int accountId,
    required String classify,
  });

  Future<CategoryTree> loadTree({
    required int accountId,
    required String classify,
  });

  Future<void> saveChild(CategoryChildDraft draft);
  Future<void> saveGroup(CategoryGroupDraft draft);
  Future<void> deleteChild({required int accountId, required String childId});
  Future<void> deleteGroup({required int accountId, required String groupId});
  Future<List<String>> loadKeywords({
    required int accountId,
    required String categoryId,
  });

  /// Từ khoá của MỌI danh mục thuộc tài khoản, gom theo `categoryId`.
  /// Dùng cho bộ gợi ý — nó cần cả tập cùng lúc, gọi `loadKeywords` trong vòng
  /// lặp sẽ sinh một truy vấn cho mỗi danh mục.
  Future<Map<String, List<String>>> loadAllKeywords({required int accountId});
  Future<void> saveKeywords({
    required int accountId,
    required String categoryId,
    required Iterable<String> keywords,
  });
  Future<List<Category>> selectableChildren({
    required int accountId,
    required String classify,
  });

  /// Mọi danh mục con chọn được của tài khoản, không phân biệt `classify`.
  ///
  /// Cho bộ gợi ý theo ghi chú ở trang thêm giao dịch: từ 2026-09-05 chiều
  /// tiền suy từ danh mục được chọn chứ không từ segment, nên không còn phân
  /// loại nào để khoanh vùng trước khi tìm.
  Future<List<Category>> selectableChildrenAll({required int accountId});
}

class CategoryManagementRepositoryImpl implements CategoryManagementRepository {
  CategoryManagementRepositoryImpl({required this.db, this.syncEngine});

  final AppDatabase db;

  /// Kích hoạt đồng bộ nền sau mỗi lần ghi danh mục — cùng cách wallet/
  /// transaction/goal/bill repository đang làm. Nullable để test dựng
  /// repository mà không cần SyncEngine.
  final SyncEngine? syncEngine;

  @override
  Stream<CategoryTree> watchTree({
    required int accountId,
    required String classify,
  }) {
    // Trước 2026-09-07 hàm này ghép HAI dòng dữ liệu: danh mục, và bảng
    // `CategoryGroupMemberships` — thứ chỉ tồn tại để gán danh mục **mặc định**
    // (toàn cục) vào nhóm của từng tài khoản. Nay mỗi tài khoản có bản sao
    // riêng nên việc gán nhóm nằm gọn trong `parentId` của chính hàng danh
    // mục, và dòng thứ hai không còn ảnh hưởng gì tới cây.
    return db.categoryDao
        .watchCategoryRows(accountId, classify)
        .map((rows) => _treeFromRows(rows, accountId));
  }

  @override
  Future<CategoryTree> loadTree({
    required int accountId,
    required String classify,
  }) async =>
      _treeFromRows(
        await db.categoryDao.getCategoryRows(accountId, classify),
        accountId,
      );

  @override
  Future<void> saveChild(CategoryChildDraft draft) async {
    final name = draft.name.trim();
    _requireName(name);
    // Chỉ chặn khi ĐANG SỬA một danh mục đã có (draft.id != null).
    // Với danh mục TẠO MỚI, draft.id == null; nếu người dùng để nguyên lựa
    // chọn mặc định "Chưa nhóm" thì parentId cũng == null → `parentId == id`
    // là `null == null` (true) và sẽ chặn nhầm toàn bộ luồng tạo danh mục
    // không thuộc nhóm nào.
    if (draft.id != null && draft.parentId == draft.id) {
      throw const CategoryValidationException(
        'Danh mục không thể là nhóm của chính nó.',
      );
    }

    final existing =
        draft.id == null ? null : await db.categoryDao.getById(draft.id!);
    _rejectDefault(existing);
    _requireOwnership(existing, draft.accountId);
    if (existing?.isGroup == true) {
      throw const CategoryValidationException(
          'Nhóm danh mục không thể là danh mục con.');
    }

    final parent = await _validParent(
      accountId: draft.accountId,
      parentId: draft.parentId,
    );
    final classify = parent?.classify ?? draft.classify;
    if (await _hasDuplicateName(
      accountId: draft.accountId,
      excludingId: draft.id,
      name: name,
      currentName: existing?.name,
    )) {
      throw const CategoryValidationException(
        'Tên danh mục đã tồn tại. Mỗi tài khoản không được có hai danh mục trùng tên, kể cả khác loại hay khác nhóm.',
      );
    }

    final id = draft.id ?? const Uuid().v4();
    final now = DateTime.now();
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: id,
      idaccount: draft.accountId,
      name: name,
      classify: classify,
      icon: Value(draft.icon),
      colour: Value(draft.colour),
      parentId: Value(draft.parentId),
      isGroup: const Value(false),
      isDefault: const Value(false),
      // Danh mục người dùng được đồng bộ lên backend (backend lưu cả
      // Is_group lẫn Idgroup), nên không còn là dữ liệu chỉ-có-ở-client.
      isLocalOnly: const Value(false),
      syncStatus: const Value('pending'),
      updatedAt: now,
    ));
    await db.categoryDao.replaceKeywords(
      accountId: draft.accountId,
      categoryId: id,
      keywords: draft.keywords,
      now: now,
    );
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> saveGroup(CategoryGroupDraft draft) async {
    await db.transaction(() async {
      final name = draft.name.trim();
      _requireName(name);
      final existing =
          draft.id == null ? null : await db.categoryDao.getById(draft.id!);
      _rejectDefault(existing);
      _requireOwnership(existing, draft.accountId);
      if (existing != null && !existing.isGroup) {
        throw const CategoryValidationException(
            'Danh mục con không thể là nhóm.');
      }
      if (await _hasDuplicateName(
        accountId: draft.accountId,
        excludingId: draft.id,
        name: name,
        currentName: existing?.name,
      )) {
        throw const CategoryValidationException(
          'Tên danh mục đã tồn tại. Mỗi tài khoản không được có hai danh mục trùng tên, kể cả khác loại hay khác nhóm.',
        );
      }

      final childIds = draft.childIds.toSet();
      final personalChildren = <Category>[];
      for (final childId in childIds) {
        final child = await db.categoryDao.getById(childId);
        if (child == null || child.isDeleted || child.isGroup) {
          throw const CategoryValidationException(
            'Chỉ có thể thêm danh mục con cá nhân hợp lệ vào nhóm.',
          );
        }
        // Từ 2026-09-07 danh mục mặc định không còn hiện với người dùng —
        // mỗi tài khoản có bản sao của riêng mình — nên chúng không thể là
        // ứng viên con của một nhóm nữa.
        if (child.isDefault || child.idaccount != draft.accountId) {
          throw const CategoryValidationException(
            'Chỉ có thể thêm danh mục con cá nhân hợp lệ vào nhóm.',
          );
        }
        personalChildren.add(child);
      }
      if (_hasDuplicateAssignedChildName(personalChildren)) {
        throw const CategoryValidationException(
          'Tên danh mục đã tồn tại. Mỗi tài khoản không được có hai danh mục trùng tên, kể cả khác loại hay khác nhóm.',
        );
      }

      final id = draft.id ?? const Uuid().v4();
      final now = DateTime.now();
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: id,
        idaccount: draft.accountId,
        name: name,
        classify: draft.classify,
        icon: Value(draft.icon),
        colour: Value(draft.colour),
        isGroup: const Value(true),
        isDefault: const Value(false),
        isLocalOnly: const Value(false),
        syncStatus: const Value('pending'),
        updatedAt: now,
      ));

      // Gỡ các danh mục con cũ ra khỏi nhóm — parentId đổi nên phải đẩy lại.
      await (db.update(db.categories)
            ..where((row) =>
                row.idaccount.equals(draft.accountId) &
                row.parentId.equals(id)))
          .write(CategoriesCompanion(
        parentId: const Value(null),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      for (final child in personalChildren) {
        await (db.update(db.categories)
              ..where((row) => row.id.equals(child.id)))
            .write(CategoriesCompanion(
          parentId: Value(id),
          classify: Value(draft.classify),
          // parentId đổi → phải đồng bộ lên backend (Idgroup).
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ));
      }
      // Không còn ghi `CategoryGroupMemberships`: bảng ấy tồn tại CHỈ vì danh
      // mục mặc định là toàn cục nên không ghi `parentId` riêng cho từng tài
      // khoản được. Nay mọi danh mục người dùng thấy đều là của chính họ, và
      // `parentId` (→ `Idgroup`) đã nằm trong payload đẩy. Bảng và các hàm DAO
      // giữ nguyên cho tới khi có một migration đáng làm.
    });
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> deleteChild({
    required int accountId,
    required String childId,
  }) async {
    final child = await db.categoryDao.getById(childId);
    _rejectDefault(child);
    // Không còn kiểm tra `isLocalOnly`: danh mục người dùng giờ đều được đồng
    // bộ nên cờ đó luôn false. _rejectDefault() ở trên + kiểm tra idaccount
    // dưới đây đã đủ chặn xoá nhầm danh mục mặc định / của tài khoản khác.
    if (child == null ||
        child.idaccount != accountId ||
        child.isDeleted ||
        child.isGroup) {
      throw const CategoryValidationException(
          'Chỉ có thể xóa danh mục con cá nhân.');
    }
    await (db.update(db.categories)..where((row) => row.id.equals(childId)))
        .write(CategoriesCompanion(
      isDeleted: const Value(true),
      // Đánh dấu pending để thao tác xoá được đẩy lên backend (delete_at).
      syncStatus: const Value('pending'),
      updatedAt: Value(DateTime.now()),
    ));
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> deleteGroup({
    required int accountId,
    required String groupId,
  }) async {
    await db.transaction(() async {
      final group = await db.categoryDao.getById(groupId);
      _rejectDefault(group);
      if (group == null ||
          group.idaccount != accountId ||
          !group.isGroup ||
          group.isDeleted) {
        throw const CategoryValidationException(
            'Chỉ có thể xóa nhóm danh mục cá nhân.');
      }
      final now = DateTime.now();
      // Gỡ con ra khỏi nhóm trước — parentId đổi nên phải đẩy lại.
      await (db.update(db.categories)
            ..where((row) =>
                row.idaccount.equals(accountId) & row.parentId.equals(groupId)))
          .write(CategoriesCompanion(
        parentId: const Value(null),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await (db.update(db.categories)..where((row) => row.id.equals(groupId)))
          .write(CategoriesCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
    });
    syncEngine?.scheduleSync();
  }

  @override
  Future<List<String>> loadKeywords({
    required int accountId,
    required String categoryId,
  }) =>
      db.categoryDao.getKeywords(accountId, categoryId);

  @override
  Future<Map<String, List<String>>> loadAllKeywords({
    required int accountId,
  }) =>
      db.categoryDao.getAllKeywords(accountId);

  @override
  Future<void> saveKeywords({
    required int accountId,
    required String categoryId,
    required Iterable<String> keywords,
  }) async {
    final category = await db.categoryDao.getById(categoryId);
    if (category == null ||
        category.isDeleted ||
        (!category.isDefault && category.idaccount != accountId)) {
      throw const CategoryValidationException(
          'Danh mục không tồn tại hoặc không thuộc tài khoản.');
    }
    await db.categoryDao.replaceKeywords(
      accountId: accountId,
      categoryId: categoryId,
      keywords: keywords,
      now: DateTime.now(),
    );
  }

  @override
  Future<List<Category>> selectableChildren({
    required int accountId,
    required String classify,
  }) async =>
      (await db.categoryDao.getCategoryRows(accountId, classify))
          .where((category) => !category.isGroup)
          .toList();

  @override
  Future<List<Category>> selectableChildrenAll({required int accountId}) async {
    // Đi qua `selectableChildren` từng classify để hưởng đúng phép khử trùng
    // lặp theo tên của `getCategoryRows` (bản seed cũ ↔ bản UUID từ backend).
    final perClassify = await Future.wait(kCategoryClassifies.map(
      (classify) =>
          selectableChildren(accountId: accountId, classify: classify),
    ));
    final seen = <String>{};
    return [
      for (final list in perClassify)
        for (final category in list)
          if (seen.add(category.id)) category,
    ];
  }

  CategoryTree _treeFromRows(List<Category> rows, int accountId) {
    final groups = rows
        .where((category) =>
            category.idaccount == accountId &&
            category.isGroup &&
            !category.isDefault)
        .toList();
    // Danh mục mặc định KHÔNG còn có mặt ở đây: `rows` đến từ
    // `watchCategoryRows`/`getCategoryRows`, và từ 2026-09-07 hai hàm ấy chỉ
    // trả danh mục của chính tài khoản. Mỗi người có bản sao riêng, nên việc
    // gán nhóm nay biểu diễn được bằng `parentId` — thứ vốn đã đồng bộ lên
    // backend qua cột `Idgroup`.
    final children =
        rows.where((category) => !category.isGroup).toList();
    final groupIds = groups.map((group) => group.id).toSet();
    return CategoryTree(
      groups: groups
          .map(
            (group) => CategoryGroupNode(
              group: group,
              children: children
                  .where((child) => child.parentId == group.id)
                  .toList(),
            ),
          )
          .toList(),
      ungroupedChildren: children
          .where((child) =>
              child.parentId == null || !groupIds.contains(child.parentId))
          .toList(),
      defaultChildren: const [],
    );
  }

  Future<Category?> _validParent({
    required int accountId,
    required String? parentId,
  }) async {
    if (parentId == null) return null;
    final parent = await db.categoryDao.getById(parentId);
    if (parent == null ||
        parent.idaccount != accountId ||
        !parent.isGroup ||
        parent.isDefault ||
        parent.isDeleted) {
      throw const CategoryValidationException('Nhóm cha không hợp lệ.');
    }
    return parent;
  }

  /// Tên danh mục đã bị chiếm trong phạm vi tài khoản chưa.
  ///
  /// Khoá duy nhất là **(phạm vi tài khoản, tên đã chuẩn hoá)** — không có
  /// `classify`, không có nhóm cha; nhóm, danh mục con và cả danh mục MẶC ĐỊNH
  /// dùng chung một không gian tên, vì người dùng nhìn thấy tất cả trong cùng
  /// một danh sách chọn.
  ///
  /// Lưu ý về mức chặt: PostgreSQL hiện vẫn ràng buộc theo
  /// `(Create_by, NameCategory, Classify)` — tức KHÁC quy tắc này ở cả hai
  /// chiều. Client chặt hơn ở chỗ bỏ `classify` và tính cả danh mục mặc định;
  /// nhưng CSDL lại chặt hơn ở chỗ hàng đã xoá mềm vẫn giữ chỗ và tên phân biệt
  /// hoa/thường. Cho tới khi backend thay hai unique index, đây là nơi DUY NHẤT
  /// bảo đảm quy tắc — mà `/sync/push` chỉ đánh dấu thao tác hỏng là `failed`
  /// nên vi phạm lọt qua sẽ không hiện ra màn hình.
  Future<bool> _hasDuplicateName({
    required int accountId,
    required String? excludingId,
    required String name,
    String? currentName,
  }) async {
    final target = _normalize(name);

    // Đang SỬA mà không đổi tên thì không xét trùng nữa. Bản client trước
    // 2026-09-03 loại danh mục mặc định khỏi phép kiểm tra, nên máy người dùng
    // có thể đang giữ một danh mục riêng trùng tên với danh mục mặc định.
    // Chặn tuyệt đối sẽ khiến họ không sửa nổi danh mục đó nữa — kể cả chỉ đổi
    // icon — và không có cách nào thoát ngoài việc đổi tên.
    if (currentName != null && _normalize(currentName) == target) return false;

    final inUse = await db.categoryDao.getNamesInUse(accountId);
    return inUse.any((category) =>
        category.id != excludingId && _normalize(category.name) == target);
  }

  bool _hasDuplicateAssignedChildName(Iterable<Category> children) {
    final names = <String>{};
    for (final child in children) {
      if (!names.add(_normalize(child.name))) return true;
    }
    return false;
  }

  void _requireName(String name) {
    if (name.isEmpty) {
      throw const CategoryValidationException(
          'Tên danh mục không được để trống.');
    }
  }

  void _rejectDefault(Category? category) {
    if (category?.isDefault == true) {
      throw const CategoryValidationException(
        'Danh mục mặc định chỉ cho phép sửa từ khóa.',
      );
    }
  }

  void _requireOwnership(Category? category, int accountId) {
    if (category != null && category.idaccount != accountId) {
      throw const CategoryValidationException(
        'Danh mục không thuộc tài khoản này.',
      );
    }
  }

  /// Uỷ quyền cho định nghĩa DUY NHẤT ở `core/category/category_name.dart`.
  /// Trước đây mỗi nơi so tên tự viết một biến thể riêng, và chúng đã lệch nhau.
  String _normalize(String value) => normalizeCategoryName(value);
}
