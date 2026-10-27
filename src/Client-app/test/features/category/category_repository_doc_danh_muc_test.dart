/// Ba lối đọc danh mục của `CategoryManagementRepository` cho bảng tra tên và bộ lọc Sổ giao dịch — nay trả `CategoryEntity`
/// (spec Entity Danh mục 2026-10-15 mục 4.2; trước đó là `category_repository_rows_test`, ba lối hàng Drift).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/domain/ban_sao_mac_dinh.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository_impl.dart';

void main() {
  late AppDatabase db;
  late CategoryManagementRepositoryImpl repo;
  final moc = DateTime(2026, 10, 10);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryManagementRepositoryImpl(db: db);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c0',
        name: 'Khuôn',
        idaccount: 0,
        classify: 'chi',
        isDefault: const Value(true),
        updatedAt: moc));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c1',
        name: 'Ăn uống',
        idaccount: 10,
        classify: 'chi',
        updatedAt: moc));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c2',
        name: 'Đã xoá',
        idaccount: 10,
        classify: 'chi',
        isDeleted: const Value(true),
        deletedAt: Value(moc),
        updatedAt: moc));
  });
  tearDown(() => db.close());

  test(
      'loadBangTraTen giữ cả hàng đã xoá mềm và hàng mặc định toàn cục (G41/E8)',
      () async {
    final ds = await repo.loadBangTraTen(accountId: 10);
    expect(ds, everyElement(isA<CategoryEntity>()));
    expect(ds.map((c) => c.id), containsAll(['c0', 'c1', 'c2']),
        reason:
            'Giao dịch cũ trỏ vào danh mục đã xoá hay danh mục mặc định vẫn phải tra được tên.');
  });

  test('watchAll phát lại khi bảng đổi', () async {
    final tho = <List<String>>[];
    final sub = repo
        .watchAll(accountId: 10)
        .listen((ds) => tho.add([for (final c in ds) c.id]));
    addTearDown(sub.cancel);
    await pumpEventQueue(times: 50);
    expect(tho, isNotEmpty);
    expect(tho.last, contains('c1'));
    expect(tho.last, isNot(contains('c3')));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c3', name: 'Mới', idaccount: 10, classify: 'chi', updatedAt: moc));
    await pumpEventQueue(times: 50);
    expect(tho.last, contains('c3'),
        reason:
            'Bộ lọc Sổ giao dịch và Trang chủ nghe stream này — không phát lại là chip danh mục đứng hình.');
  });

  test('getById trả cả hàng đã xoá mềm, null khi không có', () async {
    expect((await repo.getById('c1'))?.name, 'Ăn uống');
    expect((await repo.getById('c2'))?.isDeleted, isTrue,
        reason:
            'Tên danh mục trên bảng thanh toán hoá đơn phải tra được dù danh mục đã xoá.');
    expect(await repo.getById('x'), isNull);
  });

  group('bản sao ẩn theo khuôn — spec 2026-10-27 mục 4', () {
    setUp(() async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'kx', name: 'Thử khuôn', idaccount: 0, classify: 'chi', isDefault: const Value(true),
          isDeleted: const Value(true), deletedAt: Value(DateTime.utc(2026, 10, 28)), updatedAt: moc));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'sx', name: 'Thử khuôn', idaccount: 10, classify: 'chi', updatedAt: moc));
    });

    test('⭐ danh sách CHỌN bỏ bản ẩn: selectableChildren, selectableChildrenAll, loadTree', () async {
      expect((await repo.selectableChildren(accountId: 10, classify: 'chi')).map((c) => c.id), isNot(contains('sx')));
      expect((await repo.selectableChildrenAll(accountId: 10)).map((c) => c.id), isNot(contains('sx')));
      final cay = await repo.loadTree(accountId: 10, classify: 'chi');
      expect(cay.ungroupedChildren.map((c) => c.id), isNot(contains('sx')));
      expect(cay.ungroupedChildren.map((c) => c.id), contains('c1'));
    });

    test('bảng TRA giữ bản ẩn: watchAll, loadBangTraTen, getById — lịch sử giữ tên', () async {
      expect((await repo.watchAll(accountId: 10).first).map((c) => c.id), contains('sx'));
      expect((await repo.loadBangTraTen(accountId: 10)).map((c) => c.id), contains('sx'));
      expect((await repo.getById('sx'))?.name, 'Thử khuôn');
    });

    test('⭐ watchTree phát lại khi admin khôi phục khuôn — bản sao hiện lại', () async {
      final tho = <List<String>>[];
      final sub = repo
          .watchTree(accountId: 10, classify: 'chi')
          .listen((t) => tho.add([for (final c in t.ungroupedChildren) c.id]));
      addTearDown(sub.cancel);
      await pumpEventQueue(times: 50);
      expect(tho.last, isNot(contains('sx')));
      await (db.update(db.categories)..where((t) => t.id.equals('kx')))
          .write(const CategoriesCompanion(isDeleted: Value(false), deletedAt: Value(null)));
      await pumpEventQueue(times: 50);
      expect(tho.last, contains('sx'));
    });

    test('⭐ tạo danh mục trùng tên bản ẩn → câu riêng; trùng hàng thường → câu cũ', () async {
      CategoryChildDraft nhap(String ten) => CategoryChildDraft(
          accountId: 10, name: ten, classify: 'chi', parentId: null, icon: 'category', colour: '#4CAF50', keywords: const []);
      await expectLater(
        repo.saveChild(nhap('thử  KHUÔN')),
        throwsA(isA<CategoryValidationException>()
            .having((e) => e.message, 'message', cauTrungBanSaoDangAn('Thử khuôn'))),
      );
      await expectLater(
        repo.saveChild(nhap('Ăn uống')),
        throwsA(isA<CategoryValidationException>().having((e) => e.message, 'message', startsWith('Tên danh mục đã tồn tại'))),
      );
    });
  });
}
