/// G68 (2026-10-06) — thanh điều hướng dưới không được tràn ở màn HẸP hay chữ LỚN.
///
/// Nghiệm thu Realme 2026-10-06: người dùng nâng cỡ chữ/hiển thị ColorOS một–hai
/// nấc thì thanh dưới hiện sọc *"RIGHT OVERFLOWED BY 40 PIXELS"* và tab **Cá
/// nhân** bị đẩy khỏi màn ở mọi trang. Gốc: hàng là năm ô rộng CỐ ĐỊNH 72 dp
/// (bốn tab + chỗ trống cho nút +) — cộng lại **đúng 360 dp**, nên vừa khít ở
/// khổ thường và tràn ngay khi màn hẹp hơn. ColorOS phóng *cỡ hiển thị* bằng
/// cách đổi mật độ điểm ảnh (`font_scale` vẫn đọc 1.0): 480 → 540 dpi đưa
/// 1080 px còn **320 dp** — thiếu đúng 40 px.
///
/// Đo bằng font thật (`font_that.dart`) vì Ahem rộng gấp đôi chữ thật.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/shared/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/font_that.dart';

const _nhan = ['Trang chủ', 'Phân tích', 'Giao dịch', 'Cá nhân'];

void main() {
  setUp(() => sl.registerSingleton<ThongBaoNhanh>(ThongBaoNhanh()));
  tearDown(() async => sl.reset());

  Future<void> dung(WidgetTester tester, double rong, double coChu) async {
    await napFontThat();
    tester.view.physicalSize = Size(rong * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = coChu;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    GoRoute trang(String p) => GoRoute(
        path: p, builder: (_, __) => const Scaffold(body: SizedBox()));
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => MainShell(navigationShell: shell),
          branches: [
            for (final p in ['/a', '/b', '/c', '/d'])
              StatefulShellBranch(routes: [trang(p)]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(fontFamily: 'Inter_regular'),
    ));
    await tester.pump();
  }

  for (final (rong, coChu) in [
    (360.0, 1.0),
    (320.0, 1.0), // ColorOS phóng cỡ hiển thị một nấc (540 dpi)
    (300.0, 1.0),
    (360.0, 1.3),
    (360.0, 1.5),
    (320.0, 1.3), // cả hai cùng nâng
  ]) {
    testWidgets('$rong dp, chữ ×$coChu: không tràn, đủ bốn tab trong màn',
        (tester) async {
      await dung(tester, rong, coChu);
      expect(tester.takeException(), isNull,
          reason: 'thanh dưới không được tràn (G68)');
      for (final n in _nhan) {
        final f = find.text(n);
        expect(f, findsOneWidget, reason: 'tab "$n" phải còn trên thanh');
        final r = tester.getRect(f);
        expect(r.left, greaterThanOrEqualTo(0), reason: '"$n" lọt mép trái');
        expect(r.right, lessThanOrEqualTo(rong),
            reason: '"$n" bị đẩy khỏi mép phải màn (G68)');
      }
      // Nút + vẫn ở giữa, không chồng lên tab nào.
      final cong = tester.getRect(find.byType(FloatingActionButton));
      for (final n in _nhan) {
        expect(tester.getRect(find.text(n)).overlaps(cong), isFalse,
            reason: 'nhãn "$n" chồng lên nút +');
      }
    });
  }

  // Realme 320 dp × cỡ chữ 1,6 (2026-10-26): mỗi nhãn một `FittedBox` riêng nên nhãn ngắn ("Cá nhân") giữ cỡ còn nhãn dài
  // ("Trang chủ" đậm vì đang chọn) co — bốn nhãn lệch cỡ. Bốn ô bằng nhau thì bốn nhãn phải co CÙNG hệ số, kể cả nhãn đậm.
  for (final (rong, coChu) in [(320.0, 1.76), (360.0, 1.5)]) {
    testWidgets('$rong dp, chữ ×$coChu: bốn nhãn CÙNG cỡ vẽ (nhãn đang chọn đậm cũng vậy)', (tester) async {
      await dung(tester, rong, coChu);
      expect(tester.takeException(), isNull);
      final cao = [for (final n in _nhan) tester.getRect(find.text(n)).height];
      for (final h in cao) {
        expect((h - cao.first).abs(), lessThan(0.3),
            reason: 'bốn nhãn lệch cỡ: ${cao.map((h) => h.toStringAsFixed(1)).join(' / ')}');
      }
    });
  }
}
