/// Khung chờ của trang Phân tích (E1 lượt UX, 2026-10-06): lúc đang tải, trang
/// vẽ hình dạng các khối đầu bằng thanh xám thay vì một vòng xoay giữa khoảng
/// trống — thứ người dùng thấy mỗi lần mở tab (ảnh `05_analytics.png`).
library;

import 'package:flowmoney/features/analytics/presentation/widgets/khung_cho_phan_tich.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> dung(WidgetTester tester, double rong) async {
    tester.view.physicalSize = Size(rong, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: KhungChoPhanTich(),
        ),
      ),
    ));
  }

  for (final rong in [360.0, 411.0]) {
    testWidgets('$rong dp: dựng không tràn, không chữ, không số', (tester) async {
      await dung(tester, rong);
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsNothing,
          reason: 'khung chờ không được hiện một chữ / con số giả nào');
    });
  }

  testWidgets('đứng yên — không hoạt ảnh lặp (pumpAndSettle của trang không treo)', (tester) async {
    await dung(tester, 411);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('trình đọc màn hình nghe "Đang tải số liệu", không nghe từng thanh', (tester) async {
    final h = tester.ensureSemantics();
    await dung(tester, 411);
    expect(find.bySemanticsLabel('Đang tải số liệu'), findsOneWidget);
    h.dispose();
  });
}
