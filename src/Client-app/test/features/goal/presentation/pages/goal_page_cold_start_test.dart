/// Canh chừng G17: trang Mục tiêu rỗng ở lần vào đầu tiên sau khởi động nguội.
///
/// Tái hiện nhiều lần trên máy ảo: vào Mục tiêu **ngay sau khi mở app nguội**
/// thì danh sách rỗng dù CSDL có dữ liệu; thoát ra vào lại là thấy.
///
/// Nguyên nhân gốc KHÔNG phải `?? 0` như ghi chép ban đầu — `?? 0` chỉ làm lỗi
/// **im lặng** thay vì nổ. Gốc là trang đọc mã tài khoản **đúng một lần** bên
/// trong `BlocProvider.create`, qua `currentAccountIdOrNull` vốn dùng
/// `context.read<AuthBloc>()`. `read` không đăng ký gì cả và `create` chỉ chạy
/// một lần, nên khi trang được dựng trước lúc `AuthBloc` khôi phục xong phiên,
/// nó đăng ký `watchGoals(0)` và giữ nguyên đăng ký ấy mãi.
///
/// `home_page` và `transaction_page` không mắc lỗi này vì chúng dùng
/// `context.watch<AuthBloc>()`.
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
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/goal/presentation/bloc/goal_cubit.dart';
import 'package:flowmoney/features/goal/presentation/pages/goal_page.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Khác `_FixedAuthBloc` ở các tệp test khác: bloc này **đổi trạng thái được**,
/// vì chính cú chuyển `AuthChecking → AuthSuccess` là thứ đang bị bỏ lỡ.
class _SwitchableAuthBloc extends AuthBloc {
  _SwitchableAuthBloc() : super(authRepository: _StubAuthRepository());

  void dat(AuthState moi) => emit(moi);
}

/// Ghi lại MỌI mã tài khoản mà trang hỏi tới. Chỉ tài khoản 10 có dữ liệu.
class _SpyGoalRepository implements GoalRepository {
  final List<int> daHoi = [];

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value(idaccount == 10
        ? [
            GoalEntity(
              id: 'g1',
              idaccount: 10,
              name: 'MuaXe',
              targetAmount: 2000000,
              currentAmount: 1100000,
              targetDate: DateTime(2028, 4, 27),
              updatedAt: DateTime(2026, 9, 1),
            ),
          ]
        : <GoalEntity>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SpyGoalRepository repo;
  late AppDatabase db;

  setUp(() async {
    repo = _SpyGoalRepository();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);
    if (sl.isRegistered<GoalCubit>()) {
      await sl.unregister<GoalCubit>();
    }
    sl.registerFactory<GoalCubit>(() => GoalCubit(repository: repo));
  });

  tearDown(() async {
    if (sl.isRegistered<GoalCubit>()) {
      await sl.unregister<GoalCubit>();
    }
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    await db.close();
  });

  testWidgets('phiên tới muộn thì trang Mục tiêu vẫn phải hiện dữ liệu',
      (tester) async {
    final auth = _SwitchableAuthBloc();
    addTearDown(auth.close);
    // Khởi động nguội: `AuthBloc` đang khôi phục phiên, chưa có tài khoản.
    auth.dat(AuthChecking());

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: const MaterialApp(home: GoalPage()),
      ),
    );
    await tester.pump();

    expect(repo.daHoi, isNotEmpty,
        reason: 'Trang phải hỏi một mã nào đó ngay khi dựng.');

    // Phiên tới nơi — đúng thời điểm mà bản cũ bỏ lỡ.
    auth.dat(AuthSuccess(user: _user('10')));
    await tester.pump();
    await tester.pump();

    expect(
      repo.daHoi,
      contains(10),
      reason: 'Canh chừng G17. Trang đọc mã tài khoản MỘT LẦN trong '
          '`BlocProvider.create`, qua `context.read` nên không đăng ký gì với '
          'AuthBloc. Phiên tới sau là trang không bao giờ hỏi lại, và người '
          'dùng thấy danh sách rỗng cho tới khi thoát ra vào lại.',
    );

    // Tháo cây widget TRƯỚC khi tearDown đóng CSDL. `NotificationBell` trên
    // thanh tiêu đề nhận một stream Drift (đếm thông báo chưa đọc); stream ấy
    // không bao giờ kết thúc, và khi đóng CSDL lúc nó còn sống, Drift hẹn một
    // timer dọn dẹp trong `StreamQueryStore.markAsClosed` — khung test báo
    // "Pending timers" rồi treo. Đây là bẫy khung test, không phải lỗi sản
    // phẩm; cùng họ với bẫy `asyncMap` đã ghi ở mục 6.6 BILL_DOCUMENTATION.
    await tester.pumpWidget(const SizedBox.shrink());
    // `pumpAndSettle` chứ không `pump`: timer dọn dẹp của Drift được hẹn
    // TRONG lúc huỷ đăng ký, nên một nhịp pump chưa chắc đã tới lượt nó.
    await tester.pumpAndSettle();
  });
}

UserModel _user(String id) => UserModel(
      id: id,
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
    );
