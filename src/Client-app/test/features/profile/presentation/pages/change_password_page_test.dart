/// Đổi mật khẩu xong thì phiên phải ĐÓNG THẬT (soát bảo mật 2026-10-24).
///
/// Lỗi cũ: `AuthRepository.changePassword` xoá token nhưng màn không báo `AuthBloc` — state vẫn `AuthSuccess`, nên
/// `context.go('/login')` bị `authRedirect` đẩy ngược về `/home`. Người dùng thấy toast *"Vui lòng đăng nhập lại"* mà vẫn
/// ở Trang chủ; `PhienDieuPhoi.dongPhien` không chạy nên đồng bộ, socket, bộ quét, cờ đọc tin ngân hàng (D1), cờ nhận
/// biên lai và lịch tự chuyển tiền nền vẫn bật — app ở trạng thái "đăng nhập không token", mọi lời gọi API lỗi 401 im lặng.
library;

import 'dart:async';

import 'package:flowmoney/core/auth/buoc_dang_xuat.dart';
import 'package:flowmoney/core/auth/phien_dieu_phoi.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/profile/presentation/pages/change_password_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RepoGia implements AuthRepository {
  final doiMatKhau = <List<String>>[];
  int logoutCalls = 0;

  @override
  Future<UserModel> login(String username, String password) async =>
      UserModel(id: '11', username: 'dat', name: 'Đạt', email: 'dat@example.com');

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async =>
      doiMatKhau.add([currentPassword, newPassword]);

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _PhienGia implements PhienDieuPhoi {
  int dongPhienCalls = 0;

  @override
  Stream<void> get phienCoTheChet => const Stream.empty();

  @override
  Stream<ThongBaoBuocDangXuat> get buocDangXuat => const Stream.empty();

  @override
  Future<void> moPhienCucBo(int idaccount) async {}

  @override
  Future<void> batThoiGianThuc(int idaccount) async {}

  @override
  Future<void> batDongBo(int idaccount, {required bool cho}) async {}

  @override
  Future<void> sauDangNhap(int idaccount) async {}

  @override
  Future<void> dongPhien() async => dongPhienCalls++;

  @override
  Future<void> dispose() async {}
}

void main() {
  late _RepoGia repo;
  late _PhienGia phien;

  setUp(() {
    repo = _RepoGia();
    phien = _PhienGia();
    sl.registerSingleton<AuthRepository>(repo);
  });

  tearDown(() async => sl.reset());

  testWidgets('đổi mật khẩu thành công → đóng phiên và về màn Đăng nhập', (tester) async {
    // Khổ rộng: ca này canh luồng phiên, không canh bố cục — ở 411 dp font Ahem của `flutter test` (1 em mỗi ký tự) làm
    // dòng "Chứa ít nhất 1 ký tự đặc biệt" (11 px) tràn 23 px, font thật chỉ ~165 px.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Bloc và router dựng TRONG thân ca (zone FakeAsync của testWidgets): dựng ở `setUp` thì microtask của handler Bloc
    // nằm ở zone thật, `pump()` không chạy tới — Bloc kẹt ở `AuthLoading` dù `dongPhien` đã gọi.
    final bloc = AuthBloc(authRepository: repo, phien: phien);
    addTearDown(bloc.close);
    bloc.add(const LoginSubmitted(email: 'dat', password: 'cu123456'));
    await tester.pump();
    expect(bloc.state, isA<AuthSuccess>(), reason: 'tiền đề: đang đăng nhập');

    // Cùng cách nối router với AuthBloc như `AppRouter.createRouter` — chỉ thay ba trang bằng nhãn.
    final lamMoi = GoRouterRefreshStream(bloc.stream);
    addTearDown(lamMoi.dispose);
    final router = GoRouter(
      initialLocation: '/doi-mat-khau',
      refreshListenable: lamMoi,
      redirect: (_, s) => AppRouter.authRedirect(authState: bloc.state, matchedLocation: s.matchedLocation),
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const Text('MÀN ĐĂNG NHẬP')),
        GoRoute(path: '/home', builder: (_, __) => const Text('TRANG CHỦ')),
        GoRoute(path: '/doi-mat-khau', builder: (_, __) => const ChangePasswordPage()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pump();

    final o = find.byType(TextFormField);
    await tester.enterText(o.at(0), 'cu123456');
    await tester.enterText(o.at(1), 'moi123456');
    await tester.enterText(o.at(2), 'moi123456');
    final nut = find.text('Cập Nhật Mật Khẩu');
    await tester.ensureVisible(nut);
    await tester.tap(nut);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(repo.doiMatKhau, [
      ['cu123456', 'moi123456']
    ]);
    expect(find.text('MÀN ĐĂNG NHẬP'), findsOneWidget,
        reason: 'Màn báo "Vui lòng đăng nhập lại" thì phải tới màn Đăng nhập — bản cũ bị authRedirect đẩy về /home '
            'vì AuthBloc vẫn AuthSuccess.');
    expect(find.text('TRANG CHỦ'), findsNothing);
    expect(bloc.state, isA<AuthUnauthenticated>());
    expect(phien.dongPhienCalls, 1,
        reason: 'Không đóng phiên thì đồng bộ, socket, bộ quét, cờ đọc tin ngân hàng D1, cờ nhận biên lai và lịch tự '
            'chuyển tiền nền vẫn chạy sau khi token đã bị xoá.');
    expect(tester.takeException(), isNull);
  });
}
