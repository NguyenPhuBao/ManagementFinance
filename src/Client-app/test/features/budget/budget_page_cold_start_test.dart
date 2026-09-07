/// Cùng lỗi với G17, nhưng ở trang Ngân sách.
///
/// `budget_page.dart` có **đúng hình dạng** đã làm hỏng trang Mục tiêu: đọc mã
/// tài khoản bằng `currentAccountIdOrNull` (vốn dùng `context.read`, không đăng
/// ký gì) rồi truyền vào `BlocProvider.create` — thứ chỉ chạy MỘT lần. Trang
/// dựng trước khi `AuthBloc` khôi phục xong phiên sẽ gọi `watchBudgets(null)`
/// và không bao giờ hỏi lại.
///
/// Khác trang Mục tiêu ở một điểm khiến nó **khó thấy hơn**: `?? 0` không có ở
/// đây, cubit nhận thẳng `null` và cố ý *không đọc gì cả*. Nghĩa là người dùng
/// không thấy "danh sách rỗng" mà thấy trạng thái ban đầu — im lặng hơn nữa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_cubit.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_page.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SwitchableAuthBloc extends AuthBloc {
  _SwitchableAuthBloc() : super(authRepository: _StubAuthRepository());

  void dat(AuthState moi) => emit(moi);
}

/// Ghi lại mọi mã tài khoản mà trang hỏi tới.
class _SpyBudgetRepository implements BudgetRepository {
  final List<int> daHoi = [];

  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) {
    daHoi.add(idaccount);
    return Stream.value(const <BudgetView>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SpyBudgetRepository repo;

  setUp(() async {
    repo = _SpyBudgetRepository();
    if (sl.isRegistered<BudgetCubit>()) {
      await sl.unregister<BudgetCubit>();
    }
    sl.registerFactory<BudgetCubit>(() => BudgetCubit(repository: repo));
  });

  tearDown(() async {
    if (sl.isRegistered<BudgetCubit>()) {
      await sl.unregister<BudgetCubit>();
    }
  });

  testWidgets('phiên tới muộn thì trang Ngân sách vẫn phải đọc dữ liệu',
      (tester) async {
    final auth = _SwitchableAuthBloc();
    addTearDown(auth.close);
    // Khởi động nguội: AuthBloc đang khôi phục phiên.
    auth.dat(AuthChecking());

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: const MaterialApp(home: BudgetPage()),
      ),
    );
    await tester.pump();

    expect(repo.daHoi, isEmpty,
        reason: 'Chưa có phiên thì KHÔNG được đoán một mã tài khoản — đó là '
            'bài học G4, và trang này vốn đã làm đúng.');

    // Phiên tới nơi.
    auth.dat(AuthSuccess(user: _user('10')));
    await tester.pump();
    await tester.pump();

    expect(
      repo.daHoi,
      contains(10),
      reason: 'Cùng lỗi với G17: trang đọc mã tài khoản MỘT LẦN trong '
          '`BlocProvider.create` qua `context.read`, nên phiên tới sau là nó '
          'không bao giờ hỏi lại. Người dùng phải thoát ra vào lại mới thấy '
          'ngân sách của mình.',
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
