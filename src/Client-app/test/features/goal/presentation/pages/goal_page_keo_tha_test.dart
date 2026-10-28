/// G112 — vuốt để CUỘN trang Mục tiêu không được đổi thứ tự ưu tiên.
///
/// Realme 2026-10-28 phiên 22: một cú `input swipe` 400 ms bắt đầu trên thẻ MuaDT để cuộn trang đã kéo MuaDT lên trên
/// MuaXe — ưu tiên 1 / 3 thành 100 / 200, đồng bộ lên server, không hộp nào hỏi. Thẻ bọc `ReorderableDragStartListener`
/// (bắt kéo NGAY khi ngón tay di chuyển) trong khi chữ hướng dẫn dưới danh sách nói *"Nhấn giữ một mục tiêu để kéo đổi thứ
/// tự ưu tiên"*. Luật: kéo thả chỉ bắt đầu sau khi NHẤN GIỮ; vuốt thường là cuộn.
library;

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
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

import '../../../../helpers/nguon_doc_gia.dart';

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
  final List<Map<String, int>> lanDoiUuTien = [];
  _RepoGia(this.goals);

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) => Stream.value(goals);

  @override
  Future<void> capNhatUuTien(Map<String, int> uuTienMoi) async => lanDoiUuTien.add(uuTienMoi);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoalEntity _goal(String id, String ten, int uuTien) => GoalEntity(
      id: id,
      idaccount: 10,
      name: ten,
      targetAmount: 2000000,
      currentAmount: 500000,
      targetDate: DateTime(2028, 4, 27),
      isCompleted: false,
      priority: uuTien,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  late AppDatabase db;
  late _RepoGia repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
    repo = _RepoGia([_goal('g1', 'MuaXe', 1), _goal('g2', 'MuaDT', 3)]);
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    sl.registerFactory<GoalCubit>(() => GoalCubit(repository: repo));
  });

  tearDown(() async {
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<void> dung(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _FixedAuthBloc();
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: const MaterialApp(home: GoalPage()),
    ));
    await tester.pump();
    await tester.pump();
  }

  /// Tháo cây TRƯỚC khi tearDown đóng CSDL (timer dọn dẹp của Drift) — gọi ở CUỐI THÂN test.
  Future<void> thao(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ G112 — vuốt nhanh từ thẻ thứ hai lên trên là CUỘN, không đổi ưu tiên', (tester) async {
    await dung(tester);
    expect(find.text('MuaDT'), findsWidgets, reason: 'tiền đề: thẻ MuaDT phải dựng');
    // Như `adb shell input swipe` 400 ms: ngón tay chạm rồi đi ngay, không dừng.
    await tester.timedDrag(find.text('MuaDT').first, const Offset(0, -300), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repo.lanDoiUuTien, isEmpty,
        reason: 'G112: cú vuốt cuộn trang đã kéo thẻ đổi chỗ — ưu tiên đổi và đồng bộ lên mà người dùng không định');
    await thao(tester);
  });

  testWidgets('nhấn giữ rồi kéo thẻ thứ hai lên trên → đổi ưu tiên (kéo thả vẫn chạy)', (tester) async {
    await dung(tester);
    final g = await tester.startGesture(tester.getCenter(find.text('MuaDT').first), kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(repo.lanDoiUuTien, hasLength(1), reason: 'nhấn giữ đủ lâu rồi kéo phải sắp lại thứ tự');
    final moi = repo.lanDoiUuTien.single;
    expect(moi['g2']! < moi['g1']!, isTrue, reason: 'MuaDT kéo lên trên phải đứng trước MuaXe: $moi');
    await thao(tester);
  });
}
