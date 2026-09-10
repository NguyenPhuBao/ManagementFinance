/// Thẻ tổng quan đầu trang ngân sách: đọc được ở 411dp và nói đúng "kỳ".
///
/// Vì sao cần: trên máy ảo 2026-09-06 dòng "330.000 đ / 100.000 đ đã dùng"
/// bị cắt thành "đã ..." vì nằm cùng hàng với "0% ngân sách còn lại" — con số
/// quan trọng nhất của thẻ lại là thứ bị cắt. Và tiêu đề ghi "THÁNG NÀY" trong
/// khi ngân sách có thể theo tuần, quý, năm hoặc "Ngày cụ thể".
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';

void main() {
  BudgetView view({required String id, required double amount, double spent = 0}) {
    return BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c1',
        amount: amount,
        spent: spent,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: 'Ăn uống',
    );
  }

  Future<void> dung(WidgetTester tester, List<BudgetView> active) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: BudgetTabsView(
        now: DateTime(2026, 9, 6, 12),
        state: BudgetLoaded(
          active: active,
          expired: const [],
          totalAmount: active.fold(0.0, (s, v) => s + v.budget.amount),
          totalSpent: active.fold(0.0, (s, v) => s + v.budget.spent),
        ),
        onCreate: () {},
        onEdit: (_) {},
        onDelete: (_) async => false,
        onShowDetail: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('dòng "đã dùng" không bị cắt ở 411dp khi số tiền dài',
      (tester) async {
    await dung(tester, [
      view(id: 'b1', amount: 50000, spent: 285000),
      view(id: 'b2', amount: 50000, spent: 45000),
    ]);

    final paragraph =
        tester.renderObject<RenderParagraph>(find.textContaining('đã dùng'));
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '"330.000 đ / 100.000 đ đã dùng" là con số chính của thẻ; bị '
          'cắt thành "đã ..." thì thẻ mất luôn ý nghĩa.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tiêu đề nói "kỳ này", không đóng đinh vào tháng',
      (tester) async {
    await dung(tester, [view(id: 'b1', amount: 50000, spent: 285000)]);
    expect(find.text('ĐÃ TIÊU VƯỢT KỲ NÀY'), findsOneWidget,
        reason: 'Ngân sách có thể theo tuần/quý/năm hoặc "Ngày cụ thể".');

    await dung(tester, [view(id: 'b1', amount: 50000, spent: 5000)]);
    expect(find.text('CÒN LẠI KỲ NÀY'), findsOneWidget);
  });
}
