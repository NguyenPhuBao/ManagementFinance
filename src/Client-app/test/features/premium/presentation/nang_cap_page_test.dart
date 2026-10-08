/// Màn Nâng cấp `/premium` (spec Premium 2026-10-06 mục 9.1–9.2): Basic thấy
/// bốn đặc quyền + giá + Thanh toán (câu trần khi đến từ cửa chặn); Premium
/// thấy hạn + Gia hạn + Lịch sử mua. KHÔNG hứa "đồng bộ tức thì" (câu 4).
/// Bấm Thanh toán hai lần chỉ tạo MỘT đơn; tạo đơn hỏng thì ở lại màn.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/cubit/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/pages/nang_cap_page.dart';
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
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) =>
      throw UnimplementedError();
}

void main() {
  final now = DateTime(2026, 10, 6, 10);

  Future<GoiCubit> goi({required bool premium, DateTime? hetHan}) async {
    final kho = InMemoryGoiStore();
    if (premium) {
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
  }) async {
    final cubit = await goi(premium: premium, hetHan: hetHan);
    final router = GoRouter(initialLocation: '/premium', routes: [
      GoRoute(
        path: '/premium',
        builder: (_, __) => NangCapPage(
            tran: tran,
            quyen: quyen,
            api: api ?? _ApiGia(),
            goi: cubit,
            clock: () => now),
      ),
      GoRoute(
        path: '/premium/cho-thanh-toan',
        builder: (_, s) =>
            Scaffold(body: Text('CHỜ ${(s.extra as DonThanhToan).orderCode}')),
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

  testWidgets('?tran=vi: câu mở đầu nêu 3/3 ví', (tester) async {
    await dung(tester, premium: false, tran: LoaiTran.vi);
    expect(find.text('Bạn đã dùng 3/3 ví của gói Basic.'), findsOneWidget);
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
          home: NangCapPage(api: _ApiGia(), goi: cubit, clock: () => now)),
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
}
