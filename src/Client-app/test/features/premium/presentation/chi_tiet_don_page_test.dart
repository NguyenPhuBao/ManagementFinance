/// Màn Chi tiết đơn `/premium/don/:orderCode` (spec G94 2026-10-18 mục 5.5; Stitch `408de0af…` chờ xác nhận + hộp hỏi
/// lại, `d3b59018…` bốn trạng thái): mỗi trạng thái một thân; *Yêu cầu hoàn tiền* hỏi lại một lần; *Đồng ý* làm mới gói
/// rồi nạp lại → *Đã kích hoạt Premium* + *Xong*; xác nhận hỏng → viên lỗi, nút mở lại; 4xx → nạp lại theo server;
/// tín hiệu `payment.*` / quay lại app → nạp lại; 320 dp không tràn với số tiền 13 chữ số.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/repositories/don_thanh_toan_repository_impl.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/domain/chuyen_huong_theo_goi.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/pages/chi_tiet_don_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../helpers/bat_thong_bao.dart';

class _ApiGia implements PaymentApi {
  /// Kịch bản `lichSu` theo lượt gọi; hết kịch bản thì lặp phần tử cuối; rỗng = lịch sử trống.
  final List<List<Map<String, Object?>>> lichSuLanLuot = [];

  /// Lỗi ném cho các lượt `lichSu` đầu, theo thứ tự; hết danh sách thì trả theo [lichSuLanLuot].
  final List<Object> loiLichSu = [];

  /// Lỗi ném cho từng lượt `xacNhanNangCap`; hết danh sách thì lượt ấy thành công.
  final List<Object> loiXacNhan = [];

  /// Có thì `xacNhanNangCap` chờ nó — để thấy trạng thái *đang gửi*.
  Completer<void>? chanXacNhan;
  int soLanLichSu = 0;
  int soLanXacNhan = 0;
  int soLanHoiGoi = 0;
  bool? chapNhan;

  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) async {
    soLanLichSu++;
    if (loiLichSu.isNotEmpty) throw loiLichSu.removeAt(0);
    if (lichSuLanLuot.isEmpty) return const [];
    return lichSuLanLuot.length > 1 ? lichSuLanLuot.removeAt(0) : lichSuLanLuot.first;
  }

  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) async {
    soLanXacNhan++;
    chapNhan = accept;
    final c = chanXacNhan;
    if (c != null) await c.future;
    if (loiXacNhan.isNotEmpty) throw loiXacNhan.removeAt(0);
    return {'success': true};
  }

  @override
  Future<Map<String, Object?>> thongTinGoi() async {
    soLanHoiGoi++;
    return const {'accountType': 'Premium', 'premiumExpiresAt': '2026-11-17T01:00:00.000Z'};
  }

  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
}

const _taoLuc = '2026-10-18T07:05:00.000Z';

/// Một hàng `GET /payment/history` của đơn #9, giá 49.000.
Map<String, Object?> _dong(
  String status, {
  num? daChuyen = 60000,
  num? daHoan,
  String? hoanLuc,
  String? traLuc,
}) =>
    {
      'order_code': 9,
      'amount': 49000,
      'status': status,
      'created_at': _taoLuc,
      'amount_received': daChuyen,
      'refunded_amount': daHoan,
      'refunded_at': hoanLuc,
      'paid_at': traLuc,
    };

DioException _loiMang() => DioException(
    requestOptions: RequestOptions(path: '/payment/x'), type: DioExceptionType.connectionError);

