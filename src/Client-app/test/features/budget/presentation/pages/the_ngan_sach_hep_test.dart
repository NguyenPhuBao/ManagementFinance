/// Thẻ từng ngân sách (tab *Đang hoạt động*) ở khổ hẹp + cỡ chữ lớn — Realme 320 dp, cỡ chữ 1,6 (lượt đo lại bản
/// `626c6060`, 2026-10-26): dòng phụ *"Còn 490.000 đ"* gãy giữa chữ số (*"Còn 49 / 0.000 / đ"*) và tên danh mục cụt
/// *"Ăn u…"*. Gốc: cột số tiền bên phải (*"10.000 đ"* · *"/ 500.000 đ"*) giữ bề rộng tự nhiên, cột tên chỉ còn ~77 dp mà dòng
/// phụ cần ~164 dp — chữ không vừa một từ thì Flutter bẻ giữa từ, không có sọc vàng. ×1,76 ≈ Inter ở 1,6 (Roboto hẹp hơn).
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

import '../../../../helpers/font_that.dart';

void main() {
  setUp(napFontThat);

  Future<void> dung(WidgetTester t, double rong, double co, {required double hanMuc, required double daChi}) async {
    t.view.physicalSize = Size(rong, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: BudgetTabsView(
        now: DateTime(2026, 9, 15, 12),
        state: BudgetLoaded(
          active: [
            BudgetView(
              budget: BudgetEntity(
                id: 'a',
                idaccount: 7,
                categoryId: 'c',
                amount: hanMuc,
                spent: daChi,
                startDate: DateTime(2026, 9, 1),
                updatedAt: DateTime(2026, 9, 1),
              ),
              categoryName: 'Ăn uống',
            ),
          ],
          expired: const [],
          totalAmount: hanMuc,
          totalSpent: daChi,
        ),
        onCreate: () {},
        onEdit: (_) {},
        onDelete: (_) async => false,
        onShowDetail: (_) {},
      ),
    ));
    await t.pump();
  }

  /// Dòng phụ của thẻ — so theo chữ nhìn thấy (khoảng trắng nào cũng được: số có thể dính `đ` bằng U+00A0).
  Finder dongPhu(String nhin) =>
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').replaceAll(' ', ' ') == nhin);

  /// Các đỉnh dòng mà đoạn [tu]..hết chuỗi của [f] nằm trên.
  Set<int> dinhDong(WidgetTester t, Finder f, {int tu = 0}) {
    final p = t.renderObject<RenderParagraph>(f);
    final dai = p.text.toPlainText().length;
    return p.getBoxesForSelection(TextSelection(baseOffset: tu, extentOffset: dai)).map((b) => b.top.round()).toSet();
  }

  /// Mép trong của thẻ (hộp `InkWell` trừ `margin` dưới 16 và đệm 16).
  Rect trongThe(WidgetTester t) {
    final r = t.getRect(find.ancestor(of: find.text('Ăn uống'), matching: find.byType(InkWell)).first);
    return Rect.fromLTRB(r.left + 16, r.top + 16, r.right - 16, r.bottom - 32);
  }

  for (final (hanMuc, daChi, phu, chi, tong) in [
    (500000.0, 10000.0, 'Còn 490.000 đ', '10.000 đ', '/ 500.000 đ'),
    // "Còn 1.490.000" vừa dòng mà thêm " đ" thì lố: dấu cách thường cho "đ" rơi xuống dòng riêng.
    (2000000.0, 510000.0, 'Còn 1.490.000 đ', '510.000 đ', '/ 2.000.000 đ'),
    (500000.0, 460000.0, 'Sắp hết — còn 40.000 đ', '460.000 đ', '/ 500.000 đ'),
    (1000000.0, 2250000.0, 'Vượt 1.250.000 đ', '2.250.000 đ', '/ 1.000.000 đ'),
  ]) {
    testWidgets('320 dp × 1,76, "$phu": số tiền không gãy, tên trọn, hai số tiền trong thẻ', (t) async {
      await dung(t, 320, 1.76, hanMuc: hanMuc, daChi: daChi);
      expect(t.takeException(), isNull);
      final f = dongPhu(phu);
      expect(f, findsOneWidget, reason: 'chữ dòng phụ không đổi: "$phu"');
      final batDauSo = phu.indexOf(RegExp(r'[0-9]'));
      expect(dinhDong(t, f, tu: batDauSo), hasLength(1),
          reason: 'Realme: "Còn 49 / 0.000 / đ" — con số (kèm "đ") phải nằm trọn một dòng');
      expect(dinhDong(t, f).length, lessThanOrEqualTo(2), reason: 'dòng phụ quá hai dòng');
      expect(t.renderObject<RenderParagraph>(find.text('Ăn uống')).didExceedMaxLines, isFalse,
          reason: 'Realme: tên danh mục cụt "Ăn u…"');
      final the = trongThe(t);
      for (final so in [chi, tong]) {
        final r = t.getRect(find.text(so));
        expect(dinhDong(t, find.text(so)), hasLength(1), reason: '"$so" gãy dòng');
        expect(r.right, lessThanOrEqualTo(the.right + 0.5), reason: '"$so" tràn mép phải thẻ');
        expect(r.left, greaterThanOrEqualTo(the.left - 0.5), reason: '"$so" tràn mép trái thẻ');
      }
    });
  }

  // Đối chứng: đủ chỗ thì bố cục Stitch giữ nguyên — hai số tiền ở cột phải, ngang hàng tên + dòng phụ. Bản sai "lúc nào
  // cũng xếp chồng" phải đỏ ở đây.
  for (final (rong, co) in [(411.0, 1.1), (320.0, 1.1)]) {
    testWidgets('$rong dp × $co: hai số tiền ở cột phải, cạnh dòng phụ', (t) async {
      await dung(t, rong, co, hanMuc: 500000, daChi: 10000);
      expect(t.takeException(), isNull);
      final phu = t.getRect(dongPhu('Còn 490.000 đ'));
      final chi = t.getRect(find.text('10.000 đ'));
      final tong = t.getRect(find.text('/ 500.000 đ'));
      expect(chi.left, greaterThan(phu.right), reason: 'số đã chi phải đứng bên phải dòng phụ');
      expect(chi.top, lessThan(phu.bottom), reason: 'số đã chi phải ngang hàng tên / dòng phụ, không xuống dưới');
      expect(tong.right, closeTo(trongThe(t).right, 0.5), reason: 'cột số tiền căn mép phải thẻ');
      expect(dinhDong(t, dongPhu('Còn 490.000 đ')), hasLength(1));
    });
  }
}
