/// G76 (phần mục tiêu) — thẻ mục tiêu ở màn HẸP (Realme để cỡ hiển thị lớn:
/// mật độ 540 → 320 dp).
///
/// Quét 2026-10-07: *"2.000.000 đ55.0%"* — phần trăm DÍNH SÁT số tiền. Hàng là
/// `Row(spaceBetween)` mà không phần nào co: hết chỗ thì khoảng cách về 0.
///
/// ⚠️ Roboto thay Inter trong bộ test hẹp hơn vài phần trăm — Realme 320 dp
/// dính mà font test ở 320 dp còn vừa. Ca 320 dp phóng chữ ×1,1 để chừa biên.
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:flowmoney/shared/theme/app_theme.dart';

import '../../../../helpers/font_that.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc() : super(authRepository: _StubAuthRepository()) {
    emit(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'a@b.c'),
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

GoalEntity _goal({double target = 2000000, double current = 1100000}) =>
    GoalEntity(
      id: 'g1',
      idaccount: 10,
      name: 'MuaXe',
      targetAmount: target,
      currentAmount: current,
      targetDate: DateTime(2028, 4, 27),
      isCompleted: false,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    await napFontThat();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> dung(WidgetTester tester, double rong, GoalEntity goal,
      {double chu = 1.0}) async {
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    sl.registerFactory<GoalCubit>(
        () => GoalCubit(repository: _RepoGia([goal])));
    tester.view.physicalSize = Size(rong, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _FixedAuthBloc();
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(chu)),
          child: child!,
        ),
        home: const GoalPage(),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  /// Tháo cây TRƯỚC khi tearDown đóng CSDL (timer dọn dẹp của Drift) — gọi ở
  /// CUỐI THÂN test, không qua `addTearDown`.
  Future<void> thao(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  void veTron(WidgetTester tester, String chu, String vi) {
    final o = find.text(chu);
    expect(o, findsOneWidget, reason: 'phải tìm đúng "$chu" trên thẻ');
    final rp = tester.renderObject<RenderParagraph>(o);
    expect(rp.didExceedMaxLines, isFalse, reason: '$vi: "$chu" bị cắt');
    expect(rp.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(rp.size.width + 0.5),
        reason: '$vi: "$chu" không vừa một dòng');
  }

  final cases = <(double, double, double, double, String, String, String)>[
    (320, 1.1, 2000000, 1100000, '1.100.000 đ', '/ 2.000.000 đ', '55.0%'),
    (300, 1.0, 2000000, 1100000, '1.100.000 đ', '/ 2.000.000 đ', '55.0%'),
    (
      300,
      1.0,
      250000000,
      120000000,
      '120.000.000 đ',
      '/ 250.000.000 đ',
      '48.0%'
    ),
  ];
  for (final (rong, chu, target, current, daCo, dich, phanTram) in cases) {
    testWidgets(
        'G76 · $rong dp ×$chu, $dich: số tiền và phần trăm tách rời, vẽ trọn',
        (tester) async {
      await dung(tester, rong, _goal(target: target, current: current),
          chu: chu);
      expect(tester.takeException(), isNull,
          reason: '$rong dp: hàng số tiền tràn');
      veTron(tester, daCo, '$rong dp');
      veTron(tester, dich, '$rong dp');
      veTron(tester, phanTram, '$rong dp');
      final hopDich = tester.getRect(find.text(dich));
      final hopPt = tester.getRect(find.text(phanTram));
      final cungHang = hopPt.top < hopDich.bottom && hopDich.top < hopPt.bottom;
      if (cungHang) {
        expect(hopPt.left - hopDich.right, greaterThanOrEqualTo(8),
            reason: '$rong dp: "$dich$phanTram" dính sát — cần khoảng cách');
      }
      await thao(tester);
    });
  }

  testWidgets(
      'G76 · 411 dp: dáng cũ GIỮ NGUYÊN — số tiền và phần trăm cùng một hàng',
      (tester) async {
    await dung(tester, 411, _goal());
    final daCo = tester.getRect(find.text('1.100.000 đ'));
    final dich = tester.getRect(find.text('/ 2.000.000 đ'));
    final pt = tester.getRect(find.text('55.0%'));
    expect((daCo.center.dy - dich.center.dy).abs(), lessThan(4),
        reason: 'màn đủ chỗ: "đã có / đích" vẫn trên một dòng');
    expect(pt.left, greaterThan(dich.right + 8));
    await thao(tester);
  });
}
