/// Màn Đang chờ thanh toán `/premium/cho-thanh-toan` (spec Premium 9.3 & Payment spec):
/// mở link ngay khi vào; hiển thị mã nhận diện 6 ký tự; hỏi trạng thái mỗi 3 s khi đang hiện;
/// hỏi ngay khi bấm "Tôi đã chuyển khoản" / khi socket báo lên gói;
/// PAID → làm mới gói + Thành công + Xong pop hai lớp;
/// WAITING_CONFIRMATION → Xác nhận thừa tiền + gọi API xacNhanNangCap (hỏng → câu báo lỗi, nút mở lại);
/// REFUND_PENDING → Cần xử lý hoàn tiền;
/// EXPIRED → Tạo đơn mới — đồng hồ trên máy về 0 KHÔNG tự báo hết hạn, server quyết (G94 việc 1);
/// rời màn thì dừng hỏi; mở link hỏng thì hiện link chép được.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/data/models/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/pages/cho_thanh_toan_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/bat_thong_bao.dart';

class _ApiGia implements PaymentApi {
  /// Kịch bản trả lời theo thứ tự; hết kịch bản thì lặp phần tử cuối; rỗng =
  /// `PENDING` mãi.
  final List<String> trangThai = [];

  /// Có thì thắng [trangThai] — trả lời theo đồng hồ giả, như server cho đơn
  /// `PENDING` quá `expired_at` thành `EXPIRED` ngay lúc đọc.
  String Function()? traLoiTheoGio;

