/// Tab "Đã hết hạn" phải khoá sửa và xoá — chỉ xem được chi tiết.
///
/// Vì sao cần: khoá thao tác là **quy tắc nghiệp vụ**, nhưng nó chỉ tồn tại
/// dưới dạng "widget này không được dựng". Không có test thì một lần dọn giao
/// diện vô tình đưa nút sửa trở lại sẽ không làm gì đỏ lên, và người dùng sửa
/// được một ngân sách đã chốt sổ.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';

void main() {
  BudgetView view({
    required String id,
    double amount = 1000000,
    double spent = 0,
  }) {
    return BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c1',
        amount: amount,
        spent: spent,
        startDate: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: 'Ăn uống',
    );
  }

  Future<void> dung(
    WidgetTester tester, {
    List<BudgetView> active = const [],
    List<BudgetView> expired = const [],
    void Function(BudgetView)? onEdit,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: BudgetTabsView(
        state: BudgetLoaded(
          active: active,
          expired: expired,
          totalAmount: active.fold(0.0, (s, v) => s + v.budget.amount),
          totalSpent: active.fold(0.0, (s, v) => s + v.budget.spent),
        ),
        onCreate: () {},
        onEdit: onEdit ?? (_) {},
        onDelete: (_) async => false,
        onShowDetail: (_) {},
      ),
    ));
  }

  testWidgets('tab đang hoạt động: vuốt xoá được và có nút chỉnh',
      (tester) async {
    await dung(tester, active: [view(id: 'b1')]);

    expect(find.byType(Dismissible), findsOneWidget,
        reason: 'Ngân sách đang chạy phải vuốt để xoá được như trước.');
    expect(find.byKey(const ValueKey('budget-edit-b1')), findsOneWidget,
        reason: 'Nút chỉnh (biểu tượng tune) có trong bản dựng hình Stitch.');
  });

  testWidgets('tab đã hết hạn: không vuốt xoá được', (tester) async {
    await dung(tester, expired: [view(id: 'b1')]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(
      find.byType(Dismissible),
      findsNothing,
      reason: 'Còn Dismissible thì người dùng vẫn vuốt xoá được một ngân sách '
          'đã chốt sổ — mất luôn lịch sử mà không có cảnh báo nào.',
    );
  });

  testWidgets('tab đã hết hạn: không có nút chỉnh', (tester) async {
    await dung(tester, expired: [view(id: 'b1')]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget-edit-b1')), findsNothing,
        reason: 'Sửa hạn mức của một kỳ đã đóng làm số liệu lịch sử đổi theo.');
  });

  testWidgets('chạm thẻ đã hết hạn KHÔNG mở trang sửa', (tester) async {
    final daMoSua = <String>[];
    await dung(
      tester,
      expired: [view(id: 'b1')],
      onEdit: (v) => daMoSua.add(v.budget.id),
    );
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();

    expect(daMoSua, isEmpty,
        reason: 'Chạm thẻ ở tab này mở bảng chi tiết chỉ đọc, không phải form.');
  });

  testWidgets('tab đã hết hạn còn dư thì báo "Còn dư", vượt thì báo "Vượt"',
      (tester) async {
    await dung(tester, expired: [
      view(id: 'du', amount: 1000000, spent: 400000),
      view(id: 'vuot', amount: 1000000, spent: 1350000),
    ]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Còn dư'), findsOneWidget);
    expect(find.textContaining('Vượt'), findsOneWidget,
        reason: 'Anh yêu cầu tab này nói rõ vượt bao nhiêu, không chỉ tô màu.');
  });

  testWidgets('chỉ có ngân sách hết hạn thì không hiện màn hình rỗng toàn trang',
      (tester) async {
    await dung(tester, expired: [view(id: 'b1')]);

    expect(find.textContaining('Đã hết hạn'), findsOneWidget,
        reason: 'Thanh tab phải còn đó để người dùng sang xem được dữ liệu cũ.');
  });
}
