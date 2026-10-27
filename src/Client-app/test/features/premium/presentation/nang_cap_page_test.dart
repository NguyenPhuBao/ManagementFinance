/// Màn Nâng cấp `/premium` (spec Premium 2026-10-06 mục 9.1–9.2): Basic thấy
/// bốn đặc quyền + giá + Thanh toán (câu trần khi đến từ cửa chặn); Premium
/// thấy hạn + Gia hạn + Lịch sử mua. KHÔNG hứa "đồng bộ tức thì" (câu 4).
/// Bấm Thanh toán hai lần chỉ tạo MỘT đơn; tạo đơn hỏng thì ở lại màn.
/// Đơn cần xử lý (spec G94 2026-10-18 mục 5.7): chờ xác nhận → thẻ nổi + khoá
/// Thanh toán / Gia hạn; chờ hoàn tiền → thẻ nhỏ, không khoá; lịch sử hỏng →
/// không thẻ, nút mở; tín hiệu `payment.*` / quay về → đọc lại.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/data/repositories/don_thanh_toan_repository_impl.dart';
import 'package:flowmoney/features/premium/data/models/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/data/models/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flowmoney/features/premium/data/models/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/pages/nang_cap_page.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import '../../../helpers/bat_thong_bao.dart';

class _ApiGia implements PaymentApi {
  int soLanTao = 0;
  bool nem = false;
  Completer<void>? treo;

  /// `null` → `lichSu` ném (lịch sử hỏng) — mặc định của mọi ca cũ: không thẻ, nút mở.
  List<Map<String, Object?>>? lichSuItems;
  int soLanLichSu = 0;

  @override
  Future<Map<String, Object?>> taoDon() async {
    soLanTao++;
    if (treo != null) await treo!.future;
    if (nem) {
      final req = RequestOptions(path: '/payment/create-order');
      throw DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: 503));
    }
    return const {
      'orderCode': 200370869,
      'checkoutUrl': 'https://pay.payos.vn/web/abc',
      'amount': 49000,
      'expiredAt': '2026-10-06T04:00:00.000Z',
    };
  }

  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) async {
    soLanLichSu++;
    final ds = lichSuItems;
    if (ds == null) {
      final req = RequestOptions(path: '/payment/history');
      throw DioException(requestOptions: req, type: DioExceptionType.connectionError);
    }
    return ds;
  }
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) =>
      throw UnimplementedError();
}

/// Màn Chờ giả: khung đầu `pushReplacement` sang Chi tiết đơn — đúng đường của màn Chờ thật với đơn chuyển thừa.
class _ChoThayNgay extends StatefulWidget {
  const _ChoThayNgay(this.ma);

  final int ma;

  @override
  State<_ChoThayNgay> createState() => _ChoThayNgayState();
}

class _ChoThayNgayState extends State<_ChoThayNgay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement('/premium/don/${widget.ma}');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('CHỜ'));
}

Map<String, Object?> _don(int ma, String status) =>
    {'order_code': ma, 'amount': 49000, 'status': status, 'created_at': '2026-10-06T02:00:00.000Z'};

