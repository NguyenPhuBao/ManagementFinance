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
}
