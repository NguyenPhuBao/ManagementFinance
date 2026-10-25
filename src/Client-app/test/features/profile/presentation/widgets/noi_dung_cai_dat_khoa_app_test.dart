import 'dart:async';

import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_cubit.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flowmoney/features/profile/presentation/widgets/noi_dung_cai_dat.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/khoa_app_gia.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget app({KhoaAppCubit? khoaApp}) {
    final auth = AuthBloc(authRepository: _RepoGia());
    addTearDown(auth.close);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: SingleChildScrollView(child: NoiDungCaiDat())),
      ),
      GoRoute(path: '/settings/khoa-app', builder: (_, __) => const Scaffold(body: Text('trang khoá app'))),
    ]);
    Widget w = MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router);
    if (khoaApp != null) w = BlocProvider.value(value: khoaApp, child: w);
    return BlocProvider<AuthBloc>.value(value: auth, child: w);
  }

  testWidgets('thẻ Bảo mật có hàng Khoá ứng dụng; chạm → /settings/khoa-app; không cubit → không nhãn', (t) async {
    await t.pumpWidget(app());
    await t.pump();
    expect(find.text('Khoá ứng dụng'), findsOneWidget);
    expect(find.text('Đang bật'), findsNothing);
    await t.tap(find.text('Khoá ứng dụng'));
    await t.pumpAndSettle();
    expect(find.text('trang khoá app'), findsOneWidget);
  });

  testWidgets('KhoaAppCubit đang Mo(daBat: true) → nhãn "Đang bật"', (t) async {
    final sv = KhoaAppService(store: InMemoryKhoaAppStore(), kenh: KenhGia(), bam: bamNhanh);
    final phien = StreamController<int?>.broadcast();
    final vongDoi = StreamController<AppLifecycleState>.broadcast();
    final cubit = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream);
    addTearDown(() async {
      await cubit.close();
      await phien.close();
      await vongDoi.close();
    });
    await cubit.nhanPhien(10);
    await sv.datPin(10, '246810');
    await cubit.napLai();
    await t.pumpWidget(app(khoaApp: cubit));
    await t.pump();
    expect(find.text('Đang bật'), findsOneWidget);
  });

  testWidgets('KhoaAppMo(daBat: false) và KhoaAppTat → KHÔNG có nhãn "Đang bật"', (t) async {
    final sv = KhoaAppService(store: InMemoryKhoaAppStore(), kenh: KenhGia(), bam: bamNhanh);
    final phien = StreamController<int?>.broadcast();
    final vongDoi = StreamController<AppLifecycleState>.broadcast();
    final cubit = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream);
    addTearDown(() async {
      await cubit.close();
      await phien.close();
      await vongDoi.close();
    });
    await cubit.nhanPhien(10); // chưa đặt PIN → Mo(daBat: false)
    expect(cubit.state, isA<KhoaAppMo>());
    await t.pumpWidget(app(khoaApp: cubit));
    await t.pump();
    expect(find.text('Đang bật'), findsNothing);
    await cubit.nhanPhien(null); // không phiên → Tat
    await t.pump();
    expect(cubit.state, isA<KhoaAppTat>());
    expect(find.text('Đang bật'), findsNothing);
  });
}
