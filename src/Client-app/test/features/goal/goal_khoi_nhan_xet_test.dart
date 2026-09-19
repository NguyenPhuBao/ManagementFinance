/// Khối "Nhận xét" trên trang Mục tiêu (Edge-SLM P2, Task 14 — đóng A6).
///
/// Dựng `GoalPage` thật theo khuôn `goal_page_cold_start_test.dart` (cần
/// `AppDatabase` trong GetIt vì `NotificationBell` trên thanh tiêu đề đọc một
/// stream Drift). Canh chừng: khối nói về mục tiêu **đầu tiên đang theo đuổi**
/// với đúng số của `GoalEntity`, và không dựng khi không có mục tiêu nào đang
/// chạy — khung rỗng của tab đã nói câu ấy.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/ai_edge/presentation/widgets/khoi_nhan_xet.dart';
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

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc() : super(authRepository: _StubAuthRepository()) {
    emit(AuthSuccess(
      user: UserModel(
        id: '10',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
  }
}

class _RepoGia implements GoalRepository {
  final List<GoalEntity> goals;
  _RepoGia(this.goals);

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) => Stream.value(goals);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoalEntity _goal({
  required String id,
  required String ten,
  required double target,
  required double current,
  bool isCompleted = false,
}) =>
    GoalEntity(
      id: id,
      idaccount: 10,
      name: ten,
      targetAmount: target,
      currentAmount: current,
      targetDate: DateTime(2028, 4, 27),
      isCompleted: isCompleted,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);
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

  Future<void> dung(WidgetTester tester, List<GoalEntity> goals) async {
    if (sl.isRegistered<GoalCubit>()) {
      await sl.unregister<GoalCubit>();
    }
    sl.registerFactory<GoalCubit>(
        () => GoalCubit(repository: _RepoGia(goals)));
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _FixedAuthBloc();
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: const MaterialApp(home: GoalPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Tháo cây TRƯỚC khi tearDown đóng CSDL — cùng lý do ghi ở
  /// `goal_page_cold_start_test.dart` (timer dọn dẹp của Drift). ⚠️ Phải gọi ở
  /// CUỐI THÂN test, không qua `addTearDown`: khung test kiểm "Pending timers"
  /// ngay khi thân test kết thúc, trước mọi tearDown.
  Future<void> thao(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('có mục tiêu đang theo đuổi → một khối, câu đúng số',
      (tester) async {
    await dung(tester, [
      _goal(id: 'g1', ten: 'MuaXe', target: 2000000, current: 1100000),
    ]);

    expect(find.byType(KhoiNhanXet), findsOneWidget,
        reason: 'A6: trang Mục tiêu phải có khối Nhận xét (Stitch b396533b…).');
    // 1.100.000 / 2.000.000 = 55,0 %; còn thiếu 900.000. Số ngày còn lại phụ
    // thuộc đồng hồ máy nên không khẳng định.
    expect(find.textContaining('MuaXe: 55,0%, còn thiếu 900.000 đ'),
        findsOneWidget,
        reason: 'Câu phải nói về mục tiêu đầu tiên đang theo đuổi với đúng số '
            'của `GoalEntity.progress` / `remainingAmount`.');
    // ⚠️ Không khẳng định `takeException() == null` ở đây: thẻ mục tiêu có
    // sẵn (`goal_page.dart`, hàng số tiền + phần trăm) tràn 150px ở 411dp với
    // font Ahem của bộ test (rộng gấp đôi, bẫy 4.4) — có từ trước Task 14, không
    // do khối mới. Khối Nhận xét có ca 411dp riêng ở `khoi_nhan_xet_test.dart`.
    tester.takeException();
    await thao(tester);
  });

  testWidgets('chỉ có mục tiêu đã hoàn thành → KHÔNG dựng khối',
      (tester) async {
    await dung(tester, [
      _goal(
          id: 'g1',
          ten: 'Xong',
          target: 1000000,
          current: 1000000,
          isCompleted: true),
    ]);

    expect(find.byType(KhoiNhanXet), findsNothing,
        reason: 'Tab "Đang theo đuổi" rỗng đã có khung rỗng nói "Không còn '
            'mục tiêu nào đang chạy"; một thẻ Nhận xét nói y hệt là thừa.');
    await thao(tester);
  });
}
