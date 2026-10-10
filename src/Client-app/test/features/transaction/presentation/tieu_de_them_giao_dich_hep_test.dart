/// G80 (2026-10-07, nghiệm thu Realme 320 dp): khi 16 phím số ẩn thì nút ✓ lên
/// thanh tiêu đề, và tiêu đề màn Thêm / Sửa giao dịch bị cắt thành
/// *"Thêm giao dị…"*. Người dùng chọn **co chữ cho vừa** (cùng lối nhãn tab
/// Ngân sách, G76) — màn rộng không đổi.
library;

import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/font_that.dart';
import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);

  setUp(napFontThat);

  Future<void> dung(WidgetTester tester, double rong) async {
    tester.view.physicalSize = Size(rong, 900);
    tester.view.devicePixelRatio = 1.0;
    // Roboto (font test) hẹp hơn Inter thật, nhất là chữ đậm — phóng ×1,1 để
    // chừa biên, nếu không ca 320 dp xanh trong khi Realme vẫn cắt.
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final bloc = TransactionBloc(transactionRepository: FakeTransactionRepository());
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/start/add',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, __) => const Scaffold(body: Text('Trang trước')),
          routes: [
            GoRoute(
              path: 'add',
              builder: (_, __) => AddTransactionPage(
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
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
    // Đúng thao tác trên Realme: chạm khối số tiền để ẩn 16 phím → ✓ lên thanh
    // tiêu đề, cạnh nút ⋮.
    await tester.tap(find.byKey(const Key('so-tien-cham')));
    await tester.pumpAndSettle();
  }

  for (final rong in [320.0, 300.0]) {
    testWidgets('G80 · $rong dp: ✓ trên thanh tiêu đề thì tiêu đề vẫn hiện trọn',
        (tester) async {
      await dung(tester, rong);
      expect(find.byKey(const Key('luu-thanh-tieu-de')), findsOneWidget,
          reason: 'Tiền đề: ca này đo đúng lúc ✓ chiếm chỗ trên thanh tiêu đề.');
      final rp = tester.renderObject<RenderParagraph>(find.text('Thêm giao dịch'));
      expect(rp.didExceedMaxLines, isFalse,
          reason: '$rong dp: tiêu đề bị cắt thành "…"');
      expect(rp.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(rp.size.width + 0.5),
          reason: '$rong dp: tiêu đề không vừa ô — bị cắt');
    });
  }

  testWidgets('G80 · 411 dp: đủ chỗ thì tiêu đề giữ cỡ chữ gốc', (tester) async {
    await dung(tester, 411);
    final fit = find.ancestor(
        of: find.text('Thêm giao dịch'), matching: find.byType(FittedBox));
    final hopChu = tester.getSize(find.text('Thêm giao dịch'));
    final hopFit = tester.getSize(fit);
    expect(hopFit.width, closeTo(hopChu.width, 0.5),
        reason: 'Màn rộng không được co chữ — chỉ co khi đo thấy chật.');
  });
}
