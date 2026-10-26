/// Hàng *GIAO DỊCH GẦN ĐÂY · Xem tất cả* ở khổ hẹp + cỡ chữ lớn — Realme 320 dp, cỡ chữ 1,6 (lượt đo lại bản `626c6060`,
/// 2026-10-26): nút *Xem tất cả* bị cắt mép phải (bản release không vẽ sọc vàng, chỉ thấy nút cụt). ×1,76 ≈ Inter ở 1,6
/// (Roboto hẹp hơn). ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/home/presentation/widgets/tieu_de_giao_dich_gan_day.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  Future<void> dung(WidgetTester t, double rong, double co) async {
    t.view.physicalSize = Size(rong, 800);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      // Lề ngang 24 = lề thật của Trang chủ (`home_page.dart`).
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TieuDeGiaoDichGanDay(onXemTatCa: () {}),
        ),
      ),
    ));
    await t.pump();
  }

  for (final rong in [320.0, 360.0]) {
    testWidgets('$rong dp × 1,76: nút "Xem tất cả" nằm trọn trong lề, một dòng; tiêu đề không đè lên nút', (t) async {
      await dung(t, rong, 1.76);
      expect(t.takeException(), isNull, reason: 'Realme: nút "Xem tất cả" bị cắt mép phải');
      final nut = t.getRect(find.byType(TextButton));
      expect(nut.right, lessThanOrEqualTo(rong - 24 + 0.5), reason: 'nút tràn khỏi lề phải');
      final chuNut = t.renderObject<RenderParagraph>(find.text('Xem tất cả'));
      expect(chuNut.didExceedMaxLines, isFalse);
      expect(chuNut.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(chuNut.size.width + 0.5),
          reason: 'chữ trong nút bị ép gọn — "Xem tất…"');
      final tieuDe = t.getRect(find.text('GIAO DỊCH GẦN ĐÂY'));
      expect(tieuDe.right, lessThanOrEqualTo(nut.left + 0.5), reason: 'tiêu đề đè lên nút');
      expect(tieuDe.left, closeTo(24, 0.5));
    });
  }

  testWidgets('411 dp × 1,1: tiêu đề một dòng, nút cùng hàng ở mép phải', (t) async {
    await dung(t, 411, 1.1);
    expect(t.takeException(), isNull);
    final tieuDe = find.text('GIAO DỊCH GẦN ĐÂY');
    final p = t.renderObject<RenderParagraph>(tieuDe);
    expect(p.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(p.size.width + 0.5), reason: 'đủ chỗ thì một dòng');
    expect(t.getRect(find.byType(TextButton)).right, closeTo(411 - 24, 0.5));
  });
}
