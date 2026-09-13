/// Kỳ kế tiếp khi hoá đơn có ân hạn.
///
/// Cái bẫy §4.4 tài liệu xin backend: thêm cột `Period_end` mà KHÔNG đổi cách
/// tính kỳ kế tiếp thì hoá đơn "kỳ 01–30/09, hạn 15/10" sinh kỳ sau bắt đầu
/// 15/10 — hở nửa tháng, mỗi kỳ trôi thêm. Kỳ sau phải bắt đầu tại NGÀY KẾT
/// THÚC KỲ, và hạn trả kỳ sau phải giữ đúng số ngày ân hạn.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;

  const accountId = 7;
  const walletId = 'wallet-1';
  const categoryId = 'cat-dien';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    await db.walletDao.insert(WalletsCompanion.insert(
      id: walletId,
      idaccount: accountId,
      name: 'Ví chính',
      balance: const Value(100000000),
      updatedAt: DateTime(2026, 1, 1),
    ));
  });

  tearDown(() => db.close());

  Future<Bill> seed({
    required DateTime start,
    required DateTime due,
    DateTime? periodEnd,
    int? anchorDay,
    String chuKy = kBillCycleMonth,
    String id = 'bill-goc',
  }) async {
    await db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: accountId,
      walletId: const Value(walletId),
      categoryId: const Value(categoryId),
      name: 'Tiền điện',
      amount: 250000,
      startDate: Value(start),
      periodEnd: Value(periodEnd),
      dueDate: due,
      isRecurrence: const Value(true),
      timeRecurrence: Value(chuKy),
      recurrence: const Value('monthly'),
      anchorDay: Value(anchorDay),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2026, 1, 1),
    ));
    return (await db.billDao.getById(id))!;
  }

  Future<Bill> kySauCua(Bill b) async => (await db.billDao.getAll(accountId))
      .firstWhere((x) => x.generatedFromBillId == b.id);

  test('trả kỳ có ân hạn 15: kỳ sau nối từ ngày kết thúc kỳ, giữ 15 ngày',
      () async {
    final goc = await seed(
      start: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 10, 1),
      due: DateTime(2026, 10, 16),
      anchorDay: 1,
    );

    await repository.payBill(
        bill: goc, walletId: walletId, idaccount: accountId);
    final sau = await kySauCua(goc);

    expect(sau.startDate, DateTime(2026, 10, 1),
        reason: 'Bắt đầu tại NGÀY KẾT THÚC KỲ, không phải hạn trả 16/10 — nếu '
            'không mỗi kỳ hở thêm 15 ngày.');
    expect(sau.periodEnd, DateTime(2026, 11, 1));
    expect(sau.dueDate, DateTime(2026, 11, 16),
        reason: 'Ân hạn đi theo chuỗi mà không cần cột riêng.');
  });

  test('chuỗi ba kỳ giữ nguyên ân hạn 15, gốc 31 kẹp đúng', () async {
    final goc = await seed(
      start: DateTime(2025, 12, 31),
      periodEnd: DateTime(2026, 1, 31),
      due: DateTime(2026, 2, 15),
      anchorDay: 31,
    );
    var hienTai = goc;
    final ra = <List<DateTime>>[];
    for (var i = 0; i < 3; i++) {
      await repository.payBill(
          bill: hienTai, walletId: walletId, idaccount: accountId);
      hienTai = await kySauCua(hienTai);
      ra.add([hienTai.startDate!, hienTai.periodEnd!, hienTai.dueDate]);
    }
    expect(ra, [
      [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 15)],
      [DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 15)],
      [DateTime(2026, 3, 31), DateTime(2026, 4, 30), DateTime(2026, 5, 15)],
    ]);
  });

  test('hàng cũ (periodEnd NULL): kỳ sau y hệt trước v21 và ĐƯỢC ghi periodEnd',
      () async {
    final goc = await seed(
      start: DateTime(2026, 8, 20),
      due: DateTime(2026, 9, 20),
      anchorDay: 20,
    );

    await repository.payBill(
        bill: goc, walletId: walletId, idaccount: accountId);
    final sau = await kySauCua(goc);

    expect(sau.startDate, DateTime(2026, 9, 20));
    expect(sau.dueDate, DateTime(2026, 10, 20),
        reason: 'Ân hạn 0 ⇒ kết quả phải bằng mã trước v21.');
    expect(sau.periodEnd, DateTime(2026, 10, 20),
        reason: 'Hàng MỚI luôn có periodEnd — NULL chỉ dành cho hàng cũ.');
  });

  test('bỏ qua kỳ cũng nối từ ngày kết thúc kỳ và giữ ân hạn', () async {
    final goc = await seed(
      start: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 10, 1),
      due: DateTime(2026, 10, 16),
      anchorDay: 1,
    );

    await repository.skipBill(billId: goc.id);
    final sau = await kySauCua(goc);

    expect(sau.startDate, DateTime(2026, 10, 1));
    expect(sau.periodEnd, DateTime(2026, 11, 1));
    expect(sau.dueDate, DateTime(2026, 11, 16),
        reason: 'skipBill đi qua cùng _nextPeriodOf với payBill — sửa một chỗ '
            'phải phủ cả hai.');
  });
}
