/// Đầu Trang chủ ở khổ hẹp + cỡ chữ lớn — Realme 320 dp, cỡ chữ 1,6 (buổi 4 `KHOA_APP_FEATURE.md`, 2026-10-26): chữ
/// *FlowMoney* đẩy chuông thông báo ra quá mép phải, chuông + *"99+"* bị cắt nửa. ×1,76 ≈ Inter ở 1,6 (Roboto hẹp hơn).
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/home/presentation/widgets/dau_trang_chu.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  const chuong = Key('chuong');

  Future<void> dung(WidgetTester t, double rong, double co) async {
    t.view.physicalSize = Size(rong, 800);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      // Lề ngang 24 = lề thật của Trang chủ (`home_page.dart`).
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: DauTrangChu(chuong: SizedBox(key: chuong, width: 48, height: 48)),
        ),
      ),
    ));
    await t.pump();
  }

  for (final rong in [320.0, 360.0]) {
    testWidgets('$rong dp × 1,76: chuông nằm trọn trong lề, chữ FlowMoney một dòng', (t) async {
      await dung(t, rong, 1.76);
      expect(t.takeException(), isNull);
      expect(t.getRect(find.byKey(chuong)).right, lessThanOrEqualTo(rong - 24 + 0.5),
          reason: 'chữ FlowMoney đẩy chuông ra quá mép — Realme cắt nửa chuông + "99+"');
      expect(t.getRect(find.text('FlowMoney')).right, lessThanOrEqualTo(t.getRect(find.byKey(chuong)).left + 0.5),
          reason: 'chữ không được đè lên chuông');
    });
  }

  testWidgets('411 dp × 1,1: chữ FlowMoney giữ nguyên cỡ (chỉ co khi chật)', (t) async {
    await dung(t, 411, 1.1);
    expect(t.getRect(find.text('FlowMoney')).width / t.getSize(find.text('FlowMoney')).width, greaterThan(0.99));
  });
}
