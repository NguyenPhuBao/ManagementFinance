/// Canh chừng **bẫy 4.5** `GOAL_FEATURE.md`: trang chi tiết mục tiêu không
/// nghe dòng dữ liệu.
///
/// Bản cũ lấy `sl<GoalRepository>()` trong `initState`, gọi `getGoalById` đúng
/// **một lần**, rồi tự giữ `_goal` trong `State`. Đồng bộ kéo về một thay đổi
/// của chính mục tiêu **đang mở** thì màn hình vẫn hiện số cũ — không lỗi,
/// không log, và người dùng chỉ phát hiện khi thoát ra vào lại. Trang danh sách
/// thì ngược lại: nó nghe `watchGoals` nên tự cập nhật.
///
/// Bán kính của bẫy này **vừa rộng ra** ngày 2026-09-08: cột `priority` nay
/// cũng đi qua đường đồng bộ, nên số thay đổi kéo về trên một mục tiêu đang mở
/// nhiều hơn trước.
library;

import 'dart:async';

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
import 'package:flowmoney/features/goal/presentation/pages/goal_detail_page.dart';

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

GoalEntity _mt({double current = 1100000}) => GoalEntity(
      id: 'g1',
      idaccount: 10,
      name: 'MuaXe',
      targetAmount: 2000000,
      currentAmount: current,
      startDate: DateTime(2026, 1, 1),
      targetDate: DateTime(2028, 4, 27),
      updatedAt: DateTime(2026, 9, 1),
    );

/// Trả một dòng dữ liệu **điều khiển được**, đúng như `watchGoals` thật: nó
/// phát lại mỗi khi bảng `goals` đổi, kể cả khi cái đổi nó là nhánh pull.
class _LiveGoalRepository implements GoalRepository {
  final _ctrl = StreamController<List<GoalEntity>>.broadcast();
  GoalEntity hienTai = _mt();
  int soLanHoiWatch = 0;

  void keoVe(GoalEntity moi) {
    hienTai = moi;
    _ctrl.add([moi]);
  }

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    soLanHoiWatch++;
    return _ctrl.stream;
  }

  @override
  Future<GoalEntity?> getGoalById(String id) async => hienTai;

  @override
  Stream<dynamic> watchGoalTransactions(
    int idaccount,
    String goalId,
    String goalName,
  ) =>
      Stream<List<dynamic>>.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _LiveGoalRepository repo;
  late AppDatabase db;

  setUp(() async {
    repo = _LiveGoalRepository();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    if (sl.isRegistered<GoalRepository>()) {
      await sl.unregister<GoalRepository>();
    }
    sl.registerSingleton<GoalRepository>(repo);
  });

  tearDown(() async {
    if (sl.isRegistered<GoalRepository>()) {
      await sl.unregister<GoalRepository>();
    }
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    await repo._ctrl.close();
    await db.close();
  });

  Future<void> moTrang(WidgetTester tester) async {
    final auth = _FixedAuthBloc();
    addTearDown(auth.close);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: const MaterialApp(home: GoalDetailPage(id: 'g1')),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('đăng ký với dòng dữ liệu ngay khi mở trang', (tester) async {
    await moTrang(tester);

    expect(repo.soLanHoiWatch, greaterThan(0),
        reason: 'Bẫy 4.5: bản cũ chỉ gọi `getGoalById` một lần rồi tự giữ '
            '`_goal` trong State, nên không có đăng ký nào để đồng bộ đánh '
            'thức. Không hỏi `watchGoals` là lỗi quay lại y nguyên.');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('đồng bộ kéo về số mới thì màn hình đổi theo', (tester) async {
    await moTrang(tester);

    expect(find.textContaining('1.100.000'), findsWidgets,
        reason: 'Số ban đầu, đọc qua `getGoalById`.');

    // Máy khác nạp thêm 400 nghìn rồi đẩy lên; lượt pull kế tiếp ghi xuống
    // SQLite và `watchGoals` phát lại — đây đúng là ca mà bản cũ bỏ lỡ.
    repo.keoVe(_mt(current: 1500000));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('1.500.000'), findsWidgets,
        reason: 'Trang phải hiện số MỚI. Bản cũ giữ nguyên 1.100.000 cho tới '
            'khi người dùng thoát ra vào lại — hai máy nói hai con số khác '
            'nhau về cùng một mục tiêu, im lặng.');
    expect(find.textContaining('1.100.000'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('mục tiêu bị xoá ở máy khác thì trang không giữ số cũ',
      (tester) async {
    await moTrang(tester);

    repo.keoVe(_mt().copyWith(isDeleted: true));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Cờ xoá kéo về khi trang đang mở không được làm màn đỏ. Đây '
            'là ca hiếm nhưng có thật: xoá mục tiêu ở máy khác trong lúc máy '
            'này đang mở đúng nó.');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
