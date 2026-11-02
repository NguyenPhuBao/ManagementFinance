import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// Danh mục của NHÀ (gia đình, spec 2026-11-01 mục 7.2): sửa không được làm rơi `idhousehold` — `categoryDao.insert` là
/// `insertOrReplace`, thiếu trường là danh mục nhà thành danh mục riêng, im lặng.
void main() {
  late AppDatabase db;
  late CategoryManagementRepositoryImpl repo;

  Future<void> them(
    String id,
    String ten, {
    int idaccount = 20,
    int? idhousehold,
    String classify = 'chi',
    bool isGroup = false,
    bool xoa = false,
    List<String> tuKhoa = const [],
  }) async {
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: id,
      idaccount: idaccount,
      name: ten,
      classify: classify,
      idhousehold: Value(idhousehold),
      isGroup: Value(isGroup),
      isLocalOnly: const Value(false),
      syncStatus: const Value('synced'),
      deletedAt: Value(xoa ? DateTime(2026, 9, 1) : null),
      updatedAt: DateTime(2026, 8, 21),
    ));
    if (tuKhoa.isNotEmpty) {
      await db.categoryDao.replaceKeywords(
          accountId: idaccount, categoryId: id, keywords: tuKhoa, now: DateTime(2026, 8, 21));
    }
  }

  CategoryChildDraft draft({
    String? id,
    required String ten,
    int accountId = 10,
    int? idhousehold,
    String? parentId,
    List<String> keywords = const [],
  }) =>
      CategoryChildDraft(
        id: id,
        accountId: accountId,
        name: ten,
        classify: 'chi',
        parentId: parentId,
        icon: 'icon',
        colour: '#FFFFFF',
        keywords: keywords,
        idhousehold: idhousehold,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryManagementRepositoryImpl(db: db);
  });
  tearDown(() => db.close());

  test('sửa danh mục của nhà giữ idhousehold, giữ người tạo, đánh dấu pending', () async {
    await them('dn', 'Tiền chợ', idaccount: 20, idhousehold: 7);
    await repo.saveChild(draft(id: 'dn', ten: 'Tiền chợ mới', accountId: 10, idhousehold: 7));
    final h = (await db.categoryDao.getById('dn'))!;
    expect(h.name, 'Tiền chợ mới');
    expect(h.idhousehold, 7,
        reason: 'insertOrReplace thay cả hàng, thiếu trường là danh mục nhà thành danh mục riêng im lặng');
    expect(h.idaccount, 20, reason: 'idaccount là người tạo, không đổi khi người khác sửa');
    expect(h.syncStatus, 'pending');
  });

  test('draft không nêu idhousehold mà hàng đang thuộc nhà: vẫn giữ nhà', () async {
    await them('dn', 'Tiền chợ', idaccount: 20, idhousehold: 7);
    await repo.saveChild(draft(id: 'dn', ten: 'Tiền chợ 2', accountId: 10));
    final h = (await db.categoryDao.getById('dn'))!;
    expect(h.idhousehold, 7, reason: 'đường sửa cá nhân không được lặng lẽ kéo danh mục nhà về riêng');
    expect(h.idaccount, 20);
  });

  test('danh mục của nhà do người khác tạo: thành viên sửa được; hàng RIÊNG của người khác vẫn bị từ chối', () async {
    await them('rieng', 'Của người khác', idaccount: 20);
    await expectLater(
      repo.saveChild(draft(id: 'rieng', ten: 'Đổi tên', accountId: 10)),
      throwsA(isA<CategoryValidationException>()),
      reason: 'chốt chủ sở hữu chỉ nới cho hàng có idhousehold',
    );
  });

  test('tạo mới danh mục của nhà: idaccount = người tạo, idhousehold từ draft, pending', () async {
    await repo.saveChild(draft(ten: 'Điện nước', accountId: 10, idhousehold: 7));
    final hang = (await db.categoryDao.getCuaNha(7)).single;
    expect(hang.idaccount, 10);
    expect(hang.idhousehold, 7);
    expect(hang.syncStatus, 'pending');
  });

  test('sửa danh mục của nhà không đổi từ khoá đang có', () async {
    await them('dn', 'Tiền chợ', idaccount: 20, idhousehold: 7, tuKhoa: ['cho', 'sieu thi']);
    await repo.saveChild(draft(id: 'dn', ten: 'Tiền chợ mới', accountId: 10, idhousehold: 7, keywords: ['khac']));
    final tu = (await (db.select(db.categoryKeywords)..where((k) => k.categoryId.equals('dn'))).get())
        .map((k) => '${k.idaccount}:${k.keyword}')
        .toSet();
    expect(tu, {'20:cho', '20:sieu thi'},
        reason: 'từ khoá gắn idaccount người sửa rồi đẩy lên cột chung sẽ đè nhau — 1A danh mục nhà không sửa từ khoá');
  });

  test('nhóm cha là nhóm của nhà do người khác tạo: hợp lệ', () async {
    await them('nhom', 'Sinh hoạt', idaccount: 20, idhousehold: 7, isGroup: true);
    await repo.saveChild(draft(ten: 'Gas', accountId: 10, idhousehold: 7, parentId: 'nhom'));
    expect((await db.categoryDao.getCuaNha(7)).where((h) => h.name == 'Gas').single.parentId, 'nhom');
  });

  test('nhóm cha RIÊNG của người khác vẫn không hợp lệ', () async {
    await them('nhom', 'Nhóm riêng', idaccount: 20, isGroup: true);
    await expectLater(
      repo.saveChild(draft(ten: 'Gas', accountId: 10, parentId: 'nhom')),
      throwsA(isA<CategoryValidationException>()),
    );
  });

  test('kiểm trùng tên trong nhà; trùng với danh mục riêng thì được (cả hai chiều)', () async {
    await them('dn', 'Tiền chợ', idaccount: 20, idhousehold: 7);
    await them('rieng', 'Ăn sáng', idaccount: 10);

    await expectLater(
      repo.saveChild(draft(ten: '  tiền CHỢ ', accountId: 10, idhousehold: 7)),
      throwsA(isA<CategoryValidationException>()),
      reason: 'uq_category_household_name: tên chuẩn hoá duy nhất trong nhà',
    );
    // nhà trùng tên với danh mục riêng của tôi: được
    await repo.saveChild(draft(ten: 'Ăn sáng', accountId: 10, idhousehold: 7));
    // riêng trùng tên với danh mục của nhà: được
    await repo.saveChild(draft(ten: 'Tiền chợ', accountId: 10));
  });

  test('tên trùng hàng xoá mềm của nhà không giữ chỗ', () async {
    await them('cu', 'Điện', idaccount: 20, idhousehold: 7, xoa: true);
    await repo.saveChild(draft(ten: 'Điện', accountId: 10, idhousehold: 7));
    expect((await db.categoryDao.getCuaNha(7)).single.name, 'Điện');
  });

  test('sửa mà không đổi tên thì không xét trùng (hàng cũ trùng tên vẫn sửa được icon)', () async {
    await them('a1', 'Điện', idaccount: 20, idhousehold: 7);
    await them('a2', 'Điện', idaccount: 21, idhousehold: 7);
    await repo.saveChild(draft(id: 'a1', ten: 'Điện', accountId: 10, idhousehold: 7));
    expect((await db.categoryDao.getById('a1'))!.syncStatus, 'pending',
        reason: 'bỏ lối tắt currentName là hai hàng cũ trùng tên không sửa nổi nữa');
  });

  test('draft nhà sửa hàng RIÊNG của tôi: ném, hàng vẫn riêng', () async {
    await them('r', 'Riêng', idaccount: 10);
    await expectLater(repo.saveChild(draft(id: 'r', ten: 'Riêng', accountId: 10, idhousehold: 7)),
        throwsA(isA<CategoryValidationException>()));
    expect((await db.categoryDao.getById('r'))!.idhousehold, isNull,
        reason: 'hàng riêng lặng lẽ thành hàng nhà là biến khỏi danh sách cá nhân và HOUSEHOLD_SCOPE_MISMATCH');
  });

  test('draft nhà A sửa hàng nhà B: ném', () async {
    await them('b', 'Của B', idaccount: 20, idhousehold: 8);
    await expectLater(repo.saveChild(draft(id: 'b', ten: 'Của B', accountId: 10, idhousehold: 7)),
        throwsA(isA<CategoryValidationException>()));
    expect((await db.categoryDao.getById('b'))!.idhousehold, 8);
  });

  test('sửa hàng của nhà đã xoá mềm: ném, không sống lại (cả isDeleted lẫn deletedAt)', () async {
    await them('x', 'Đã xoá', idaccount: 20, idhousehold: 7, xoa: true);
    await expectLater(repo.saveChild(draft(id: 'x', ten: 'Đã xoá', accountId: 10, idhousehold: 7)),
        throwsA(isA<CategoryValidationException>()));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'y',
      idaccount: 20,
      name: 'Cờ xoá',
      classify: 'chi',
      idhousehold: const Value(7),
      isDeleted: const Value(true),
      isLocalOnly: const Value(false),
      updatedAt: DateTime(2026, 8, 21),
    ));
    await expectLater(repo.saveChild(draft(id: 'y', ten: 'Cờ xoá', accountId: 10, idhousehold: 7)),
        throwsA(isA<CategoryValidationException>()));
    expect((await db.categoryDao.getById('x'))!.deletedAt, isNotNull);
    expect((await db.categoryDao.getById('y'))!.isDeleted, isTrue);
  });

  test('nhóm cha là null-nhà: danh mục NHÀ không nhận nhóm RIÊNG của chính tôi làm cha', () async {
    await them('nr', 'Nhóm riêng của tôi', idaccount: 10, isGroup: true);
    await expectLater(repo.saveChild(draft(ten: 'Gas', accountId: 10, idhousehold: 7, parentId: 'nr')),
        throwsA(isA<CategoryValidationException>()),
        reason: 'bỏ vế parent.idhousehold == null ở nhánh riêng (hoặc so idhousehold sai) là con nhà treo vào nhóm riêng');
  });

  test('nhóm cha là nhóm NHÀ: danh mục RIÊNG của tôi không được nhận làm cha dù tôi là người tạo', () async {
    await them('nn', 'Nhóm nhà tôi tạo', idaccount: 10, idhousehold: 7, isGroup: true);
    await expectLater(repo.saveChild(draft(ten: 'Gas', accountId: 10, parentId: 'nn')),
        throwsA(isA<CategoryValidationException>()),
        reason: 'bỏ vế parent.idhousehold == null: idaccount khớp nên hàng riêng treo vào nhóm nhà');
  });

  group('saveGroup của nhà', () {
    CategoryGroupDraft gd({
      String? id,
      String ten = 'Nhóm',
      int accountId = 10,
      int? idhousehold,
      List<String> childIds = const [],
    }) =>
        CategoryGroupDraft(
          id: id,
          accountId: accountId,
          name: ten,
          classify: 'chi',
          icon: 'icon',
          colour: '#FFFFFF',
          childIds: childIds,
          idhousehold: idhousehold,
        );

    test('sửa nhóm nhà do người khác tạo giữ nhà và người tạo, pending', () async {
      await them('g', 'Sinh hoạt', idaccount: 20, idhousehold: 7, isGroup: true);
      await repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt mới', idhousehold: 7));
      final h = (await db.categoryDao.getById('g'))!;
      expect(h.idhousehold, 7, reason: 'insertOrReplace: thiếu trường là nhóm nhà thành nhóm riêng im lặng');
      expect(h.idaccount, 20);
      expect(h.isGroup, isTrue);
      expect(h.syncStatus, 'pending');
    });

    test('nhóm nhà nhận con cùng nhà của người khác', () async {
      await them('g', 'Sinh hoạt', idaccount: 20, idhousehold: 7, isGroup: true);
      await them('c', 'Gas', idaccount: 21, idhousehold: 7);
      await repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt', idhousehold: 7, childIds: ['c']));
      expect((await db.categoryDao.getById('c'))!.parentId, 'g');
    });

    test('nhóm nhà từ chối con nhà khác và con riêng', () async {
      await them('g', 'Sinh hoạt', idaccount: 20, idhousehold: 7, isGroup: true);
      await them('cb', 'Của B', idaccount: 20, idhousehold: 8);
      await them('cr', 'Riêng', idaccount: 10);
      for (final c in ['cb', 'cr']) {
        await expectLater(repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt', idhousehold: 7, childIds: [c])),
            throwsA(isA<CategoryValidationException>()),
            reason: 'con $c không cùng nhà');
      }
    });

    test('draft KHÔNG nêu idhousehold mà nhóm đang thuộc nhà: vẫn giữ nhà (nha = draft ?? cũ)', () async {
      await them('g', 'Sinh hoạt', idaccount: 20, idhousehold: 7, isGroup: true);
      await repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt mới'));
      final h = (await db.categoryDao.getById('g'))!;
      expect(h.idhousehold, 7, reason: 'rơi vế `?? cũ` là nhóm rơi khỏi nhà thành nhóm riêng, im lặng (insertOrReplace)');
      expect(h.idaccount, 20, reason: 'người tạo không đổi');
    });

    test('draft nhà sửa nhóm RIÊNG của tôi: ném, nhóm vẫn riêng', () async {
      await them('gr', 'Nhóm riêng', idaccount: 10, isGroup: true);
      await expectLater(repo.saveGroup(gd(id: 'gr', ten: 'Nhóm riêng', idhousehold: 7)),
          throwsA(isA<CategoryValidationException>()));
      expect((await db.categoryDao.getById('gr'))!.idhousehold, isNull,
          reason: 'nhóm riêng lặng lẽ thành nhóm nhà là biến khỏi danh sách cá nhân và HOUSEHOLD_SCOPE_MISMATCH');
    });

    test('sửa nhóm của nhà đã xoá mềm: ném, không sống lại', () async {
      await them('gx', 'Đã xoá', idaccount: 20, idhousehold: 7, isGroup: true, xoa: true);
      await expectLater(repo.saveGroup(gd(id: 'gx', ten: 'Đã xoá', idhousehold: 7)),
          throwsA(isA<CategoryValidationException>()));
      expect((await db.categoryDao.getById('gx'))!.deletedAt, isNotNull);
    });

    test('tên nhóm trùng trong nhà bị từ chối; trùng danh mục riêng của tôi thì được', () async {
      await them('dn', 'Sinh hoạt', idaccount: 20, idhousehold: 7);
      await them('rieng', 'Du lịch', idaccount: 10);
      await expectLater(repo.saveGroup(gd(ten: ' sinh HOẠT ', idhousehold: 7)),
          throwsA(isA<CategoryValidationException>()),
          reason: 'uq_category_household_name: tên chuẩn hoá duy nhất trong nhà, kể cả khác loại hàng (nhóm ↔ danh mục)');
      await repo.saveGroup(gd(ten: 'Du lịch', idhousehold: 7));
      expect((await db.categoryDao.getCuaNha(7)).map((c) => c.name), contains('Du lịch'));
    });

    test('tạo mới nhóm của nhà: người tạo = accountId, idhousehold từ draft, là nhóm, pending', () async {
      await repo.saveGroup(gd(ten: 'Nhóm mới', accountId: 10, idhousehold: 7));
      final h = (await db.categoryDao.getCuaNha(7)).single;
      expect(h.name, 'Nhóm mới');
      expect(h.idhousehold, 7);
      expect(h.idaccount, 10, reason: 'hàng mới: người tạo là người lưu');
      expect(h.isGroup, isTrue);
      expect(h.syncStatus, 'pending');
    });

    test('nhóm riêng từ chối con của nhà dù tôi là người tạo', () async {
      await them('g', 'Nhóm riêng', idaccount: 10, isGroup: true);
      await them('cn', 'Con nhà', idaccount: 10, idhousehold: 7);
      await expectLater(repo.saveGroup(gd(id: 'g', ten: 'Nhóm riêng', childIds: ['cn'])),
          throwsA(isA<CategoryValidationException>()));
    });

    test('bỏ chọn con ở nhóm nhà gỡ đúng hàng, không đụng hàng nhà khác', () async {
      await them('g', 'Sinh hoạt', idaccount: 20, idhousehold: 7, isGroup: true);
      await them('c1', 'Gas', idaccount: 21, idhousehold: 7);
      await them('c2', 'Nước', idaccount: 20, idhousehold: 7);
      await repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt', idhousehold: 7, childIds: ['c1', 'c2']));
      await them('b', 'Nhóm B', idaccount: 20, idhousehold: 8, isGroup: true);
      await them('cb', 'Con B', idaccount: 20, idhousehold: 8);
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'cb',
        idaccount: 20,
        name: 'Con B',
        classify: 'chi',
        idhousehold: const Value(8),
        parentId: const Value('g'), // cố tình trỏ vào id nhóm của nhà 7
        isLocalOnly: const Value(false),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 8, 21),
      ));
      await repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt', idhousehold: 7, childIds: ['c1']));
      expect((await db.categoryDao.getById('c1'))!.parentId, 'g');
      final c2 = (await db.categoryDao.getById('c2'))!;
      expect(c2.parentId, isNull);
      expect(c2.syncStatus, 'pending');
      final cb = (await db.categoryDao.getById('cb'))!;
      expect(cb.parentId, 'g', reason: 'hàng nhà khác không bị gỡ');
      expect(cb.syncStatus, 'synced');
    });

    test('bỏ chọn con ở nhóm nhà: con trùng tên khuôn đã xoá vẫn gỡ được (không áp ẩn theo khuôn)', () async {
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'k',
        idaccount: 0,
        name: 'Điện',
        classify: 'chi',
        isDefault: const Value(true),
        isLocalOnly: const Value(false),
        isDeleted: const Value(true),
        deletedAt: Value(DateTime(2026, 10, 28)),
        updatedAt: DateTime(2026, 10, 28),
      ));
      await them('g', 'Sinh hoạt', idaccount: 20, idhousehold: 7, isGroup: true);
      await them('c', 'Điện', idaccount: 20, idhousehold: 7);
      await repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt', idhousehold: 7, childIds: ['c']));
      await repo.saveGroup(gd(id: 'g', ten: 'Sinh hoạt', idhousehold: 7));
      expect((await db.categoryDao.getById('c'))!.parentId, isNull,
          reason: 'bộ nhà do server sao từ khuôn cùng tên; khuôn bị xoá không được làm con kẹt trong nhóm');
    });
  });

  test('getCuaNha trả hàng của nhà theo classify, bỏ hàng xoá mềm và hàng nhà khác / riêng', () async {
    await them('a', 'A', idhousehold: 7);
    await them('b', 'B', idhousehold: 7, classify: 'thu');
    await them('c', 'C', idhousehold: 7, xoa: true);
    await them('d', 'D', idhousehold: 8);
    await them('e', 'E');
    expect((await db.categoryDao.getCuaNha(7)).map((h) => h.id).toSet(), {'a', 'b'});
    expect((await db.categoryDao.getCuaNha(7, classify: 'thu')).map((h) => h.id), ['b']);
    final dong = await db.categoryDao.watchCuaNha(7, classify: 'chi').first;
    expect(dong.map((h) => h.id), ['a']);
  });

  test('saveKeywords từ chối hàng của nhà (1B Task 11)', () async {
    await them('dn', 'Tiền chợ', idaccount: 10, idhousehold: 7, tuKhoa: ['cho']);
    await expectLater(
      repo.saveKeywords(accountId: 10, categoryId: 'dn', keywords: const ['x']),
      throwsA(isA<CategoryValidationException>()
          .having((e) => e.message, 'message', 'Danh mục của nhà không có từ khoá.')),
      reason: 'cột Keyword chung, các thành viên đè nhau; người tạo cũng không được mở cửa sau này',
    );
    final tu = (await (db.select(db.categoryKeywords)..where((k) => k.categoryId.equals('dn'))).get())
        .map((k) => k.keyword)
        .toSet();
    expect(tu, {'cho'}, reason: 'từ chối thì bộ từ khoá đang có giữ nguyên');
  });

  test('saveKeywords hàng riêng của tôi vẫn ghi được (không mở nhầm chốt)', () async {
    await them('r', 'Riêng', idaccount: 10);
    await repo.saveKeywords(accountId: 10, categoryId: 'r', keywords: const ['a']);
    expect((await db.select(db.categoryKeywords).get()).map((k) => k.keyword), ['a']);
  });

  test('trùng tên trong nhà báo câu nói "trong nhà" (form nhà hiện nguyên câu này)', () async {
    await them('dn', 'Tiền chợ', idaccount: 20, idhousehold: 7);
    await expectLater(
      repo.saveChild(draft(ten: 'tiền chợ', accountId: 10, idhousehold: 7)),
      throwsA(isA<CategoryValidationException>().having((e) => e.message, 'message', contains('trong nhà'))),
    );
  });

  test('HỒI QUY: Thành viên sửa danh mục nhà giữ aiCoDinh, parentId và người tạo', () async {
    await them('nhom', 'Sinh hoạt', idaccount: 10, idhousehold: 7, isGroup: true);
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'dn',
      idaccount: 10,
      name: 'Điện nước',
      classify: 'chi',
      idhousehold: const Value(7),
      parentId: const Value('nhom'),
      aiCoDinh: const Value(true),
      isLocalOnly: const Value(false),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2026, 8, 21),
    ));
    await repo.saveChild(CategoryChildDraft(
      id: 'dn',
      accountId: 20, // thành viên khác sửa
      name: 'Điện nước mới',
      classify: 'chi',
      parentId: 'nhom',
      icon: 'icon',
      colour: '#FFFFFF',
      keywords: const [],
      aiCoDinh: true,
      idhousehold: 7,
    ));
    final h = (await db.categoryDao.getById('dn'))!;
    expect(h.aiCoDinh, isTrue, reason: 'insertOrReplace: thiếu dòng aiCoDinh là mỗi lần sửa tắt cờ Cố định (xanh ngay: 1A đã đúng)');
    expect(h.parentId, 'nhom');
    expect(h.idaccount, 10, reason: 'người tạo không đổi khi người khác sửa (xanh ngay: 1A đã đúng)');
    expect(h.idhousehold, 7);
  });

  test('danh mục riêng vẫn không có idhousehold sau khi sửa', () async {
    await them('r', 'Riêng', idaccount: 10);
    await repo.saveChild(draft(id: 'r', ten: 'Riêng mới', accountId: 10));
    expect((await db.categoryDao.getById('r'))!.idhousehold, isNull);
  });
}
