/// Cùng lỗi với G17, ở trang Danh sách ví — và kèm một món nợ cũ của G4.
///
/// `wallet_list_page.dart` **tự chép tay** phép suy mã tài khoản
/// (`int.tryParse(user?.id ?? '') ?? 0`) thay vì gọi `currentAccountIdOrNull`.
/// Đó đúng là bản chép tay mà `core/auth/current_account.dart` được tạo ra để
/// xoá bỏ, và nó sót lại.
///
/// Cộng thêm: `context.read<AuthBloc>()` không đăng ký gì, còn
/// `BlocProvider.create` chỉ chạy MỘT lần — nên trang dựng trước khi phiên
/// khôi phục xong sẽ gọi `loadWallets(0)` rồi không bao giờ hỏi lại.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flowmoney/features/wallet/presentation/pages/wallet_list_page.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SwitchableAuthBloc extends AuthBloc {
  _SwitchableAuthBloc() : super(authRepository: _StubAuthRepository());

  void dat(AuthState moi) => emit(moi);
}

/// Ghi lại mọi mã tài khoản mà trang hỏi tới.
class _SpyWalletRepository implements WalletRepository {
  final List<int> daHoi = [];

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async {
    daHoi.add(idaccount);
    return const <WalletEntity>[];
  }

  @override
  Future<double> getTotalBalance(int idaccount) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SpyWalletRepository repo;

  setUp(() async {
    repo = _SpyWalletRepository();
    if (sl.isRegistered<WalletCubit>()) {
      await sl.unregister<WalletCubit>();
    }
    sl.registerFactory<WalletCubit>(() => WalletCubit(repository: repo));
  });

  tearDown(() async {
    if (sl.isRegistered<WalletCubit>()) {
      await sl.unregister<WalletCubit>();
    }
  });

  testWidgets('phiên tới muộn thì trang Ví vẫn phải đọc dữ liệu',
      (tester) async {
    final auth = _SwitchableAuthBloc();
    addTearDown(auth.close);
    auth.dat(AuthChecking());

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: const MaterialApp(home: WalletListPage()),
      ),
    );
    await tester.pump();

    auth.dat(AuthSuccess(user: _user('10')));
    await tester.pump();
    await tester.pump();

    expect(
      repo.daHoi,
      contains(10),
      reason: 'Cùng lỗi với G17: trang đọc mã tài khoản MỘT LẦN trong '
          '`BlocProvider.create` qua `context.read`, nên phiên tới sau là nó '
          'không bao giờ hỏi lại — người dùng phải thoát ra vào lại mới thấy '
          'ví của mình.',
    );
    expect(
      repo.daHoi,
      isNot(contains(1)),
      reason: 'Bài học G4: `idaccount = 1` là tài khoản admin THẬT. Đường đọc '
          'không bao giờ được rơi về nó.',
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
