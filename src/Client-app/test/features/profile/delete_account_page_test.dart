/// Trang Xoá tài khoản sau G33 — spec cưỡng chế đăng xuất §5.4.
library;

import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/profile/presentation/pages/delete_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RepoGia implements AuthRepository {
  final matKhauDaGui = <String>[];

  @override
  Future<void> deleteAccount(String password) async => matKhauDaGui.add(password);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BlocGhiSuKien extends AuthBloc {
  _BlocGhiSuKien() : super(authRepository: _RepoGia());

  final suKien = <AuthEvent>[];

  @override
  void add(AuthEvent event) => suKien.add(event);
}

void main() {
  late _RepoGia repo;
  late _BlocGhiSuKien bloc;

  setUp(() {
    repo = _RepoGia();
    bloc = _BlocGhiSuKien();
  });
  tearDown(() => bloc.close());

  Future<void> moTrang(WidgetTester tester) async {
    // Nút gửi nằm dưới mép khung 800×600 mặc định của bộ test.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/settings/delete-account',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Trang chủ giả'))),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Đăng nhập giả'))),
        GoRoute(
          path: '/settings/delete-account',
          builder: (_, __) => DeleteAccountPage(authRepository: repo),
        ),
      ],
    );
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('trang không còn hứa "đăng nhập lại là khôi phục"', (tester) async {
    await moTrang(tester);
    expect(find.textContaining('đăng nhập lại'), findsNothing,
        reason: 'G33: backend không khôi phục khi đăng nhập lại; người tin lời hứa mất tài khoản sau 30 ngày.');
    expect(find.textContaining('đăng xuất khỏi tất cả thiết bị'), findsNothing);
  });

  testWidgets('không còn nút huỷ yêu cầu ở cuối trang', (tester) async {
    await moTrang(tester);
    expect(find.text('Hủy yêu cầu xóa tài khoản'), findsNothing,
        reason: 'Huỷ nằm ở Trang chủ và Cài đặt; nút này từng hiện cả khi tài khoản Active.');
  });

  testWidgets('gửi yêu cầu xong: KHÔNG đăng xuất, đọc lại trạng thái, về Trang chủ', (tester) async {
    await moTrang(tester);
    await tester.enterText(find.byType(TextFormField), 'mat-khau-thu');
    await tester.tap(find.text('Gửi yêu cầu xóa tài khoản'));
    await tester.pumpAndSettle();
    expect(find.textContaining('đăng nhập lại'), findsNothing,
        reason: 'Hộp thoại xác nhận cũ cũng hứa khôi phục bằng đăng nhập lại.');

    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(repo.matKhauDaGui, ['mat-khau-thu']);
    expect(
        find.text('Bạn vẫn dùng app bình thường trong 30 ngày, và huỷ được bất cứ lúc nào ở Trang chủ hoặc Cài đặt.'),
        findsOneWidget);

    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    expect(bloc.suKien.whereType<LogoutRequested>(), isEmpty,
        reason: 'G33: gửi yêu cầu xoá không đăng xuất.');
    expect(bloc.suKien.whereType<ThongTinTaiKhoanThayDoi>(), hasLength(1));
    expect(find.text('Trang chủ giả'), findsOneWidget);
  });
}
