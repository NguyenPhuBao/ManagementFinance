import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
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
  Future<void> saveKeywords({
    required int accountId,
    required String categoryId,
    required Iterable<String> keywords,
  });
  Future<List<Category>> selectableChildren({
    required int accountId,
    required String classify,
  });
}

class CategoryManagementRepositoryImpl implements CategoryManagementRepository {
  CategoryManagementRepositoryImpl({required this.db});

  final AppDatabase db;

  @override
  Stream<CategoryTree> watchTree({
    required int accountId,
    required String classify,
  }) {
    late final StreamSubscription<List<Category>> categorySubscription;
    late final StreamSubscription<List<CategoryGroupMembership>>
        membershipSubscription;
    List<Category>? categoryRows;
    List<CategoryGroupMembership>? memberships;

    late final StreamController<CategoryTree> controller;
    controller = StreamController<CategoryTree>(
      onListen: () {
        void publish() {
          if (categoryRows == null || memberships == null) return;
          controller.add(_treeFromRows(categoryRows!, accountId, memberships!));
        }

        categorySubscription = db.categoryDao
            .watchCategoryRows(accountId, classify)
            .listen((rows) {
          categoryRows = rows;
          publish();
        }, onError: controller.addError);
        membershipSubscription = (db.select(db.categoryGroupMemberships)
              ..where((row) => row.idaccount.equals(accountId)))
            .watch()
            .listen((rows) {
          memberships = rows;
          publish();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await categorySubscription.cancel();
        await membershipSubscription.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<CategoryTree> loadTree({
    required int accountId,
    required String classify,
  }) async =>
      _treeFromRows(
        await db.categoryDao.getCategoryRows(accountId, classify),
        accountId,
        await db.categoryDao.getGroupMemberships(accountId),
      );

  @override
  Future<void> saveChild(CategoryChildDraft draft) async {
    final name = draft.name.trim();
    _requireName(name);
    if (draft.parentId == draft.id) {
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
    if (await _hasDuplicateChildName(
      accountId: draft.accountId,
      classify: classify,
      parentId: draft.parentId,
      excludingId: draft.id,
      name: name,
    )) {
      throw const CategoryValidationException(
        'Tên danh mục đã tồn tại trong phạm vi này.',
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
      isLocalOnly: const Value(true),
      syncStatus: const Value('pending'),
      updatedAt: now,
    ));
    await db.categoryDao.replaceKeywords(
      accountId: draft.accountId,
      categoryId: id,
      keywords: draft.keywords,
      now: now,
    );
  }

  @override
  Future<void> saveGroup(CategoryGroupDraft draft) {
    return db.transaction(() async {
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
      if (await _hasDuplicateGroupName(
        accountId: draft.accountId,
        classify: draft.classify,
        excludingId: draft.id,
        name: name,
      )) {
        throw const CategoryValidationException(
          'Tên danh mục đã tồn tại trong phạm vi này.',
        );
      }

      final childIds = draft.childIds.toSet();
      final personalChildren = <Category>[];
      final defaultChildren = <Category>[];
      final defaultChildIds = <String>[];
      for (final childId in childIds) {
        final child = await db.categoryDao.getById(childId);
        if (child == null || child.isDeleted || child.isGroup) {
          throw const CategoryValidationException(
            'Chỉ có thể thêm danh mục con cá nhân hợp lệ vào nhóm.',
          );
        }
        if (child.isDefault) {
          if (child.idaccount != 0 || child.classify != draft.classify) {
            throw const CategoryValidationException(
              'Chỉ có thể thêm danh mục mặc định hợp lệ cùng loại vào nhóm.',
            );
          }
          defaultChildren.add(child);
          defaultChildIds.add(child.id);
        } else {
          if (child.idaccount != draft.accountId) {
            throw const CategoryValidationException(
              'Chỉ có thể thêm danh mục con cá nhân hợp lệ vào nhóm.',
            );
          }
          personalChildren.add(child);
        }
      }
      if (_hasDuplicateAssignedChildName([
        ...personalChildren,
        ...defaultChildren,
      ])) {
        throw const CategoryValidationException(
          'Tên danh mục đã tồn tại trong phạm vi này.',
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
        isLocalOnly: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: now,
      ));

      await (db.update(db.categories)
            ..where((row) =>
                row.idaccount.equals(draft.accountId) &
                row.parentId.equals(id)))
          .write(CategoriesCompanion(
              parentId: const Value(null), updatedAt: Value(now)));
      for (final child in personalChildren) {
        await (db.update(db.categories)
              ..where((row) => row.id.equals(child.id)))
            .write(CategoriesCompanion(
          parentId: Value(id),
          classify: Value(draft.classify),
          isLocalOnly: const Value(true),
          updatedAt: Value(now),
        ));
      }
      await db.categoryDao.replaceGroupMemberships(
        accountId: draft.accountId,
        groupId: id,
        categoryIds: defaultChildIds,
        now: now,
      );
    });
  }

  @override
  Future<void> deleteChild({
    required int accountId,
    required String childId,
  }) async {
    final child = await db.categoryDao.getById(childId);
    _rejectDefault(child);
    if (child == null ||
        child.idaccount != accountId ||
        child.isDeleted ||
        child.isGroup ||
        !child.isLocalOnly) {
      throw const CategoryValidationException(
          'Chỉ có thể xóa danh mục con cá nhân.');
    }
    await (db.update(db.categories)..where((row) => row.id.equals(childId)))
        .write(CategoriesCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> deleteGroup({
    required int accountId,
    required String groupId,
  }) {
    return db.transaction(() async {
      final group = await db.categoryDao.getById(groupId);
      _rejectDefault(group);
      if (group == null ||
          group.idaccount != accountId ||
          !group.isGroup ||
          group.isDeleted ||
          !group.isLocalOnly) {
        throw const CategoryValidationException(
            'Chỉ có thể xóa nhóm danh mục cá nhân.');
      }
      final now = DateTime.now();
      await (db.update(db.categories)
            ..where((row) =>
                row.idaccount.equals(accountId) & row.parentId.equals(groupId)))
          .write(CategoriesCompanion(
              parentId: const Value(null), updatedAt: Value(now)));
      await db.categoryDao.removeGroupMemberships(accountId, groupId);
      await (db.update(db.categories)..where((row) => row.id.equals(groupId)))
          .write(CategoriesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ));
    });
  }

  @override
  Future<List<String>> loadKeywords({
    required int accountId,
    required String categoryId,
  }) =>
      db.categoryDao.getKeywords(accountId, categoryId);

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

  CategoryTree _treeFromRows(
    List<Category> rows,
    int accountId,
    List<CategoryGroupMembership> memberships,
  ) {
    final groups = rows
        .where((category) =>
            category.idaccount == accountId &&
            category.isGroup &&
            !category.isDefault &&
            category.isLocalOnly)
        .toList();
    final children = rows
        .where((category) =>
            !category.isGroup &&
            (category.idaccount == accountId || category.isDefault))
        .toList();
    final groupIds = groups.map((group) => group.id).toSet();
    final defaultChildIds = children
        .where((category) => category.isDefault)
        .map((category) => category.id)
        .toSet();
    final membershipGroupByDefaultId = <String, String>{
      for (final membership in memberships)
        if (groupIds.contains(membership.groupId) &&
            defaultChildIds.contains(membership.categoryId))
          membership.categoryId: membership.groupId,
    };
    return CategoryTree(
      groups: groups
          .map(
            (group) => CategoryGroupNode(
              group: group,
              children: children
                  .where((child) =>
                      (!child.isDefault && child.parentId == group.id) ||
                      (child.isDefault &&
                          membershipGroupByDefaultId[child.id] == group.id))
                  .toList(),
            ),
          )
          .toList(),
      ungroupedChildren: children
          .where((child) => child.isDefault
              ? !membershipGroupByDefaultId.containsKey(child.id)
              : child.parentId == null || !groupIds.contains(child.parentId))
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
        parent.isDeleted ||
        !parent.isLocalOnly) {
      throw const CategoryValidationException('Nhóm cha không hợp lệ.');
    }
    return parent;
  }

  Future<bool> _hasDuplicateGroupName({
    required int accountId,
    required String classify,
    required String? excludingId,
    required String name,
  }) async =>
      (await db.categoryDao.getCategoryRows(accountId, classify)).any(
        (category) =>
            category.idaccount == accountId &&
            category.isGroup &&
            !category.isDefault &&
            category.id != excludingId &&
            _normalize(category.name) == _normalize(name),
      );

  Future<bool> _hasDuplicateChildName({
    required int accountId,
    required String classify,
    required String? parentId,
    required String? excludingId,
    required String name,
  }) async =>
      (await db.categoryDao.getCategoryRows(accountId, classify)).any(
        (category) =>
            category.idaccount == accountId &&
            !category.isGroup &&
            !category.isDefault &&
            category.parentId == parentId &&
            category.id != excludingId &&
            _normalize(category.name) == _normalize(name),
      );

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

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
