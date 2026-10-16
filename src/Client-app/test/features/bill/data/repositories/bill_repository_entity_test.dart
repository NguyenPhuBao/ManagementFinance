/// Hai lối đọc thêm cho DI / runner để chúng thôi gọi billDao (spec Entity Hoá đơn 2026-10-14 mục 4.3). Hợp đồng: bọc
/// đúng DAO (cùng danh sách id, cùng thứ tự) và trả entity.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repo;
  const acc = 7;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db);
  });
  tearDown(() => db.close());

  Future<void> seed(String id, DateTime due, {bool xoa = false}) =>
      db.billDao.insert(
        BillsCompanion.insert(
          id: id,
          idaccount: acc,
          name: id,
          amount: 100,
          dueDate: due,
          isDeleted: Value(xoa),
          deletedAt: Value(xoa ? DateTime(2026, 9, 1) : null),
          updatedAt: DateTime(2026, 9, 1),
        ),
      );

  test(
    'getUpcoming bọc billDao.getUpcoming — cùng id, cùng thứ tự, trả entity',
    () async {
      await seed('gan', DateTime(2026, 9, 5));
      await seed('xa', DateTime(2027, 1, 5));
      final now = DateTime(2026, 9, 1);
      final dao = await db.billDao.getUpcoming(acc, days: 30, now: now);
      final ra = await repo.getUpcoming(acc, days: 30, now: now);
      expect(ra.map((b) => b.id).toList(), dao.map((b) => b.id).toList());
      expect(ra, everyElement(isA<BillEntity>()));
      expect(ra.map((b) => b.id), contains('gan'));
    },
  );

  test(
    'getAllIncludingDeleted bọc getTatCaKeCaDaXoa — có cả hàng đã xoá mềm',
    () async {
      await seed('song', DateTime(2026, 9, 5));
      await seed('daXoa', DateTime(2026, 9, 6), xoa: true);
      final ra = await repo.getAllIncludingDeleted(acc);
      expect(ra.map((b) => b.id).toSet(), {'song', 'daXoa'});
      expect(ra.firstWhere((b) => b.id == 'daXoa').isDeleted, isTrue);
      expect(
        (await repo.getBills(acc)).map((b) => b.id),
        ['song'],
        reason: 'getBills vẫn lọc hàng đã xoá',
      );
    },
  );
}
