/// Luồng xoá hoá đơn qua màn xác nhận (`xacNhanXoaHoaDon`, 2026-10-17): ba lối vào — thùng rác trên thẻ danh sách,
/// nút xoá ở trang Chi tiết, nút "Xóa hóa đơn" ở form Sửa — đều mở `/bills/:id/delete`; xác nhận thì chỗ gọi gửi
/// `DeleteBillEvent` vào `BillBloc` của nó, huỷ thì không gì đổi. Trước đó ba lối dùng `AlertDialog` mặc định và
/// không ca test nào phủ việc xoá.
library;

import '../../../../helpers/nguon_doc_gia.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_delete_page.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_detail_page.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_edit_page.dart';
import 'package:flowmoney/features/bill/presentation/widgets/bill_actions.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthCoDinh extends AuthBloc {
  _AuthCoDinh(this._s) : super(authRepository: _RepoGia());
  final AuthState _s;
  @override
  AuthState get state => _s;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
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
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.billDao.insert(BillsCompanion.insert(
      id: 'a',
      idaccount: 10,
      walletId: const drift.Value('w1'),
      categoryId: const drift.Value('c1'),
      name: 'Tiền điện',
      amount: 250000,
      dueDate: DateTime(2026, 9, 8),
      isRecurrence: const drift.Value(true),
      timeRecurrence: const drift.Value(kBillCycleMonth),
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<BillEntity> hoaDonA() async => BillEntity.fromDrift((await db.billDao.getById('a'))!);
  Future<bool> daXoa() async => (await db.billDao.getById('a'))!.isDeleted;

  /// Một GoRouter tối thiểu mang đúng route xác nhận của app, cùng `BillBloc` thật trên CSDL bộ nhớ.
  Future<void> dung(WidgetTester tester, String batDau, Widget Function(GoRouterState) trang) async {
    tester.view.physicalSize = const Size(411, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _AuthCoDinh(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final bloc = BillBloc(repository: BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db));
    addTearDown(bloc.close);
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('gốc'))),
      GoRoute(
        path: '/bills/:id/delete',
        builder: (_, s) => BillDeletePage(id: s.pathParameters['id']!, bill: s.extra as BillEntity?),
      ),
      GoRoute(path: '/dich', builder: (_, s) => trang(s)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    router.push(batDau);
    await tester.pumpAndSettle();
  }

  testWidgets('xacNhanXoaHoaDon: Xác nhận Xóa → hoá đơn bị xoá mềm', (tester) async {
    await dung(tester, '/dich', (_) => Scaffold(
          body: Builder(
            builder: (c) => TextButton(onPressed: () => xacNhanXoaHoaDon(c, 'a'), child: const Text('xoá')),
          ),
        ));
    await tester.tap(find.text('xoá'));
    await tester.pumpAndSettle();
    expect(find.byType(BillDeletePage), findsOneWidget);

    await tester.tap(find.text('Xác nhận Xóa'));
    await tester.pumpAndSettle();

    expect(await daXoa(), isTrue);
    expect(find.byType(BillDeletePage), findsNothing);
  });

  testWidgets('xacNhanXoaHoaDon: Hủy bỏ → không xoá gì', (tester) async {
    await dung(tester, '/dich', (_) => Scaffold(
          body: Builder(
            builder: (c) => TextButton(onPressed: () => xacNhanXoaHoaDon(c, 'a'), child: const Text('xoá')),
          ),
        ));
    await tester.tap(find.text('xoá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy bỏ'));
    await tester.pumpAndSettle();

    expect(await daXoa(), isFalse);
    expect(find.text('xoá'), findsOneWidget);
  });

  testWidgets('trang Chi tiết: nút xoá mở màn xác nhận; xác nhận thì xoá và đóng trang', (tester) async {
    final bill = await hoaDonA();
    await dung(tester, '/dich', (_) => BillDetailPage(id: 'a', bill: bill, now: DateTime(2026, 9, 6)));

    await tester.tap(find.byKey(const ValueKey('bill-detail-delete')));
    await tester.pumpAndSettle();
    expect(find.byType(BillDeletePage), findsOneWidget,
        reason: 'Màn xác nhận theo Stitch, không còn AlertDialog mặc định.');
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Xác nhận Xóa'));
    await tester.pumpAndSettle();

    expect(await daXoa(), isTrue);
    expect(find.byType(BillDetailPage), findsNothing, reason: 'Xoá xong thì không còn gì để xem.');
    expect(find.text('gốc'), findsOneWidget);
  });

  testWidgets('form Sửa: nút "Xóa hóa đơn" mở màn xác nhận; xác nhận thì xoá và đóng form', (tester) async {
    final bill = await hoaDonA();
    await dung(tester, '/dich', (_) => BillEditPage(id: 'a', bill: bill));

    final nut = find.widgetWithText(OutlinedButton, 'Xóa hóa đơn');
    await tester.ensureVisible(nut);
    await tester.tap(nut);
    await tester.pumpAndSettle();
    expect(find.byType(BillDeletePage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Xác nhận Xóa'));
    await tester.pumpAndSettle();

    expect(await daXoa(), isTrue);
    expect(find.byType(BillEditPage), findsNothing);
    expect(find.text('gốc'), findsOneWidget);
  });

  testWidgets('form Sửa: Hủy bỏ thì quay lại form, không xoá', (tester) async {
    final bill = await hoaDonA();
    await dung(tester, '/dich', (_) => BillEditPage(id: 'a', bill: bill));

    final nut = find.widgetWithText(OutlinedButton, 'Xóa hóa đơn');
    await tester.ensureVisible(nut);
    await tester.tap(nut);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy bỏ'));
    await tester.pumpAndSettle();

    expect(await daXoa(), isFalse);
    expect(find.byType(BillEditPage), findsOneWidget);
  });

  testWidgets('route thật của app: /bills/:id/delete dựng BillDeletePage đúng id', (tester) async {
    tester.view.physicalSize = const Size(411, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _AuthCoDinh(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final router = AppRouter.createRouter('/bills/a/delete', auth);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(tester.widget<BillDeletePage>(find.byType(BillDeletePage)).id, 'a');
    expect(find.text('Tiền điện'), findsOneWidget);
  });
}