void main() {
  final now = DateTime(2026, 10, 6, 10);
  late StreamController<RealtimeEvent> suKien;

  setUp(() => suKien = StreamController<RealtimeEvent>.broadcast());
  tearDown(() => suKien.close());

  Future<GoiCubit> goi({required bool premium, DateTime? hetHan, TrangThaiGoi? trangThai}) async {
    final kho = InMemoryGoiStore();
    if (trangThai != null) {
      await kho.ghi(10, trangThai);
    } else if (premium) {
      await kho.ghi(
          10,
          TrangThaiGoi(
              loai: LoaiGoi.premium,
              hetHan: hetHan ?? DateTime(2026, 11, 5, 8),
              nhanLuc: now));
    }
    final repo = GoiRepository(api: _ApiGia(), kho: kho, clock: () => now);
    await repo.datTaiKhoan(10);
    final cubit = GoiCubit(repo, clock: () => now);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });
    return cubit;
  }

  Future<GoRouter> dung(
    WidgetTester tester, {
    required bool premium,
    LoaiTran? tran,
    MaQuyen? quyen,
    _ApiGia? api,
    DateTime? hetHan,
    bool choThayNgay = false,
    TrangThaiGoi? trangThai,
  }) async {
    final cubit = await goi(premium: premium, hetHan: hetHan, trangThai: trangThai);
    final router = GoRouter(initialLocation: '/premium', routes: [
      GoRoute(
        path: '/premium',
        builder: (_, __) => NangCapPage(
            tran: tran,
            quyen: quyen,
            repo: DonThanhToanRepositoryImpl(api: api ?? _ApiGia(), clock: () => now),
            goi: cubit,
            suKien: suKien.stream,
            clock: () => now),
      ),
      GoRoute(
        path: '/premium/don/:orderCode',
        builder: (_, s) => Scaffold(body: Text('CHI TIẾT ${s.pathParameters['orderCode']}')),
      ),
      GoRoute(
        path: '/premium/cho-thanh-toan',
        builder: (_, s) => choThayNgay
            // Như màn Chờ thật khi server trả trạng thái đối soát: THAY chính nó bằng Chi tiết đơn.
            ? _ChoThayNgay((s.extra as DonThanhToan).orderCode)
            : Scaffold(body: Text('CHỜ ${(s.extra as DonThanhToan).orderCode}')),
      ),
      GoRoute(
          path: '/premium/lich-su',
          builder: (_, __) => const Scaffold(body: Text('LỊCH SỬ'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<GoiCubit>.value(
      value: cubit,
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Basic: đặc quyền theo bảng (mặc định: 3 trần + 3 quyền AI), giá qua CurrencyFormatter, Thanh toán; KHÔNG chữ đồng bộ',
      (tester) async {
    await dung(tester, premium: false);
    expect(find.text('Gói hiện tại: Basic'), findsOneWidget);
    for (final d in [
      'Không giới hạn ví',
      'Không giới hạn ngân sách',
      'Không giới hạn mục tiêu tiết kiệm',
      MaQuyen.aiAssistant.ten,
      MaQuyen.aiQuickInput.ten,
      MaQuyen.aiEdgeModel.ten,
    ]) {
      expect(find.text(d), findsOneWidget, reason: d);
    }
    expect(find.text(MaQuyen.exportReports.ten), findsNothing,
        reason: 'thiếu khoá = mở với Basic → không phải đặc quyền');
    expect(find.textContaining('49.000 đ'), findsOneWidget);
    expect(find.textContaining('đồng bộ'), findsNothing,
        reason: 'câu 4: không hứa thứ không khác');
    expect(find.widgetWithText(ElevatedButton, 'Thanh toán'), findsOneWidget);
    expect(find.text('Bạn đã dùng 3/3 ví của gói Basic.'), findsNothing);
  });

  testWidgets('?quyen=cashflow_forecast: câu mở đầu nêu tên tính năng (spec phân quyền 4.4)',
      (tester) async {
    await dung(tester, premium: false, quyen: MaQuyen.cashflowForecast);
    expect(find.text('Dự báo 30 ngày tới là tính năng Premium.'), findsOneWidget);
    expect(find.byKey(const Key('nang-cap-cau-quyen')), findsOneWidget);
  });

  group('B1 — câu mở đầu theo trạng thái quyền và trần hiệu lực (spec 2026-10-27 mục 4)', () {
    testWidgets('⭐ Premium, bảng tắt export_reports, ?quyen=export_reports → "… hiện đang tạm ngừng."', (tester) async {
      await dung(tester,
          premium: true,
          quyen: MaQuyen.exportReports,
          trangThai: TrangThaiGoi(
              loai: LoaiGoi.premium,
              hetHan: DateTime(2026, 11, 5, 8),
              nhanLuc: now,
              quyenTinhNang: const {'export_reports': false}));
      expect(find.text('Xuất báo cáo hiện đang tạm ngừng.'), findsOneWidget);
      expect(find.text('Xuất báo cáo là tính năng Premium.'), findsNothing);
    });

    testWidgets('⭐ Premium, trần cột Premium 10 ví, ?tran=vi → "Gói Premium hiện cho tạo tối đa 10 ví."', (tester) async {
      await dung(tester,
          premium: true,
          tran: LoaiTran.vi,
          trangThai: TrangThaiGoi(
              loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 5, 8), nhanLuc: now, tran: const TranGoi(vi: 10)));
      expect(find.text('Gói Premium hiện cho tạo tối đa 10 ví.'), findsOneWidget);
    });

    testWidgets('⭐ G109 trên màn: Premium hết hạn lúc offline, ?tran=vi → câu Basic 3/3 (không phải "null/null")',
        (tester) async {
      await dung(tester,
          premium: false,
          tran: LoaiTran.vi,
          trangThai: TrangThaiGoi(
              loai: LoaiGoi.premium,
              hetHan: DateTime(2026, 10, 6, 9),
              nhanLuc: DateTime(2026, 10, 5),
              tran: const TranGoi()));
      expect(find.text('Bạn đã dùng 3/3 ví của gói Basic.'), findsOneWidget);
    });

    testWidgets('Premium còn hạn, quyền mở, ?quyen= → không câu khoá', (tester) async {
      await dung(tester, premium: true, quyen: MaQuyen.cashflowForecast);
      expect(find.byKey(const Key('nang-cap-cau-quyen')), findsNothing);
      expect(find.byKey(const Key('nang-cap-han')), findsOneWidget);
    });

    testWidgets('Basic, cột Premium cũng tắt → ?quyen= nói tạm ngừng', (tester) async {
      await dung(tester,
          premium: false,
          quyen: MaQuyen.exportReports,
          trangThai: TrangThaiGoi(
              loai: LoaiGoi.basic,
              nhanLuc: now,
              quyenTinhNang: const {'export_reports': false},
              quyenPremium: const {'export_reports': false}));
      expect(find.text('Xuất báo cáo hiện đang tạm ngừng.'), findsOneWidget);
    });
  });

  testWidgets('?tran=vi: câu mở đầu nêu 3/3 ví', (tester) async {
    await dung(tester, premium: false, tran: LoaiTran.vi);
    expect(find.text('Bạn đã dùng 3/3 ví của gói Basic.'), findsOneWidget);
    final icon = tester.widget<Icon>(find.descendant(
        of: find.byKey(const Key('nang-cap-cau-tran')), matching: find.byIcon(Icons.info_outline)));
    expect(icon.color, AppColors.warning, reason: 'màu chỉ từ AppColors — bản cũ ghi cứng Color(0xFFE65100)');
  });

  testWidgets('Premium: còn N ngày + hạn, Gia hạn, Lịch sử mua → /premium/lich-su',
      (tester) async {
    await dung(tester, premium: true);
    expect(find.textContaining('còn 30 ngày'), findsOneWidget);
    expect(find.textContaining('05/11/2026'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Gia hạn thêm 30 ngày'),
        findsOneWidget);
    expect(find.text('Gói hiện tại: Basic'), findsNothing);
    await tester.tap(find.text('Lịch sử mua'));
    await tester.pumpAndSettle();
    expect(find.text('LỊCH SỬ'), findsOneWidget);
  });

  testWidgets('Premium chưa biết hạn: chỉ "Premium", không "còn"', (tester) async {
    final kho = InMemoryGoiStore();
    final repo = GoiRepository(api: _ApiGia(), kho: kho, clock: () => now);
    await repo.datTaiKhoan(11, loaiPhien: 'Premium');
    final cubit = GoiCubit(repo, clock: () => now);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });
    await tester.pumpWidget(BlocProvider<GoiCubit>.value(
      value: cubit,
      child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: NangCapPage(
              repo: DonThanhToanRepositoryImpl(api: _ApiGia(), clock: () => now),
              goi: cubit,
              suKien: const Stream.empty(),
              clock: () => now)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsWidgets);
    expect(find.textContaining('còn '), findsNothing);
  });

  testWidgets('Thanh toán: tạo đơn → sang Đang chờ với extra; bấm đôi chỉ MỘT đơn',
      (tester) async {
    final api = _ApiGia()..treo = Completer<void>();
    await dung(tester, premium: false, api: api);
    await tester.tap(find.text('Thanh toán'));
    await tester.pump();
    // Trong lúc chờ, nút hiện vòng xoay thay chữ và bị khoá — bấm theo key.
    await tester.tap(find.byKey(const Key('nang-cap-thanh-toan')),
        warnIfMissed: false);
    await tester.pump();
    expect(api.soLanTao, 1, reason: 'bấm đôi không được tạo hai đơn');
    api.treo!.complete();
    await tester.pumpAndSettle();
    expect(find.text('CHỜ 200370869'), findsOneWidget);
  });

  testWidgets('tạo đơn hỏng: toast câu ngắn, ở lại màn, nút mở lại',
      (tester) async {
    final bat = batThongBao();
    final api = _ApiGia()..nem = true;
    await dung(tester, premium: false, api: api);
    await tester.tap(find.text('Thanh toán'));
    await tester.pumpAndSettle();
    expect(bat.cau, ['Máy chủ chưa phản hồi. Thử lại sau.']);
    expect(bat.cuoi!.loai, LoaiThongBao.loi);
    expect(find.text('Gói hiện tại: Basic'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Thanh toán'))
            .enabled,
        isTrue);
  });

  testWidgets('360 × 640 cả hai trạng thái không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await dung(tester, premium: false, tran: LoaiTran.nganSach);
    expect(tester.takeException(), isNull);
    await dung(tester, premium: true);
    expect(tester.takeException(), isNull);
  });

  // ── Đơn cần xử lý (spec G94 2026-10-18 mục 5.7; Stitch `5c629d0a…`) ──────────

  ButtonStyleButton nutThanhToan(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(find.byKey(const Key('nang-cap-thanh-toan')));

  testWidgets('1 đơn chờ xác nhận → thẻ nổi đầu màn + KHOÁ Thanh toán kèm lý do; chạm thẻ → Chi tiết đơn đó',
      (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(5, 'WAITING_CONFIRMATION'), _don(4, 'PAID')];
    await dung(tester, premium: false, api: api);
    expect(find.text('Bạn đã chuyển thừa cho đơn #5'), findsOneWidget);
    expect(find.text('Xác nhận để kích hoạt gói hoặc yêu cầu hoàn tiền'), findsOneWidget);
    expect(nutThanhToan(tester).onPressed, isNull, reason: 'khoản thừa còn chờ dùng — tạo đơn mới là trả lần hai');
    expect(find.byKey(const Key('nang-cap-ly-do-khoa')), findsOneWidget);
    expect(find.text('Xác nhận đơn chuyển thừa trước khi tạo đơn mới'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('nang-cap-the-cho-xac-nhan'))).dy,
        lessThan(tester.getTopLeft(find.text('Gói hiện tại: Basic')).dy),
        reason: 'thẻ đứng ĐẦU màn, trên thẻ gói');
    await tester.tap(find.byKey(const Key('nang-cap-the-cho-xac-nhan')));
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT 5'), findsOneWidget);
  });

  testWidgets('Premium có đơn chờ xác nhận → Gia hạn cũng khoá', (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(5, 'WAITING_CONFIRMATION')];
    await dung(tester, premium: true, api: api);
    expect(find.widgetWithText(ElevatedButton, 'Gia hạn thêm 30 ngày'), findsOneWidget);
    expect(nutThanhToan(tester).onPressed, isNull);
  });

  testWidgets('2 đơn chờ xác nhận → "Bạn có 2 đơn…"; chạm → Lịch sử mua', (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(5, 'WAITING_CONFIRMATION'), _don(7, 'WAITING_CONFIRMATION')];
    await dung(tester, premium: false, api: api);
    expect(find.text('Bạn có 2 đơn chuyển thừa chờ xác nhận'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nang-cap-the-cho-xac-nhan')));
    await tester.pumpAndSettle();
    expect(find.text('LỊCH SỬ'), findsOneWidget);
  });

  testWidgets('đơn chờ hoàn tiền → thẻ nhỏ, KHÔNG khoá (chuyển thiếu vẫn mua lại được); chạm → Chi tiết đơn',
      (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(6, 'REFUND_PENDING'), _don(3, 'REFUNDED')];
    await dung(tester, premium: false, api: api);
    expect(find.text('Đơn #6 đang chờ hoàn tiền'), findsOneWidget);
    expect(find.byKey(const Key('nang-cap-the-cho-xac-nhan')), findsNothing);
    expect(nutThanhToan(tester).onPressed, isNotNull);
    expect(find.byKey(const Key('nang-cap-ly-do-khoa')), findsNothing);
    await tester.tap(find.byKey(const Key('nang-cap-the-cho-hoan-tien')));
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT 6'), findsOneWidget);
  });

  testWidgets('2 đơn chờ hoàn tiền → "2 đơn đang chờ hoàn tiền"', (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(6, 'REFUND_PENDING'), _don(8, 'REFUND_PENDING')];
    await dung(tester, premium: false, api: api);
    expect(find.text('2 đơn đang chờ hoàn tiền'), findsOneWidget);
  });

  testWidgets('lịch sử hỏng → không thẻ, nút MỞ (không chặn mua vì mạng)', (tester) async {
    final api = _ApiGia(); // lichSuItems null → ném
    await dung(tester, premium: false, api: api);
    expect(api.soLanLichSu, 1, reason: 'mở màn là đọc lịch sử');
    expect(find.byKey(const Key('nang-cap-the-cho-xac-nhan')), findsNothing);
    expect(find.byKey(const Key('nang-cap-the-cho-hoan-tien')), findsNothing);
    expect(nutThanhToan(tester).onPressed, isNotNull);
  });

  testWidgets('tín hiệu donThanhToanDoi → đọc lại: đơn vừa sang chờ xác nhận thì thẻ hiện + khoá', (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(5, 'PENDING')];
    await dung(tester, premium: false, api: api);
    expect(nutThanhToan(tester).onPressed, isNotNull);
    api.lichSuItems = [_don(5, 'WAITING_CONFIRMATION')];
    suKien.add(RealtimeEvent.donThanhToanDoi);
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 2);
    expect(find.text('Bạn đã chuyển thừa cho đơn #5'), findsOneWidget);
    expect(nutThanhToan(tester).onPressed, isNull);
    suKien.add(RealtimeEvent.dongBoXong);
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 2, reason: 'sự kiện khác không đọc lại');
  });

  testWidgets('quay về từ Chi tiết đơn (vừa xác nhận) → đọc lại: thẻ mất, nút mở lại', (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(5, 'WAITING_CONFIRMATION')];
    final router = await dung(tester, premium: false, api: api);
    await tester.tap(find.byKey(const Key('nang-cap-the-cho-xac-nhan')));
    await tester.pumpAndSettle();
    api.lichSuItems = [_don(5, 'PAID')];
    router.pop();
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 2);
    expect(find.byKey(const Key('nang-cap-the-cho-xac-nhan')), findsNothing);
    expect(nutThanhToan(tester).onPressed, isNotNull);
  });

  testWidgets('⭐ đường chính: Thanh toán → màn Chờ THAY bằng Chi tiết đơn → Đồng ý → về Nâng cấp: đọc lại SAU khi về, thẻ mất, nút mở',
      (tester) async {
    final api = _ApiGia()..lichSuItems = const [];
    final router = await dung(tester, premium: false, api: api, choThayNgay: true);
    await tester.tap(find.byKey(const Key('nang-cap-thanh-toan')));
    // Người dùng chuyển thừa trong lúc ở màn Chờ → server: đơn chờ xác nhận.
    api.lichSuItems = [_don(200370869, 'WAITING_CONFIRMATION')];
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT 200370869'), findsOneWidget, reason: 'màn Chờ đã tự thay bằng Chi tiết đơn');

    // Ở Chi tiết đơn người dùng bấm Đồng ý → server PAID (chỉ phát account.upgraded — Nâng cấp đang bị che).
    api.lichSuItems = [_don(200370869, 'PAID')];
    final truocKhiVe = api.soLanLichSu;
    router.pop();
    // Không `pumpAndSettle`: bản lỗi để nút Thanh toán quay mãi → treo thay vì đỏ.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Gói hiện tại: Basic'), findsOneWidget, reason: 'đã về Nâng cấp');
    expect(
        find.descendant(
            of: find.byKey(const Key('nang-cap-thanh-toan')), matching: find.byType(CircularProgressIndicator)),
        findsNothing,
        reason: 'future của `push` tới màn Chờ (đã bị thay) không về — nút từng quay mãi khi người dùng quay lại');
    expect(api.soLanLichSu, greaterThan(truocKhiVe),
        reason: '`push` tới màn Chờ bị `pushReplacement` — future của nó không gắn với lúc người dùng thật sự quay về');
    expect(find.byKey(const Key('nang-cap-the-cho-xac-nhan')), findsNothing);
    expect(nutThanhToan(tester).onPressed, isNotNull, reason: 'đơn đã kích hoạt — khoá với lý do sai là chặn gia hạn');
  });

  testWidgets('đường chính với Từ chối: về Nâng cấp → thẻ chờ xác nhận thành thẻ chờ hoàn tiền, nút mở', (tester) async {
    final api = _ApiGia()..lichSuItems = const [];
    final router = await dung(tester, premium: false, api: api, choThayNgay: true);
    await tester.tap(find.byKey(const Key('nang-cap-thanh-toan')));
    api.lichSuItems = [_don(200370869, 'WAITING_CONFIRMATION')];
    await tester.pumpAndSettle();
    expect(find.text('CHI TIẾT 200370869'), findsOneWidget);
    // Từ chối → server REFUND_PENDING, KHÔNG phát sự kiện nào.
    api.lichSuItems = [_don(200370869, 'REFUND_PENDING')];
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('nang-cap-the-cho-xac-nhan')), findsNothing);
    expect(find.text('Đơn #200370869 đang chờ hoàn tiền'), findsOneWidget);
    expect(nutThanhToan(tester).onPressed, isNotNull);
  });

  testWidgets('tín hiệu taiKhoanNangCap (Đồng ý ở máy khác → server phát account.upgraded) → đọc lại', (tester) async {
    final api = _ApiGia()..lichSuItems = [_don(5, 'WAITING_CONFIRMATION')];
    await dung(tester, premium: false, api: api);
    expect(nutThanhToan(tester).onPressed, isNull);
    api.lichSuItems = [_don(5, 'PAID')];
    suKien.add(RealtimeEvent.taiKhoanNangCap);
    await tester.pumpAndSettle();
    expect(api.soLanLichSu, 2);
    expect(nutThanhToan(tester).onPressed, isNotNull);
  });

  for (final rong in const [360.0, 320.0]) {
    testWidgets('$rong × 640 có cả hai thẻ + dòng khoá không tràn', (tester) async {
      tester.view.physicalSize = Size(rong, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiGia()..lichSuItems = [_don(200370869, 'WAITING_CONFIRMATION'), _don(200370870, 'REFUND_PENDING')];
      await dung(tester, premium: false, tran: LoaiTran.vi, api: api);
      expect(find.byKey(const Key('nang-cap-the-cho-xac-nhan')), findsOneWidget);
      expect(find.byKey(const Key('nang-cap-the-cho-hoan-tien')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
