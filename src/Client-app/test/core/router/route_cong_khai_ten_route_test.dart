import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/core/router/theo_doi_route_cong_khai.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Nối router THẬT với `laRouteCongKhai`: observer đọc `settings.name` của route; đổi bản go_router hoặc thêm `name:` cho
/// route công khai là lớp khoá ứng dụng âm thầm rơi về van an toàn 3 s.
void main() {
  test('mọi route công khai của router thật: GoRoute không đặt name (tên route = đường dẫn) và khớp laRouteCongKhai', () {
    final auth = AuthBloc(authRepository: _RepoGia());
    addTearDown(auth.close);
    final router = AppRouter.createRouter('/login', auth);
    addTearDown(router.dispose);
    final goc = router.configuration.routes.whereType<GoRoute>().toList();
    final login = goc.firstWhere((r) => r.path == '/login');
    expect(login.name, isNull, reason: 'GoRouter đặt page name = name ?? path; có name thì observer đọc sai');
    for (final r in goc.where((r) => AppRouter.laRouteCongKhai(r.path))) {
      expect(r.name, isNull, reason: 'route công khai ${r.path} không được có name');
    }
    expect(AppRouter.laRouteCongKhai('/login'), isTrue);
    expect(AppRouter.laRouteCongKhai('/home'), isFalse);
  });

  testWidgets('observer gắn vào router thật (cùng khuôn createRouter) thấy /login công khai sau khi hiệu ứng xong', (t) async {
    final theoDoi = TheoDoiRouteCongKhai(laCongKhai: AppRouter.laRouteCongKhai);
    addTearDown(theoDoi.dispose);
    final router = GoRouter(initialLocation: '/home', observers: [theoDoi], routes: [
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login'))),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(theoDoi.dungYenOCongKhai.value, isFalse);
    router.go('/login');
    await t.pumpAndSettle();
    expect(theoDoi.dungYenOCongKhai.value, isTrue);
  });
}
