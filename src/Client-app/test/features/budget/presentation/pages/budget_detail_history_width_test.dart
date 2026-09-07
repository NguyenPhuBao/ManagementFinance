/// Biểu đồ lịch sử: một kỳ không được vẽ thành một khối chiếm cả thẻ.
///
/// Vì sao cần: cột dùng `Expanded` nên ngân sách mới (một kỳ) trên máy ảo
/// 2026-09-06 hiện một khối đỏ rộng ~370dp cao 120dp — nhìn như lỗi vẽ chứ
/// không như biểu đồ. Bề rộng cột phải có trần, và với đủ sáu kỳ thì vẫn
/// dàn kín như trước.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_history.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_detail_cubit.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_detail_view.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';

void main() {
  final now = DateTime(2026, 9, 6, 12);

  BudgetView view() => BudgetView(
        budget: BudgetEntity(
          id: 'b1',
          idaccount: 7,
          categoryId: 'c1',
          amount: 50000,
          spent: 285000,
          startDate: DateTime(2026, 9, 4),
          endDate: DateTime(2026, 9, 11),
          recurrence: false,
          timeRecurrence: BudgetRecurrence.week,
          updatedAt: DateTime(2026, 9, 1),
        ),
        categoryName: 'Di chuyển',
      );

  Future<void> dung(WidgetTester tester, List<BudgetPeriodSummary> lichSu) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final v = view();
    await tester.pumpWidget(MaterialApp(
      home: BudgetDetailView(
        state: BudgetDetailLoaded(
          view: v,
          pace: budgetPaceOf(v.budget, now),
          history: lichSu,
          transactions: const [],
          lookup: TransactionLookup.empty,
          expired: false,
        ),
        onEdit: () {},
        onTapTransaction: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  BudgetPeriodSummary ky(int tuan, {double spent = 285000}) =>
      BudgetPeriodSummary(
        from: DateTime(2026, 9, 4 - 7 * tuan),
        to: DateTime(2026, 9, 11 - 7 * tuan),
        amount: 50000,
        spent: spent,
      );

  testWidgets('một kỳ: cột có trần bề rộng, không phình ra cả thẻ',
      (tester) async {
    await dung(tester, [ky(0)]);

    final size = tester.getSize(find.byKey(const ValueKey('budget-history-bar-0')));
    expect(
      size.width,
      lessThanOrEqualTo(64),
      reason: 'Một cột rộng ~370dp không đọc được như biểu đồ. Trần 64dp là '
          'cỡ cột khi có sáu kỳ ở 411dp, nên nhìn nhất quán dù ít hay nhiều kỳ.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sáu kỳ: các cột vẫn chia đều bề rộng thẻ như trước',
      (tester) async {
    await dung(tester, [for (var i = 5; i >= 0; i--) ky(i)]);

    final w0 = tester.getSize(find.byKey(const ValueKey('budget-history-bar-0'))).width;
    final w5 = tester.getSize(find.byKey(const ValueKey('budget-history-bar-5'))).width;
    expect(w0, closeTo(w5, 0.5), reason: 'Cột phải bằng nhau.');
    expect(w0, greaterThan(40),
        reason: 'Trần bề rộng không được bóp cột khi có đủ kỳ.');
    expect(tester.takeException(), isNull);
  });
}
