import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  Future<void> insertCategory({
    required String id,
    String? parentId,
    bool isGroup = false,
    bool isLocalOnly = false,
  }) {
    return db.categoryDao.insert(CategoriesCompanion.insert(
      id: id,
      idaccount: 1,
      name: id,
      classify: 'chi',
      parentId: Value(parentId),
      isGroup: Value(isGroup),
      isLocalOnly: Value(isLocalOnly),
      updatedAt: DateTime(2026, 8, 21),
    ));
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('migrates v2 category data and creates category keyword storage',
      () async {
    await db.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        database.execute('''
          CREATE TABLE categories (
            id TEXT NOT NULL PRIMARY KEY,
            idaccount INTEGER NOT NULL,
            name TEXT NOT NULL,
            classify TEXT NOT NULL,
            icon TEXT NOT NULL DEFAULT 'category',
            colour TEXT NOT NULL DEFAULT '#4CAF50',
            is_default INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            updated_at INTEGER NOT NULL
          )
        ''');
        database.execute('''
          INSERT INTO categories (
            id, idaccount, name, classify, icon, colour,
            is_default, is_deleted, sync_status, updated_at
          ) VALUES (
            'legacy-food', 1, 'Legacy food', 'chi', 'category', '#4CAF50',
            0, 0, 'synced', 1787270400000
          )
        ''');
        database.execute('PRAGMA user_version = 2');
      },
    ));
    addTearDown(upgraded.close);

    final legacyRow = await upgraded.categoryDao.getById('legacy-food');
    final columns =
        await upgraded.customSelect('PRAGMA table_info(categories)').get();
    final keywordTable = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'category_keywords'",
        )
        .getSingle();

    expect(legacyRow?.name, 'Legacy food');
    expect(legacyRow?.parentId, isNull);
    expect(legacyRow?.isGroup, isFalse);
    expect(legacyRow?.isLocalOnly, isFalse);
    expect(
      columns.map((column) => column.read<String>('name')),
      containsAll(['parent_id', 'is_group', 'is_local_only']),
    );
    expect(keywordTable.read<String>('name'), 'category_keywords');
  });

  test('migrates v3 category data and creates group membership storage',
      () async {
    await db.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        database.execute('''
          CREATE TABLE categories (
            id TEXT NOT NULL PRIMARY KEY,
            idaccount INTEGER NOT NULL,
            name TEXT NOT NULL,
            classify TEXT NOT NULL,
            icon TEXT NOT NULL DEFAULT 'category',
            colour TEXT NOT NULL DEFAULT '#4CAF50',
            is_default INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            parent_id TEXT,
            is_group INTEGER NOT NULL DEFAULT 0,
            is_local_only INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            updated_at INTEGER NOT NULL
          )
        ''');
        database.execute('''
          CREATE TABLE category_keywords (
            id TEXT NOT NULL PRIMARY KEY,
            idaccount INTEGER NOT NULL,
            category_id TEXT NOT NULL,
            keyword TEXT NOT NULL,
            normalized_keyword TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            UNIQUE (idaccount, category_id, normalized_keyword)
          )
        ''');
        database.execute('PRAGMA user_version = 3');
      },
    ));
    addTearDown(upgraded.close);

    final membershipTable = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'category_group_memberships'",
        )
        .getSingle();

    expect(membershipTable.read<String>('name'), 'category_group_memberships');
  });

  test('returns raw visible category rows from both category row APIs',
      () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'global-food',
      idaccount: 0,
      name: 'Food',
      classify: 'chi',
      isDefault: const Value(true),
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'personal-food',
      idaccount: 1,
      name: 'Food',
      classify: 'chi',
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'deleted-food',
      idaccount: 1,
      name: 'Deleted food',
      classify: 'chi',
      isDeleted: const Value(true),
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'other-account-food',
      idaccount: 2,
      name: 'Other account food',
      classify: 'chi',
      updatedAt: now,
    ));

    final watchedRows = await db.categoryDao.watchCategoryRows(1, 'chi').first;
    final fetchedRows = await db.categoryDao.getCategoryRows(1, 'chi');

    for (final rows in [watchedRows, fetchedRows]) {
      expect(rows.map((row) => row.id),
          containsAll(['global-food', 'personal-food']));
      expect(rows.map((row) => row.id), isNot(contains('deleted-food')));
      expect(rows.map((row) => row.id), isNot(contains('other-account-food')));
      expect(rows.where((row) => row.name == 'Food'), hasLength(2));
    }
  });

  test('stores a personal parent group and an ungrouped child', () async {
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'group-food',
      idaccount: 1,
      name: 'Ăn uống',
      classify: 'chi',
      isGroup: const Value(true),
      isLocalOnly: const Value(true),
      updatedAt: DateTime(2026, 8, 21),
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'child-coffee',
      idaccount: 1,
      name: 'Cà phê',
      classify: 'chi',
      parentId: const Value('group-food'),
      isLocalOnly: const Value(true),
      updatedAt: DateTime(2026, 8, 21),
    ));

    final rows = await db.categoryDao.watchCategoryRows(1, 'chi').first;

    expect(
        rows.map((row) => row.id), containsAll(['group-food', 'child-coffee']));
    expect(rows.singleWhere((row) => row.id == 'child-coffee').parentId,
        'group-food');
  });

  test('keeps keyword records isolated by account for a default category',
      () async {
    await db.categoryDao.replaceKeywords(
      accountId: 1,
      categoryId: 'cat_food',
      keywords: ['GrabFood'],
      now: DateTime(2026, 8, 21),
    );
    await db.categoryDao.replaceKeywords(
      accountId: 2,
      categoryId: 'cat_food',
      keywords: ['Bún chả'],
      now: DateTime(2026, 8, 21),
    );

    expect(await db.categoryDao.getKeywords(1, 'cat_food'), ['GrabFood']);
    expect(await db.categoryDao.getKeywords(2, 'cat_food'), ['Bún chả']);
  });

  test('normalizes keywords and replaces only the requested category set',
      () async {
    await db.categoryDao.replaceKeywords(
      accountId: 1,
      categoryId: 'cat_food',
      keywords: ['  Grab   Food  ', '', ' grab food '],
      now: DateTime(2026, 8, 21),
    );
    await db.categoryDao.replaceKeywords(
      accountId: 1,
      categoryId: 'cat_transport',
      keywords: ['Taxi'],
      now: DateTime(2026, 8, 21),
    );
    expect(await db.categoryDao.getKeywords(1, 'cat_food'), ['Grab   Food']);
    await db.categoryDao.replaceKeywords(
      accountId: 1,
      categoryId: 'cat_food',
      keywords: ['Coffee'],
      now: DateTime(2026, 8, 21),
    );

    expect(await db.categoryDao.getKeywords(1, 'cat_food'), ['Coffee']);
    expect(await db.categoryDao.getKeywords(1, 'cat_transport'), ['Taxi']);
  });

  test('clears keywords when a replacement contains only whitespace', () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.replaceKeywords(
      accountId: 1,
      categoryId: 'cat_food',
      keywords: ['GrabFood'],
      now: now,
    );

    await db.categoryDao.replaceKeywords(
      accountId: 1,
      categoryId: 'cat_food',
      keywords: [' ', '\t\n'],
      now: now,
    );

    expect(await db.categoryDao.getKeywords(1, 'cat_food'), isEmpty);
  });

  test('keeps group memberships isolated by account', () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-food',
      categoryIds: ['cat_food'],
      now: now,
    );
    await db.categoryDao.replaceGroupMemberships(
      accountId: 2,
      groupId: 'group-food',
      categoryIds: ['cat_transport'],
      now: now,
    );

    expect(
      (await db.categoryDao.getGroupMemberships(1))
          .map((membership) => membership.categoryId),
      ['cat_food'],
    );
    expect(
      (await db.categoryDao.getGroupMemberships(2))
          .map((membership) => membership.categoryId),
      ['cat_transport'],
    );
  });

  test('replaces only the supplied category IDs for a group', () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-food',
      categoryIds: ['cat_food', 'cat_drink', 'cat_food'],
      now: now,
    );
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-transport',
      categoryIds: ['cat_transport'],
      now: now,
    );

    expect(
      (await db.categoryDao.getGroupMemberships(1))
          .where((membership) => membership.groupId == 'group-food')
          .map((membership) => membership.categoryId),
      unorderedEquals(['cat_food', 'cat_drink']),
    );

    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-food',
      categoryIds: ['cat_grocery'],
      now: now,
    );

    final memberships = await db.categoryDao.getGroupMemberships(1);
    expect(
      memberships
          .where((membership) => membership.groupId == 'group-food')
          .map((membership) => membership.categoryId),
      ['cat_grocery'],
    );
    expect(
      memberships
          .where((membership) => membership.groupId == 'group-transport')
          .map((membership) => membership.categoryId),
      ['cat_transport'],
    );
  });

  test('removes group memberships without affecting another group', () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-food',
      categoryIds: ['cat_food'],
      now: now,
    );
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-transport',
      categoryIds: ['cat_transport'],
      now: now,
    );

    await db.categoryDao.removeGroupMemberships(1, 'group-food');

    expect(
      (await db.categoryDao.getGroupMemberships(1))
          .map((membership) => membership.categoryId),
      ['cat_transport'],
    );
  });

  test('returns only syncable categories for the requested account', () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'syncable',
      idaccount: 1,
      name: 'Syncable',
      classify: 'chi',
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'local-only',
      idaccount: 1,
      name: 'Local only',
      classify: 'chi',
      isLocalOnly: const Value(true),
      updatedAt: now,
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'another-account',
      idaccount: 2,
      name: 'Another account',
      classify: 'chi',
      updatedAt: now,
    ));

    final rows = await db.categoryDao.getSyncableCategories(1);

    expect(rows.map((row) => row.id), ['syncable']);
  });

  test('getSyncableCategories excludes local-only groups and children',
      () async {
    await insertCategory(id: 'server-child', isLocalOnly: false);
    await insertCategory(id: 'local-group', isGroup: true, isLocalOnly: true);
    await insertCategory(
      id: 'local-child',
      parentId: 'local-group',
      isLocalOnly: true,
    );

    final rows = await db.categoryDao.getSyncableCategories(1);

    expect(rows.map((row) => row.id), contains('server-child'));
    expect(rows.map((row) => row.id), isNot(contains('local-group')));
    expect(rows.map((row) => row.id), isNot(contains('local-child')));
  });
}
