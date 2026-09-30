/// D1 Task 8 — thẻ *"Có N biến động chưa ghi"* trên Sổ giao dịch (Stitch `e59155ff…`): đứng TRÊN thẻ C1, N là số hàng
/// loại 20 chưa ghi (`NotificationDao.watchDemBienDong`), **Xem** mở trung tâm thông báo lọc sẵn nhóm Biến động.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

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

class _KyRongRepository implements TransactionRepository {
  @override
  Stream<List<TransactionEntity>> watchKhoang(int idaccount, DateTime from, DateTime to) =>
      Stream.value(const <TransactionEntity>[]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('vi'));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: _KyRongRepository()),
    );
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(
    WidgetTester tester, {
    Stream<int> Function(int idaccount)? nguonBienDong,
    Stream<int> Function(int idaccount)? nguonChuaGan,
  }) async {
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '7', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final router = GoRouter(
      initialLocation: '/transactions',
      routes: [
        GoRoute(
          path: '/transactions',
          builder: (_, __) => TransactionPage(nguonBienDong: nguonBienDong, nguonChuaGan: nguonChuaGan),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, s) => Scaffold(body: Text('TRUNG TÂM ${s.uri.queryParameters['nhom']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('⭐ N > 0 → thẻ nói đúng N, đứng TRÊN thẻ C1 (Stitch)', (tester) async {
    await moTrang(tester, nguonBienDong: (_) => Stream.value(2), nguonChuaGan: (_) => Stream.value(3));

    expect(find.text('Có 2 biến động chưa ghi'), findsOneWidget);
    expect(find.text('Có 3 giao dịch chưa có danh mục'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Có 2 biến động chưa ghi')).dy,
        lessThan(tester.getTopLeft(find.text('Có 3 giao dịch chưa có danh mục')).dy));

    await dongTrang(tester);
  });

  testWidgets('N = 0 → không dựng thẻ, trang vẫn dựng đủ', (tester) async {
    await moTrang(tester, nguonBienDong: (_) => Stream.value(0), nguonChuaGan: (_) => Stream.value(0));

    expect(find.textContaining('biến động chưa ghi'), findsNothing);
    expect(find.text('Thu nhập'), findsOneWidget, reason: 'ĐÒI KẾT QUẢ: bản sai làm trắng trang cũng xanh kỳ vọng trên');

    await dongTrang(tester);
  });

  testWidgets('⭐ bấm Xem → trung tâm thông báo lọc nhóm bienDong', (tester) async {
    await moTrang(tester, nguonBienDong: (_) => Stream.value(1), nguonChuaGan: (_) => Stream.value(0));

    await tester.tap(find.byKey(const Key('the-bien-dong-xem')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TRUNG TÂM bienDong'), findsOneWidget);

    await dongTrang(tester);
  });

  testWidgets('nguồn mặc định đếm hàng loại 20 của tài khoản đang đăng nhập', (tester) async {
    await tester.runAsync(() async {
      Future<void> them(String id, int acc, String kind) => db.notificationDao.insertIfAbsent(
            AppNotificationsCompanion.insert(
              id: id,
              idaccount: acc,
              kind: kind,
              dedupeKey: 'k-$id',
              title: 't',
              body: 'b',
              severity: 'info',
              createdAt: DateTime(2026, 9, 10),
            ),
          );
      await them('a', 7, 'bienDongSoDu');
      await them('b', 7, 'bienDongSoDu');
      await them('c', 99, 'bienDongSoDu');
      await them('d', 7, 'billDueSoon');
    });

    await moTrang(tester, nguonChuaGan: (_) => Stream.value(0));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Có 2 biến động chưa ghi'), findsOneWidget);

    await dongTrang(tester);
  });

  testWidgets('360 × 640: hai thẻ cùng có không làm tràn bố cục', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await moTrang(tester, nguonBienDong: (_) => Stream.value(12), nguonChuaGan: (_) => Stream.value(12));

    expect(tester.takeException(), isNull);

    await dongTrang(tester);
  });
}
