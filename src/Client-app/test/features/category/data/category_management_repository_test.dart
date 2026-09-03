import 'dart:async';

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
      accountOneTree.ungroupedChildren.map((category) => category.id),
      isNot(contains('default-utilities')),
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

  test('moves a default membership when saving a second personal group',
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
      childIds: ['default-utilities'],
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

    await repository.saveGroup(CategoryGroupDraft(
      id: 'group-work',
      accountId: 1,
      name: 'Work',
      classify: 'chi',
      icon: 'work',
      colour: '#2196F3',
      childIds: ['default-utilities'],
    ));

    final tree = await repository.loadTree(accountId: 1, classify: 'chi');
    final home =
        tree.groups.singleWhere((node) => node.group.id == 'group-home');
    final work =
        tree.groups.singleWhere((node) => node.group.id == 'group-work');
    final memberships = await db.categoryDao.getGroupMemberships(1);

    expect(home.children, isEmpty);
    expect(work.children.map((category) => category.id), ['default-utilities']);
    expect(memberships, hasLength(1));
    expect(memberships.single.groupId, 'group-work');
    expect(memberships.single.categoryId, 'default-utilities');
    expect(
        (await db.categoryDao.getById('default-utilities'))!.parentId, isNull);
  });

  test('watchTree resolves membership-only changes without category writes',
      () async {
    await insertCategory(
      id: 'default-utilities',
      name: 'Utilities',
      accountId: 0,
      isDefault: true,
      isLocalOnly: false,
    );
    await insertCategory(id: 'group-home', name: 'Home', isGroup: true);

    final trees = StreamIterator(
      repository.watchTree(accountId: 1, classify: 'chi'),
    );
    addTearDown(trees.cancel);

    expect(
      await trees.moveNext().timeout(const Duration(seconds: 5)),
      isTrue,
    );
    expect(
      trees.current.ungroupedChildren.map((category) => category.id),
      contains('default-utilities'),
    );

    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-home',
      categoryIds: ['default-utilities'],
      now: DateTime(2026, 8, 22),
    );

    expect(
      await trees.moveNext().timeout(const Duration(seconds: 5)),
      isTrue,
    );
    expect(
      trees.current.groups.single.children.map((category) => category.id),
      ['default-utilities'],
    );
    expect(
      trees.current.ungroupedChildren.map((category) => category.id),
      isNot(contains('default-utilities')),
    );

    await db.categoryDao.removeGroupMemberships(1, 'group-home');

    expect(
      await trees.moveNext().timeout(const Duration(seconds: 5)),
      isTrue,
    );
    expect(
      trees.current.groups.single.children.map((category) => category.id),
      isEmpty,
    );
    expect(
      trees.current.ungroupedChildren.map((category) => category.id),
      contains('default-utilities'),
    );
  });

  test('rejects a default child that does not match the group classify',
      () async {
    await insertCategory(
      id: 'default-salary',
      name: 'Salary',
      accountId: 0,
      classify: 'thu',
      isDefault: true,
      isLocalOnly: false,
    );

    await expectLater(
      repository.saveGroup(CategoryGroupDraft(
        id: 'group-home',
        accountId: 1,
        name: 'Home',
        classify: 'chi',
        icon: 'home',
        colour: '#4CAF50',
        childIds: ['default-salary'],
      )),
      throwsA(isA<CategoryValidationException>()),
    );

    expect(await db.categoryDao.getById('group-home'), isNull);
    expect(await db.categoryDao.getGroupMemberships(1), isEmpty);
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

  group('Tên danh mục là duy nhất trong phạm vi tài khoản', () {
    // Quy tắc đã chốt: trong phạm vi một tài khoản, tên danh mục là duy nhất —
    // bất kể `classify`, bất kể nằm trong nhóm nào, và nhóm / danh mục con /
    // danh mục MẶC ĐỊNH dùng chung một không gian tên. So tên không phân biệt
    // hoa thường và gom khoảng trắng thừa; hàng đã xoá mềm không giữ chỗ.
    //
    // Lưu ý khi thêm test ở đây: `AppDatabase.forTesting` chạy `onCreate` nên
    // CSDL đã có sẵn 18 danh mục mặc định (Ăn uống, Di chuyển, Lương, Giải
    // trí…). Đặt tên trùng một trong số đó thì lệnh tạo ĐẦU TIÊN đã bị chặn —
    // dùng tên nằm ngoài danh sách seed cho các test không nhắm vào danh mục
    // mặc định.

    Future<void> makeGroup(String id, String name, {String classify = 'chi'}) =>
        repository.saveGroup(CategoryGroupDraft(
          id: id,
          accountId: 1,
          name: name,
          classify: classify,
          icon: 'folder',
          colour: '#2196F3',
          childIds: const [],
        ));

    Future<void> makeChild(
      String id,
      String name, {
      String classify = 'chi',
      String? parentId,
    }) =>
        repository.saveChild(CategoryChildDraft(
          id: id,
          accountId: 1,
          name: name,
          classify: classify,
          parentId: parentId,
          icon: 'local_cafe',
          colour: '#795548',
          keywords: const [],
        ));

    test('Trùng tên khác CLASSIFY vẫn bị chặn', () async {
      await makeChild('thu-cung-chi', 'Thú cưng', classify: 'chi');

      await expectLater(
        makeChild('thu-cung-thu', 'Thú cưng', classify: 'thu'),
        throwsA(isA<CategoryValidationException>()),
        reason: 'Khoá duy nhất KHÔNG có classify. Trước đây bộ kiểm tra gọi '
            '`getCategoryRows(accountId, classify)` nên nó không bao giờ nhìn '
            'thấy danh mục thuộc loại khác — một danh mục trùng tên lọt qua '
            'client rồi vỡ ràng buộc ở PostgreSQL, và hỏng âm thầm.',
      );
    });

    test('Trùng tên ở NHÓM CHA KHÁC vẫn bị chặn', () async {
      await makeGroup('nhom-a', 'Nhóm A');
      await makeGroup('nhom-b', 'Nhóm B');
      await makeChild('ca-phe-a', 'Cà phê', parentId: 'nhom-a');

      await expectLater(
        makeChild('ca-phe-b', 'Cà phê', parentId: 'nhom-b'),
        throwsA(isA<CategoryValidationException>()),
        reason: 'Mỗi nhóm KHÔNG phải một không gian tên riêng. Trước đây '
            '`parentId` nằm trong khoá kiểm tra nên client cho tạo, còn '
            'PostgreSQL (unique không có Idgroup) thì chặn.',
      );
    });

    test('Nhóm và danh mục con dùng CHUNG một không gian tên', () async {
      await makeGroup('nhom-thu-cung', 'Thú cưng');

      await expectLater(
        makeChild('con-thu-cung', 'Thú cưng'),
        throwsA(isA<CategoryValidationException>()),
        reason: 'Trước đây hai hàm kiểm tra loại trừ lẫn nhau qua cờ isGroup, '
            'nên một nhóm và một danh mục con trùng tên đều lọt qua.',
      );
    });

    test('Danh mục con chặn ngược lại việc đặt tên nhóm trùng', () async {
      await makeChild('con-sach-vo', 'Sách vở');

      await expectLater(
        makeGroup('nhom-sach-vo', 'Sách vở'),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('So tên bỏ qua hoa/thường và khoảng trắng thừa', () async {
      await makeChild('goc', '  Cà   Phê ');

      await expectLater(
        makeChild('bien-the', 'cà phê'),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('Danh mục đã xoá mềm KHÔNG giữ chỗ tên', () async {
      await insertCategory(id: 'da-xoa', name: 'Thú cưng', isDeleted: true);

      await makeChild('tao-lai', 'Thú cưng');

      expect((await db.categoryDao.getById('tao-lai'))!.name, 'Thú cưng');
    });

    test('Tên của TÀI KHOẢN KHÁC không chặn', () async {
      await insertCategory(
        id: 'cua-nguoi-khac',
        name: 'Thú cưng',
        accountId: 2,
      );

      await makeChild('cua-minh', 'Thú cưng');

      expect((await db.categoryDao.getById('cua-minh'))!.name, 'Thú cưng');
    });

    test('Sửa chính danh mục đó thì không tự coi là trùng', () async {
      await makeChild('tu-sua', 'Thú cưng');

      await makeChild('tu-sua', 'Thú Cưng');

      expect((await db.categoryDao.getById('tu-sua'))!.name, 'Thú Cưng');
    });

    // ── Trùng với danh mục MẶC ĐỊNH ─────────────────────────────────────────
    // Các test dưới đây cố ý dùng thẳng danh mục mặc định do `onCreate` seed
    // sẵn, thay vì tự chèn — như vậy mới đúng thứ người dùng thật gặp phải.

    test('KHÔNG được đặt trùng tên với danh mục mặc định', () async {
      await expectLater(
        makeChild('rieng-an-uong', 'Ăn uống'),
        throwsA(isA<CategoryValidationException>()),
        reason: 'Danh mục mặc định và danh mục người dùng dùng CHUNG một không '
            'gian tên: người dùng nhìn thấy cả hai trong cùng một danh sách '
            'chọn, nên hai mục trùng tên là không phân biệt được.',
      );
    });

    test('Trùng tên danh mục mặc định vẫn bị chặn dù khác loại', () async {
      // 'Lương' được seed là danh mục THU.
      await expectLater(
        makeChild('chi-luong', 'Lương', classify: 'chi'),
        throwsA(isA<CategoryValidationException>()),
        reason: 'Classify không nằm trong khoá, kể cả khi phía kia là danh mục '
            'mặc định.',
      );
    });

    test('Nhóm cũng không được trùng tên với danh mục mặc định', () async {
      await expectLater(
        makeGroup('nhom-di-chuyen', 'Di chuyển'),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('So tên với danh mục mặc định cũng bỏ qua hoa/thường', () async {
      await expectLater(
        makeChild('rieng-mua-sam', '  mua   SẮM '),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('Danh mục mặc định ĐÃ XOÁ thì không giữ chỗ tên', () async {
      await insertCategory(
        id: 'mac-dinh-da-xoa',
        name: 'Du lịch',
        accountId: 0,
        isDefault: true,
        isDeleted: true,
        isLocalOnly: false,
      );

      await makeChild('rieng-du-lich', 'Du lịch');

      expect((await db.categoryDao.getById('rieng-du-lich'))!.name, 'Du lịch');
    });
  });

  test('rejects a duplicate child name regardless of which group it goes into',
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

    // Trước 2026-09-03 khối dưới đây được coi là HỢP LỆ: mỗi nhóm là một không
    // gian tên riêng. Quy tắc đã chốt lại — tên là duy nhất trong phạm vi tài
    // khoản, bất kể nhóm cha — và PostgreSQL vốn vẫn luôn chặn trường hợp này
    // (unique không có Idgroup), nên hành vi cũ chỉ tạo ra dữ liệu đẩy lên là
    // hỏng.
    await expectLater(
      repository.saveChild(CategoryChildDraft(
        id: 'child-coffee-work',
        accountId: 1,
        name: 'coffee',
        classify: 'chi',
        parentId: 'group-work',
        icon: 'local_cafe',
        colour: '#795548',
        keywords: [],
      )),
      throwsA(isA<CategoryValidationException>()),
    );
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

  // Danh mục người dùng giờ được đồng bộ với backend (isLocalOnly = false),
  // nên chúng PHẢI xoá được — việc xoá sẽ đẩy delete_at lên backend.
  // Danh mục mặc định vẫn được _rejectDefault() bảo vệ như cũ.
  test('deletes a synced personal child and marks it for sync', () async {
    await insertCategory(
      id: 'server-child',
      name: 'Server child',
      isLocalOnly: false,
    );

    await repository.deleteChild(accountId: 1, childId: 'server-child');

    final deleted = (await db.categoryDao.getById('server-child'))!;
    expect(deleted.isDeleted, isTrue);
    expect(deleted.syncStatus, 'pending');
  });

  test('rolls back group deletion when the group update fails', () async {
    await insertCategory(id: 'group-food', name: 'Food', isGroup: true);
    await insertCategory(
      id: 'child-coffee',
      name: 'Coffee',
      parentId: 'group-food',
    );
    await insertCategory(
      id: 'default-utilities',
      name: 'Utilities',
      accountId: 0,
      isDefault: true,
      isLocalOnly: false,
    );
    await db.categoryDao.replaceGroupMemberships(
      accountId: 1,
      groupId: 'group-food',
      categoryIds: ['default-utilities'],
      now: DateTime(2026, 8, 22),
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
    expect(
      (await db.categoryDao.getGroupMemberships(1))
          .map((membership) => membership.categoryId),
      ['default-utilities'],
    );
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
