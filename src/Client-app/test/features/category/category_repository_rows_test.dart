/// Ba lối hàng Drift của `CategoryManagementRepository` cho bảng tra tên và bộ lọc Sổ giao dịch (spec mục 4.3).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryManagementRepositoryImpl repo;
  final moc = DateTime(2026, 10, 10);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryManagementRepositoryImpl(db: db);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c1', name: 'Ăn uống', idaccount: 10, classify: 'chi', updatedAt: moc));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c2', name: 'Đã xoá', idaccount: 10, classify: 'chi', isDeleted: const Value(true), updatedAt: moc));
  });
  tearDown(() => db.close());

  test('loadBangTraTen giữ cả hàng đã xoá mềm (G41/E8)', () async {
    expect((await repo.loadBangTraTen(accountId: 10)).map((c) => c.id), containsAll(['c1', 'c2']));
  });

  test('watchAllRows / getRowById chuyển tiếp đúng DAO', () async {
    expect((await repo.watchAllRows(accountId: 10).first).any((c) => c.id == 'c1'), isTrue);
    expect((await repo.getRowById('c1'))?.name, 'Ăn uống');
    expect(await repo.getRowById('x'), isNull);
  });

  test('getCategoryRows GỒM cả hàng nhóm (R8: form hoá đơn giữ danh sách cũ)', () async {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'g1', name: 'Nhóm sinh hoạt', idaccount: 10, classify: 'chi', isGroup: const Value(true), updatedAt: moc));
    final ids = (await repo.getCategoryRows(accountId: 10, classify: 'chi')).map((c) => c.id);
    expect(ids, containsAll(['c1', 'g1']),
        reason: 'Dropdown phẳng của form hoá đơn từng gồm cả hàng nhóm; selectableChildren lọc !isGroup nên không dùng được.');
    expect(ids, isNot(contains('c2')));
  });
}
