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

  test('LoadBillsEvent emits BillLoaded with correct unpaid summary', () async {
    await db.billDao.insert(
      BillsCompanion.insert(
        id: '1',
        idaccount: 1,
        name: 'Internet',
        amount: 300000.0,
        dueDate: DateTime.now(),
        isPaid: const Value(false),
        updatedAt: DateTime.now(),
      ),
    );

    bloc.add(LoadBillsEvent(idaccount: 1));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<BillLoaded>().having(
          (s) => s.totalUnpaidAmount,
          'totalUnpaidAmount',
          300000.0,
        ),
      ),
    );
  });

  test('thanh toán hoá đơn đã trả báo đúng lý do, không phải lỗi chung chung',
      () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví',
        balance: const Value(1000000.0),
        updatedAt: DateTime.now(),
      ),
    );
    await db.billDao.insert(
      BillsCompanion.insert(
        id: 'paid-1',
        idaccount: 1,
        walletId: const Value('w1'),
        name: 'Internet',
        amount: 100000.0,
        dueDate: DateTime.now(),
        payStatus: const Value('Payed'),
        isPaid: const Value(true),
        updatedAt: DateTime.now(),
      ),
    );
    final bill = (await db.billDao.getAll(1)).single;

    bloc.add(PayBillEvent(bill: bill, walletId: 'w1', idaccount: 1));

    final state = await bloc.stream.firstWhere((s) => s is BillError) as BillError;
    expect(
      state.message,
      'Hóa đơn này đã được thanh toán rồi.',
      reason: 'Ném nguyên exception ra màn hình cho người dùng đọc một chuỗi '
          'kỹ thuật, trong khi đây là tình huống bình thường: bấm nút hai lần.',
    );
  });
}
