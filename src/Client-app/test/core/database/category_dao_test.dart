import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';

/// Các bảng ngoài `categories` ở hình dạng **trước v5**, để migration thật có
/// thể chạy trên CSDL giả.
///
/// Migration từ v2/v3 lên bản hiện tại có `ALTER TABLE` trên wallets,
/// transactions, budgets, bills, goals. CSDL giả chỉ có mỗi bảng `categories`
/// sẽ làm migration chết ở bước `from < 5` với lỗi "no such table: wallets" —
/// một lỗi CỦA FIXTURE, không phải của migration.
///
/// Cố tình BỎ những cột mà migration sẽ tự thêm (include_in_total,
/// bank_casso_id, status, provider, wallet_transfer, bank_tran_id, deleted_at,
/// spent, over_spending, pay_status, start_date của bills, ...) để phần
/// `addColumn` được thực thi đúng như trên máy người dùng thật.
// `database` là sqlite3.Database do NativeDatabase.memory(setup:) truyền vào.
// Dùng dynamic để khỏi phải thêm `sqlite3` làm phụ thuộc trực tiếp.
void _createLegacyNonCategoryTables(dynamic database) {
  database.execute('''
    CREATE TABLE wallets (
      id TEXT NOT NULL PRIMARY KEY,
      idaccount INTEGER NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'cash',
      balance REAL NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'VND',
      icon TEXT NOT NULL DEFAULT 'wallet',
      colour TEXT NOT NULL DEFAULT '#4CAF50',
      is_default INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE transactions (
      id TEXT NOT NULL PRIMARY KEY,
      wallet_id TEXT NOT NULL,
      idaccount INTEGER NOT NULL,
      category_id TEXT,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      date INTEGER NOT NULL,
      images TEXT NOT NULL DEFAULT '[]',
      sync_status TEXT NOT NULL DEFAULT 'pending',
      updated_at INTEGER NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');
  database.execute('''
    CREATE TABLE budgets (
      id TEXT NOT NULL PRIMARY KEY,
      idaccount INTEGER NOT NULL,
      category_id TEXT,
      amount REAL NOT NULL,
      start_date INTEGER NOT NULL,
      end_date INTEGER,
      period TEXT NOT NULL DEFAULT 'monthly',
      note TEXT NOT NULL DEFAULT '',
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE bills (
      id TEXT NOT NULL PRIMARY KEY,
      idaccount INTEGER NOT NULL,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      due_date INTEGER NOT NULL,
      is_paid INTEGER NOT NULL DEFAULT 0,
      recurrence TEXT NOT NULL DEFAULT 'monthly',
      icon TEXT NOT NULL DEFAULT 'receipt',
      colour TEXT NOT NULL DEFAULT '#4CAF50',
      note TEXT NOT NULL DEFAULT '',
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE goals (
      id TEXT NOT NULL PRIMARY KEY,
      idaccount INTEGER NOT NULL,
      name TEXT NOT NULL,
      target_amount REAL NOT NULL,
      current_amount REAL NOT NULL DEFAULT 0,
      target_date INTEGER NOT NULL,
      wallet_id TEXT,
      icon TEXT NOT NULL DEFAULT 'flag',
      colour TEXT NOT NULL DEFAULT '#4CAF50',
      note TEXT NOT NULL DEFAULT '',
      is_completed INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      updated_at INTEGER NOT NULL
    )
  ''');
}

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
        _createLegacyNonCategoryTables(database);
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
        database.execute('''
          INSERT INTO categories (
            id, idaccount, name, classify, icon, colour,
            is_default, is_deleted, parent_id, is_group, is_local_only,
            sync_status, updated_at
          ) VALUES (
            'legacy-food', 1, 'Legacy food', 'chi', 'category', '#4CAF50',
            0, 0, NULL, 0, 0, 'synced', 1787270400000
          )
        ''');
        _createLegacyNonCategoryTables(database);
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
    expect((await upgraded.categoryDao.getById('legacy-food'))!.name,
        'Legacy food');
  });

  // Hai API này KHÔNG trả về hàng thô: chúng khử trùng lặp theo tên (thêm có
  // chủ đích để sửa lỗi danh mục hiển thị trùng khi bản seed cục bộ 'cat_food'
  // và bản UUID từ backend cùng tồn tại). Test này khoá lại đúng hành vi đó.
  test(
      'chỉ trả về danh mục nhìn thấy được, đã khử trùng lặp theo tên, '
      'từ cả hai API', () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'global-transport',
      idaccount: 0,
      name: 'Transport',
      classify: 'chi',
      isDefault: const Value(true),
      updatedAt: now,
    ));
    // Trùng tên với 'personal-food' bên dưới → hai cái sẽ bị gộp làm một.
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
      final ids = rows.map((row) => row.id);
      // Danh mục mặc định (idaccount = 0) vẫn hiển thị cho người dùng.
      expect(ids, contains('global-transport'));
      // Đã xoá mềm và của tài khoản khác thì không hiện.
      expect(ids, isNot(contains('deleted-food')));
      expect(ids, isNot(contains('other-account-food')));
      // Trùng tên "Food" chỉ còn MỘT — bản của chính người dùng thắng bản mặc
      // định vì truy vấn sắp xếp theo idaccount giảm dần.
      expect(rows.where((row) => row.name == 'Food'), hasLength(1));
      expect(ids, contains('personal-food'));
      expect(ids, isNot(contains('global-food')));
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

  test('moves a requested membership from another group in the same account',
      () async {
    final now = DateTime(2026, 8, 21);
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-food',
      categoryIds: ['cat_food', 'cat_drink'],
      now: now,
    );

    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-home',
      categoryIds: ['cat_food'],
      now: now,
    );

    final memberships = await db.categoryDao.getGroupMemberships(1);
    expect(
      memberships.where((membership) => membership.categoryId == 'cat_food'),
      hasLength(1),
    );
    expect(
      memberships
          .singleWhere((membership) => membership.categoryId == 'cat_food')
          .groupId,
      'group-home',
    );
    expect(
      memberships
          .singleWhere((membership) => membership.categoryId == 'cat_drink')
          .groupId,
      'group-food',
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
