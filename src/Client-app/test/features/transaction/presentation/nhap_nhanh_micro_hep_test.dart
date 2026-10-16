// test/features/transaction/presentation/nhap_nhanh_micro_hep_test.dart
/// C4 — micro chen vào hàng [ô · Điền] của ô Nhập nhanh. Ở 320 dp hàng ấy vốn chật (G84); micro 36 dp không được làm tràn
/// hay đẩy mất nút Điền. ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/transaction/presentation/bloc/nghe_giong_noi_state.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  for (final tt in TrangThaiNghe.values) {
    testWidgets('320 dp, $tt: không tràn, micro + Điền đều hiện', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = TextEditingController();
      final f = FocusNode();
      addTearDown(c.dispose);
      addTearDown(f.dispose);
      await tester.pumpWidget(MaterialApp(
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
              trangThaiNghe: tt,
              giayGhi: 3,
              onMicro: () {},
              onHuyNghe: () {},
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('nhap-nhanh-micro')), findsOneWidget);
      expect(find.byKey(const Key('nhap-nhanh-dien')), findsOneWidget);
    });
  }
}
