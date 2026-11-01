import 'package:drift/drift.dart' hide isNull;
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

  test('tên trùng hàng xoá mềm của nhà không giữ chỗ; sửa mà không đổi tên thì không xét trùng', () async {
    await them('cu', 'Điện', idaccount: 20, idhousehold: 7, xoa: true);
    await repo.saveChild(draft(ten: 'Điện', accountId: 10, idhousehold: 7));
    final moi = (await db.categoryDao.getCuaNha(7)).single;
    await repo.saveChild(draft(id: moi.id, ten: 'Điện', accountId: 10, idhousehold: 7));
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

  test('danh mục riêng vẫn không có idhousehold sau khi sửa', () async {
    await them('r', 'Riêng', idaccount: 10);
    await repo.saveChild(draft(id: 'r', ten: 'Riêng mới', accountId: 10));
    expect((await db.categoryDao.getById('r'))!.idhousehold, isNull);
  });
}
