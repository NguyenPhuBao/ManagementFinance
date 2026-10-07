/// G72 — ba thẻ Thu nhập / Chi tiêu / Thu net ở Trang chủ, màn HẸP (Realme để
/// cỡ hiển thị lớn: mật độ 540 → 320 dp).
///
/// Nghiệm thu 2026-10-06: ba thẻ **lệch chiều cao** — nhãn *"Thu nhập"* xuống
/// hai dòng, và mỗi số tiền tự co bằng `FittedBox` RIÊNG nên ba con số co theo
/// ba tỉ lệ khác nhau. Sửa: đo một lần cho cả ba, dùng CHUNG một cỡ chữ (cỡ nhỏ
/// nhất mà cả ba vừa) cho số tiền và cho nhãn; màn đủ chỗ giữ cỡ cũ.
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/core/utils/currency_formatter.dart';
import 'package:flowmoney/features/home/presentation/widgets/the_so_lieu_thang.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  Future<void> bom(WidgetTester tester, double man,
      {double thu = 14635000, double chi = 1045000}) async {
    tester.view.physicalSize = Size(man, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          // Cùng lề ngang của Trang chủ (`home_page.dart`).
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TheSoLieuThang(thu: thu, chi: chi),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Hộp thẻ (Container trắng) bao quanh một nhãn.
  Rect hopThe(WidgetTester tester, String nhan) => tester.getRect(find
      .ancestor(of: find.text(nhan), matching: find.byType(Container))
      .first);

  for (final man in [320.0, 300.0]) {
    testWidgets('G72 · $man dp: ba thẻ CAO BẰNG NHAU, nhãn một dòng', (tester) async {
      await bom(tester, man);
      expect(tester.takeException(), isNull);
      final cao = [
        for (final n in ['Thu nhập', 'Chi tiêu', 'Thu net']) hopThe(tester, n).height,
      ];
      expect(cao[1], closeTo(cao[0], 0.5), reason: '$man dp: thẻ Chi tiêu lệch cao với Thu nhập');
      expect(cao[2], closeTo(cao[0], 0.5), reason: '$man dp: thẻ Thu net lệch cao với Thu nhập');
      for (final n in ['Thu nhập', 'Chi tiêu', 'Thu net']) {
        final rp = tester.renderObject<RenderParagraph>(find.text(n));
        expect(rp.size.height, lessThan(rp.preferredLineHeight * 1.5),
            reason: '$man dp: nhãn "$n" xuống hai dòng');
        expect(rp.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(rp.size.width + 0.5),
            reason: '$man dp: nhãn "$n" bị cắt');
      }
    });

    testWidgets('G72 · $man dp: ba số tiền vẽ CÙNG CỠ và không cắt', (tester) async {
      await bom(tester, man);
      final so = [
        CurrencyFormatter.format(14635000),
        CurrencyFormatter.format(1045000),
        CurrencyFormatter.formatCoDau(13590000, thu: true),
      ];
      final cao = [for (final s in so) tester.getRect(find.text(s)).height];
      expect(cao[1], closeTo(cao[0], 0.5),
          reason: '$man dp: số tiền thẻ Chi tiêu vẽ cỡ khác thẻ Thu nhập (co riêng từng thẻ)');
      expect(cao[2], closeTo(cao[0], 0.5),
          reason: '$man dp: số tiền thẻ Thu net vẽ cỡ khác thẻ Thu nhập');
      for (final s in so) {
        final rp = tester.renderObject<RenderParagraph>(find.text(s));
        expect(rp.didExceedMaxLines, isFalse, reason: '$man dp: "$s" bị cắt');
      }
    });
  }

  testWidgets('G72 · 411 dp: đủ chỗ thì giữ cỡ cũ — số tiền 16, nhãn 13', (tester) async {
    // Số nhỏ: ở 411 dp mỗi ô chữ ~81 dp, "+300.000 đ" cỡ 16 đã không vừa.
    await bom(tester, 411, thu: 50000, chi: 20000);
    final soTien = tester.renderObject<RenderParagraph>(
        find.text(CurrencyFormatter.format(50000)));
    expect(soTien.text.style?.fontSize, 16);
    final nhan = tester.renderObject<RenderParagraph>(find.text('Thu nhập'));
    expect(nhan.text.style?.fontSize, 13);
  });
}
