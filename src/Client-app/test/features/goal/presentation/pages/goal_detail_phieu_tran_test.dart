/// Hai ô số tiền của phiếu Nạp / Rút (trang Chi tiết mục tiêu) có trần 13 chữ số như mọi ô tiền khác (spec 2026-10-13
/// mục 4). Trước đợt ấy hai ô chỉ bị chặn gián tiếp bởi "Số dư ví … không đủ" / "Mục tiêu chỉ đang giữ …".
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
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

import '../../../../helpers/nguon_doc_gia.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc() : super(authRepository: _StubAuthRepository()) {
    emit(AuthSuccess(
      user: UserModel(
          id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
  }
}

final _mucTieu = GoalEntity(
  id: 'g1',
  idaccount: 10,
  name: 'MuaXe',
  targetAmount: 2000000,
  currentAmount: 1100000,
  startDate: DateTime(2026, 1, 1),
  targetDate: DateTime(2028, 4, 27),
  updatedAt: DateTime(2026, 9, 1),
  walletId: 'vi-tl',
);

class _GoalRepoGia implements GoalRepository {
  final _ctrl = StreamController<List<GoalEntity>>.broadcast();
  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) => _ctrl.stream;
  @override
  Future<GoalEntity?> getGoalById(String id) async => _mucTieu;
  @override
  Future<List<GoalEntity>> getGoals(int idaccount) async => [_mucTieu];
  @override
  Stream<dynamic> watchGoalTransactions(
          int idaccount, String goalId, String goalName) =>
      Stream<List<dynamic>>.value(const []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late _GoalRepoGia repo;

  setUp(() async {
    repo = _GoalRepoGia();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
    if (sl.isRegistered<GoalRepository>()) {
      await sl.unregister<GoalRepository>();
    }
    sl.registerSingleton<GoalRepository>(repo);
    for (final (id, ten) in [('vi-tl', 'Tiết kiệm'), ('vi-tm', 'Tiền mặt')]) {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: id,
        idaccount: 10,
        name: ten,
        balance: const Value(5000000),
        updatedAt: DateTime(2026, 9, 1),
      ));
    }
  });

  tearDown(() async {
    if (sl.isRegistered<GoalRepository>()) {
      await sl.unregister<GoalRepository>();
    }
    if (sl.isRegistered<AppDatabase>()) {
      await sl.unregister<AppDatabase>();
    }
    await repo._ctrl.close();
    await db.close();
  });

  Future<void> moPhieu(WidgetTester tester, String nut) async {
    final auth = _FixedAuthBloc();
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: const MaterialApp(home: GoalDetailPage(id: 'g1')),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(nut));
    await tester.tap(find.text(nut));
    await tester.pumpAndSettle();
  }

  Future<void> goVuotTran(WidgetTester tester, String nhanO) async {
    final o = find.widgetWithText(TextField, nhanO);
    expect(o, findsOneWidget, reason: 'Phiếu phải đang mở, có ô "$nhanO".');
    await tester.enterText(o, '1234567890123'); // 13 chữ số — đúng trần.
    await tester.pump();
    await tester.enterText(o, '12345678901234'); // chữ số thứ 14.
    await tester.pump();
    expect(tester.widget<TextField>(o).controller!.text, '1234567890123',
        reason:
            'Tám cột tiền PostgreSQL là numeric(15,2): chữ số thứ 14 phải không vào ô, như mọi ô tiền khác '
            '(GioiHanSoChuSo giữ chuỗi cũ khi vượt).');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('phiếu Nạp: ô số tiền chặn ở 13 chữ số', (tester) async {
    await moPhieu(tester, 'Gửi thêm tiết kiệm');
    await goVuotTran(tester, 'Nhập số tiền muốn tích lũy thêm (VNĐ)');
  });

  testWidgets('phiếu Rút: ô số tiền chặn ở 13 chữ số', (tester) async {
    await moPhieu(tester, 'Rút khỏi mục tiêu');
    await goVuotTran(tester, 'Số tiền muốn rút (VNĐ)');
  });
}
