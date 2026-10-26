/// Thẻ tổng của Sổ giao dịch ở khổ hẹp + cỡ chữ lớn — Realme 320 dp, cỡ chữ 1,6 (buổi 4 `KHOA_APP_FEATURE.md`,
/// 2026-10-26): hai số *Chi tiêu* và *Thu net* dính nhau *"-310.000 đ-310.00"* và bị cắt ra ngoài thẻ. ×1,76 ≈ Inter ở
/// 1,6 (Roboto hẹp hơn). ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/transaction/presentation/widgets/the_tong_so_giao_dich.dart';
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

  Future<void> dung(WidgetTester t, double rong, double co, {double thu = 0, double chi = 310000}) async {
    t.view.physicalSize = Size(rong, 900);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: TheTongSoGiaoDich(totalIncome: thu, totalExpense: chi)),
    ));
    await t.pump();
  }

  for (final (rong, thu, chi, ba) in [
    (320.0, 0.0, 310000.0, ['0 đ', '-310.000 đ', '-310.000 đ']),
    (320.0, 12500000.0, 9875000.0, ['+12.500.000 đ', '-9.875.000 đ', '+2.625.000 đ']),
  ]) {
    testWidgets('$rong dp × 1,76, ${ba.join(' / ')}: ba số mỗi số một dòng, trong thẻ, không chồng nhau', (t) async {
      await dung(t, rong, 1.76, thu: thu, chi: chi);
      expect(t.takeException(), isNull);
      // Mép thẻ nhìn thấy = hộp widget trừ `margin` ngang 16.
      final hop = t.getRect(find.byType(TheTongSoGiaoDich)).deflate(16);
      final cacSo = find.byWidgetPredicate((w) => w is Text && ba.contains(w.data));
      expect(cacSo, findsNWidgets(3), reason: 'chữ trên thẻ không đổi: ${ba.join(' · ')}');
      final cacHop = [for (final e in cacSo.evaluate()) t.getRect(find.byWidget(e.widget))]..sort((a, b) => a.left.compareTo(b.left));
      for (final e in cacSo.evaluate()) {
        expect(soDong(t, find.byWidget(e.widget)), 1);
      }
      for (var i = 0; i < 3; i++) {
        expect(cacHop[i].left, greaterThanOrEqualTo(hop.left - 0.5), reason: 'số thứ ${i + 1} tràn mép trái thẻ');
        expect(cacHop[i].right, lessThanOrEqualTo(hop.right + 0.5), reason: 'số thứ ${i + 1} tràn mép phải thẻ');
        if (i > 0) {
          expect(cacHop[i].left, greaterThanOrEqualTo(cacHop[i - 1].right),
              reason: 'Realme: hai số dính nhau "-310.000 đ-310.00"');
        }
      }
    });
  }

  // Realme 320 dp × 1,6 (lượt đo lại 2026-10-26): "0 đ" to hơn hẳn hai số kia — mỗi cột một `FittedBox` riêng nên số
  // ngắn giữ cỡ, số dài co. Ba ô bằng nhau thì ba số (và ba nhãn) phải co CÙNG hệ số.
  testWidgets('320 dp × 1,76, kỳ chỉ có chi: ba số CÙNG cỡ vẽ, ba nhãn cùng cỡ vẽ', (t) async {
    await dung(t, 320, 1.76);
    final caoSo = [for (final e in find.byWidgetPredicate((w) => w is Text && (w.data ?? '').endsWith(' đ')).evaluate()) t.getRect(find.byWidget(e.widget)).height];
    expect(caoSo, hasLength(3));
    for (final h in caoSo) {
      expect((h - caoSo.first).abs(), lessThan(0.3),
          reason: 'Realme: "0 đ" to hơn "-310.000 đ" — cao ${caoSo.map((h) => h.toStringAsFixed(1)).join(' / ')}');
    }
    final caoNhan = [for (final n in ['Thu nhập', 'Chi tiêu', 'Thu net']) t.getRect(find.text(n)).height];
    for (final h in caoNhan) {
      expect((h - caoNhan.first).abs(), lessThan(0.3), reason: 'ba nhãn cao ${caoNhan.map((h) => h.toStringAsFixed(1)).join(' / ')}');
    }
  });

  testWidgets('411 dp × 1,1: ba số giữ nguyên cỡ (chỉ co khi chật)', (t) async {
    await dung(t, 411, 1.1);
    // Cỡ vẽ tự nhiên = chữ 14 đậm của theme ở cỡ chữ 1,1, đo bằng cùng họ chữ như `Text` (độc lập với cách thẻ co chữ).
    final ctx = t.element(find.byType(TheTongSoGiaoDich));
    final mau = TextPainter(
      text: TextSpan(
          text: '-310.000 đ',
          style: DefaultTextStyle.of(ctx).style.merge(const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
      textScaler: const TextScaler.linear(1.1),
      textDirection: TextDirection.ltr,
    )..layout();
    for (final e in find.text('-310.000 đ').evaluate()) {
      expect(t.getRect(find.byWidget(e.widget)).height, greaterThan(mau.height - 0.5), reason: 'đủ chỗ thì không co');
    }
    mau.dispose();
  });
}
