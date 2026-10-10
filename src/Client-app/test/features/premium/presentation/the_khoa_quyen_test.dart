import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/cubit/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/widgets/the_khoa_quyen.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/font_that.dart';

class _ApiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
}

/// Ba dạng khoá theo quyền — spec phân quyền 2026-10-08 mục 4.3 (2), Stitch `595529bf…` · `68593384…`.
void main() {
  final now = DateTime(2026, 10, 8, 12);

  Future<GoiCubit> goi(Map<String, bool> q) async {
    final repo = GoiRepository(api: _ApiIm(), kho: InMemoryGoiStore(), clock: () => now);
    final cubit = GoiCubit(repo, clock: () => now);
    cubit.emit(TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: now, quyenTinhNang: q));
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });
    return cubit;
  }

  Future<void> dung(WidgetTester tester, Widget con, {GoiCubit? cubit, double rong = 411}) async {
    tester.view.physicalSize = Size(rong * 3, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: con))),
      GoRoute(
          path: '/premium',
          builder: (_, s) => Scaffold(body: Text('NÂNG CẤP ${s.uri.queryParameters['quyen']}'))),
    ]);
    addTearDown(router.dispose);
    final app = MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router);
    await tester.pumpWidget(cubit == null ? app : BlocProvider<GoiCubit>.value(value: cubit, child: app));
    await tester.pumpAndSettle();
  }

  testWidgets('KhoaTheoQuyen: có quyền → nội dung; không quyền → thẻ khoá', (tester) async {
    final cubit = await goi(const {'cashflow_forecast': false});
    await dung(
        tester,
        const Column(children: [
          KhoaTheoQuyen(ma: MaQuyen.cashflowForecast, child: Text('BIỂU ĐỒ DỰ BÁO')),
          KhoaTheoQuyen(ma: MaQuyen.exportReports, child: Text('XUẤT')),
        ]),
        cubit: cubit);
    expect(find.text('BIỂU ĐỒ DỰ BÁO'), findsNothing);
    expect(find.byKey(const Key('the-khoa-cashflow_forecast')), findsOneWidget);
    expect(find.text('Dự báo 30 ngày tới'), findsOneWidget);
    expect(find.text('Dành cho Premium'), findsOneWidget);
    expect(find.text('XUẤT'), findsOneWidget, reason: 'thiếu khoá = mở');
  });

  testWidgets('không có GoiCubit → nội dung (quy ước Premium: không provider = không khoá)', (tester) async {
    await dung(tester, const KhoaTheoQuyen(ma: MaQuyen.cashflowForecast, child: Text('BIỂU ĐỒ DỰ BÁO')));
    expect(find.text('BIỂU ĐỒ DỰ BÁO'), findsOneWidget);
  });

  testWidgets('chạm Nâng cấp ở thẻ khoá → /premium?quyen=…', (tester) async {
    final cubit = await goi(const {'cashflow_forecast': false});
    await dung(tester, const KhoaTheoQuyen(ma: MaQuyen.cashflowForecast, child: SizedBox()), cubit: cubit);
    await tester.tap(find.byKey(const Key('nut-nang-cap')));
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP cashflow_forecast'), findsOneWidget);
  });

  testWidgets('DongKhoaCongTac: hai câu theo giá trị đang lưu; chạm → Nâng cấp', (tester) async {
    await dung(
        tester,
        const Column(children: [
          DongKhoaCongTac(ma: MaQuyen.billAutoPay, dangBat: false),
          DongKhoaCongTac(ma: MaQuyen.goalAutoDeposit, dangBat: true),
        ]));
    expect(find.text('Cần Premium'), findsOneWidget);
    expect(find.text('Tạm dừng — cần Premium'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nut-nang-cap')).last);
    await tester.pumpAndSettle();
    expect(find.text('NÂNG CẤP goal_auto_deposit'), findsOneWidget);
  });

  for (final rong in [360.0, 320.0]) {
    testWidgets('${rong.toInt()} dp, font thật: tên dài nhất và câu dòng khoá không cắt, không tràn', (tester) async {
      await napFontThat();
      final cubit = await goi(const {'smart_budget_rebalancing': false});
      await dung(
          tester,
          const Column(children: [
            KhoaTheoQuyen(ma: MaQuyen.smartBudgetRebalancing, child: SizedBox()),
            SizedBox(height: 8),
            DongKhoaQuyen(
                ma: MaQuyen.anomalySpendingInsights,
                cau: 'Có khoản chi bất thường kỳ này — dành cho Premium'),
            DongKhoaCongTac(ma: MaQuyen.billAutoPay, dangBat: true),
          ]),
          cubit: cubit,
          rong: rong);
      expect(tester.takeException(), isNull);
      for (final t in [
        'Đề xuất cân đối ngân sách',
        'Có khoản chi bất thường kỳ này — dành cho Premium',
        'Tạm dừng — cần Premium',
      ]) {
        final r = tester.renderObject<RenderParagraph>(find.text(t));
        expect(r.didExceedMaxLines, isFalse, reason: t);
        expect(r.size.width, lessThanOrEqualTo(rong), reason: t);
      }
    });
  }
}
