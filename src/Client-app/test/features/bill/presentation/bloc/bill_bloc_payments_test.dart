/// `BillLoaded` mang theo khoản chi của từng hoá đơn đã trả.
///
/// Vì sao cần: tab "Đã thanh toán" chỉ nói "Hạn dd/mm" — người dùng hỏi "tôi
/// trả hôm nào" thì không có câu trả lời, dù khoản chi đã nằm sẵn trong sổ với
/// sợi dây `billId` (v16). Bloc gộp bản đồ ấy vào trạng thái để trang không
/// phải giữ thêm một stream Drift (thứ làm widget test treo vì "Pending
/// timers").
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  const accountId = 7;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    bloc = BillBloc(repository: repository);

    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: accountId,
      name: 'Tiền mặt',
      balance: const Value(1000000.0),
      updatedAt: DateTime(2025, 9, 1),
    ));
    for (final id in ['b-tra', 'b-chua']) {
      await db.billDao.insert(BillsCompanion.insert(
        id: id,
        idaccount: accountId,
        walletId: const Value('w1'),
        categoryId: const Value('c1'),
        name: id,
        amount: 200000,
        dueDate: DateTime(2025, 9, 20),
        isRecurrence: const Value(false),
        updatedAt: DateTime(2025, 9, 1),
      ));
    }
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  test('hoá đơn đã trả có khoản chi kèm theo, hoá đơn chưa trả thì không',
      () async {
    final bill = (await db.billDao.getById('b-tra'))!;
    await repository.payBill(
      bill: bill,
      walletId: 'w1',
      idaccount: accountId,
      occurredAt: DateTime(2025, 9, 18),
    );

    bloc.add(LoadBillsEvent(idaccount: accountId));

    final state = await bloc.stream.firstWhere((s) => s is BillLoaded) as BillLoaded;
    expect(state.payments.keys, {'b-tra'},
        reason: 'Bản đồ billId → khoản chi; hoá đơn chưa trả không có mục.');
    expect(state.payments['b-tra']!.date, DateTime(2025, 9, 18),
        reason: 'Ngày TRẢ (ngày của giao dịch), không phải ngày đến hạn.');
    expect(state.payments['b-tra']!.amount, 200000);
  });

  test('khoản chi đã xoá mềm không được tính là lần trả', () async {
    final bill = (await db.billDao.getById('b-tra'))!;
    await repository.payBill(bill: bill, walletId: 'w1', idaccount: accountId);
    await repository.undoPayment(billId: 'b-tra');

    bloc.add(LoadBillsEvent(idaccount: accountId));

    final state = await bloc.stream.firstWhere((s) => s is BillLoaded) as BillLoaded;
    expect(state.payments, isEmpty,
        reason: 'Hoàn tác xoá mềm khoản chi; hiện ngày trả của một khoản đã '
            'hoàn là nói dối.');
  });

  test('bản đồ được tính lại sau mỗi lần thanh toán', () async {
    bloc.add(LoadBillsEvent(idaccount: accountId));
    final truoc = await bloc.stream.firstWhere((s) => s is BillLoaded) as BillLoaded;
    expect(truoc.payments, isEmpty);

    final bill = (await db.billDao.getById('b-tra'))!;
    await repository.payBill(bill: bill, walletId: 'w1', idaccount: accountId);

    final sau = await bloc.stream
        .firstWhere((s) => s is BillLoaded && s.payments.isNotEmpty) as BillLoaded;
    expect(sau.payments.containsKey('b-tra'), isTrue,
        reason: 'Trả xong trên chính trang này thì ngày trả phải hiện ngay, '
            'không đợi mở lại trang.');
  });
}
