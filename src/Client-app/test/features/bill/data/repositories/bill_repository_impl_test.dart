import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BillLocalDataSource dataSource;
  late BillRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = BillLocalDataSource(db);
    repository = BillRepositoryImpl(dataSource: dataSource, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('payBill marks bill paid, creates transaction, updates wallet, and generates next bill', () async {
    // 1. Setup initial wallet and bill
    const walletId = 'wallet-1';
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: walletId,
        idaccount: 1,
        name: 'Ví chính',
        balance: const Value(1000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    const billId = 'bill-1';
    final dueDate = DateTime(2026, 8, 20);
    await db.billDao.insert(
      BillsCompanion.insert(
        id: billId,
        idaccount: 1,
        name: 'Tiền điện',
        amount: 200000.0,
        dueDate: dueDate,
        recurrence: const Value('monthly'),
        updatedAt: DateTime.now(),
      ),
    );

    final billsInitial = await repository.getBills(1);
    expect(billsInitial.length, 1);
    final bill = billsInitial.first;

    // 2. Pay bill
    await repository.payBill(bill: bill, walletId: walletId, idaccount: 1);

    // 3. Assert current bill is paid
    final bills = await repository.getBills(1);
    final updatedPaidBill = bills.firstWhere((b) => b.id == billId);
    expect(updatedPaidBill.isPaid, true);

    // 4. Assert transaction was created
    final transactions = await db.transactionDao.getAll(1);
    expect(transactions.length, 1);
    expect(transactions.first.amount, 200000.0);
    expect(transactions.first.walletId, walletId);
    expect(transactions.first.type, 'chi');

    // 5. Assert wallet balance was deducted (1000000 - 200000 = 800000)
    final wallet = await db.walletDao.getById(walletId);
    expect(wallet?.balance, 800000.0);

    // 6. Assert next period bill was created (due in Sept 2026)
    expect(bills.length, 2);
    final nextBill = bills.firstWhere((b) => b.id != billId);
    expect(nextBill.isPaid, false);
    expect(nextBill.name, 'Tiền điện');
    expect(nextBill.dueDate.month, 9);
  });
}
