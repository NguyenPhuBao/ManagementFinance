/// Hàng tiêu đề *NHẬP NHANH* + chip *Giọng nói & Gõ* ở khổ hẹp + cỡ chữ lớn — Realme 320 dp, cỡ chữ 1,6 (buổi 4
/// `KHOA_APP_FEATURE.md`, 2026-10-26): chip tràn ra ngoài mép thẻ. ×1,76 ≈ Inter ở 1,6 (Roboto hẹp hơn).
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/transaction/presentation/bloc/nghe_giong_noi_state.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  Future<void> dung(WidgetTester t, double rong, double co) async {
    t.view.physicalSize = Size(rong, 900);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = TextEditingController();
    final f = FocusNode();
    addTearDown(c.dispose);
    addTearDown(f.dispose);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ONhapNhanh(
            controller: c,
            focusNode: f,
            laPremium: true,
            dangDocAi: false,
            ketQua: null,
            onDien: () {},
            onHuy: () {},
            coMicro: true,
            trangThaiNghe: TrangThaiNghe.cho,
            giayGhi: 0,
            onMicro: () {},
            onHuyNghe: () {},
          ),
        ),
      ),
    ));
    await t.pump();
  }

  final chip = find.text('Giọng nói & Gõ');
  final tieuDe = find.text('NHẬP NHANH');

  for (final rong in [320.0, 360.0]) {
    testWidgets('$rong dp × 1,76: chip "Giọng nói & Gõ" nằm trong thẻ', (t) async {
      await dung(t, rong, 1.76);
      expect(t.takeException(), isNull);
      expect(t.getRect(chip).right, lessThanOrEqualTo(t.getRect(find.byType(ONhapNhanh)).right + 0.5),
          reason: 'Realme 320 dp × 1,6: chip tràn ra ngoài mép thẻ');
    });
  }

  testWidgets('411 dp × 1,1: chip vẫn cùng hàng với "NHẬP NHANH" (Stitch d696e81e)', (t) async {
    await dung(t, 411, 1.1);
    expect((t.getCenter(chip).dy - t.getCenter(tieuDe).dy).abs(), lessThan(4));
    // Chip có đệm ngang 6 quanh chữ; mép phải trong của thẻ = mép thẻ − đệm 16.
    expect(t.getRect(chip).right, closeTo(t.getRect(find.byType(ONhapNhanh)).right - 16 - 6, 1.5),
        reason: 'chip sát mép phải (như `Spacer` cũ) — `Wrap` không đủ bề rộng thẻ thì chip dính ngay sau "NHẬP NHANH"');
  });
}
