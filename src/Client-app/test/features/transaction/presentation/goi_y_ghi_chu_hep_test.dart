/// G83 (2026-10-07, nghiệm thu Realme 320 dp): chữ gợi ý của ô ghi chú màn Thêm
/// giao dịch bị cắt thành *"Thêm ghi chú cho gi…"*. Người dùng chọn **rút gọn
/// chữ** (không cho xuống dòng — ô giữ nguyên chiều cao, form không xê dịch).
///
/// Ca test tìm chữ gợi ý theo VỊ TRÍ (Text duy nhất trong ô ghi chú) chứ không
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

  Future<void> dung(WidgetTester tester, double rong) async {
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
      ),
    ));
    await tester.pumpAndSettle();
  }

  RenderParagraph goiY(WidgetTester tester) {
    final chu = find.descendant(
        of: find.byKey(const Key('ghi-chu-giao-dich')),
        matching: find.byType(Text));
    expect(chu, findsOneWidget,
        reason: 'Tiền đề: ô ghi chú trống thì chỉ có một Text — chữ gợi ý.');
    return tester.renderObject<RenderParagraph>(chu);
  }

  for (final rong in [320.0, 300.0]) {
    testWidgets('G83 · $rong dp: chữ gợi ý ô ghi chú hiện trọn, một dòng',
        (tester) async {
      await dung(tester, rong);
      final rp = goiY(tester);
      expect(rp.didExceedMaxLines, isFalse,
          reason: '$rong dp: chữ gợi ý bị cắt thành "…"');
      expect(rp.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(rp.size.width + 0.5),
          reason: '$rong dp: chữ gợi ý không vừa ô — bị cắt');
    });
  }
}
