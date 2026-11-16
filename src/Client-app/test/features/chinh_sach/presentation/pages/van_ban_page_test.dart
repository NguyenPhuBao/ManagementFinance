import 'package:flowmoney/features/chinh_sach/domain/van_ban.dart';
import 'package:flowmoney/features/chinh_sach/presentation/pages/danh_sach_van_ban_page.dart';
import 'package:flowmoney/features/chinh_sach/presentation/pages/van_ban_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> dung(WidgetTester t, Widget trang, {Size kho = const Size(411, 914)}) async {
    t.view.physicalSize = kho;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: trang));
    await t.pump();
  }

  test('dongPhienBan', () {
    expect(dongPhienBan(vanBanTheoMa('bao-mat')!), 'Phiên bản 1.0 · Có hiệu lực từ ngày 16/11/2026');
  });

  testWidgets('trang đọc: tiêu đề, dòng phiên bản, mọi tiêu đề mục có trong cây', (t) async {
    final v = vanBanTheoMa('bao-mat')!;
    await dung(t, const VanBanPage(ma: 'bao-mat'));
    expect(find.text(v.tieuDe), findsOneWidget);
    expect(find.text(dongPhienBan(v)), findsOneWidget);
    for (final m in v.muc) {
      await t.scrollUntilVisible(find.text(m.tieuDe), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text(m.tieuDe), findsOneWidget, reason: m.tieuDe);
    }
  });

  testWidgets('mã lạ → "Không tìm thấy văn bản", không đỏ màn', (t) async {
    await dung(t, const VanBanPage(ma: 'khong-co'));
    expect(find.text('Không tìm thấy văn bản'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('320 dp: hai văn bản, cuộn qua từng mục (dựng mọi gạch đầu dòng), không tràn', (t) async {
    for (final v in danhSachVanBan) {
      // Khoá riêng: không có nó trang thứ hai dùng lại vị trí cuộn (đang ở cuối) của trang trước.
      await dung(t, VanBanPage(key: ValueKey(v.ma), ma: v.ma), kho: const Size(320, 640));
      var soCham = 0;
      final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
      while (true) {
        soCham += find.text('•  ').evaluate().length;
        expect(t.takeException(), isNull, reason: '${v.ma} @ ${pos.pixels}');
        if (pos.pixels >= pos.maxScrollExtent) break;
        pos.jumpTo((pos.pixels + 200).clamp(0, pos.maxScrollExtent).toDouble());
        await t.pump();
      }
      // Ca tiền đề: lượt cuộn phải thật sự dựng gạch đầu dòng, không thì ca trên không canh gì (vấp 2026-11-16).
      expect(soCham, greaterThan(0), reason: v.ma);
    }
  });

  testWidgets('danh sách: hai dòng, bấm → /chinh-sach/<ma>', (t) async {
    final router = GoRouter(initialLocation: '/chinh-sach', routes: [
      GoRoute(path: '/chinh-sach', builder: (_, __) => const DanhSachVanBanPage()),
      GoRoute(path: '/chinh-sach/:ma', builder: (_, s) => VanBanPage(ma: s.pathParameters['ma'])),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await t.pump();
    expect(find.text('Điều khoản sử dụng'), findsOneWidget);
    expect(find.text('Chính sách bảo mật'), findsOneWidget);
    expect(find.text('Phiên bản 1.0 · 16/11/2026'), findsNWidgets(2));
    await t.tap(find.byKey(const Key('van-ban-dieu-khoan')));
    await t.pumpAndSettle();
    expect(find.text('Điều khoản sử dụng FlowMoney'), findsOneWidget);
  });
}
