/// Hộp *"Bắt đầu vòng mới?"* (trang Chi tiết mục tiêu) khuyên bấm *"Rút khỏi mục tiêu"* để tiêu số đã tích — chỉ khi nút
/// ấy bấm được. Quyền `goal_deposit_withdraw` khoá (B1, spec 2026-10-27 mục 3) thì nút Rút tắt, và lời khuyên chỉ người
/// dùng vào một nút chết (đợt sửa cuối B1, soát Task 10).
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
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';

import '../../../../helpers/goi_gia.dart';
import '../../../../helpers/nguon_doc_gia.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc() : super(authRepository: _StubAuthRepository()) {
    emit(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
  }
}

/// Mục tiêu ĐÃ XONG và CÓ lặp lại — nút *"Bắt đầu vòng mới"* chỉ hiện khi đủ cả hai (`nut_duoi_muc_tieu.dart`).
final _mucTieu = GoalEntity(
  id: 'g1',
  idaccount: 10,
  name: 'QuyDuLich',
  targetAmount: 2000000,
  currentAmount: 2000000,
  startDate: DateTime(2026, 1, 1),
  targetDate: DateTime(2026, 9, 30),
  updatedAt: DateTime(2026, 9, 1),
  walletId: 'vi-tl',
  recurrence: true,
  timeRecurrence: 'monthly',
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
  Stream<List<TransactionEntity>> watchGoalTransactions(int idaccount, String goalId, String goalName) =>
      Stream.value(const <TransactionEntity>[]);
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
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'vi-tl',
      idaccount: 10,
      name: 'Tiết kiệm',
      balance: const Value(5000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
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

  /// Mở trang, chạm *"Bắt đầu vòng mới"*, trả về finder chữ thân hộp xác nhận.
  Future<Finder> moHop(WidgetTester tester, GoiCubit goi) async {
    final auth = _FixedAuthBloc();
    addTearDown(auth.close);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<GoiCubit>.value(value: goi),
      ],
      child: const MaterialApp(home: GoalDetailPage(id: 'g1')),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bắt đầu vòng mới'));
    await tester.tap(find.text('Bắt đầu vòng mới'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'hộp "Bắt đầu vòng mới?" phải đang mở');
    return find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('vẫn nằm nguyên'));
  }

  Future<void> dong(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('⭐ goal_deposit_withdraw khoá → hộp KHÔNG khuyên bấm "Rút khỏi mục tiêu" (nút ấy đang tắt)', (tester) async {
    final than = await moHop(tester, goiBasic(const {'goal_deposit_withdraw': false}));
    expect(than, findsOneWidget, reason: 'câu "tiền vẫn nằm nguyên trong ví" giữ nguyên');
    expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('Rút khỏi mục tiêu')), findsNothing,
        reason: 'nút Rút đã khoá theo quyền — khuyên bấm nó là chỉ vào một nút chết');
    await dong(tester);
  });

  testWidgets('có quyền nạp / rút → hộp vẫn khuyên "Rút khỏi mục tiêu" như cũ', (tester) async {
    final than = await moHop(tester, goiBasic(const {}));
    expect(than, findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('Rút khỏi mục tiêu')),
        findsOneWidget);
    await dong(tester);
  });
}
