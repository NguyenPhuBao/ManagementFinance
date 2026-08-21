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
  }) {
    return db.categoryDao.insert(CategoriesCompanion.insert(
      id: id,
      idaccount: accountId,
      name: name,
      classify: classify,
      parentId: Value(parentId),
      isGroup: Value(isGroup),
      isDefault: Value(isDefault),
      isLocalOnly: const Value(true),
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

  test('rejects duplicate child name in one scope but permits another group',
      () async {
    await repository.saveGroup(const CategoryGroupDraft(
      id: 'group-food',
      accountId: 1,
      name: 'Food',
      classify: 'chi',
      icon: 'restaurant',
      colour: '#FF5722',
      childIds: [],
    ));
    await repository.saveGroup(const CategoryGroupDraft(
      id: 'group-work',
      accountId: 1,
      name: 'Work',
      classify: 'chi',
      icon: 'work',
      colour: '#2196F3',
      childIds: [],
    ));
    await repository.saveChild(const CategoryChildDraft(
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
      repository.saveChild(const CategoryChildDraft(
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

    await repository.saveChild(const CategoryChildDraft(
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
      repository.saveChild(const CategoryChildDraft(
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
}
