/// Màn Đang chờ thanh toán `/premium/cho-thanh-toan` (spec Premium 9.3 & Payment spec):
/// mở link ngay khi vào; hiển thị mã nhận diện 6 ký tự; hỏi trạng thái mỗi 3 s khi đang hiện;
/// hỏi ngay khi bấm "Tôi đã chuyển khoản" / khi socket báo lên gói;
/// PAID → làm mới gói + Thành công + Xong pop hai lớp;
/// WAITING_CONFIRMATION → Xác nhận thừa tiền + gọi API xacNhanNangCap;
/// REFUND_PENDING → Cần xử lý hoàn tiền;
/// EXPIRED / đếm ngược về 0 → Tạo đơn mới; rời màn thì dừng hỏi; mở link hỏng thì hiện link chép được.
library;

import 'dart:async';

import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/pages/cho_thanh_toan_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _ApiGia implements PaymentApi {
  /// Kịch bản trả lời theo thứ tự; hết kịch bản thì lặp phần tử cuối; rỗng =
  /// `PENDING` mãi.
  final List<String> trangThai = [];
  int soLanHoiDon = 0;
  int soLanHoiGoi = 0;
  int soLanXacNhan = 0;
  bool? xacNhanChapNhan;

  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) async {
    soLanHoiDon++;
    final s = trangThai.isEmpty
        ? 'PENDING'
        : (trangThai.length > 1 ? trangThai.removeAt(0) : trangThai.first);
    return {'order_code': orderCode, 'status': s};
  }

  @override
  Future<Map<String, Object?>> thongTinGoi() async {
    soLanHoiGoi++;
    return const {
      'accountType': 'Premium',
      'premiumExpiresAt': '2026-11-05T01:00:00.000Z',
    };
  }

  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) async {
    soLanXacNhan++;
    xacNhanChapNhan = accept;
    return {'success': true};
  }

  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) =>
      throw UnimplementedError();
}

