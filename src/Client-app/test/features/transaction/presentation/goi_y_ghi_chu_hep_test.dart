/// G83 (2026-10-07, nghiệm thu Realme 320 dp): chữ gợi ý của ô ghi chú màn Thêm
/// giao dịch bị cắt thành *"Thêm ghi chú cho gi…"*. Người dùng chọn **rút gọn
/// chữ** (không cho xuống dòng — ô giữ nguyên chiều cao, form không xê dịch).
///
/// G84 (cùng tối, cùng lượt nghiệm thu): chữ gợi ý ô **Nhập nhanh** cắt thành
/// *"VD: hôm qua ăn phở …"* — mất đúng phần ví dụ số tiền + ví; và ô ghi chú
/// mang **viền + nền** của theme trong khi Stitch `8afdfe11…` vẽ hàng phẳng như
/// hàng Danh mục / Ngày. Người dùng chọn sửa cả hai.
///
/// Ca test tìm chữ gợi ý theo VỊ TRÍ (Text duy nhất trong ô trống) chứ không
/// theo nội dung, để nó đo cả bản cũ lẫn bản mới.
library;

import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/font_that.dart';
import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);

  setUp(napFontThat);

  Future<void> dung(WidgetTester tester, double rong, {bool laPremium = true}) async {
    tester.view.physicalSize = Size(rong, 900);
    tester.view.devicePixelRatio = 1.0;
    // Roboto (font test) hẹp hơn Inter thật — phóng ×1,1 để chừa biên (như G80).
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final bloc = TransactionBloc(transactionRepository: FakeTransactionRepository());
    addTearDown(bloc.close);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: AddTransactionPage(
        transactionBloc: bloc,
        categoryRepository: FakeCategoryRepository(
          trees: {
            'chi': CategoryTree(
                groups: const [],
                ungroupedChildren: const [],
                defaultChildren: [anUong]),
          },
        ),
        wallets: [makeWallet()],
        idaccount: 1,
        budgetLookup: (_, __) async => null,
        laPremium: laPremium,
      ),
    ));
    await tester.pumpAndSettle();
  }

  RenderParagraph goiY(WidgetTester tester, Key o) {
    final chu = find.descendant(of: find.byKey(o), matching: find.byType(Text));
    expect(chu, findsOneWidget,
        reason: 'Tiền đề: ô trống thì chỉ có một Text — chữ gợi ý.');
    return tester.renderObject<RenderParagraph>(chu);
  }

  void vuaO(RenderParagraph rp, String ten) {
    expect(rp.didExceedMaxLines, isFalse, reason: '$ten bị cắt thành "…"');
    expect(rp.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(rp.size.width + 0.5),
        reason: '$ten không vừa ô — bị cắt');
  }

  for (final rong in [320.0, 300.0]) {
    testWidgets('G83 · $rong dp: chữ gợi ý ô ghi chú hiện trọn, một dòng',
        (tester) async {
      await dung(tester, rong);
      vuaO(goiY(tester, const Key('ghi-chu-giao-dich')),
          '$rong dp: chữ gợi ý ô ghi chú');
    });

    for (final premium in [true, false]) {
      testWidgets(
          'G84 · $rong dp · ${premium ? 'Premium' : 'Basic'}: chữ gợi ý ô Nhập nhanh hiện trọn',
          (tester) async {
        await dung(tester, rong, laPremium: premium);
        vuaO(goiY(tester, const Key('nhap-nhanh-o')),
            '$rong dp: chữ gợi ý ô Nhập nhanh');
      });
    }
  }

  testWidgets('G84: ví dụ Nhập nhanh vẫn nêu số tiền và ví — thứ câu ví dụ sinh ra để chỉ',
      (tester) async {
    await dung(tester, 411);
    final hint = tester
        .widget<TextField>(find.byKey(const Key('nhap-nhanh-o')))
        .decoration!
        .hintText!;
    expect(hint, contains('45k'), reason: 'ví dụ phải có số tiền');
    expect(hint, contains('tiền mặt'), reason: 'ví dụ phải nêu ví');
  });

  testWidgets('G84: chữ ô ghi chú thẳng cột với nhãn "Ngày" (theme đệm ngang 16)',
      (tester) async {
    await dung(tester, 320);
    final chu = find.descendant(
        of: find.byKey(const Key('ghi-chu-giao-dich')),
        matching: find.byType(Text));
    expect(tester.getTopLeft(chu).dx,
        closeTo(tester.getTopLeft(find.text('Ngày')).dx, 1),
        reason: 'chữ gợi ý thụt vào so với cột chữ của các hàng khác');
  });

  testWidgets('G84: ô ghi chú là hàng phẳng — không nền, không viền (Stitch 8afdfe11…)',
      (tester) async {
    await dung(tester, 411);
    final trangTri = tester
        .widget<InputDecorator>(find.descendant(
            of: find.byKey(const Key('ghi-chu-giao-dich')),
            matching: find.byType(InputDecorator)))
        .decoration;
    expect(trangTri.filled, isFalse,
        reason: 'theme đặt filled cho mọi ô — phải tắt riêng');
    for (final (ten, vien) in [
      ('enabledBorder', trangTri.enabledBorder),
      ('focusedBorder', trangTri.focusedBorder),
      ('border', trangTri.border),
    ]) {
      expect(vien == null || vien == InputBorder.none, isTrue,
          reason: '$ten của ô ghi chú phải là InputBorder.none (theme ghi đè '
              '`border: none` bằng enabledBorder / focusedBorder riêng)');
    }
  });
}
