// test/features/home/presentation/widgets/hang_nut_nhanh_kieu_test.dart
/// Kiểu dáng hàng nút nhanh theo màn Stitch `c8f09f19…` *"Trang chủ - Năm nút nhanh có Nói"* — người dùng chốt
/// 2026-10-16 cho app theo Stitch (lệch ghi ở mục 8 `GIONG_NOI_FEATURE.md`): nút đậm nền ĐẶC `#1A1A19` (không
/// gradient), nút trắng viền `#D5D5CE`, nhãn cách vòng 6 dp. Tách khỏi `hang_nut_nhanh_test.dart` vì tệp ấy nạp font
/// thật cho cả isolate.
library;

import 'package:flowmoney/features/home/presentation/widgets/hang_nut_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> dung(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: HangNutNhanh(nut: [
          NutNhanh(bieuTuong: Icons.arrow_upward, nhan: 'Thêm chi', dam: true, onTap: () {}, khoa: const Key('dam')),
          NutNhanh(bieuTuong: Icons.mic, nhan: 'Nói', dam: false, onTap: () {}, khoa: const Key('trang')),
        ]),
      ),
    ));
  }

  BoxDecoration vong(WidgetTester tester, String khoa) => tester
      .widget<Container>(find.descendant(of: find.byKey(Key(khoa)), matching: find.byType(Container)).first)
      .decoration! as BoxDecoration;

  testWidgets('nút đậm: nền đặc #1A1A19, không gradient, có bóng', (tester) async {
    await dung(tester);
    final d = vong(tester, 'dam');
    expect(d.gradient, isNull, reason: 'Stitch vẽ bg-[#1A1A19] đặc; gradient #1A1A19 → #374151 là kiểu cũ của app.');
    expect(d.color, const Color(0xFF1A1A19));
    expect(d.boxShadow, isNotEmpty, reason: 'Stitch: shadow-md.');
  });

  testWidgets('nút trắng: viền #D5D5CE, có bóng nhẹ', (tester) async {
    await dung(tester);
    final d = vong(tester, 'trang');
    expect(d.color, Colors.white);
    expect((d.border! as Border).top.color, const Color(0xFFD5D5CE),
        reason: 'Stitch: border-[#D5D5CE]; Colors.black12 cũ là một màu khác.');
    expect(d.boxShadow, isNotEmpty, reason: 'Stitch: shadow-sm.');
  });

  testWidgets('nhãn cách vòng 6 dp (Stitch mt-1.5)', (tester) async {
    await dung(tester);
    final dayVong = tester.getBottomLeft(
        find.descendant(of: find.byKey(const Key('trang')), matching: find.byType(Container)).first).dy;
    final dinhNhan = tester.getTopLeft(find.text('Nói')).dy;
    expect(dinhNhan - dayVong, closeTo(6, 0.01), reason: 'Bản cũ cách 10 dp; Stitch mt-1.5 = 6 dp.');
  });
}
