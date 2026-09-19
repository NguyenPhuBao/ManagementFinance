/// Trang Ngân sách phải có đường quay lại — nhóm D, 2026-09-19.
///
/// ## Vì sao
///
/// `/budget` **rời `StatefulShellRoute`** ngày 2026-09-19: nó nhường chỗ ở
/// thanh dưới cho Sổ giao dịch và nay được `push` từ drawer. Nhưng header của
/// trang được viết hồi nó còn là **tab**, nên nó đặt
/// `automaticallyImplyLeading: false` — một tab thì không có gì để pop, và cờ
/// ấy đúng vào lúc ấy. Sau khi rời shell, chính cờ đó biến trang thành **ngõ
/// cụt**: không mũi tên quay lại, và cũng không còn thanh tab bên dưới vì
/// route đã chồng lên toàn màn.
///
/// Hai trạng thái còn lại tệ hơn: `_EmptyScaffold` và `_ErrorScaffold` **không
/// có `AppBar` nào cả**, nên tài khoản chưa có ngân sách nào sẽ rơi vào một
/// màn trắng không lối ra.
///
/// ⚠️ Máy ảo bắt được cả ba, trong khi 2953 ca test đều xanh — `flutter test`
/// không dựng cây route thật nên không có gì để pop, và ở đó cờ kia vô hại.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_cubit.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RepoGia implements BudgetRepository {
  _RepoGia(this.hang);
  final List<BudgetView> hang;

  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) =>
      Stream.value(hang);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthGia extends AuthBloc {
  _AuthGia() : super(authRepository: _RepoAuthGia());
  void dat(AuthState s) => emit(s);
}

class _RepoAuthGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BudgetView _mot() => BudgetView(
      budget: BudgetEntity(
        id: 'b1',
        idaccount: 10,
        categoryId: 'food',
        amount: 500000,
        spent: 100000,
        overSpending: BudgetOverSpending.over,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: 'Ăn uống',
    );

void main() {
  Future<void> moQuaDrawer(WidgetTester tester, List<BudgetView> hang) async {
    if (sl.isRegistered<BudgetCubit>()) await sl.unregister<BudgetCubit>();
    sl.registerFactory<BudgetCubit>(() => BudgetCubit(repository: _RepoGia(hang)));
    addTearDown(() async {
      if (sl.isRegistered<BudgetCubit>()) await sl.unregister<BudgetCubit>();
    });

    final auth = _AuthGia();
    addTearDown(auth.close);
    auth.dat(AuthSuccess(
      user: UserModel(
          id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));

    // Router thật: `/budget` được **push** từ một trang khác, đúng như drawer
    // làm. `MaterialApp(home:)` thì không có gì để pop và ca test mất nghĩa.
    final router = GoRouter(
      initialLocation: '/truoc',
      routes: [
        GoRoute(
            path: '/truoc',
            builder: (_, __) => const Scaffold(body: Text('TRANG TRƯỚC'))),
        GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(
          theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();

    router.push('/budget');
    await tester.pumpAndSettle();
  }

  testWidgets('⚠️ có ngân sách: header có mũi tên quay lại', (tester) async {
    await moQuaDrawer(tester, [_mot()]);

    expect(find.text('Ngân sách'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget,
        reason: '`automaticallyImplyLeading: false` đúng hồi trang này là một '
            'tab, nhưng từ 2026-09-19 nó được push từ drawer — cờ ấy nay biến '
            'trang thành ngõ cụt, và thanh tab cũng không còn vì route chồng '
            'lên toàn màn.');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('TRANG TRƯỚC'), findsOneWidget);
  });

  testWidgets('⚠️ chưa có ngân sách nào: vẫn phải quay lại được',
      (tester) async {
    await moQuaDrawer(tester, const []);

    expect(find.text('Chưa có ngân sách nào'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget,
        reason: 'Trạng thái rỗng KHÔNG có `AppBar` nào — tài khoản mới mở '
            'Ngân sách lần đầu rơi vào một màn trắng không lối ra. Đây là ca '
            'người dùng mới gặp trước tiên.');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('TRANG TRƯỚC'), findsOneWidget);
  });
}
