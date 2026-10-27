/// B1 (spec 2026-10-27 mục 4, chốt 3) — ô Nhập nhanh khi `ai_quick_input` tạm ngừng: không nút Nâng cấp, câu tạm ngừng.
library;

import 'package:flowmoney/features/transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> dung(WidgetTester t, {required bool tamNgung}) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = TextEditingController();
    final f = FocusNode();
    addTearDown(c.dispose);
    addTearDown(f.dispose);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ONhapNhanh(
          controller: c,
          focusNode: f,
          laPremium: false,
          tamNgung: tamNgung,
          dangDocAi: false,
          ketQua: null,
          onDien: () {},
          onHuy: () {},
        ),
      ),
    ));
    await t.pump();
  }

  testWidgets('tiền đề: Basic (cần Premium) → nút Nâng cấp + "Nâng cấp để đọc câu bằng AI"', (t) async {
    await dung(t, tamNgung: false);
    expect(find.byKey(const Key('nut-nang-cap')), findsOneWidget);
    expect(find.text('Nâng cấp để đọc câu bằng AI'), findsOneWidget);
  });

  testWidgets('⭐ tạm ngừng → KHÔNG nút Nâng cấp, câu tạm ngừng', (t) async {
    await dung(t, tamNgung: true);
    expect(find.byKey(const Key('nut-nang-cap')), findsNothing);
    expect(find.text('Nhập nhanh bằng câu hiện đang tạm ngừng.'), findsOneWidget);
  });
}
