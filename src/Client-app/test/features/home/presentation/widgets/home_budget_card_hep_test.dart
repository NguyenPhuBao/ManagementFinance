/// G75 — thẻ ngân sách ở Trang chủ ở màn HẸP (Realme để cỡ hiển thị lớn: mật
/// độ 540 → 320 dp).
///
/// Quét 2026-10-07: *"Đã dùng 10.000 đ / 50…"* — **mất hạn mức**, con số chính
/// của thẻ; dòng nhịp *"Nên chi 19.600 đ/ngày · còn 25 ng…"* cũng cụt. Cả hai là
/// `maxLines: 1` + `ellipsis`.
///
/// Cùng nguyên tắc người dùng chọn ở G74 (2026-10-07): **chỉ đổi khi chật** —
/// hai dòng ấy xuống tối đa hai dòng, ngắt ở chỗ hợp lý (trước *"/"*, sau
/// *"·"*), không gãy giữa *"500.000 đ"* hay *"còn 25 ngày"*; màn đủ chỗ vẫn
/// một dòng.
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/home/presentation/widgets/home_budget_card.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

import '../../../../helpers/font_that.dart';

void main() {
  final now = DateTime(2026, 9, 6, 12);

  BudgetView view({double amount = 500000, double spent = 10000}) => BudgetView(
        budget: BudgetEntity(
          id: 'a',
          idaccount: 7,
          categoryId: 'c-a',
          amount: amount,
          spent: spent,
          startDate: DateTime(2026, 9, 1),
          recurrence: true,
          updatedAt: now,
        ),
        categoryName: 'Ăn uống',
      );

  setUp(napFontThat);

  Future<void> dung(WidgetTester tester, double rong, {BudgetView? v}) async {
    tester.view.physicalSize = Size(rong, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          // Cùng lề ngang của Trang chủ (`home_page.dart`).
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: HomeBudgetCard(budgets: [v ?? view()], now: now),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  RenderParagraph dong(WidgetTester tester, String batDau) {
    final o = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith(batDau));
    expect(o, findsOneWidget, reason: 'phải tìm đúng dòng "$batDau…"');
    return tester.renderObject<RenderParagraph>(o);
  }

  /// Số dòng thật đã vẽ — đo bằng chiều cao, vì `didExceedMaxLines` chỉ báo khi
  /// bị cắt, không báo khi đã xuống dòng.
  int soDong(RenderParagraph rp) =>
      (rp.size.height / rp.preferredLineHeight).round();

  for (final rong in [320.0, 300.0]) {
    testWidgets('G75 · $rong dp: hạn mức và "còn N ngày" vẽ trọn, không cụt',
        (tester) async {
      await dung(tester, rong);
      expect(tester.takeException(), isNull);
      final daDung = dong(tester, 'Đã dùng');
      expect(daDung.didExceedMaxLines, isFalse,
          reason: '$rong dp: "Đã dùng … / 500.000 đ" bị cắt — mất hạn mức');
      expect(daDung.text.toPlainText(), contains('500.000'),
          reason: 'hạn mức phải nằm trong dòng ấy');
      final nhip = dong(tester, 'Nên chi');
      expect(nhip.didExceedMaxLines, isFalse,
          reason: '$rong dp: dòng nhịp chi bị cắt — mất "còn N ngày"');
    });
  }

  testWidgets('G75 · 320 dp: ngắt đúng chỗ — hạn mức và "còn N ngày" không gãy giữa',
      (tester) async {
    await dung(tester, 320);
    final daDung = dong(tester, 'Đã dùng');
    expect(soDong(daDung), 2, reason: 'ở 320 dp dòng "Đã dùng" phải xuống hai dòng');
    // Dòng thứ hai bắt đầu bằng "/" — hạn mức đi liền khối với dấu gạch.
    final dongHai = daDung.getPositionForOffset(
        Offset(0, daDung.preferredLineHeight * 1.5));
    final chu = daDung.text.toPlainText();
    expect(chu.substring(dongHai.offset).trimLeft(), startsWith('/'),
        reason: 'ngắt TRƯỚC "/", không gãy giữa "500.000 đ"');
    final nhip = dong(tester, 'Nên chi');
    if (soDong(nhip) == 2) {
      final p = nhip.getPositionForOffset(Offset(0, nhip.preferredLineHeight * 1.5));
      expect(nhip.text.toPlainText().substring(p.offset).trimLeft(), startsWith('còn'),
          reason: 'ngắt SAU "·", không gãy giữa "còn 25 ngày"');
    }
  });

  testWidgets('G75 · 300 dp, số lớn: "1.250.000 đ / 3.000.000 đ" vẫn trọn hạn mức',
      (tester) async {
    // Bộ ngắt dòng Unicode CẤM ngắt trước "/" kể cả sau dấu cách: để nó tự ngắt
    // thì cả cụm "1.250.000 đ / 3.000.000 đ" là một khối, rộng hơn dòng ở 300
    // dp, và hạn mức bị cắt. Nên thẻ đo rồi tự ngắt trước "/".
    await dung(tester, 300, v: view(amount: 3000000, spent: 1250000));
    final daDung = dong(tester, 'Đã dùng');
    expect(daDung.didExceedMaxLines, isFalse);
    expect(daDung.text.toPlainText(), contains('3.000.000'));
  });

  testWidgets('G75 · 411 dp: dáng cũ GIỮ NGUYÊN — hai dòng vẫn một dòng', (tester) async {
    await dung(tester, 411);
    expect(soDong(dong(tester, 'Đã dùng')), 1);
    expect(soDong(dong(tester, 'Nên chi')), 1);
  });
}
