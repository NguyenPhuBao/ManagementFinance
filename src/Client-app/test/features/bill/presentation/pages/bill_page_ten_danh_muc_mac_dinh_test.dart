/// Thẻ hoá đơn phải hiện đúng tên danh mục MẶC ĐỊNH toàn cục và danh mục đã
/// xoá mềm — cùng họ **G41** (2026-09-15), nay ở trang hoá đơn (UX 2026-09-19,
/// E8).
///
/// Máy ảo đo được 2/3 hoá đơn hiện "Danh mục đã xoá". Nguyên nhân:
/// `BillPage._napTenGoi` và `BillDetailPage` dựng `TransactionLookup` từ
/// `categoryDao.getAll(accountId)` — hàm ấy lọc `idaccount = accountId` và
/// `deletedAt IS NULL`, nên hàng mặc định toàn cục (`idaccount = 0`,
/// `isDefault = true` — `sync_engine.dart:733`) lẫn hàng đã xoá mềm đều **mất
/// tên**. Bảng tra tên có một định nghĩa duy nhất: `CategoryDao.getBangTraTen`.
library;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';

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
  _FixedBillRepository(this.bills);
  final List<Bill> bills;

  @override
  Stream<List<Bill>> watchBills(int idaccount) => Stream.value(bills);

  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Bill _bill({required String id, required String categoryId, required String name}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: categoryId,
      name: name,
      amount: 100000,
      startDate: DateTime(2026, 8, 6),
      dueDate: DateTime(2026, 9, 26),
      payStatus: 'Pending',
      isPaid: false,
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
  final now = DateTime(2026, 9, 19, 10);
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
    // Danh mục mặc định TOÀN CỤC: idaccount = 0, cờ isDefault.
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'c-mac-dinh',
      idaccount: 0,
      name: 'Nhà cửa',
      classify: 'chi',
      isDefault: const drift.Value(true),
      updatedAt: DateTime(2026, 9, 1),
    ));
    // Danh mục của tài khoản nhưng đã xoá mềm — tên vẫn còn trong hàng.
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'c-da-xoa',
      idaccount: 10,
      name: 'Internet',
      classify: 'chi',
      deletedAt: drift.Value(DateTime(2026, 9, 10)),
      updatedAt: DateTime(2026, 9, 10),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  testWidgets('thẻ hoá đơn hiện tên danh mục mặc định và danh mục đã xoá mềm',
      (tester) async {
    tester.view.physicalSize = const Size(411, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'a@b.c'),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(
      repository: _FixedBillRepository([
        _bill(id: 'b1', categoryId: 'c-mac-dinh', name: 'Tiền điện'),
        _bill(id: 'b2', categoryId: 'c-da-xoa', name: 'Tiền mạng'),
      ]),
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

    expect(find.text('Danh mục đã xoá'), findsNothing,
        reason: 'Máy ảo 2026-09-19: 2/3 hoá đơn hiện "Danh mục đã xoá" vì '
            'trang tra tên bằng `categoryDao.getAll` (lọc idaccount và '
            'deletedAt) thay vì `getBangTraTen`.');
    expect(find.text('Tiền điện'), findsOneWidget, reason: 'Thẻ phải dựng.');
    expect(find.textContaining('Nhà cửa'), findsWidgets,
        reason: 'Danh mục mặc định toàn cục (idaccount = 0) phải có tên.');
    expect(find.textContaining('Internet'), findsWidgets,
        reason: 'Danh mục đã xoá mềm vẫn còn tên trong hàng — "Internet" có '
            'ích hơn "Danh mục đã xoá".');
  });

  test('bảng tra tên của ngân sách cũng giữ hàng mặc định và hàng đã xoá', () async {
    final ds = BudgetLocalDataSourceImpl(db: db);
    final ten = (await ds.getAllCategories(10)).map((c) => c.name).toSet();
    expect(ten, containsAll(['Nhà cửa', 'Internet']),
        reason: '`lookupFor` của ngân sách dựng từ hàm này — cùng lỗi, cùng '
            'định nghĩa `getBangTraTen`.');
  });
}
