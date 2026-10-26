/// Thẻ *Tổng số dư ví* ở khổ hẹp + cỡ chữ lớn — Realme 320 dp, cỡ chữ 1,6 (buổi 4 `KHOA_APP_FEATURE.md`, 2026-10-26):
/// con số *-3.256.000 đ* gãy GIỮA chữ số (*"-3.256.0"* / *"00 đ"*), chip *Số dư thực tế* tràn ra ngoài thẻ và mép màn.
/// ×1,76 ≈ Inter ở 1,6 (Roboto hẹp hơn). Không sọc vàng nào ở bản release — đo số dòng và mép hộp.
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/home/presentation/widgets/the_tong_so_du.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  int soDong(WidgetTester t, Finder f) {
    final p = t.renderObject<RenderParagraph>(f);
    final dai = p.text.toPlainText().length;
    return p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: dai)).map((b) => b.top.round()).toSet().length;
  }

  Future<void> dung(WidgetTester t, double rong, double co, double tong) async {
    t.view.physicalSize = Size(rong, 900);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: TheTongSoDu(tongSoDu: tong)),
      ),
    ));
    await t.pump();
  }

  Finder so(String chu) => find.text(chu);
  final chip = find.text('Số dư thực tế');
  final tieuDe = find.text('Tổng số dư ví');

  for (final (rong, tong, chu) in [
    (320.0, -3256000.0, '-3.256.000 đ'),
    (360.0, -3256000.0, '-3.256.000 đ'),
    (320.0, 9999999999999.0, '9.999.999.999.999 đ'),
  ]) {
    testWidgets('$rong dp × 1,76, $chu: số một dòng trong thẻ, chip trong thẻ', (t) async {
      await dung(t, rong, 1.76, tong);
      expect(t.takeException(), isNull);
      final the = t.getRect(find.byType(TheTongSoDu));
      expect(soDong(t, so(chu)), 1, reason: 'Realme: con số gãy giữa chữ số "-3.256.0" / "00 đ"');
      expect(t.getRect(so(chu)).right, lessThanOrEqualTo(the.right - 24 + 0.5), reason: 'con số vượt mép trong của thẻ');
      expect(t.getRect(chip).right, lessThanOrEqualTo(the.right + 0.5), reason: 'chip "Số dư thực tế" tràn ra ngoài thẻ');
    });
  }

  testWidgets('411 dp × 1,1: chip cùng hàng với tiêu đề, con số giữ nguyên cỡ (đúng Stitch)', (t) async {
    await dung(t, 411, 1.1, -3256000);
    expect((t.getCenter(chip).dy - t.getCenter(tieuDe).dy).abs(), lessThan(4),
        reason: 'còn chỗ thì chip đứng bên phải tiêu đề — xuống dòng chỉ là đường lùi khi chật');
    // Chữ trong chip cách mép chip 12 (đệm ngang); mép phải trong của thẻ = mép thẻ − đệm 24.
    expect(t.getRect(chip).right, closeTo(t.getRect(find.byType(TheTongSoDu)).right - 24 - 12, 1.5),
        reason: 'chip sát mép phải trong của thẻ (Stitch) — `Wrap` không đủ bề rộng thẻ thì chip dính ngay sau tiêu đề');
    expect(t.getRect(so('-3.256.000 đ')).width / t.getSize(so('-3.256.000 đ')).width, greaterThan(0.99),
        reason: 'con số chỉ co khi không vừa');
  });
}
