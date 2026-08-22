import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryManagementRepository repository;

  Future<void> insertCategory({
    required String id,
    required String name,
    String classify = 'chi',
    int accountId = 1,
    String? parentId,
    bool isGroup = false,
    bool isDefault = false,
    bool isDeleted = false,
    bool isLocalOnly = true,
  }) {
    return db.categoryDao.insert(CategoriesCompanion.insert(
      id: id,
      idaccount: accountId,
      name: name,
      classify: classify,
      parentId: Value(parentId),
      isGroup: Value(isGroup),
      isDefault: Value(isDefault),
      isLocalOnly: Value(isLocalOnly),
      isDeleted: Value(isDeleted),
      updatedAt: DateTime(2026, 8, 21),
    ));
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CategoryManagementRepositoryImpl(db: db);
  });

  tearDown(() => db.close());

  test('deleting a group ungroups children and soft-deletes only the group',
      () async {
    await insertCategory(id: 'group-food', name: 'Food', isGroup: true);
    await insertCategory(
      id: 'child-coffee',
      name: 'Coffee',
      parentId: 'group-food',
    );

    await repository.deleteGroup(accountId: 1, groupId: 'group-food');

    expect((await db.categoryDao.getById('group-food'))!.isDeleted, isTrue);
    expect((await db.categoryDao.getById('child-coffee'))!.parentId, isNull);
    expect((await db.categoryDao.getById('child-coffee'))!.isDeleted, isFalse);
  });

  test('lists an unassigned default leaf with ungrouped children', () async {
    await insertCategory(
      id: 'default-utilities',
      name: 'Utilities',
      accountId: 0,
      isDefault: true,
      isLocalOnly: false,
    );

    final tree = await repository.loadTree(accountId: 1, classify: 'chi');

    expect(
      tree.ungroupedChildren.map((category) => category.id),
      contains('default-utilities'),
    );
    expect(tree.defaultChildren, isEmpty);
  });

  test('groups a default leaf only for its account without changing global row',
      () async {
    await insertCategory(
      id: 'default-utilities',
      name: 'Utilities',
      accountId: 0,
      isDefault: true,
      isLocalOnly: false,
    );
    await repository.saveGroup(CategoryGroupDraft(
      id: 'group-home',
      accountId: 1,
      name: 'Home',
      classify: 'chi',
      icon: 'home',
      colour: '#4CAF50',
      childIds: [],
    ));

    await repository.saveGroup(CategoryGroupDraft(
      id: 'group-home',
      accountId: 1,
      name: 'Home',
      classify: 'chi',
      icon: 'home',
      colour: '#4CAF50',
      childIds: ['default-utilities'],
    ));

    final accountOneTree =
        await repository.loadTree(accountId: 1, classify: 'chi');
    final accountTwoTree =
        await repository.loadTree(accountId: 2, classify: 'chi');

    expect(
      accountOneTree.groups.single.children.map((category) => category.id),
      ['default-utilities'],
    );
    expect(
      accountTwoTree.ungroupedChildren.map((category) => category.id),
      contains('default-utilities'),
    );
    expect(
        (await db.categoryDao.getById('default-utilities'))!.parentId, isNull);
    expect(
      (await db.categoryDao.getGroupMemberships(1))
          .map((membership) => membership.categoryId),
      ['default-utilities'],
    );
    expect(await db.categoryDao.getGroupMemberships(2), isEmpty);
  });

  test(
      'deleting a group clears default memberships and returns leaves ungrouped',
      () async {
    await insertCategory(
      id: 'default-utilities',
      name: 'Utilities',
      accountId: 0,
      isDefault: true,
      isLocalOnly: false,
    );
    await insertCategory(id: 'group-home', name: 'Home', isGroup: true);
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-home',
      categoryIds: ['default-utilities'],
      now: DateTime(2026, 8, 22),
    );

    await repository.deleteGroup(accountId: 1, groupId: 'group-home');

    expect(await db.categoryDao.getGroupMemberships(1), isEmpty);
    final tree = await repository.loadTree(accountId: 1, classify: 'chi');
    expect(
      tree.ungroupedChildren.map((category) => category.id),
      contains('default-utilities'),
    );
  });

  test('rejects duplicate child name in one scope but permits another group',
      () async {
    await repository.saveGroup(CategoryGroupDraft(
      id: 'group-food',
      accountId: 1,
      name: 'Food',
      classify: 'chi',
      icon: 'restaurant',
      colour: '#FF5722',
      childIds: [],
    ));
    await repository.saveGroup(CategoryGroupDraft(
      id: 'group-work',
      accountId: 1,
      name: 'Work',
      classify: 'chi',
      icon: 'work',
      colour: '#2196F3',
      childIds: [],
    ));
    await repository.saveChild(CategoryChildDraft(
      id: 'child-coffee-food',
      accountId: 1,
      name: ' Coffee ',
      classify: 'chi',
      parentId: 'group-food',
      icon: 'local_cafe',
      colour: '#795548',
      keywords: [],
    ));

    await expectLater(
      repository.saveChild(CategoryChildDraft(
        id: 'child-coffee-duplicate',
        accountId: 1,
        name: 'coffee',
        classify: 'chi',
        parentId: 'group-food',
        icon: 'local_cafe',
        colour: '#795548',
        keywords: [],
      )),
      throwsA(isA<CategoryValidationException>()),
    );

    await repository.saveChild(CategoryChildDraft(
      id: 'child-coffee-work',
      accountId: 1,
      name: 'coffee',
      classify: 'chi',
      parentId: 'group-work',
      icon: 'local_cafe',
      colour: '#795548',
      keywords: [],
    ));
  });

  test('allows default keywords but rejects default mutation and deletion',
      () async {
    await insertCategory(
      id: 'cat-food',
      name: 'Food',
      accountId: 0,
      isDefault: true,
    );

    await repository.saveKeywords(
      accountId: 1,
      categoryId: 'cat-food',
      keywords: ['GrabFood'],
    );
    expect(await repository.loadKeywords(accountId: 1, categoryId: 'cat-food'),
        ['GrabFood']);

    await expectLater(
      repository.saveChild(CategoryChildDraft(
        id: 'cat-food',
        accountId: 1,
        name: 'Changed food',
        classify: 'chi',
        parentId: null,
        icon: 'restaurant',
        colour: '#FF5722',
        keywords: [],
      )),
      throwsA(isA<CategoryValidationException>()),
    );
    await expectLater(
      repository.deleteChild(accountId: 1, childId: 'cat-food'),
      throwsA(isA<CategoryValidationException>()),
    );
  });

  test('selectable children omit groups and deleted children', () async {
    await insertCategory(id: 'group-food', name: 'Food', isGroup: true);
    await insertCategory(id: 'child-coffee', name: 'Coffee');
    await insertCategory(
      id: 'child-deleted',
      name: 'Deleted',
      isDeleted: true,
    );

    final children =
        await repository.selectableChildren(accountId: 1, classify: 'chi');

    expect(children.map((category) => category.id), contains('child-coffee'));
    expect(
        children.map((category) => category.id), isNot(contains('group-food')));
    expect(children.map((category) => category.id),
        isNot(contains('child-deleted')));
  });

  test('rejects duplicate child names that would share a reassigned group',
      () async {
    await insertCategory(id: 'group-food', name: 'Food', isGroup: true);
    await insertCategory(id: 'group-work', name: 'Work', isGroup: true);
    await insertCategory(
      id: 'coffee-food',
      name: ' Coffee ',
      parentId: 'group-food',
    );
    await insertCategory(
      id: 'coffee-work',
      name: 'coffee',
      parentId: 'group-work',
    );

    await expectLater(
      repository.saveGroup(CategoryGroupDraft(
        id: 'group-food',
        accountId: 1,
        name: 'Renamed food',
        classify: 'chi',
        icon: 'restaurant',
        colour: '#FF5722',
        childIds: ['coffee-food', 'coffee-work'],
      )),
      throwsA(isA<CategoryValidationException>()),
    );

    expect((await db.categoryDao.getById('group-food'))!.name, 'Food');
    expect(
        (await db.categoryDao.getById('coffee-work'))!.parentId, 'group-work');
  });

  test('rejects cross-account existing child and group IDs before mutation',
      () async {
    await insertCategory(
      id: 'other-child',
      name: 'Other child',
      accountId: 2,
    );
    await insertCategory(
      id: 'other-group',
      name: 'Other group',
      accountId: 2,
      isGroup: true,
    );

    await expectLater(
      repository.saveChild(CategoryChildDraft(
        id: 'other-child',
        accountId: 1,
        name: 'Hijacked child',
        classify: 'chi',
        parentId: null,
        icon: 'category',
        colour: '#4CAF50',
        keywords: [],
      )),
      throwsA(isA<CategoryValidationException>()),
    );
    await expectLater(
      repository.saveGroup(CategoryGroupDraft(
        id: 'other-group',
        accountId: 1,
        name: 'Hijacked group',
        classify: 'chi',
        icon: 'category',
        colour: '#4CAF50',
        childIds: [],
      )),
      throwsA(isA<CategoryValidationException>()),
    );

    expect((await db.categoryDao.getById('other-child'))!.idaccount, 2);
    expect((await db.categoryDao.getById('other-group'))!.idaccount, 2);
  });

  test('rejects deletion of a non-local personal child', () async {
    await insertCategory(
      id: 'server-child',
      name: 'Server child',
      isLocalOnly: false,
    );

    await expectLater(
      repository.deleteChild(accountId: 1, childId: 'server-child'),
      throwsA(isA<CategoryValidationException>()),
    );

    expect((await db.categoryDao.getById('server-child'))!.isDeleted, isFalse);
  });

  test('rolls back group deletion when the group update fails', () async {
    await insertCategory(id: 'group-food', name: 'Food', isGroup: true);
    await insertCategory(
      id: 'child-coffee',
      name: 'Coffee',
      parentId: 'group-food',
    );
    await db.customStatement('''
      CREATE TRIGGER fail_group_delete
      BEFORE UPDATE ON categories
      WHEN NEW.id = 'group-food'
      BEGIN
        SELECT RAISE(ABORT, 'group deletion blocked');
      END;
    ''');

    await expectLater(
      repository.deleteGroup(accountId: 1, groupId: 'group-food'),
      throwsA(isA<Exception>()),
    );

    expect((await db.categoryDao.getById('group-food'))!.isDeleted, isFalse);
    expect(
        (await db.categoryDao.getById('child-coffee'))!.parentId, 'group-food');
  });

  test('draft list fields are defensive and unmodifiable', () {
    final keywords = <String>['coffee'];
    final childIds = <String>['child-coffee'];
    final childDraft = CategoryChildDraft(
      accountId: 1,
      name: 'Coffee',
      classify: 'chi',
      parentId: null,
      icon: 'local_cafe',
      colour: '#795548',
      keywords: keywords,
    );
    final groupDraft = CategoryGroupDraft(
      accountId: 1,
      name: 'Food',
      classify: 'chi',
      icon: 'restaurant',
      colour: '#FF5722',
      childIds: childIds,
    );

    keywords.add('latte');
    childIds.add('child-latte');

    expect(childDraft.keywords, ['coffee']);
    expect(groupDraft.childIds, ['child-coffee']);
    expect(() => childDraft.keywords.add('tea'), throwsUnsupportedError);
    expect(() => groupDraft.childIds.add('child-tea'), throwsUnsupportedError);
  });
}
