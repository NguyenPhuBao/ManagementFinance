/// B1 (spec 2026-10-27 mục 3) — quyền `in_app_calculator`: hai phím + / − mờ, không báo phím; phím số vẫn gõ.
library;

import 'package:flowmoney/features/transaction/presentation/widgets/them_giao_dich/ban_phim_so.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String>> go(WidgetTester t, {required bool choPhepTinh}) async {
    final phim = <String>[];
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BanPhimSo(isSubmitting: false, onKey: phim.add, onLuu: () {}, choPhepTinh: choPhepTinh),
      ),
    ));
    for (final k in ['1', '+', '−', '2']) {
      await t.tap(find.text(k));
    }
    await t.pump();
    return phim;
  }

  testWidgets('có quyền → bốn phím đều báo', (t) async {
    expect(await go(t, choPhepTinh: true), ['1', '+', '-', '2']);
  });

  testWidgets('⭐ không quyền → + / − không báo, phím số vẫn báo', (t) async {
    expect(await go(t, choPhepTinh: false), ['1', '2']);
  });
}
