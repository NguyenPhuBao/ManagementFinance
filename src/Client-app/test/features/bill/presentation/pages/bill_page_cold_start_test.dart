/// Cùng lỗi với G17, ở trang Hoá đơn — nhưng **hình dạng khác hai trang kia**.
///
/// `goal_page` và `budget_page` hỏng vì đọc mã tài khoản trong
/// `BlocProvider.create` (chạy một lần). Trang này không có `BlocProvider` —
/// `BillBloc` do router cung cấp — mà nạp trong `addPostFrameCallback` của
/// `initState`, với `if (accountId == null) return;`.
///
/// Hệ quả y hệt và im lặng hơn: chưa có phiên thì **không nạp gì cả**, và vì
/// `initState` chỉ chạy một lần, nó **không bao giờ thử lại**. Người dùng thấy
/// trang hoá đơn trống cho tới khi thoát ra vào lại.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_page.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SwitchableAuthBloc extends AuthBloc {
  _SwitchableAuthBloc() : super(authRepository: _StubAuthRepository());

  void dat(AuthState moi) => emit(moi);
}

/// Ghi lại mọi mã tài khoản mà trang hỏi tới.
class _SpyBillRepository implements BillRepository {
  final List<int> daHoi = [];

  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value(const <Bill>[]);
  }

  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SpyBillRepository repo;
  late AppDatabase db;

  setUp(() async {
    repo = _SpyBillRepository();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    await db.close();
  });

  testWidgets('phiên tới muộn thì trang Hoá đơn vẫn phải nạp dữ liệu',
      (tester) async {
    final auth = _SwitchableAuthBloc();
    addTearDown(auth.close);
    final bloc = BillBloc(repository: repo);
    addTearDown(bloc.close);

    auth.dat(AuthChecking());

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: BlocProvider<BillBloc>.value(
          value: bloc,
          child: const MaterialApp(home: BillPage()),
        ),
      ),
    );
    await tester.pump();

    expect(repo.daHoi, isEmpty,
        reason: 'Chưa có phiên thì KHÔNG được đoán một mã tài khoản (G4).');

    auth.dat(AuthSuccess(user: _user('10')));
    await tester.pump();
    await tester.pump();

    expect(
      repo.daHoi,
      contains(10),
      reason: 'Trang nạp trong `addPostFrameCallback` của `initState` và bỏ '
          'qua khi chưa có phiên. `initState` chỉ chạy MỘT lần nên khi phiên '
          'tới sau, không có gì nạp lại — trang hoá đơn trống cho tới khi '
          'người dùng thoát ra vào lại.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

UserModel _user(String id) => UserModel(
      id: id,
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
    );
