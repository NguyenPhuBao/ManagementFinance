/// `payBill` với `occurredAt`, và cờ tự trả kế thừa sang kỳ sau.
///
/// Hai thứ bộ tự động thanh toán cần từ đường tiền hiện có:
///
/// - Khoản chi trả **bù** mang ngày đến hạn của kỳ, không phải lúc bù. Bỏ app
///   ba tháng rồi mở lại là ba kỳ được trả trong một lượt; để chúng cùng mang
///   ngày mở app là ba tháng tiền điện dồn thành một cột trong thống kê theo
///   ngày (cùng lý do với mục 3.14 `GOAL_FEATURE.md`).
/// - Kỳ kế tiếp phải **kế thừa** cờ tự trả, nếu không chuỗi tự động dừng sau
///   đúng một kỳ mà không có gì báo.
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
      name: 'Tiền mặt',
      balance: const Value(1000000.0),
      updatedAt: DateTime(2025, 9, 1),
    ));
  });

  tearDown(() => db.close());

  Future<Bill> seedBill({bool autoPay = false}) async {
    await db.billDao.insert(BillsCompanion.insert(
      id: 'bill-1',
      idaccount: accountId,
      walletId: const Value(walletId),
      categoryId: const Value(categoryId),
      name: 'Tiền điện',
      amount: 200000,
      // Quá khứ so với đồng hồ thật: `occurredAt` bị chặn ở tương lai và
      // `updatedAt` là "bây giờ" — cùng bài học với bộ test trích tự động.
      startDate: Value(DateTime(2025, 8, 20)),
      dueDate: DateTime(2025, 9, 20),
      isRecurrence: const Value(true),
      timeRecurrence: const Value(kBillCycleMonth),
      recurrence: const Value('monthly'),
      autoPayEnabled: Value(autoPay),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2025, 9, 1),
    ));
    return (await db.billDao.getById('bill-1'))!;
  }

  Future<Transaction> khoanChi() async =>
      (await db.transactionDao.getAll(accountId)).single;

  test('kỳ kế tiếp kế thừa cờ tự động thanh toán', () async {
    final bill = await seedBill(autoPay: true);

    await repository.payBill(
        bill: bill, walletId: walletId, idaccount: accountId);

    final ky2 = (await db.billDao.getAll(accountId))
        .firstWhere((b) => b.id != 'bill-1');
    expect(ky2.autoPayEnabled, isTrue,
        reason: 'Quên chép là chuỗi tự trả dừng sau đúng một kỳ, im lặng — '
            'cùng lớp lỗi với việc quên chép `timeNotification`.');
  });

  test('không bật thì kỳ sau cũng không bật', () async {
    final bill = await seedBill(autoPay: false);
    await repository.payBill(
        bill: bill, walletId: walletId, idaccount: accountId);

    final ky2 = (await db.billDao.getAll(accountId))
        .firstWhere((b) => b.id != 'bill-1');
    expect(ky2.autoPayEnabled, isFalse);
  });

  test('occurredAt ghi vào NGÀY của giao dịch, không phải updatedAt', () async {
    final bill = await seedBill();
    final truoc = DateTime.now().subtract(const Duration(seconds: 1));

    await repository.payBill(
      bill: bill,
      walletId: walletId,
      idaccount: accountId,
      occurredAt: DateTime(2025, 9, 20),
    );

    final chi = await khoanChi();
    expect(chi.date, DateTime(2025, 9, 20),
        reason: 'Khoản trả bù phải nằm đúng ngày của kỳ trong thống kê.');
    expect(chi.updatedAt.isAfter(truoc), isTrue,
        reason: '`updatedAt` là sổ sách đồng bộ. Lùi nó theo là LWW coi bản '
            'ghi cũ hơn thực tế và ghi đè mất chính khoản vừa trả.');
  });

  test('không truyền occurredAt thì giao dịch mang thời điểm trả', () async {
    final bill = await seedBill();
    final truoc = DateTime.now().subtract(const Duration(seconds: 1));

    await repository.payBill(
        bill: bill, walletId: walletId, idaccount: accountId);

    expect((await khoanChi()).date.isAfter(truoc), isTrue,
        reason: 'Đường trả tay giữ nguyên hành vi cũ.');
  });

  test('occurredAt ở TƯƠNG LAI bị từ chối, không ghi gì', () async {
    final bill = await seedBill();

    await expectLater(
      repository.payBill(
        bill: bill,
        walletId: walletId,
        idaccount: accountId,
        occurredAt: DateTime.now().add(const Duration(days: 2)),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(await db.transactionDao.getAll(accountId), isEmpty,
        reason: 'Đây là tầng ghi tiền; một tham số ngày để ngỏ là cửa sau. '
            'Khoản chi không thể mang dấu thời gian chưa tới.');
    expect((await db.billDao.getById('bill-1'))!.isPaid, isFalse);
  });
}
