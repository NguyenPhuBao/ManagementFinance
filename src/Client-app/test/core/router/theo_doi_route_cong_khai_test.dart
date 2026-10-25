import 'package:flowmoney/core/router/theo_doi_route_cong_khai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('chỉ true khi route trên cùng là công khai VÀ hiệu ứng vào đã xong', (t) async {
    final theoDoi = TheoDoiRouteCongKhai(laCongKhai: (ten) => ten == '/login');
    final router = GoRouter(initialLocation: '/a', observers: [theoDoi], routes: [
      GoRoute(path: '/a', builder: (_, __) => const Scaffold(body: Text('A'))),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login'))),
    ]);
    addTearDown(() {
      router.dispose();
      theoDoi.dispose();
    });
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(theoDoi.dungYenOCongKhai.value, isFalse, reason: 'đang ở /a — không công khai');
    router.push('/login');
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(theoDoi.dungYenOCongKhai.value, isFalse, reason: 'đã ở /login nhưng hiệu ứng còn chạy');
    await t.pumpAndSettle();
    expect(theoDoi.dungYenOCongKhai.value, isTrue);
    router.pop();
    await t.pumpAndSettle();
    expect(theoDoi.dungYenOCongKhai.value, isFalse, reason: 'quay lại /a');
  });
}
