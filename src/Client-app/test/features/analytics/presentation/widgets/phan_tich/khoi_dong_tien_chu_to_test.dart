/// Nhãn *SỐ DƯ ĐẦU KỲ* / *SỐ DƯ CUỐI KỲ* ở khổ hẹp + cỡ chữ lớn — Realme 320 dp, cỡ chữ 1,6 (buổi 4
/// `KHOA_APP_FEATURE.md`, 2026-10-26): nhãn một dòng + dấu ba chấm thành *"SỐ DƯ ĐẦ…"* / *"SỐ DƯ CU…"* — mất đúng chữ phân
/// biệt hai cột. Cùng bố cục ở trang Phân tích (`KhoiDongTien`) và Xem trước báo cáo (`KhoiDongTienBaoCao`) — một tệp đo
/// cả hai. ×1,76 ≈ Inter ở 1,6 (Roboto hẹp hơn). ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/presentation/widgets/phan_tich/khoi_dong_tien.dart';
import 'package:flowmoney/features/analytics/presentation/widgets/xem_truoc_bao_cao/khoi_dong_tien_bao_cao.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  const dt = DongTien(dauKy: -2946000, cuoiKy: -3256000);
  const nhan = ['SỐ DƯ ĐẦU KỲ', 'SỐ DƯ CUỐI KỲ'];

  int soDong(WidgetTester t, Finder f) {
    final p = t.renderObject<RenderParagraph>(f);
    final dai = p.text.toPlainText().length;
    return p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: dai)).map((b) => b.top.round()).toSet().length;
  }

  Future<void> dung(WidgetTester t, Widget khoi, double rong, double co) async {
    t.view.physicalSize = Size(rong, 900);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: khoi)),
    ));
    await t.pump();
  }

  for (final (ten, khoi) in [
    ('Phân tích', const KhoiDongTien(dt: dt) as Widget),
    ('Xem trước báo cáo', const KhoiDongTienBaoCao(dt)),
  ]) {
    testWidgets('$ten · 320 dp × 1,76: hai nhãn số dư hiện ĐỦ chữ (xuống dòng, không cắt)', (t) async {
      await dung(t, khoi, 320, 1.76);
      expect(t.takeException(), isNull);
      for (final n in nhan) {
        expect(find.text(n), findsOneWidget);
        expect(t.renderObject<RenderParagraph>(find.text(n)).didExceedMaxLines, isFalse,
            reason: 'Realme: "$n" thành "${n.substring(0, 8)}…"');
      }
    });

    testWidgets('$ten · 411 dp × 1,1: nhãn vẫn một dòng (không đổi bố cục khi đủ chỗ)', (t) async {
      await dung(t, khoi, 411, 1.1);
      for (final n in nhan) {
        expect(soDong(t, find.text(n)), 1);
      }
    });
  }
}
