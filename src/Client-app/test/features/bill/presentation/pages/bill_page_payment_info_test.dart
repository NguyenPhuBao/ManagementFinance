/// Tab "Đã thanh toán": dòng ghi NGÀY TRẢ và chạm vào mở đúng khoản chi.
///
/// Vì sao cần: trước đây dòng đã trả chỉ nói "Hạn dd/mm" — người dùng hỏi
/// "tôi trả hôm nào, bao nhiêu" thì phải sang sổ giao dịch tự tìm, dù khoản
/// chi đã nối với hoá đơn bằng `billId` (v16). Money Lover và Wallet đều ghi
/// "Đã trả ngày…" và cho mở thẳng giao dịch từ hoá đơn.
library;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_page.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/transaction_detail_sheet.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());
  final AuthState _fixed;
  @override
  AuthState get state => _fixed;
}

class _FixedBillRepository implements BillRepository {
  _FixedBillRepository(this.bills, this.payments);
  final List<Bill> bills;
  final Map<String, Transaction> payments;

  @override
  Stream<List<Bill>> watchBills(int idaccount) => Stream.value(bills);

  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) async => payments;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Bill _bill({required String id, required bool paid, DateTime? dueDate}) => Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: 100000,
      startDate: DateTime(2026, 8, 6),
      dueDate: dueDate ?? DateTime(2026, 9, 6),
      payStatus: paid ? 'Payed' : 'Pending',
      isPaid: paid,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  final now = DateTime(2026, 9, 10, 10);
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      balance: const drift.Value(5000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'c1',
      idaccount: 10,
      name: 'Điện nước',
      classify: 'chi',
      icon: const drift.Value('receipt'),
      colour: const drift.Value('#4CAF50'),
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  /// Khoản chi thật trong CSDL, để không phải dựng `Transaction` bằng tay.
  Future<Transaction> khoanChi(String billId, DateTime ngay) async {
    await db.transactionDao.insert(TransactionsCompanion.insert(
      id: 'tx-$billId',
      idaccount: 10,
      walletId: 'w1',
      categoryId: const drift.Value('c1'),
      amount: 100000,
      type: 'chi',
      note: const drift.Value('Thanh toán hóa đơn: Tiền điện'),
      billId: drift.Value(billId),
      date: ngay,
      updatedAt: ngay,
    ));
    return (await db.transactionDao.getByBill(billId))!;
  }

  Future<void> dungTrang(
    WidgetTester tester,
    List<Bill> bills,
    Map<String, Transaction> payments,
  ) async {
    tester.view.physicalSize = const Size(411, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(
        id: '10',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(
      repository: _FixedBillRepository(bills, payments),
      now: () => now,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp(home: BillPage(now: now)),
    ));
    bloc.add(LoadBillsEvent(idaccount: 10));
    await tester.pumpAndSettle();
    // Sang tab "Đã thanh toán".
    await tester.tap(find.textContaining('Đã thanh toán ('));
    await tester.pumpAndSettle();
  }

  testWidgets('dòng đã trả ghi ngày trả lấy từ khoản chi', (tester) async {
    final tx = await khoanChi('a', DateTime(2026, 9, 4));
    await dungTrang(tester, [_bill(id: 'a', paid: true)], {'a': tx});

    expect(find.textContaining('Trả 04/09/2026'), findsOneWidget,
        reason: 'Ngày TRẢ (04/09), không phải ngày đến hạn (06/09). Người '
            'dùng hỏi "tôi trả hôm nào" thì đây là câu trả lời.');
  });

  testWidgets('không có khoản chi (hàng kéo về từ server) thì chỉ ghi hạn',
      (tester) async {
    await dungTrang(tester, [_bill(id: 'a', paid: true)], const {});

    expect(find.textContaining('Trả '), findsNothing,
        reason: 'Hàng kéo về không có `billId` — không đoán ngày trả.');
    expect(find.textContaining('Hạn 06/09/2026'), findsOneWidget);
  });

  testWidgets('chạm dòng đã trả mở đúng khoản chi', (tester) async {
    final tx = await khoanChi('a', DateTime(2026, 9, 4));
    await dungTrang(tester, [_bill(id: 'a', paid: true)], {'a': tx});

    await tester.tap(find.text('Tiền điện'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionDetailSheet), findsOneWidget,
        reason: 'Trước đây phải sang sổ giao dịch tự tìm, dù hoá đơn đã cầm '
            'sẵn id của khoản chi.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dòng chưa trả chạm vào thì mở trang chi tiết /bills/:id',
      (tester) async {
    tester.view.physicalSize = const Size(411, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(
        id: '10',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(
      repository: _FixedBillRepository([_bill(id: 'a', paid: false)], const {}),
      now: () => now,
    );
    addTearDown(bloc.close);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => BillPage(now: now)),
      GoRoute(
        path: '/bills/:id',
        builder: (_, s) => Scaffold(
          body: Text('chi tiết ${s.pathParameters['id']} '
              '${(s.extra as Bill?)?.name}'),
        ),
      ),
    ]);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    bloc.add(LoadBillsEvent(idaccount: 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tiền điện'));
    await tester.pumpAndSettle();

    expect(find.text('chi tiết a Tiền điện'), findsOneWidget,
        reason: 'Dòng chưa trả không có khoản chi để mở; chạm vào là xem chi '
            'tiết hoá đơn, mang theo hàng đang giữ để trang vẽ ngay.');
    expect(find.byType(TransactionDetailSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
