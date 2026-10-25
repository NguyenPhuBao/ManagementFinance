import 'dart:async';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_cubit.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flowmoney/features/khoa_app/presentation/widgets/man_khoa/lop_khoa_app.dart';
import 'package:flowmoney/features/khoa_app/presentation/widgets/man_khoa/man_khoa.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/khoa_app_gia.dart';

void main() {
  late KhoaAppService sv;
  late KhoaAppCubit cubit;
  late StreamController<int?> phien;
  late StreamController<AppLifecycleState> vongDoi;
  var nay = DateTime(2026, 10, 24, 21);
  var nutNoiDung = 0;
  var quenPin = 0;
  final cubitCu = <KhoaAppCubit>[];

  setUp(() {
    nay = DateTime(2026, 10, 24, 21);
    nutNoiDung = 0;
    quenPin = 0;
    sv = KhoaAppService(store: InMemoryKhoaAppStore(), kenh: KenhGia(), bam: bamNhanh, clock: () => nay);
    phien = StreamController<int?>.broadcast();
    vongDoi = StreamController<AppLifecycleState>.broadcast();
    cubit = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream, clock: () => nay);
  });

  tearDown(() async {
    await cubit.close();
    for (final c in cubitCu) {
      await c.close();
    }
    cubitCu.clear();
    await phien.close();
    await vongDoi.close();
  });

  Widget lop(Widget child) => LopKhoaApp(khiQuenPin: () => quenPin++, dongHo: () => nay, child: child);

  Widget app() => BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => lop(child!),
          home: Scaffold(body: Align(alignment: Alignment.topLeft, child: ElevatedButton(onPressed: () => nutNoiDung++, child: const Text('Nội dung')))),
        ),
      );

  // P14: không runAsync (kho + băm nhanh chỉ dùng microtask); trạng thái đẩy thẳng qua cubit.nhanPhien.
  Future<void> go(WidgetTester t, String pin) async {
    for (final c in pin.split('')) {
      await t.tap(find.byKey(Key('phim-$c')));
      await t.pump();
    }
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  Future<void> khoaPhien(WidgetTester t, {int soLanSai = 0}) async {
    await sv.datPin(10, '246810');
    for (var i = 0; i < soLanSai; i++) {
      await sv.kiemPin(10, '000000');
    }
    await t.pumpWidget(app());
    await cubit.nhanPhien(10);
    await t.pump();
  }

  /// Cubit dựng TRONG thân ca (zone FakeAsync): cubit của setUp nghe `vongDoi` trong zone thật, nên state phát từ một sự
  /// kiện vòng đời đi qua microtask mà `pump` không xả được (bẫy 15) — ca F1 xanh oan vì lớp che chưa từng được dựng.
  /// ⚠️ KHÔNG `await close()` cubit cũ ở đây: đóng trong zone FakeAsync một cubit dựng ở zone thật là treo cả tệp ~10 phút —
  /// cất vào [cubitCu], `tearDown` (zone thật) đóng.
  void cubitTrongCa() {
    cubitCu.add(cubit);
    cubit = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream, clock: () => nay);
  }

  testWidgets('F1: Mo(che) — lớp ĐẶC che nội dung, nuốt chạm; resumed chưa tới mức → gỡ', (t) async {
    cubitTrongCa();
    await khoaPhien(t);
    await go(t, '246810');
    expect(find.byType(ManKhoa), findsNothing);
    final dac = find.byWidgetPredicate((w) => w is AbsorbPointer && w.child is ColoredBox);
    expect(dac, findsNothing);
    vongDoi.add(AppLifecycleState.inactive);
    await t.pump();
    await t.pump(); // sự kiện vòng đời → cubit → BlocBuilder: hai nhịp
    expect(dac, findsOneWidget, reason: 'khung vẽ ngay sau inactive là khung cuối trước khi surface bị gỡ — phải là lớp đặc');
    await t.tap(find.text('Nội dung'), warnIfMissed: false);
    expect(nutNoiDung, 0);
    vongDoi.add(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(dac, findsNothing);
    await t.tap(find.text('Nội dung'));
    expect(nutNoiDung, 1);
  });

  testWidgets('F1: lớp che KHÔNG cướp tiêu điểm — ô đang gõ giữ bàn phím qua inactive → resumed (kéo thanh thông báo)',
      (t) async {
    cubitTrongCa();
    await sv.datPin(10, '246810');
    final o = FocusNode();
    addTearDown(o.dispose);
    await t.pumpWidget(BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => lop(child!),
        home: Scaffold(body: TextField(focusNode: o)),
      ),
    ));
    await cubit.nhanPhien(10);
    await t.pump();
    await go(t, '246810');
    o.requestFocus();
    await t.pump();
    expect(o.hasFocus, isTrue);
    vongDoi.add(AppLifecycleState.inactive);
    await t.pump();
    await t.pump(); // sự kiện vòng đời → cubit → BlocBuilder: hai nhịp
    expect(cubit.state, const KhoaAppMo(daBat: true, che: true));
    expect(o.hasFocus, isTrue, reason: 'ExcludeFocus ở lớp che tạm là đóng bàn phím mỗi lần kéo thanh thông báo');
    vongDoi.add(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(o.hasFocus, isTrue);
  });

  testWidgets('DangXet: che đặc, chạm không xuyên xuống nội dung', (t) async {
    await t.pumpWidget(app());
    await t.tap(find.text('Nội dung'), warnIfMissed: false);
    expect(nutNoiDung, 0);
    expect(find.byWidgetPredicate((w) => w is AbsorbPointer && w.child is ColoredBox), findsOneWidget,
        reason: 'lớp ĐẶC (ColoredBox) bọc AbsorbPointer thật sự che và nuốt chạm');
  });

  testWidgets('đang khoá: hiện màn khoá; nhập đúng → nội dung dùng được', (t) async {
    await khoaPhien(t);
    expect(find.text('Nhập mã PIN'), findsOneWidget);
    await t.tap(find.text('Nội dung'), warnIfMissed: false);
    expect(nutNoiDung, 0, reason: 'lớp khoá chặn chạm');
    await go(t, '246810');
    expect(find.text('Nhập mã PIN'), findsNothing);
    await t.tap(find.text('Nội dung'));
    expect(nutNoiDung, 1);
  });

  testWidgets('nhập sai → câu sai, chấm xoá về 0', (t) async {
    await khoaPhien(t);
    await go(t, '000000');
    expect(find.text('Mã PIN không đúng'), findsOneWidget);
    expect(chamPin('day'), findsNothing);
    expect(chamPin('rong'), findsNWidgets(6));
  });

  testWidgets('Quên mã PIN? → tấm xác nhận → Đăng xuất gọi khiQuenPin; Huỷ thì không', (t) async {
    await khoaPhien(t);
    await t.tap(find.text('Quên mã PIN?'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Đăng xuất để đặt lại mã PIN?'), findsOneWidget);
    await t.tap(find.text('Huỷ'));
    await t.pump(const Duration(milliseconds: 300));
    expect(quenPin, 0);
    expect(find.text('Đăng xuất để đặt lại mã PIN?'), findsNothing);
    await t.tap(find.text('Quên mã PIN?'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Đăng xuất'));
    expect(quenPin, 1);
  });

  testWidgets('đang chờ: đếm ngược + phím số tắt', (t) async {
    await khoaPhien(t, soLanSai: 5);
    expect(find.textContaining('Thử lại sau 00:30', findRichText: true), findsOneWidget);
    expect(find.text('Sai mã PIN quá nhiều lần'), findsOneWidget);
    await t.tap(find.byKey(const Key('phim-1')));
    await t.pump();
    expect(chamPin('day'), findsNothing, reason: 'đang chờ không nhận số');
    nay = nay.add(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Thử lại sau 00:29', findRichText: true), findsOneWidget);
    // Vế 'phím số tắt' bằng hành vi: số gõ lúc chờ không được lọt vào PIN kế.
    for (final c in '123'.split('')) {
      await t.tap(find.byKey(Key('phim-$c')));
      await t.pump();
    }
    nay = nay.add(const Duration(seconds: 31));
    await t.pump(const Duration(seconds: 31));
    await go(t, '246810');
    expect(find.text('Nhập mã PIN'), findsNothing, reason: 'số gõ lúc chờ lọt vào PIN thì 246810 gửi đi sai');
  });

  testWidgets('hết chờ: gõ được tiếp (chấm không kẹt ở 6 số của lượt bị chặn)', (t) async {
    await khoaPhien(t, soLanSai: 5);
    nay = nay.add(const Duration(seconds: 31));
    await t.pump(const Duration(seconds: 31));
    await go(t, '246810');
    expect(find.text('Nhập mã PIN'), findsNothing, reason: 'hết chờ, PIN đúng phải mở được');
  });

  testWidgets('đăng xuất khi đang khoá → lớp khoá gỡ', (t) async {
    await khoaPhien(t);
    expect(find.text('Nhập mã PIN'), findsOneWidget,
        reason: 'ca phải thấy màn khoá TRƯỚC — chỉ đòi vắng mặt là xanh rỗng');
    await cubit.nhanPhien(null);
    await t.pump();
    expect(find.text('Nhập mã PIN'), findsNothing);
  });

  testWidgets('GoRouter thật: điều hướng bên dưới khi đang khoá, mở khoá thấy trang đích', (t) async {
    final router = GoRouter(initialLocation: '/a', routes: [
      GoRoute(path: '/a', builder: (_, __) => const Scaffold(body: Text('Trang A'))),
      GoRoute(path: '/b', builder: (_, __) => const Scaffold(body: Text('Trang B'))),
    ]);
    addTearDown(router.dispose);
    await sv.datPin(10, '246810');
    await t.pumpWidget(BlocProvider.value(
      value: cubit,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => lop(child!),
      ),
    ));
    await cubit.nhanPhien(10);
    await t.pump();
    router.push('/b');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Nhập mã PIN'), findsOneWidget);
    await go(t, '246810');
    expect(find.text('Trang B'), findsOneWidget);
    expect(find.text('Nhập mã PIN'), findsNothing);
  });


  testWidgets('khổ 360 × 800: tiêu đề, phím 5, Quên mã PIN? căn giữa ngang', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await khoaPhien(t);
    for (final f in [find.text('Nhập mã PIN'), find.byKey(const Key('phim-5')), find.text('Quên mã PIN?')]) {
      expect(t.getCenter(f).dx, closeTo(180, 0.5));
    }
  });

  testWidgets('câu lỗi dài vẫn căn giữa, xuống dòng có lề, không tràn', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: ManKhoa(
          trangThai: const KhoaAppKhoa(coVanTay: false, loiNhan: kCauVanTayDaDoi),
          khiQuenPin: () {},
          dongHo: () => nay,
        ),
      ),
    ));
    expect(t.takeException(), isNull);
    expect(t.getCenter(find.text(kCauVanTayDaDoi)).dx, closeTo(180, 0.5));
    expect(t.getSize(find.text(kCauVanTayDaDoi)).width, lessThanOrEqualTo(360 - 48));
    expect(t.getCenter(find.text('Nhập mã PIN')).dx, closeTo(180, 0.5));
    expect(t.getCenter(find.byKey(const Key('phim-5'))).dx, closeTo(180, 0.5));
  });

  testWidgets('đang khoá: Tab + Enter không bấm được nút bên dưới; trình đọc màn hình không thấy nội dung', (t) async {
    final h = t.ensureSemantics();
    await khoaPhien(t);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(nutNoiDung, 0, reason: 'focus của nội dung bên dưới phải bị loại khi khoá');
    expect(find.bySemanticsLabel('Nội dung'), findsNothing);
    h.dispose();
  });

  for (final kho in const [Size(360, 640), Size(360, 800)]) {
    testWidgets('khổ ${kho.width.toInt()} × ${kho.height.toInt()}: màn khoá không tràn', (t) async {
      t.view.physicalSize = kho;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await khoaPhien(t);
      expect(find.text('Nhập mã PIN'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Quên mã PIN?'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Đăng xuất'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('tấm Quên PIN: lớp mờ phủ cả vùng thanh trạng thái; nút Huỷ nằm trên phần thụt dưới', (t) async {
    // Nghiệm thu Realme 2026-10-25: màn khoá đặt thanh trạng thái trong suốt → lớp mờ chỉ phủ dưới SafeArea để lại dải
    // kem sáng trên nền xám.
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(t.view.reset);
    await khoaPhien(t);
    await t.tap(find.text('Quên mã PIN?'));
    await t.pump(const Duration(milliseconds: 300));
    final mo = find.byWidgetPredicate((w) => w is ColoredBox && w.color == Colors.black.withValues(alpha: 0.4));
    expect(t.getRect(mo).top, 0, reason: 'lớp mờ phải phủ từ mép trên — kể cả dưới thanh trạng thái');
    expect(t.getRect(mo).bottom, 800);
    expect(t.getRect(find.text('Huỷ')).bottom, lessThanOrEqualTo(800 - 16), reason: 'nút không được nằm dưới thanh điều hướng');
    expect(t.takeException(), isNull);
  });

  testWidgets('M9: sau lần chạm Đăng xuất đầu tiên, cả hai nút khoá — không LogoutRequested lần hai, Huỷ không bấm được', (t) async {
    await khoaPhien(t);
    await t.tap(find.text('Quên mã PIN?'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Đăng xuất'));
    await t.pump();
    await t.tap(find.text('Đăng xuất'), warnIfMissed: false);
    await t.tap(find.text('Huỷ'), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 300));
    expect(quenPin, 1, reason: 'chạm đôi là hai LogoutRequested');
    expect(find.text('Đăng xuất để đặt lại mã PIN?'), findsOneWidget, reason: 'Huỷ lúc đã đăng xuất không huỷ được gì');
  });
}
