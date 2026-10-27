/// Cửa duy nhất của danh sách CHỌN danh mục — bỏ bản sao đang ẩn theo khuôn (spec 2026-10-27 mục 4).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/danh_sach_chon_danh_muc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final moc = DateTime(2026, 10, 10);
  final sauMoc = DateTime.utc(2026, 10, 28);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'kx', name: 'Thử khuôn', idaccount: 0, classify: 'chi',
        isDefault: const Value(true), isDeleted: const Value(true), deletedAt: Value(sauMoc), updatedAt: moc));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'sx', name: 'Thử khuôn', idaccount: 10, classify: 'chi', updatedAt: moc));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'c1', name: 'Nuôi mèo', idaccount: 10, classify: 'chi', updatedAt: moc));
  });
  tearDown(() => db.close());

  test('⭐ hangChonDuoc bỏ bản sao đang ẩn, giữ danh mục thường', () async {
    final ids = (await hangChonDuoc(db, 10, 'chi')).map((c) => c.id).toList();
    expect(ids, contains('c1'));
    expect(ids, isNot(contains('sx')), reason: 'Admin xoá khuôn sau mốc → bản sao ẩn khỏi mọi bộ chọn.');
  });

  test('⭐ theoDoiHangChonDuoc phát lại khi admin KHÔI PHỤC khuôn — bản sao hiện lại', () async {
    final tho = <List<String>>[];
    final sub = theoDoiHangChonDuoc(db, 10, 'chi').listen((ds) => tho.add([for (final c in ds) c.id]));
    addTearDown(sub.cancel);
    await pumpEventQueue(times: 50);
    expect(tho.last, isNot(contains('sx')));

    await (db.update(db.categories)..where((t) => t.id.equals('kx')))
        .write(const CategoriesCompanion(isDeleted: Value(false), deletedAt: Value(null)));
    await pumpEventQueue(times: 50);
    expect(tho.last, contains('sx'),
        reason: 'Một truy vấn kèm hàng khuôn — stream phải phát lại khi hàng khuôn đổi, không chỉ khi hàng của tài khoản đổi.');
  });

  test('DAO trả kèm MỌI khuôn (kể cả đã xoá) và không lẫn khuôn vào rows', () async {
    final kq = await db.categoryDao.getCategoryRows(10, 'chi');
    expect(kq.rows.every((c) => !c.isDefault), isTrue);
    expect(kq.khuon.map((c) => c.id), contains('kx'));
    expect((await db.categoryDao.getTatCaKhuon()).map((c) => c.id), contains('kx'));
  });
}
