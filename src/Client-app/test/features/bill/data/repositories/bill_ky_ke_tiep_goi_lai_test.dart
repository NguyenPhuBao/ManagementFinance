/// `_nextPeriodOf` phải GỌI LẠI `kyKeTiepCua`, không giữ bản chép của phép
/// tính ngày.
///
/// Canh chừng điều gì: dự báo 30 ngày chiếu kỳ tương lai bằng `kyKeTiepCua`;
/// nếu đường trả tiền tính ngày theo bản riêng thì hàng thật sinh ra lệch
/// với kỳ đã dự báo — người dùng thấy dự báo nói 16/11, trả xong hoá đơn lại
/// ghi 01/11. Không exception, không log.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/domain/bill_ky_ke_tiep.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;
  const accountId = 7;
  const walletId = 'wallet-1';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository =
        BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: walletId,
      idaccount: accountId,
      name: 'Ví chính',
      balance: const Value(100000000),
      updatedAt: DateTime(2026, 1, 1),
    ));
  });

  tearDown(() => db.close());

  test('kỳ do payBill sinh ra mang đúng ba mốc và ngày gốc của kyKeTiepCua',
      () async {
    await db.billDao.insert(BillsCompanion.insert(
      id: 'bill-goc',
      idaccount: accountId,
      walletId: const Value(walletId),
      categoryId: const Value('cat-dien'),
      name: 'Tiền điện',
      amount: 250000,
      startDate: Value(DateTime(2026, 9, 1)),
      periodEnd: Value(DateTime(2026, 10, 1)),
      dueDate: DateTime(2026, 10, 16),
      isRecurrence: const Value(true),
      timeRecurrence: const Value(kBillCycleMonth),
      recurrence: const Value('monthly'),
      anchorDay: const Value(31),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2026, 1, 1),
    ));
    final goc = (await db.billDao.getById('bill-goc'))!;
    final mongDoi = kyKeTiepCua(goc);

    await repository.payBill(
        bill: goc, walletId: walletId, idaccount: accountId);
    final sau = (await db.billDao.getAll(accountId))
        .firstWhere((x) => x.generatedFromBillId == goc.id);

    expect(sau.startDate, mongDoi.batDau);
    expect(sau.periodEnd, mongDoi.ketThuc);
    expect(sau.dueDate, mongDoi.hanTra);
    expect(sau.anchorDay, mongDoi.anchorDay,
        reason:
            'Ngày gốc 31 phải được chép sang kỳ sau — quên là "ngày 31 hàng '
            'tháng" tụt về 28 vĩnh viễn ngay sau tháng Hai đầu tiên.');
  });
}