void main() {
  var now = DateTime(2026, 10, 6, 10);
  final don = DonThanhToan(
    orderCode: 200370869,
    checkoutUrl: Uri.parse('https://pay.payos.vn/web/abc'),
    soTien: 49000,
    recognitionCode: 'A8K9M2',
    hetHanLuc: DateTime(2026, 10, 6, 10, 30),
  );

  late _ApiGia api;
  late List<Uri> daMo;
  late bool moDuoc;
  late StreamController<RealtimeEvent> suKien;
  late GoRouter router;

  setUp(() {
    now = DateTime(2026, 10, 6, 10);
    api = _ApiGia();
    daMo = [];
    moDuoc = true;
    suKien = StreamController<RealtimeEvent>.broadcast();
  });
  tearDown(() => suKien.close());

  Future<void> dung(WidgetTester tester, {DonThanhToan? d}) async {
    final repo = GoiRepository(api: api, kho: InMemoryGoiStore(), clock: () => now);
    await repo.datTaiKhoan(10);
    final cubit = GoiCubit(repo, clock: () => now);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });
    router = GoRouter(initialLocation: '/truoc', routes: [
      GoRoute(path: '/truoc', builder: (_, __) => const Scaffold(body: Text('TRƯỚC'))),
      GoRoute(path: '/premium', builder: (_, __) => const Scaffold(body: Text('NÂNG CẤP'))),
      GoRoute(
        path: '/premium/cho-thanh-toan',
        builder: (_, s) => ChoThanhToanPage(
          don: s.extra as DonThanhToan,
          api: api,
          goi: cubit,
          moLienKet: (u) async {
            daMo.add(u);
            return moDuoc;
          },
          suKien: suKien.stream,
          clock: () => now,
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<GoiCubit>.value(
      value: cubit,
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    router.push('/premium');
    await tester.pumpAndSettle();
    router.push('/premium/cho-thanh-toan', extra: d ?? don);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Trôi [giay] giây: đồng hồ giả lẫn timer của Flutter cùng tiến.
  Future<void> troi(WidgetTester tester, int giay) async {
    for (var i = 0; i < giay; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('chờ: số tiền, mã đơn, mã nhận diện 6 ký tự, đếm ngược; mở link đúng MỘT lần khi vào', (tester) async {
    await dung(tester);
    expect(find.text('49.000 đ'), findsOneWidget);
    expect(find.text('Mã đơn #200370869'), findsOneWidget);
    expect(find.text('A8K9M2'), findsOneWidget);
    expect(find.textContaining('Đang chờ xác nhận'), findsOneWidget);
    expect(find.text('Còn 30:00'), findsOneWidget);
    expect(daMo, [don.checkoutUrl]);

    // Thao tác chép mã nhận diện
    final goi = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      goi.add(c);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.tap(find.byKey(const Key('cho-chep-ma')));
    await tester.pump();
    expect(goi.map((c) => c.method), contains('Clipboard.setData'));
    expect(find.text('Đã chép'), findsOneWidget);

    await troi(tester, 61);
    expect(find.text('Còn 28:59'), findsOneWidget);
    expect(daMo.length, 1);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('hỏi mỗi 3 s; PAID → làm mới gói, Thành công, Xong pop HAI lớp', (tester) async {
    api.trangThai.addAll(['PENDING', 'PAID']);
    await dung(tester);
    expect(api.soLanHoiDon, 0);
    await troi(tester, 3);
    expect(api.soLanHoiDon, 1);
    await troi(tester, 3);
    await tester.pump();
    await tester.pump();
    expect(api.soLanHoiDon, 2);
    expect(api.soLanHoiGoi, 1, reason: 'PAID → GoiRepository.lamMoi()');
    await tester.pumpAndSettle();
    expect(find.text('Nâng cấp Premium thành công'), findsOneWidget);
    expect(find.textContaining('05/11/2026'), findsOneWidget);
    await troi(tester, 6);
    expect(api.soLanHoiDon, 2, reason: 'đã trả thì dừng hỏi');
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('TRƯỚC'), findsOneWidget, reason: 'pop hai lớp — về màn trước Nâng cấp');
  });

  testWidgets('WAITING_CONFIRMATION → hiện giao diện xác nhận thừa tiền; bấm Đồng ý gọi xacNhanNangCap(accept: true)', (tester) async {
    api.trangThai.addAll(['WAITING_CONFIRMATION']);
    await dung(tester);
    await troi(tester, 3);
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận chuyển thừa tiền'), findsOneWidget);
    expect(find.text('Đồng ý kích hoạt gói'), findsOneWidget);
    expect(find.text('Từ chối & Yêu cầu hoàn tiền'), findsOneWidget);

    await tester.tap(find.text('Đồng ý kích hoạt gói'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.soLanXacNhan, 1);
    expect(api.xacNhanChapNhan, isTrue);
    expect(find.text('Nâng cấp Premium thành công'), findsOneWidget);
  });

  testWidgets('REFUND_PENDING → hiện giao diện Cần xử lý hoàn tiền', (tester) async {
    api.trangThai.addAll(['REFUND_PENDING']);
    await dung(tester);
    await troi(tester, 3);
    await tester.pumpAndSettle();

    expect(find.text('Cần xử lý hoàn tiền'), findsOneWidget);
    expect(find.text('Tạo đơn mới'), findsOneWidget);
  });

  testWidgets('EXPIRED → câu hết hạn + Tạo đơn mới pop về Nâng cấp', (tester) async {
    api.trangThai.addAll(['EXPIRED']);
    await dung(tester);
    await troi(tester, 3);
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã hết hạn'), findsOneWidget);
    await tester.tap(find.text('Tạo đơn mới'));
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP'), findsOneWidget);
  });

  testWidgets('đếm ngược về 0 → coi như hết hạn, dừng hỏi', (tester) async {
    await dung(tester, d: DonThanhToan(
        orderCode: 1, checkoutUrl: don.checkoutUrl, soTien: 49000,
        hetHanLuc: DateTime(2026, 10, 6, 10, 0, 5)));
    await troi(tester, 6);
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã hết hạn'), findsOneWidget);
    final truoc = api.soLanHoiDon;
    await troi(tester, 6);
    expect(api.soLanHoiDon, truoc);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('"Tôi đã chuyển khoản" hỏi NGAY; socket taiKhoanNangCap hỏi NGAY', (tester) async {
    await dung(tester);
    await tester.tap(find.text('Tôi đã chuyển khoản'));
    await tester.pump();
    expect(api.soLanHoiDon, 1);
    suKien.add(RealtimeEvent.taiKhoanNangCap);
    await tester.pump();
    await tester.pump();
    expect(api.soLanHoiDon, 2);
    suKien.add(RealtimeEvent.dongBoXong);
    await tester.pump();
    expect(api.soLanHoiDon, 2, reason: 'sự kiện khác không hỏi');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('Mở lại trang thanh toán gọi lại link; mở hỏng → link chép được', (tester) async {
    moDuoc = false;
    await dung(tester);
    await tester.pump();
    expect(find.text(don.checkoutUrl.toString()), findsOneWidget);
    expect(find.text('Chép'), findsOneWidget);
    final goi = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      goi.add(c);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Chép'));
    await tester.pump();
    expect(goi.map((c) => c.method), contains('Clipboard.setData'));
    await tester.tap(find.text('Mở lại trang thanh toán'));
    await tester.pump();
    expect(daMo.length, 2);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('rời màn (Huỷ) → dừng hỏi', (tester) async {
    await dung(tester);
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP'), findsOneWidget);
    final truoc = api.soLanHoiDon;
    await troi(tester, 9);
    expect(api.soLanHoiDon, truoc);
  });

  testWidgets('360 × 640 không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    moDuoc = false;
    await dung(tester);
    await tester.pump();
    expect(tester.takeException(), isNull);
    router.pop();
    await tester.pumpAndSettle();
  });
}
