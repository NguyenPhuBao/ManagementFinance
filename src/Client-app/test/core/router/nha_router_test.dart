/// Đường `/nha*` trên `GoRouter` THẬT của app (điều hướng là vùng mù của widget test đơn lẻ): route gốc ngoài shell, push chồng
/// lên nhau, Back về đúng trang trước.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/bat_thong_bao.dart';
import '../../helpers/font_that.dart';
import '../../helpers/household_api_gia.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthCoDinh extends AuthBloc {
  _AuthCoDinh(this._s) : super(authRepository: _RepoGia());
  final AuthState _s;
  @override
  AuthState get state => _s;
}

void main() {
  setUpAll(napFontThat);

  testWidgets('/nha → /nha/thanh-vien → pop về /nha', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    batThongBao();
    final repo = NhaRepositoryImpl(api: HouseholdApiGia()..cuaToiJson = nhaJson(), kho: InMemoryNhaStore());
    addTearDown(repo.dispose);
    await repo.datTaiKhoan(18);
    await repo.lamMoi();
    sl.registerSingleton<NhaRepository>(repo);
    addTearDown(() => sl.unregister<NhaRepository>());
    final auth = _AuthCoDinh(AuthSuccess(user: UserModel(id: '18', username: 'an', name: 'An', email: 'an@x.vn')));
    addTearDown(auth.close);
    final r = AppRouter.createRouter('/nha', auth);
    addTearDown(r.dispose);
    await t.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: r));
    await t.pumpAndSettle();
    expect(find.text('Nhà mình'), findsOneWidget);
    r.push('/nha/thanh-vien');
    await t.pumpAndSettle();
    expect(find.text('Quản lý thành viên'), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'màn đỏ `keyReservation` là dấu hiệu đã đặt nhầm route vào shell');
    r.pop();
    await t.pumpAndSettle();
    expect(find.text('Nhà mình'), findsOneWidget);
  });
}
