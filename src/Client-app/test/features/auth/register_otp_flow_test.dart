import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/constants/app_router.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/auth/presentation/pages/login_page.dart';
import 'package:go_router/go_router.dart';

class _SuccessfulRegistrationRepository implements AuthRepository {
  int sendOtpCalls = 0;

  @override
  Future<void> registerSendOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    String? phone,
  }) async {
    sendOtpCalls++;
  }

  @override
  Future<void> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _appWithRouter(GoRouter router, AuthBloc bloc) {
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('auth redirect policy', () {
    test('startup auth states may wait on protected routes', () {
      expect(
        AppRouter.authRedirect(
          authState: AuthInitial(),
          matchedLocation: '/home',
        ),
        isNull,
      );
      expect(
        AppRouter.authRedirect(
          authState: AuthChecking(),
          matchedLocation: '/home',
        ),
        isNull,
      );
    });

    test('operation loading is allowed only on public routes', () {
      expect(
        AppRouter.authRedirect(
          authState: AuthLoading(),
          matchedLocation: '/register',
        ),
        isNull,
      );
      expect(
        AppRouter.authRedirect(
          authState: AuthLoading(),
          matchedLocation: '/home',
        ),
        '/login',
      );
    });
  });

  testWidgets('OTP route redirects to registration when its state is absent',
      (tester) async {
    final bloc = AuthBloc(authRepository: _SuccessfulRegistrationRepository());
    final router = AppRouter.createRouter('/register/verify-otp', bloc);
    addTearDown(router.dispose);
    addTearDown(bloc.close);

    await tester.pumpWidget(_appWithRouter(router, bloc));
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/register');
  });

  testWidgets(
      'OTP completion shows feedback, returns to blank login, and keeps protected routes private',
      (tester) async {
    final bloc = AuthBloc(authRepository: _SuccessfulRegistrationRepository());
    final router = AppRouter.createRouter('/register/verify-otp', bloc);
    addTearDown(router.dispose);
    addTearDown(bloc.close);

    await tester.pumpWidget(_appWithRouter(router, bloc));
    router.go(
      '/register/verify-otp',
      extra: const RegisterOtpSent(
        username: 'new-user',
        fullname: 'New User',
        email: 'new@example.com',
        password: 'password123',
      ),
    );
    await tester.pump();

    for (var index = 0; index < 6; index++) {
      await tester.enterText(
          find.byType(TextFormField).at(index), '${index + 1}');
    }
    final loading =
        bloc.stream.firstWhere((state) => state is RegisterOtpLoading);
    final completion = bloc.stream.firstWhere(
      (state) => state is RegistrationCompleted,
    );
    await tester.tap(find.text('Xác nhận'));
    await loading;
    await tester.pump();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/register/verify-otp',
    );
    expect(find.text('Xác thực Email'), findsOneWidget);

    await completion;
    await tester.pump();

    expect(
        find.text('Đăng ký thành công. Vui lòng đăng nhập.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.byType(LoginPage), findsOneWidget);
    final loginFields =
        tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(loginFields, hasLength(2));
    expect(loginFields.map((field) => field.controller!.text),
        everyElement(isEmpty));

    router.go('/home');
    await tester.pump();

    expect(bloc.state, isNot(isA<AuthSuccess>()));
    expect(router.routeInformationProvider.value.uri.path, '/login');
  });

  testWidgets('resending OTP does not push a second OTP route', (tester) async {
    final repository = _SuccessfulRegistrationRepository();
    final bloc = AuthBloc(authRepository: repository);
    final router = AppRouter.createRouter('/register', bloc);
    addTearDown(router.dispose);
    addTearDown(bloc.close);

    await tester.pumpWidget(_appWithRouter(router, bloc));
    await tester.pump();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(0), 'new-user');
    await tester.enterText(fields.at(1), 'New User');
    await tester.enterText(fields.at(2), 'new@example.com');
    await tester.enterText(fields.at(3), 'password123');
    await tester.enterText(fields.at(4), 'password123');

    final firstSend =
        bloc.stream.firstWhere((state) => state is RegisterOtpSent);
    await tester.tap(find.text('Đăng ký'));
    await firstSend;
    await tester.pump();

    expect(
        router.routeInformationProvider.value.uri.path, '/register/verify-otp');

    final resend = bloc.stream.firstWhere((state) => state is RegisterOtpSent);
    await tester.tap(find.text('Gửi lại mã OTP'));
    await resend;
    await tester.pump();

    expect(repository.sendOtpCalls, 2);
    expect(find.text('Đã gửi lại mã OTP. Kiểm tra email của bạn.'),
        findsOneWidget);

    router.pop();
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/register');
  });
}
