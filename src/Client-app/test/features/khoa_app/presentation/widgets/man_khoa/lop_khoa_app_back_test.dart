import 'dart:async';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_cubit.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flowmoney/features/khoa_app/presentation/widgets/man_khoa/lop_khoa_app.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flowmoney/shared/widgets/thoat_hai_lan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/khoa_app_gia.dart';

/// M5 (nghiệm thu Realme 2026-10-25, bước 20): Back khi đang khoá đi tới router và gỡ trang nằm DƯỚI lớp khoá — khoá ở
/// trang *Khoá ứng dụng*, Back, mở khoá → về tab Cá nhân. Lớp khoá phải giữ Back: tấm *Quên mã PIN?* mở thì đóng tấm, còn
/// lại đưa app xuống nền (kênh `flowmoney/xuong_nen`, như Back hai lần ở Trang chủ — G100: không đóng activity).
/// Dựng GoRouter THẬT: Back của app đi `RootBackButtonDispatcher` của router; `MaterialApp(home:)` đi đường khác nên ca ở
/// đó mù.
void main() {
  late KhoaAppService sv;
  late StreamController<int?> phien;
  late StreamController<AppLifecycleState> vongDoi;
  late GoRouter router;
  late List<MethodCall> goiHeThong;
  final nay = DateTime(2026, 10, 25, 9);
  KhoaAppCubit? cubit;
  var quenPin = 0;

  setUp(() {
    quenPin = 0;
    goiHeThong = [];
    sv = KhoaAppService(store: InMemoryKhoaAppStore(), kenh: KenhGia(), bam: bamNhanh, clock: () => nay);
    phien = StreamController<int?>.broadcast();
    vongDoi = StreamController<AppLifecycleState>.broadcast();
    router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(path: '/a', builder: (_, __) => const Scaffold(body: Text('Trang A'))),
        GoRoute(path: '/b', builder: (_, __) => const Scaffold(body: Text('Trang B'))),
      ],
    );
  });

  tearDown(() async {
    await cubit?.close();
    cubit = null;
    router.dispose();
    await phien.close();
    await vongDoi.close();
  });

  /// Dựng app ở `/a`, đẩy `/b` lên (trang con có thể bị pop). [coPin] = khoá app bật cho tài khoản 10.
  /// Cubit dựng TRONG thân ca (zone FakeAsync) — bẫy 15 `KHOA_APP_FEATURE.md`.
  Future<void> dung(WidgetTester t, {required bool coPin, bool nhanPhien = true}) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      goiHeThong.add(call);
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(ThoatHaiLan.kenh, (call) async {
      goiHeThong.add(call);
      return true;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(ThoatHaiLan.kenh, null));

    if (coPin) await sv.datPin(10, '246810');
    cubit = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream, clock: () => nay);
    await t.pumpWidget(BlocProvider.value(
      value: cubit!,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => LopKhoaApp(khiQuenPin: () => quenPin++, dongHo: () => nay, child: child!),
      ),
    ));
    unawaited(router.push('/b'));
    await t.pumpAndSettle();
    expect(find.text('Trang B'), findsOneWidget, reason: 'ca phải bắt đầu ở trang con /b');
    if (nhanPhien) {
      await cubit!.nhanPhien(10);
      await t.pump();
    }
  }

  Future<void> nhanBack(WidgetTester t) async {
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
  }

  int soLanXuongNen() => goiHeThong.where((c) => c.method == 'xuongNen').length;
  bool daDongActivity() => goiHeThong.any((c) => c.method == 'SystemNavigator.pop');

  Future<void> goPin(WidgetTester t, String pin) async {
    for (final c in pin.split('')) {
      await t.tap(find.byKey(Key('phim-$c')));
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  testWidgets('đối chứng — khoá app TẮT: Back gỡ trang con như thường (router thật nhận Back trong khuôn này)', (t) async {
    await dung(t, coPin: false);
    expect(cubit!.state, isA<KhoaAppMo>());
    await nhanBack(t);
    expect(find.text('Trang A'), findsOneWidget);
    expect(find.text('Trang B'), findsNothing);
    expect(soLanXuongNen(), 0);
    expect(daDongActivity(), isFalse);
  });

  testWidgets('đang khoá ở trang con: Back KHÔNG gỡ trang dưới mà đưa app xuống nền; mở khoá vẫn đúng trang cũ', (t) async {
    await dung(t, coPin: true);
    expect(cubit!.state, isA<KhoaAppKhoa>());

    await nhanBack(t);
    expect(soLanXuongNen(), 1, reason: 'Back trên màn khoá = đưa cả task xuống nền (như nút Home)');
    expect(daDongActivity(), isFalse, reason: 'G100: đóng activity khi tiến trình còn sống là nạp thêm một bản Gemma');
    expect(cubit!.state, isA<KhoaAppKhoa>(), reason: 'xuống nền không được mở khoá');
    expect(find.text('Trang B'), findsOneWidget, reason: 'router không được nhận Back — trang dưới lớp khoá còn nguyên');

    await goPin(t, '246810');
    expect(cubit!.state, isA<KhoaAppMo>());
    expect(find.text('Trang B'), findsOneWidget, reason: 'mở khoá phải về ĐÚNG trang lúc khoá (M5: từng về trang cha)');
    expect(find.text('Trang A'), findsNothing);
  });

  testWidgets('tấm "Quên mã PIN?" mở: Back đóng tấm, không xuống nền; Back lần nữa mới xuống nền', (t) async {
    await dung(t, coPin: true);
    await t.tap(find.text('Quên mã PIN?'));
    await t.pump();
    expect(find.text('Đăng xuất để đặt lại mã PIN?'), findsOneWidget);

    await nhanBack(t);
    expect(find.text('Đăng xuất để đặt lại mã PIN?'), findsNothing, reason: 'Back trên tấm = Huỷ');
    expect(soLanXuongNen(), 0);
    expect(cubit!.state, isA<KhoaAppKhoa>());
    expect(find.text('Trang B'), findsOneWidget);

    await nhanBack(t);
    expect(soLanXuongNen(), 1);
    expect(find.text('Trang B'), findsOneWidget);
  });

  testWidgets('đã chạm Đăng xuất trên tấm: Back bị giữ — không đóng tấm (Huỷ đang khoá), không xuống nền', (t) async {
    await dung(t, coPin: true);
    await t.tap(find.text('Quên mã PIN?'));
    await t.pump();
    await t.tap(find.text('Đăng xuất'));
    await t.pump();
    expect(quenPin, 1);

    await nhanBack(t);
    expect(find.text('Đăng xuất để đặt lại mã PIN?'), findsOneWidget,
        reason: 'đóng tấm lúc đang đăng xuất là mở đường chạm "Quên mã PIN?" lần hai — hai LogoutRequested');
    expect(soLanXuongNen(), 0);
    expect(daDongActivity(), isFalse);
    expect(find.text('Trang B'), findsOneWidget);
  });

  testWidgets('đang xét (mở lạnh, lớp ĐẶC trước khi biết phiên): Back bị giữ — không gỡ trang, không thoát', (t) async {
    await dung(t, coPin: true, nhanPhien: false);
    expect(cubit!.state, isA<KhoaAppDangXet>());

    await nhanBack(t);
    expect(find.text('Trang B'), findsOneWidget, reason: 'trang dưới lớp đặc không được bị pop');
    expect(soLanXuongNen(), 0);
    expect(daDongActivity(), isFalse);
  });
}
