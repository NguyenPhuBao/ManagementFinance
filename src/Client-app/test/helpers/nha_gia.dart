/// Dựng repository nhà thật trên API giả và bọc trang cho widget test của mảng gia đình. Tự dọn bằng `addTearDown`: gọi TRONG
/// thân ca. Repository đọc thân `/me` đúng hình dạng lồng (`household_api_gia.dart`).
library;

import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'household_api_gia.dart';

Future<NhaRepositoryImpl> repoNhaThu(HouseholdApiGia api, {int id = 18}) async {
  final r = NhaRepositoryImpl(api: api, kho: InMemoryNhaStore());
  addTearDown(r.dispose);
  await r.datTaiKhoan(id);
  await r.lamMoi();
  return r;
}

class _KhoAuthGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthBlocNhaGia extends AuthBloc {
  _AuthBlocNhaGia(int? idaccount) : super(authRepository: _KhoAuthGia()) {
    if (idaccount != null) {
      emit(AuthSuccess(user: UserModel(id: '$idaccount', username: 'u$idaccount', name: 'U', email: 'u$idaccount@example.com')));
    }
  }
}

/// Phiên giả cho trang đọc `currentAccountIdOrNull`: `idaccount` null = chưa đăng nhập (đọc ra `null`, không phải 1).
Widget _cungPhien(Widget app, int? idaccount) {
  final auth = _AuthBlocNhaGia(idaccount);
  addTearDown(auth.close);
  return BlocProvider<AuthBloc>.value(value: auth, child: app);
}

Widget bocTrangNha(Widget trang, {GoiCubit? goi, int? idaccount}) {
  final app = MaterialApp(theme: AppTheme.lightTheme, home: trang);
  return _cungPhien(goi == null ? app : BlocProvider<GoiCubit>.value(value: goi, child: app), idaccount);
}

/// Stack thật `/` → `/dich` để ca canh `pop` về đúng trang trước. `go` thay cả stack: ca sẽ không còn thấy chữ GOC khi Back.
GoRouter routerThu(Widget trang) {
  final r = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('GOC'))),
    GoRoute(path: '/dich', builder: (_, __) => trang),
  ]);
  addTearDown(r.dispose);
  return r;
}

Widget bocRouterNha(GoRouter r, {GoiCubit? goi, int? idaccount}) {
  final app = MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: r);
  return _cungPhien(goi == null ? app : BlocProvider<GoiCubit>.value(value: goi, child: app), idaccount);
}

/// 360 dp, mật độ 1. `banPhim` giả bàn phím hệ thống mở (bẫy G58).
void dat360(WidgetTester t, {bool banPhim = false}) {
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  if (banPhim) {
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
  }
}