DioException _loi400() {
  final req = RequestOptions(path: '/payment/confirm-upgrade');
  return DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: req, statusCode: 400));
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  final now = DateTime(2026, 10, 18, 15);
  late _ApiGia api;
  late StreamController<RealtimeEvent> suKien;
  late GoRouter router;

  setUp(() {
    api = _ApiGia();
    suKien = StreamController<RealtimeEvent>.broadcast();
  });
  tearDown(() => suKien.close());

  /// `/truoc` → push [duong] (mặc định `/premium/don/9`).
  Future<void> dung(WidgetTester tester, {String duong = '/premium/don/9'}) async {
    final goiRepo = GoiRepository(api: api, kho: InMemoryGoiStore(), clock: () => now);
    await goiRepo.datTaiKhoan(10);
    final goi = GoiCubit(goiRepo, clock: () => now);
    addTearDown(() async {
      await goi.close();
      await goiRepo.dispose();
    });
    router = GoRouter(initialLocation: '/truoc', routes: [
      GoRoute(path: '/truoc', builder: (_, __) => const Scaffold(body: Text('TRƯỚC'))),
      GoRoute(path: '/premium/lich-su', builder: (_, __) => const Scaffold(body: Text('LỊCH SỬ'))),
      GoRoute(
        path: '/premium/don/:orderCode',
        redirect: (_, s) => chuyenHuongChiTietDon(s.pathParameters['orderCode']),
        builder: (_, s) => ChiTietDonPage(
          orderCode: int.parse(s.pathParameters['orderCode']!),
          repo: DonThanhToanRepositoryImpl(api: api),
          goiRepo: goiRepo,
          goi: goi,
          suKien: suKien.stream,
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<GoiCubit>.value(
      value: goi,
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    router.push(duong);
    await tester.pumpAndSettle();
  }

  void khoMan(WidgetTester tester, double rong) {
    tester.view.physicalSize = Size(rong, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// `Text` dài KHÔNG tràn mà ngắt / cắt im lặng (`takeException` mù) — đo dòng thật: số tiền phải nằm trọn một dòng.
  void motDong(WidgetTester tester, String chu) {
    final p = tester.renderObject<RenderParagraph>(find.text(chu));
    expect(p.didExceedMaxLines, isFalse, reason: '"$chu" bị cắt ở maxLines');
    expect(p.size.height, lessThan(p.text.style!.fontSize! * 2), reason: '"$chu" xuống dòng');
  }

  ButtonStyleButton nut(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(Key(key)));

  testWidgets('route /premium/don/abc → về Lịch sử mua (redirect nối vào route)', (tester) async {
    await dung(tester, duong: '/premium/don/abc');
    expect(find.text('LỊCH SỬ'), findsOneWidget);
    expect(api.soLanLichSu, 0, reason: 'mã rác thì không dựng màn, không hỏi server');
  });

  testWidgets('chờ xác nhận: thẻ đầu (gói, mã đơn + giờ tạo, nhãn) + khối BẠN ĐÃ CHUYỂN THỪA ba dòng + hai nút',
      (tester) async {
    api.lichSuLanLuot.add([_dong('WAITING_CONFIRMATION')]);
    await dung(tester);
    expect(find.text('Chi tiết đơn'), findsOneWidget);
    expect(find.text('Gói Premium 30 ngày'), findsOneWidget);
    final gioTao = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.parse(_taoLuc).toLocal());
    expect(find.text('Mã đơn #9 · Tạo lúc $gioTao'), findsOneWidget);
    expect(find.text('Chờ xác nhận'), findsOneWidget);
    expect(find.text('BẠN ĐÃ CHUYỂN THỪA'), findsOneWidget);
    expect(find.text('60.000 đ'), findsOneWidget);
    expect(find.text('49.000 đ'), findsOneWidget);
    expect(find.text('11.000 đ'), findsOneWidget, reason: 'thừa = đã chuyển − giá gói, không dấu');
    expect(find.textContaining('kích hoạt gói Premium 30 ngày không?'), findsOneWidget);
    expect(find.byKey(const Key('chi-tiet-dong-y')), findsOneWidget);
    expect(find.byKey(const Key('chi-tiet-tu-choi')), findsOneWidget);
    expect(find.text('Chọn hoàn tiền thì không đổi lại được. Quản trị viên sẽ hoàn lại khoản đã chuyển.'),
        findsOneWidget);
    expect(api.soLanXacNhan, 0);
  });

  testWidgets('Yêu cầu hoàn tiền HỎI LẠI một lần: Huỷ / chạm nền không gửi; xác nhận → accept:false, nạp lại → ĐÃ CHỌN HOÀN TIỀN',
      (tester) async {
    api.lichSuLanLuot.addAll([
      [_dong('WAITING_CONFIRMATION')],
      [_dong('REFUND_PENDING')],
    ]);
    await dung(tester);

    await tester.tap(find.byKey(const Key('chi-tiet-tu-choi')));
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu hoàn tiền?'), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('60.000 đ')), findsOneWidget,
        reason: 'hộp nói rõ khoản nào sẽ không dùng để kích hoạt');
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.soLanXacNhan, 0, reason: 'Huỷ là không gửi gì');

    await tester.tap(find.byKey(const Key('chi-tiet-tu-choi')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // chạm nền ngoài hộp → `showDialog` trả null
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.soLanXacNhan, 0, reason: 'đóng hộp không chọn cũng là không gửi');

    await tester.tap(find.byKey(const Key('chi-tiet-tu-choi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chi-tiet-hoi-lai-dong-y')));
    await tester.pumpAndSettle();
    expect(api.soLanXacNhan, 1);
    expect(api.chapNhan, isFalse);
    expect(api.soLanHoiGoi, 0, reason: 'từ chối không làm mới gói');
    expect(api.soLanLichSu, 2, reason: 'xác nhận xong nạp lại đơn theo server');
    expect(find.text('BẠN ĐÃ CHỌN HOÀN TIỀN'), findsOneWidget);
    expect(find.text('Chờ hoàn tiền'), findsOneWidget);
    expect(find.byKey(const Key('chi-tiet-dong-y')), findsNothing, reason: 'đã chọn thì không đổi lại được');
    expect(find.byKey(const Key('chi-tiet-tu-choi')), findsNothing);
  });

  testWidgets('Đồng ý: đang gửi khoá hai nút + vòng xoay ở nút vừa bấm → làm mới gói → Đã kích hoạt + hạn mới; Xong pop',
      (tester) async {
    api.lichSuLanLuot.addAll([
      [_dong('WAITING_CONFIRMATION')],
      [_dong('PAID', traLuc: '2026-10-18T08:00:00.000Z')],
    ]);
    api.chanXacNhan = Completer<void>();
    await dung(tester);

    await tester.tap(find.byKey(const Key('chi-tiet-dong-y')));
    await tester.pump();
    expect(nut(tester, 'chi-tiet-dong-y').onPressed, isNull);
    expect(nut(tester, 'chi-tiet-tu-choi').onPressed, isNull);
    expect(
        find.descendant(
            of: find.byKey(const Key('chi-tiet-dong-y')), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('chi-tiet-tu-choi')), matching: find.byType(CircularProgressIndicator)),
        findsNothing);

    api.chanXacNhan!.complete();
    await tester.pumpAndSettle();
    expect(api.chapNhan, isTrue);
    expect(api.soLanHoiGoi, 1, reason: 'đồng ý → GoiRepository.lamMoi()');
    expect(find.text('Đã kích hoạt Premium'), findsOneWidget);
    expect(find.text('Hạn dùng đến ${DateFormat('dd/MM/yyyy').format(DateTime.parse('2026-11-17T01:00:00.000Z').toLocal())}'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('chi-tiet-xong')));
    await tester.pumpAndSettle();
    expect(find.text('TRƯỚC'), findsOneWidget);
  });

  testWidgets('chờ hoàn tiền do chuyển thiếu: BẠN ĐÃ CHUYỂN THIẾU, thiếu 9.000 đ, không nút hành động', (tester) async {
    api.lichSuLanLuot.add([_dong('REFUND_PENDING', daChuyen: 40000)]);
    await dung(tester);
    expect(find.text('BẠN ĐÃ CHUYỂN THIẾU'), findsOneWidget);
    expect(find.text('40.000 đ'), findsOneWidget);
    expect(find.text('9.000 đ'), findsOneWidget);
    expect(find.text('Khoản này chưa đủ để kích hoạt gói. Quản trị viên sẽ hoàn lại khoản đã chuyển cho bạn.'),
        findsOneWidget);
    expect(find.byKey(const Key('chi-tiet-dong-y')), findsNothing);
    expect(find.byKey(const Key('chi-tiet-tu-choi')), findsNothing);
  });

  testWidgets('chờ hoàn tiền không rõ lý do (đã chuyển bằng giá / thiếu số): chỉ câu chung, không hứa số tiền',
      (tester) async {
    api.lichSuLanLuot.add([_dong('REFUND_PENDING', daChuyen: null)]);
    await dung(tester);
    expect(find.text('Quản trị viên sẽ hoàn lại khoản đã chuyển cho bạn.'), findsOneWidget);
    expect(find.text('BẠN ĐÃ CHUYỂN THIẾU'), findsNothing);
    expect(find.text('BẠN ĐÃ CHỌN HOÀN TIỀN'), findsNothing);
  });

  testWidgets('đã hoàn tiền: số admin đã hoàn + ngày; thiếu số đã hoàn thì dùng số đã chuyển', (tester) async {
    api.lichSuLanLuot.addAll([
      [_dong('REFUNDED', daHoan: 60000, hoanLuc: '2026-10-20T05:00:00.000Z')],
      [_dong('REFUNDED', daChuyen: 45000)],
    ]);
    await dung(tester);
    expect(find.text('Đã hoàn 60.000 đ'), findsOneWidget);
    expect(find.text('Ngày 20/10/2026'), findsOneWidget);

    suKien.add(RealtimeEvent.donThanhToanDoi);
    await tester.pumpAndSettle();
    expect(find.text('Đã hoàn 45.000 đ'), findsOneWidget);
    expect(find.textContaining('Ngày '), findsNothing, reason: 'thiếu ngày hoàn thì bỏ vế ấy');
  });

  testWidgets('đã thanh toán (mở từ Lịch sử, không vừa đồng ý): số tiền + ngày trả, không nút Xong', (tester) async {
    api.lichSuLanLuot.add([_dong('PAID', daChuyen: 49000, traLuc: '2026-10-19T05:00:00.000Z')]);
    await dung(tester);
    expect(find.text('Đã thanh toán 49.000 đ'), findsOneWidget);
    expect(find.text('Ngày 19/10/2026'), findsOneWidget);
    expect(find.text('Đã kích hoạt Premium'), findsNothing);
    expect(find.byKey(const Key('chi-tiet-xong')), findsNothing);
  });

  for (final (status, cau) in const [
    ('EXPIRED', 'Đơn đã hết hạn'),
    ('CANCELLED', 'Đơn đã huỷ'),
    ('PENDING', 'Đơn đang chờ thanh toán'),
  ]) {
    testWidgets('$status: một dòng trạng thái + giá gói', (tester) async {
      api.lichSuLanLuot.add([_dong(status, daChuyen: null)]);
      await dung(tester);
      expect(find.text(cau), findsOneWidget);
      expect(find.text('Giá gói 49.000 đ'), findsOneWidget);
      expect(find.byKey(const Key('chi-tiet-dong-y')), findsNothing);
    });
  }

  testWidgets('không thấy đơn → câu + Thử lại; lịch sử hỏng → câu lỗi + Thử lại hỏi lại server', (tester) async {
    api.lichSuLanLuot.addAll([
      [
        {..._dong('PAID'), 'order_code': 8}
      ],
      [_dong('WAITING_CONFIRMATION')],
    ]);
    api.loiLichSu.add(_loiMang());
    await dung(tester);
    expect(find.text('Không có kết nối. Thử lại khi có mạng.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chi-tiet-thu-lai')));
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 2);
    expect(find.text('Không tìm thấy đơn này'), findsOneWidget, reason: 'lịch sử chỉ có đơn #8');
    await tester.tap(find.byKey(const Key('chi-tiet-thu-lai')));
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 3);
    expect(find.text('BẠN ĐÃ CHUYỂN THỪA'), findsOneWidget);
  });

  testWidgets('xác nhận mất mạng → viên lỗi, nút mở lại, KHÔNG nạp lại; 400 → viên "Không xác nhận được…" + nạp lại',
      (tester) async {
    final bat = batThongBao();
    api.lichSuLanLuot.addAll([
      [_dong('WAITING_CONFIRMATION')],
      [_dong('REFUND_PENDING')],
    ]);
    api.loiXacNhan.addAll([_loiMang(), _loi400()]);
    await dung(tester);

    await tester.tap(find.byKey(const Key('chi-tiet-dong-y')));
    await tester.pumpAndSettle();
    expect(bat.cuoi?.cau, 'Không có kết nối. Thử lại khi có mạng.');
    expect(bat.cuoi?.loai, LoaiThongBao.loi);
    expect(nut(tester, 'chi-tiet-dong-y').onPressed, isNotNull, reason: 'sau lỗi mạng nút phải mở lại');
    expect(api.soLanLichSu, 1, reason: 'mất mạng thì đơn chưa đổi — không hỏi lại');
    expect(api.soLanHoiGoi, 0);

    await tester.tap(find.byKey(const Key('chi-tiet-dong-y')));
    await tester.pumpAndSettle();
    expect(api.soLanXacNhan, 2);
    expect(bat.cuoi?.cau, 'Không xác nhận được đơn này. Thử lại sau.');
    expect(api.soLanLichSu, 2, reason: '4xx = đơn đã đổi ở nơi khác → màn đi theo server');
    expect(find.text('BẠN ĐÃ CHỌN HOÀN TIỀN'), findsOneWidget);
  });

  testWidgets('tín hiệu donThanhToanDoi / taiKhoanNangCap và quay lại app → nạp lại; sự kiện khác thì không',
      (tester) async {
    api.lichSuLanLuot.add([_dong('WAITING_CONFIRMATION')]);
    await dung(tester);
    expect(api.soLanLichSu, 1);
    suKien.add(RealtimeEvent.donThanhToanDoi);
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 2);
    suKien.add(RealtimeEvent.taiKhoanNangCap);
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 3);
    suKien.add(RealtimeEvent.dongBoXong);
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 3, reason: 'đồng bộ dữ liệu không đổi trạng thái đơn');

    for (final s in const [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    for (final s in const [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 4, reason: 'quay lại từ app ngân hàng / Admin vừa hoàn → đọc lại');
  });

  for (final rong in const [360.0, 320.0]) {
    testWidgets('$rong dp không tràn — số tiền 13 chữ số ở cả thân chuyển thừa và thân đã hoàn', (tester) async {
      khoMan(tester, rong);
      api.lichSuLanLuot.addAll([
        [_dong('WAITING_CONFIRMATION', daChuyen: 9999999999999)],
        [_dong('REFUNDED', daChuyen: 9999999999999, daHoan: 9999999999999, hoanLuc: '2026-10-20T05:00:00.000Z')],
      ]);
      await dung(tester);
      expect(tester.takeException(), isNull);
      motDong(tester, '9.999.999.999.999 đ');
      motDong(tester, '9.999.999.950.999 đ');
      suKien.add(RealtimeEvent.donThanhToanDoi);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      motDong(tester, 'Đã hoàn 9.999.999.999.999 đ');
    });
  }
}
