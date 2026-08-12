import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_state.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;
  late BillBloc bloc;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    bloc = BillBloc(repository: repository);
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  test('Full Bill Lifecycle: Create -> Load -> Pay -> Check Sync Status', () async {
    // 1. Create wallet
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví Thử Nghiệm',
        balance: const Value(500000.0),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Add Bill via Bloc
    final dueDate = DateTime.now().add(const Duration(days: 3));
    bloc.add(
      AddBillEvent(
        bill: BillsCompanion.insert(
          id: 'b1',
          idaccount: 1,
          name: 'Hóa đơn Internet',
          amount: 200000.0,
          dueDate: dueDate,
          recurrence: const Value('monthly'),
          syncStatus: const Value('pending'),
          updatedAt: DateTime.now(),
        ),
      ),
    );

    // 3. Start Loading Bills
    bloc.add(LoadBillsEvent(idaccount: 1));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<BillLoaded>().having((s) => s.bills.length, 'bills count', 1),
      ),
    );

    // 4. Pay Bill
    final loadedState = bloc.state as BillLoaded;
    final billToPay = loadedState.bills.first;
    bloc.add(
      PayBillEvent(
        bill: billToPay,
        walletId: 'w1',
        idaccount: 1,
      ),
    );

    // 5. Verify pending bills in database for sync engine
    final pendingBills = await db.billDao.getPending();
    expect(pendingBills.isNotEmpty, true);
  });
}
