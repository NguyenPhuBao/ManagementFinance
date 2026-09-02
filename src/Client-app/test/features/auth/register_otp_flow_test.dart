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

/// Widget test mặc định dựng màn hình 800×600. Form đăng ký có 5 ô nhập nên nút
/// "Đăng ký" nằm ở khoảng y=732 — rơi ra ngoài vùng hiển thị. Khi đó `tap()`
/// trượt (chỉ cảnh báo chứ không báo lỗi), AuthBloc không bao giờ phát state,
/// và `await bloc.stream.firstWhere(...)` treo cho tới khi test timeout sau 10
/// phút. Dựng màn hình cao như điện thoại thật để mọi nút đều bấm được.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
    _useTallSurface(tester);
    final bloc = AuthBloc(authRepository: _SuccessfulRegistrationRepository());
    final router = AppRouter.createRouter('/register', bloc);
    addTearDown(router.dispose);
    addTearDown(bloc.close);

    await tester.pumpWidget(_appWithRouter(router, bloc));
    await tester.pump();

    // Phải đi qua bước đăng ký THẬT thay vì `router.go(..., extra: ...)`:
    // route '/register/verify-otp' dựng trang OTP dựa trên `_registerOtpState`,
    // mà `GoRouterState.extra` không được giữ lại tới lúc build (router bị dựng
    // lại qua refreshListenable). Khi đó builder rơi về `RegisterPage`, nút
    // "Xác nhận" không tồn tại, không state nào được phát và test treo tới
    // timeout. Cho AuthBloc vào trạng thái RegisterOtpSent thì trang OTP hiện
    // ổn định.
    final otpSent = bloc.stream.firstWhere((state) => state is RegisterOtpSent);
    final registerFields = find.byType(TextFormField);
    await tester.enterText(registerFields.at(0), 'new-user');
    await tester.enterText(registerFields.at(1), 'New User');
    await tester.enterText(registerFields.at(2), 'new@example.com');
    await tester.enterText(registerFields.at(3), 'password123');
    await tester.enterText(registerFields.at(4), 'password123');
    await tester.tap(find.text('Đăng ký'));
    // BẮT BUỘC pump ngay sau tap: trong widget test, handler async của Bloc chỉ
    // chạy khi vòng lặp sự kiện được quay. Nếu `await` thẳng vào bloc.stream mà
    // chưa pump thì Future đó không bao giờ hoàn tất và test treo tới timeout.
    await tester.pump();
    await otpSent;
    await tester.pumpAndSettle();

    expect(find.text('Xác thực Email'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));

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
    await tester.pump();
    await loading;
    await completion;
    await tester.pumpAndSettle();

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
    _useTallSurface(tester);
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
    await tester.pump(); // xem chú thích ở test phía trên
    await firstSend;
    await tester.pump();

    // Kiểm tra bằng nội dung đang hiển thị thay vì routeInformationProvider:
    // trang OTP được mở bằng `context.push`, mà push KHÔNG cập nhật
    // routeInformationProvider (nó vẫn báo '/register') — assert theo đường dẫn
    // sẽ luôn sai dù điều hướng đã đúng.
    expect(find.text('Xác thực Email'), findsOneWidget);

    final resend = bloc.stream.firstWhere((state) => state is RegisterOtpSent);
    await tester.tap(find.text('Gửi lại mã OTP'));
    await tester.pump();
    await resend;
    await tester.pump();

    expect(repository.sendOtpCalls, 2);
    // findsAtLeastNWidgets chứ không phải findsOneWidget: SnackBar cũ có thể
    // chưa biến mất hẳn khi SnackBar mới hiện ra, nên trong một nhịp pump có
    // thể thấy hai bản. Điều cần khẳng định chỉ là phản hồi "đã gửi lại" có
    // xuất hiện.
    expect(find.text('Đã gửi lại mã OTP. Kiểm tra email của bạn.'),
        findsAtLeastNWidgets(1));

    // Chỉ có ĐÚNG MỘT trang OTP trên stack: pop một lần là về lại trang đăng
    // ký. Nếu "gửi lại" lỡ push thêm route thứ hai thì sau pop vẫn còn trang
    // OTP — đây chính là điều test này canh chừng.
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Xác thực Email'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(5));
  });
}
