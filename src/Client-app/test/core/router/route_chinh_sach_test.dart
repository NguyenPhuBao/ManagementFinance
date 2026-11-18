/// Trang Điều khoản / Chính sách mở được ở CẢ HAI phía: từ màn Đăng ký (chưa đăng nhập) và từ Cài đặt (đã đăng nhập).
/// Route công khai thường đẩy người đã đăng nhập về `/home`; route thường đẩy người chưa đăng nhập về `/login`
/// (spec điều khoản viết cứng 2026-11-16 mục 2).
library;

import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route chính sách mở cho cả hai phía: không bị đẩy khi chưa / đã đăng nhập', () {
    for (final r in ['/chinh-sach', '/chinh-sach/bao-mat', '/chinh-sach/dieu-khoan']) {
      expect(AppRouter.laRouteMoChoCaHai(r), isTrue, reason: r);
      expect(AppRouter.authRedirect(authState: const AuthUnauthenticated(), matchedLocation: r), isNull, reason: r);
      expect(AppRouter.authRedirect(authState: const AuthSuccess(), matchedLocation: r), isNull, reason: r);
      expect(AppRouter.laRouteCongKhai(r), isFalse,
          reason: 'lớp khoá ứng dụng vẫn che trang này khi đã đăng nhập và đang khoá');
    }
  });

  test('hành vi cũ giữ nguyên', () {
    expect(AppRouter.authRedirect(authState: const AuthSuccess(), matchedLocation: '/register'), '/home');
    expect(AppRouter.authRedirect(authState: const AuthUnauthenticated(), matchedLocation: '/home'), '/login');
    expect(AppRouter.laRouteMoChoCaHai('/chinh-sachx'), isFalse);
    expect(AppRouter.laRouteMoChoCaHai(null), isFalse);
  });
}
