import 'package:drift/drift.dart' hide isNull, isNotNull;
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
///
/// [atVersion] là phiên bản lược đồ mà CSDL giả tự khai qua `PRAGMA
/// user_version`, và **phải khớp** với giá trị test đặt. Migration là cộng dồn:
/// một máy ở v7 nhất thiết đã chạy qua các bước `from < 6` và `from < 7`, nên
/// fixture khai v7 mà lại thiếu những cột hai bước đó thêm vào là mô tả một
/// trạng thái không tồn tại ngoài đời. Hiện chỉ bảng `budgets` dùng tham số
/// này — thêm bảng khác khi có bước migration nào đọc tới chúng.
// `database` là sqlite3.Database do NativeDatabase.memory(setup:) truyền vào.
// Dùng dynamic để khỏi phải thêm `sqlite3` làm phụ thuộc trực tiếp.
void _createLegacyNonCategoryTables(dynamic database, {int atVersion = 2}) {
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
  // `budgets` phải mang đúng những cột mà [atVersion] hẳn đã có trên máy thật.
  //
  // Trước đây bảng này luôn ở hình dạng trước v5 kể cả khi test khai
  // `user_version = 7` hoặc `9` — một trạng thái KHÔNG tồn tại trên máy người
  // dùng, vì migration là cộng dồn: ai ở v7 thì đã chạy qua bước `from < 6` và
  // `from < 7` rồi. Chuyện đó không lộ ra cho tới khi v11 dựng lại bảng
  // `budgets` bằng `TableMigration` và câu SELECT đi tìm những cột fixture
  // không có.
  final budgetColumns = <String>[
    'id TEXT NOT NULL PRIMARY KEY',
    'idaccount INTEGER NOT NULL',
    'category_id TEXT',
    'amount REAL NOT NULL',
    'start_date INTEGER NOT NULL',
    'end_date INTEGER',
    "period TEXT NOT NULL DEFAULT 'monthly'",
    "note TEXT NOT NULL DEFAULT ''",
    'is_deleted INTEGER NOT NULL DEFAULT 0',
    "sync_status TEXT NOT NULL DEFAULT 'pending'",
    'updated_at INTEGER NOT NULL',
    if (atVersion >= 6) ...[
      'spent REAL NOT NULL DEFAULT 0',
      'remaining REAL',
      'percent_spent INTEGER NOT NULL DEFAULT 0',
      "over_spending TEXT NOT NULL DEFAULT 'Over'",
      'over_amount REAL',
      'recurrence INTEGER NOT NULL DEFAULT 0',
      "time_recurrence TEXT NOT NULL DEFAULT 'Month'",
      'deleted_at INTEGER',
    ],
    if (atVersion >= 7) ...[
      'threshold_warning_amount REAL',
      'next_time_recurrence INTEGER',
    ],
    if (atVersion >= 9) ...[
      'sync_retry_count INTEGER NOT NULL DEFAULT 0',
      'sync_error TEXT',
      'sync_blocked_until INTEGER',
    ],
  ];
  database.execute('CREATE TABLE budgets (${budgetColumns.join(', ')})');
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

  test(
      'migration v7 lên v8 đưa nhóm danh mục cũ (is_local_only = 1) trở lại hàng đợi đẩy',
      () async {
    await db.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        // Bảng categories ở đúng hình dạng v7. Bước v7→v8 chỉ chạy UPDATE chứ
        // không ALTER TABLE, nên fixture không cần tới các bảng khác.
        database.execute("""
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
            deleted_at INTEGER,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            updated_at INTEGER NOT NULL
          )
        """);
        // Nhóm + danh mục con tạo bằng bản app CŨ: bị đánh dấu local-only nên
        // chưa bao giờ được đẩy lên backend.
        database.execute("""
          INSERT INTO categories (
            id, idaccount, name, classify, is_group, is_local_only,
            sync_status, updated_at
          ) VALUES (
            'legacy-group', 1, 'Nhom cu', 'chi', 1, 1, 'synced', 1787270400000
          )
        """);
        database.execute("""
          INSERT INTO categories (
            id, idaccount, name, classify, parent_id, is_local_only,
            sync_status, updated_at
          ) VALUES (
            'legacy-child', 1, 'Con cua nhom cu', 'chi', 'legacy-group', 1,
            'synced', 1787270400000
          )
        """);
        // Danh mục đã đồng bộ bình thường — migration KHÔNG được đụng tới.
        database.execute("""
          INSERT INTO categories (
            id, idaccount, name, classify, is_local_only, sync_status,
            updated_at
          ) VALUES (
            'already-synced', 1, 'Da dong bo', 'chi', 0, 'synced', 1787270400000
          )
        """);
        // v8→v9 thêm cột trạng thái thất bại cho CẢ SÁU bảng, nên fixture
        // phải có đủ chúng — nếu không, migration chết vì thiếu bảng chứ không
        // phải vì logic sai.
        _createLegacyNonCategoryTables(database, atVersion: 7);
        database.execute('PRAGMA user_version = 7');
      },
    ));
    addTearDown(upgraded.close);

    final syncable = await upgraded.categoryDao.getSyncableCategories(1);

    expect(
      syncable.map((row) => row.id),
      containsAll(['legacy-group', 'legacy-child']),
      reason: 'Canh chừng G11: nhóm danh mục tạo trước 2026-09-02 mang '
          'is_local_only = 1, và getSyncableCategories loại mọi hàng như vậy '
          'khỏi batch đẩy. Không có migration lật cờ thì nhóm cũ KHÔNG BAO GIỜ '
          'lên được backend, và hỏng hoàn toàn im lặng.',
    );

    final untouched = await upgraded.categoryDao.getById('already-synced');
    expect(
      untouched?.syncStatus,
      'synced',
      reason: 'Migration chỉ được đụng vào hàng is_local_only = 1. Đánh dấu '
          'pending cho mọi danh mục sẽ đẩy lại toàn bộ dữ liệu lên backend '
          'sau mỗi lần nâng cấp.',
    );
  });

  group('getByName — ánh xạ danh mục mặc định cục bộ sang UUID của backend', () {
    // `_resolveCategoryId` dùng hàm này để tìm bản UUID cùng tên. Trước đây nó
    // so bằng `t.name.equals(name)` nên phân biệt hoa/thường và không gộp dạng
    // Unicode; lệch một chữ hoa là ánh xạ thất bại, giao dịch bị hoãn đẩy VĨNH
    // VIỄN mà không có lỗi nào báo ra.

    Future<void> seedServerCategory(String name) =>
        db.categoryDao.insert(CategoriesCompanion.insert(
          id: '11111111-1111-4111-8111-111111111111',
          idaccount: 0,
          name: name,
          classify: 'chi',
          isDefault: const Value(true),
          updatedAt: DateTime(2026, 9, 3),
        ));

    test('Khớp dù lệch hoa/thường', () async {
      await seedServerCategory('Ăn Uống');

      final found = await db.categoryDao.getByName('ăn uống');

      expect(found.map((c) => c.id),
          contains('11111111-1111-4111-8111-111111111111'),
          reason: 'Client seed "Ăn uống" còn backend trả "Ăn Uống" là đủ để '
              'ánh xạ hỏng, và hỏng hoàn toàn im lặng.');
    });

    test('Khớp dù thừa khoảng trắng', () async {
      await seedServerCategory('Thú cưng');

      final found = await db.categoryDao.getByName('  Thú   cưng  ');

      expect(found, hasLength(1));
    });

    test('Khớp dù khác dạng Unicode', () async {
      // Dạng tách dấu, dựng bằng escape code point cho xác định.
      const nfd = 'Cà phê';
      await seedServerCategory('Cà phê'); // dạng dựng sẵn

      final found = await db.categoryDao.getByName(nfd);

      expect(found, hasLength(1),
          reason: 'Hai chuỗi nhìn y hệt nhau nhưng khác byte — nếu không gộp '
              'NFC thì ánh xạ trượt mà không ai nhìn ra được.');
    });

    test('KHÔNG khớp tên thật sự khác', () async {
      await seedServerCategory('Ăn uống');

      expect(await db.categoryDao.getByName('An uong'), isEmpty,
          reason: 'Bỏ dấu sẽ gộp nhầm hai danh mục khác nhau.');
    });

    test('Bỏ qua hàng đã xoá', () async {
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'da-xoa',
        idaccount: 0,
        name: 'Thú cưng',
        classify: 'chi',
        isDefault: const Value(true),
        deletedAt: Value(DateTime(2026, 9, 1)),
        updatedAt: DateTime(2026, 9, 3),
      ));

      expect(await db.categoryDao.getByName('Thú cưng'), isEmpty);
    });
  });

  test(
      'migration v9 lên v10 đổi tên 3 danh mục mặc định cho khớp backend',
      () async {
    await db.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        database.execute("""
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
            deleted_at INTEGER,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            sync_retry_count INTEGER NOT NULL DEFAULT 0,
            sync_error TEXT,
            sync_blocked_until INTEGER,
            updated_at INTEGER NOT NULL
          )
        """);
        void seed(String id, String name) => database.execute("""
          INSERT INTO categories (id, idaccount, name, classify, is_default,
            sync_status, updated_at)
          VALUES ('$id', 0, '$name', 'chi', 1, 'synced', 1787270400000)
        """);
        seed('cat_health', 'Sức khoẻ');
        seed('cat_housing', 'Nhà ở');
        seed('cat_bill_chi', 'Hoá đơn & Dịch vụ');
        // Danh mục của NGƯỜI DÙNG trùng id — migration không được đụng tới.
        database.execute("""
          INSERT INTO categories (id, idaccount, name, classify, is_default,
            sync_status, updated_at)
          VALUES ('rieng-cua-toi', 7, 'Nhà ở', 'chi', 0, 'synced', 1787270400000)
        """);
        _createLegacyNonCategoryTables(database, atVersion: 9);
        database.execute('PRAGMA user_version = 9');
      },
    ));
    addTearDown(upgraded.close);

    expect((await upgraded.categoryDao.getById('cat_health'))!.name, 'Y tế');
    expect((await upgraded.categoryDao.getById('cat_housing'))!.name, 'Nhà cửa');
    expect(
      (await upgraded.categoryDao.getById('cat_bill_chi'))!.name,
      'Hóa đơn',
      reason: 'Ba mục này chỉ khác NHÃN so với backend. Không đổi tên thì '
          '_resolveCategoryId không tìm được bản UUID cùng tên, trả null, và '
          'giao dịch dùng chúng bị hoãn đẩy vĩnh viễn — hỏng hoàn toàn im lặng.',
    );

    expect(
      (await upgraded.categoryDao.getById('rieng-cua-toi'))!.name,
      'Nhà ở',
      reason: 'Migration chỉ đụng hàng is_default = 1. Danh mục người dùng tự '
          'đặt tên là dữ liệu của họ, không được sửa.',
    );

    expect(
      (await upgraded.categoryDao.getById('cat_health'))!.isDeleted,
      isFalse,
      reason: 'Đổi tên chứ KHÔNG xoá hàng — xoá hàng seed trước khi giao dịch '
          'được repoint chính là lỗi 11.6.',
    );
  });

  // ── Dọn hậu quả của G14 ────────────────────────────────────────────────────
  //
  // Bản client trước 2026-09-04 tạo 5 danh mục cá nhân TRƯỚC lần pull đầu tiên,
  // nên trên máy mới nó sinh ra bản trùng tên với bản đã có trên backend. Bản vá
  // ngăn phát sinh mới, nhưng máy đã lỡ tạo thì vẫn giữ những hàng `pending` đó
  // và chúng hỏng ở MỌI chu kỳ đẩy — kéo cả engine vào giãn cách.
  //
  // `mergeDuplicatePersonalCategories` dọn nốt: chuyển tham chiếu sang bản của
  // server rồi xoá VẬT LÝ bản cục bộ. Xoá vật lý là đúng ở đây — bản đó chưa
  // từng tồn tại trên server nên không có gì để đồng bộ, còn xoá mềm sẽ để lại
  // một thao tác đẩy vô nghĩa.

  group('mergeDuplicatePersonalCategories — dọn bản trùng do máy tự tạo', () {
    const acc = 7;
    const idServer = '11111111-1111-4111-8111-111111111111';
    const idLocal = '22222222-2222-4222-8222-222222222222';

    Future<void> catRieng(
      String id,
      String name, {
      String classify = 'chi',
      String syncStatus = 'pending',
      String? parentId,
      bool isGroup = false,
    }) =>
        db.categoryDao.insert(CategoriesCompanion.insert(
          id: id,
          idaccount: acc,
          name: name,
          classify: classify,
          isDefault: const Value(false),
          isGroup: Value(isGroup),
          parentId: Value(parentId),
          syncStatus: Value(syncStatus),
          updatedAt: DateTime(2026, 9, 4),
        ));

    // Cố ý KHÔNG dùng `getAll`: hàm đó khử trùng lặp theo (classify, tên chuẩn
    // hoá) trước khi trả về, tức giấu đúng những hàng nhóm test này đang đo.
    // `getNamesInUse` trả nguyên hàng thật trong bảng.
    Future<List<Category>> conLai() async =>
        (await db.categoryDao.getNamesInUse(acc))
            .where((c) => !c.isDefault)
            .toList();

    setUp(() async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w-1',
        idaccount: acc,
        name: 'Tiền mặt',
        updatedAt: DateTime(2026, 9, 4),
      ));
    });

    test('bản pending trùng tên bị gộp vào bản đã có trên server', () async {
      await catRieng(idServer, 'Chi khác', syncStatus: 'synced');
      await catRieng(idLocal, 'Chi khác');

      final gop = await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      expect(gop, 1);
      final rows = await conLai();
      expect(rows, hasLength(1));
      expect(rows.single.id, idServer,
          reason: 'Bản của server là bản THẬT — nó đã tồn tại ở nơi khác. Giữ '
              'bản cục bộ thì thao tác đẩy của nó vẫn hỏng mãi.');
      expect(await db.categoryDao.getById(idLocal), isNull,
          reason: 'Xoá VẬT LÝ: bản này chưa từng lên server nên không có gì để '
              'đồng bộ; xoá mềm sẽ để lại một thao tác đẩy vô nghĩa.');
    });

    test('giao dịch được chuyển sang bản của server TRƯỚC khi xoá', () async {
      await catRieng(idServer, 'Chi khác', syncStatus: 'synced');
      await catRieng(idLocal, 'Chi khác');
      await db.transactionDao.insert(TransactionsCompanion.insert(
        id: 'tx-1',
        walletId: 'w-1',
        idaccount: acc,
        amount: 50000,
        type: 'chi',
        date: DateTime(2026, 9, 4),
        categoryId: const Value(idLocal),
        updatedAt: DateTime(2026, 9, 4),
      ));

      await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      final tx = (await db.transactionDao.getAll(acc)).single;
      expect(tx.categoryId, idServer,
          reason: 'Xoá trước, repoint sau thì giao dịch trỏ vào một hàng không '
              'còn tồn tại — đúng lỗi 11.6.');
      expect(tx.syncStatus, 'pending',
          reason: 'Giao dịch vừa đổi danh mục nên phải được đẩy lại.');
    });

    test('không có bản synced nào thì KHÔNG xoá gì', () async {
      await catRieng(idServer, 'Chi khác');
      await catRieng(idLocal, 'Chi khác');

      final gop = await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      expect(gop, 0);
      expect(await conLai(), hasLength(2),
          reason: 'Cả hai đều chưa lên server thì không có bằng chứng bản nào '
              'là bản thật. Đoán bừa rồi xoá là mất dữ liệu người dùng.');
    });

    test('không bao giờ xoá một bản đã synced', () async {
      await catRieng(idServer, 'Chi khác', syncStatus: 'synced');
      await catRieng(idLocal, 'chi  KHÁC', syncStatus: 'synced');

      final gop = await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      expect(gop, 0);
      expect(await conLai(), hasLength(2),
          reason: 'Hai bản cùng tên mà cả hai đều có trên server là chuyện của '
              'dữ liệu backend. Client xoá bên nào cũng là xoá dữ liệu thật.');
    });

    test('khớp tên theo dạng chuẩn hoá, không phải so chuỗi thô', () async {
      await catRieng(idServer, 'Chi khác', syncStatus: 'synced');
      await catRieng(idLocal, 'chi  KHÁC');

      await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      expect(await conLai(), hasLength(1),
          reason: 'Backend so tên sau chuẩn hoá nên vẫn coi là trùng; so chuỗi '
              'thô ở client sẽ bỏ sót đúng những bản đang gây hỏng.');
    });

    test('bỏ qua tài khoản khác và danh mục mặc định', () async {
      await catRieng(idServer, 'Chi khác', syncStatus: 'synced');
      await catRieng(idLocal, 'Chi khác');
      // Cùng tên nhưng của tài khoản khác — không được đụng tới.
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: '33333333-3333-4333-8333-333333333333',
        idaccount: 99,
        name: 'Chi khác',
        classify: 'chi',
        updatedAt: DateTime(2026, 9, 4),
      ));
      // Danh mục mặc định cùng tên — dùng chung, không thuộc tài khoản nào.
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'cat_default_other',
        idaccount: 0,
        name: 'Chi khác',
        classify: 'chi',
        isDefault: const Value(true),
        updatedAt: DateTime(2026, 9, 4),
      ));

      await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      expect(
          await db.categoryDao.getById('33333333-3333-4333-8333-333333333333'),
          isNotNull);
      expect(await db.categoryDao.getById('cat_default_other'), isNotNull);
    });

    test('danh mục con đang trỏ vào bản bị xoá được chuyển sang bản giữ lại',
        () async {
      await catRieng(idServer, 'Nhóm A', syncStatus: 'synced', isGroup: true);
      await catRieng(idLocal, 'Nhóm A', isGroup: true);
      await catRieng('44444444-4444-4444-8444-444444444444', 'Con',
          parentId: idLocal);

      await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      final con = await db.categoryDao
          .getById('44444444-4444-4444-8444-444444444444');
      expect(con!.parentId, idServer,
          reason: 'Bỏ sót parentId thì danh mục con trỏ vào một hàng đã bị xoá '
              'vật lý, và cây danh mục đứt ở giữa.');
    });

    test('từ khoá của bản bị xoá được chuyển sang, không tạo bản trùng',
        () async {
      await catRieng(idServer, 'Chi khác', syncStatus: 'synced');
      await catRieng(idLocal, 'Chi khác');
      await db.categoryDao.replaceKeywords(
        accountId: acc,
        categoryId: idLocal,
        keywords: ['cà phê', 'trà sữa'],
        now: DateTime(2026, 9, 4),
      );
      await db.categoryDao.replaceKeywords(
        accountId: acc,
        categoryId: idServer,
        keywords: ['cà phê'],
        now: DateTime(2026, 9, 4),
      );

      await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      final kw = await db.categoryDao.getKeywords(acc, idServer);
      expect(kw.toSet(), {'cà phê', 'trà sữa'},
          reason: 'Từ khoá là dữ liệu người dùng gõ tay — chuyển sang chứ '
              'không vứt. "cà phê" đã có bên đích nên không nhân đôi.');
      expect(await db.categoryDao.getKeywords(acc, idLocal), isEmpty);
    });

    test('không có gì trùng thì không đụng vào gì', () async {
      await catRieng(idServer, 'Chi khác', syncStatus: 'synced');
      await catRieng(idLocal, 'Thu khác', classify: 'thu');

      final gop = await db.categoryDao.mergeDuplicatePersonalCategories(acc);

      expect(gop, 0);
      expect(await conLai(), hasLength(2));
    });
  });
}