  /// Lỗi ném cho từng lượt `xacNhanNangCap`, theo thứ tự; hết danh sách thì
  /// lượt ấy thành công.
  final List<Object> loiXacNhan = [];
  int soLanHoiDon = 0;
  int soLanHoiGoi = 0;
  int soLanXacNhan = 0;
  bool? xacNhanChapNhan;

  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) async {
    soLanHoiDon++;
    final s = traLoiTheoGio?.call() ??
        (trangThai.isEmpty
            ? 'PENDING'
            : (trangThai.length > 1 ? trangThai.removeAt(0) : trangThai.first));
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
    if (loiXacNhan.isNotEmpty) throw loiXacNhan.removeAt(0);
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

  testWidgets('⭐ G94 việc 3: xác nhận hỏng → báo lỗi bằng câu ngắn, ở lại hộp xác nhận, nút mở lại để thử lần nữa',
      (tester) async {
    final bat = batThongBao();
    final req = RequestOptions(path: '/payment/confirm-upgrade');
    api.loiXacNhan.addAll([
      DioException(requestOptions: req, type: DioExceptionType.connectionError),
      // Server trả 400 khi đơn không còn WAITING_CONFIRMATION.
      DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: 400)),
    ]);
    api.trangThai.add('WAITING_CONFIRMATION');
    await dung(tester);
    await troi(tester, 3);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đồng ý kích hoạt gói'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(api.soLanXacNhan, 1);
    expect(bat.cuoi?.cau, 'Không có kết nối. Thử lại khi có mạng.',
        reason: 'lỗi từng chỉ vào `debugPrint` — bấm nút mà không thấy phản hồi nào');
    expect(bat.cuoi?.loai, LoaiThongBao.loi);
    expect(find.text('Xác nhận chuyển thừa tiền'), findsOneWidget);

    await tester.tap(find.text('Từ chối & Yêu cầu hoàn tiền'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(api.soLanXacNhan, 2, reason: 'sau lỗi nút phải mở lại');
    expect(bat.cuoi?.cau, 'Không xác nhận được đơn này. Thử lại sau.',
        reason: 'câu 4xx mặc định của mảng là "Không tạo được đơn thanh toán" — sai với thao tác xác nhận');
    expect(bat.ds, hasLength(2));
    expect(find.text('Xác nhận chuyển thừa tiền'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
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

  /// Đơn hạn 5 giây sau `now` của `setUp` — cho các ca đồng hồ về 0.
  DonThanhToan donHan5Giay() => DonThanhToan(
      orderCode: 1, checkoutUrl: don.checkoutUrl, soTien: 49000,
      hetHanLuc: DateTime(2026, 10, 6, 10, 0, 5));

  void doiVongDoi(WidgetTester tester, List<AppLifecycleState> chuoi) {
    // Đi đủ từng bậc — framework kiểm chuyển trạng thái hợp lệ.
    for (final s in chuoi) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  testWidgets('đồng hồ về 0 KHÔNG tự kết luận hết hạn: server còn PENDING → vẫn chờ, vẫn hỏi; server EXPIRED → hết hạn, dừng hỏi',
      (tester) async {
    // Server là nguồn sự thật: `order-status` tự trả EXPIRED cho đơn PENDING quá
    // `expired_at`. Ở đây giờ máy chạy nhanh hơn giờ server 3 giây.
    final hetHanServer = DateTime(2026, 10, 6, 10, 0, 8);
    api.traLoiTheoGio = () => now.isBefore(hetHanServer) ? 'PENDING' : 'EXPIRED';
    await dung(tester, d: donHan5Giay());
    await troi(tester, 6);
    expect(find.text('Còn 00:00'), findsOneWidget);
    expect(find.text('Đơn đã hết hạn'), findsNothing,
        reason: 'đồng hồ trên máy về 0 chỉ là lý do để hỏi — server chưa nói EXPIRED thì chưa được báo hết hạn');
    final truoc = api.soLanHoiDon;
    await troi(tester, 3);
    expect(api.soLanHoiDon, truoc + 1, reason: 'quá hạn theo máy vẫn hỏi theo nhịp');
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã hết hạn'), findsOneWidget);
    final sau = api.soLanHoiDon;
    await troi(tester, 6);
    expect(api.soLanHoiDon, sau, reason: 'server báo hết hạn thì dừng hỏi');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('⭐ G94 việc 1: đồng hồ về 0 lúc app ở nền, quay lại → thấy hộp xác nhận chuyển thừa, KHÔNG "Đơn đã hết hạn"',
      (tester) async {
    // Người dùng sang app ngân hàng chuyển thừa; webhook đưa đơn sang
    // WAITING_CONFIRMATION — server không bao giờ cho trạng thái ấy hết hạn; họ
    // quay lại sau khi đồng hồ trên máy đã về 0.
    api.trangThai.add('WAITING_CONFIRMATION');
    await dung(tester, d: donHan5Giay());
    doiVongDoi(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await troi(tester, 8);
    expect(api.soLanHoiDon, 0, reason: 'app ở nền thì không hỏi theo nhịp');
    doiVongDoi(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(api.soLanHoiDon, 1, reason: 'quay lại app → hỏi ngay');
    expect(find.text('Đơn đã hết hạn'), findsNothing,
        reason: 'đồng hồ về 0 lúc màn không hiện từng đưa màn sang hết hạn, rồi `_khiCo` bỏ qua câu trả lời của server');
    expect(find.text('Xác nhận chuyển thừa tiền'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('⭐ G94 việc 1: webhook tới sát hạn — đồng hồ về 0 trước lượt hỏi kế, server báo WAITING_CONFIRMATION → hộp xác nhận',
      (tester) async {
    api.trangThai.addAll(['PENDING', 'WAITING_CONFIRMATION']);
    await dung(tester, d: donHan5Giay());
    // Giây 3: PENDING · giây 5: đồng hồ về 0 · giây 6: WAITING_CONFIRMATION.
    await troi(tester, 6);
    await tester.pumpAndSettle();
    expect(api.soLanHoiDon, 2);
    expect(find.text('Đơn đã hết hạn'), findsNothing);
    expect(find.text('Xác nhận chuyển thừa tiền'), findsOneWidget);
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
