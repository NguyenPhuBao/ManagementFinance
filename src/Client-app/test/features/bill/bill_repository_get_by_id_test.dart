/// `BillRepository.getById` — trang Chi tiết hoá đơn thôi cầm `billDao` (spec bịt điểm rò 2026-10-10, mục 4.3).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';

void main() {
  test('getById trả hàng Drift, không có thì null', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db);
    final moc = DateTime(2026, 10, 10);
    await db.into(db.bills).insert(BillsCompanion.insert(
        id: 'b1', idaccount: 10, name: 'Netflix', amount: 180000, dueDate: moc, updatedAt: moc));
    expect((await repo.getById('b1'))?.name, 'Netflix');
    expect(await repo.getById('x'), isNull);
  });
}
