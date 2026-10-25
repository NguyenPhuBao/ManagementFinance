import 'dart:async';

import 'package:flowmoney/core/router/theo_doi_route_cong_khai.dart';
import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_cubit.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flowmoney/features/khoa_app/presentation/widgets/man_khoa/lop_khoa_app.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/khoa_app_gia.dart';

/// C1 (review toàn nhánh): mất phiên khi đang khoá -> trang được bảo vệ không được lộ ra dưới hiệu ứng chuyển sang
/// `/login`. Dựng GoRouter THẬT (`refreshListenable` + `redirect` như `app_router.dart`) — ca với MaterialApp trần mù.
void main() {
  late KhoaAppService sv;
  late StreamController<int?> phien;
  late StreamController<AppLifecycleState> vongDoi;
  late ValueNotifier<bool> dangNhap;
  late TheoDoiRouteCongKhai theoDoi;
  late GoRouter router;
  final nay = DateTime(2026, 10, 25, 9);
  KhoaAppCubit? cubit;

  setUp(() {
    sv = KhoaAppService(store: InMemoryKhoaAppStore(), kenh: KenhGia(), bam: bamNhanh, clock: () => nay);
    phien = StreamController<int?>.broadcast();
    vongDoi = StreamController<AppLifecycleState>.broadcast();
    dangNhap = ValueNotifier<bool>(true);
    theoDoi = TheoDoiRouteCongKhai(laCongKhai: (ten) => ten == '/login');
    router = GoRouter(
      initialLocation: '/a',
      observers: [theoDoi],
      refreshListenable: dangNhap,
      redirect: (context, state) {
        final vao = dangNhap.value;
        if (!vao && state.matchedLocation != '/login') return '/login';
        if (vao && state.matchedLocation == '/login') return '/a';
        return null;
      },
      routes: [
        GoRoute(path: '/a', builder: (_, __) => const Scaffold(body: Text('Trang A'))),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Trang Đăng nhập'))),
      ],
    );
  });

  tearDown(() async {
    await cubit?.close();
    router.dispose();
    theoDoi.dispose();
    dangNhap.dispose();
    await phien.close();
    await vongDoi.close();
  });

  final lopDac = find.byWidgetPredicate((w) => w is AbsorbPointer && w.child is ColoredBox);

  Future<void> dung(WidgetTester t, {Duration van = const Duration(seconds: 3), ValueListenable<bool>? tinHieu}) async {
    await sv.datPin(10, '246810');
    cubit = KhoaAppCubit(
      service: sv,
      vongDoi: vongDoi.stream,
      phien: phien.stream,
      clock: () => nay,
      dungYenOCongKhai: tinHieu ?? theoDoi.dungYenOCongKhai,
      vanAnToanRoi: van,
    );
    await t.pumpWidget(BlocProvider.value(
      value: cubit!,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => LopKhoaApp(khiQuenPin: () {}, dongHo: () => nay, child: child!),
      ),
    ));
    await cubit!.nhanPhien(10);
    await t.pump();
    expect(cubit!.state, isA<KhoaAppKhoa>(), reason: 'ca phải bắt đầu ở trạng thái khoá');
  }

  testWidgets('cưỡng chế đăng xuất khi đang khoá: Trang A không lộ ở bất kỳ khung nào, rồi gỡ lớp che', (t) async {
    await dung(t);
    // Cùng một nhịp: router được báo mất phiên VÀ cubit nhận phiên null (không có AuthLoading trước).
    dangNhap.value = false;
    await cubit!.nhanPhien(null);
    var khungLo = 0;
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 16));
      if (find.text('Trang A').evaluate().isNotEmpty &&
          lopDac.evaluate().isEmpty &&
          find.text('Nhập mã PIN').evaluate().isEmpty) {
        khungLo++;
      }
    }
    expect(khungLo, 0, reason: 'trang được bảo vệ còn được vẽ mà không có lớp che nào = lộ không cần PIN');
    await t.pumpAndSettle();
    expect(lopDac, findsNothing, reason: 'router đã đứng yên ở /login — phải gỡ lớp che');
    expect(find.text('Trang Đăng nhập'), findsOneWidget);
    expect(find.text('Trang A'), findsNothing);
    expect(cubit!.state, const KhoaAppTat());
  });

  testWidgets('Quên PIN -> Đăng xuất: router đã ở /login xong từ trước -> lớp che gỡ NGAY, không kẹt', (t) async {
    await dung(t);
    dangNhap.value = false; // AuthLoading: router sang /login dưới lớp khoá
    await t.pumpAndSettle();
    expect(theoDoi.dungYenOCongKhai.value, isTrue, reason: 'điều kiện phải thoả sẵn — không có lần push mới nào để chờ');
    await cubit!.nhanPhien(null); // AuthUnauthenticated tới muộn
    await t.pump();
    expect(cubit!.state, const KhoaAppTat());
    expect(lopDac, findsNothing);
    expect(find.text('Nhập mã PIN'), findsNothing);
    expect(find.text('Trang Đăng nhập'), findsOneWidget);
  });

  testWidgets('van an toàn: tín hiệu không bao giờ tới -> sau van vẫn gỡ lớp che', (t) async {
    final khongBaoGio = ValueNotifier<bool>(false);
    addTearDown(khongBaoGio.dispose);
    await dung(t, van: const Duration(milliseconds: 100), tinHieu: khongBaoGio);
    await cubit!.nhanPhien(null);
    await t.pump();
    expect(cubit!.state, isA<KhoaAppDangRoi>());
    expect(lopDac, findsOneWidget);
    await t.pump(const Duration(milliseconds: 150));
    expect(cubit!.state, const KhoaAppTat());
    expect(lopDac, findsNothing);
  });

  testWidgets('trang /login tự mở hộp thoại lý do ở khung đầu → lớp che gỡ khi hiệu ứng vào xong, TRƯỚC van an toàn', (t) async {
    router.dispose();
    router = GoRouter(
      initialLocation: '/a',
      observers: [theoDoi],
      refreshListenable: dangNhap,
      redirect: (context, state) {
        final vao = dangNhap.value;
        if (!vao && state.matchedLocation != '/login') return '/login';
        if (vao && state.matchedLocation == '/login') return '/a';
        return null;
      },
      routes: [
        GoRoute(path: '/a', builder: (_, __) => const Scaffold(body: Text('Trang A'))),
        GoRoute(path: '/login', builder: (_, __) => const _LoginCoHop()),
      ],
    );
    await dung(t); // van 3 s
    dangNhap.value = false;
    await cubit!.nhanPhien(null);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50)); // tổng 2 s < van 3 s
    }
    expect(find.text('Hộp thoại lý do'), findsOneWidget, reason: 'hộp thoại phải thấy được, không bị màn đặc che');
    expect(cubit!.state, const KhoaAppTat(), reason: 'hộp thoại không được chặn tín hiệu — chỉ gỡ sau van là sai');
    expect(lopDac, findsNothing);
  });

  testWidgets('popup mở trên trang ĐƯỢC BẢO VỆ không làm tín hiệu thành true', (t) async {
    await dung(t);
    unawaited(showDialog<void>(context: t.element(find.text('Trang A')), builder: (_) => const Text('hộp')));
    await t.pump(const Duration(milliseconds: 400));
    expect(theoDoi.dungYenOCongKhai.value, isFalse);
  });
}

class _LoginCoHop extends StatefulWidget {
  const _LoginCoHop();
  @override
  State<_LoginCoHop> createState() => _LoginCoHopState();
}

class _LoginCoHopState extends State<_LoginCoHop> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showDialog<void>(context: context, builder: (_) => const AlertDialog(content: Text('Hộp thoại lý do')));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Trang Đăng nhập'));
}
