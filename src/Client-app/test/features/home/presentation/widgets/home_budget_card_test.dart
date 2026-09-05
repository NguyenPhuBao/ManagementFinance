/// Thẻ ngân sách ở trang chủ: một ngân sách, chọn cái căng nhất.
///
/// Vì sao cần: trước 2026-09-06 thẻ này là dữ liệu giả cứng ("Ăn uống", "Chưa
/// thiết lập", thanh 0%) dù `watchBudgets` đã có. Stitch màn Home vẽ đúng một
/// ngân sách ("Đã dùng 2.100k / 3.000k · 68%"), nên phép chọn phải có test —
/// chọn sai là trang chủ khoe một ngân sách đang ổn trong khi cái khác vượt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/home/presentation/widgets/home_budget_card.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);

  BudgetView view({
    required String id,
    required double spent,
    double amount = 1000000,
    DateTime? start,
    bool recurrence = true,
    String name = 'Ăn uống',
  }) {
    return BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: amount,
        spent: spent,
        startDate: start ?? DateTime(2026, 9, 1),
        recurrence: recurrence,
        updatedAt: now,
      ),
      categoryName: name,
    );
  }

  group('pickHomeBudget', () {
    test('chọn ngân sách có tỉ lệ đã chi cao nhất', () {
      final picked = pickHomeBudget(
        [view(id: 'a', spent: 300000), view(id: 'b', spent: 900000)],
        now,
      );
      expect(picked?.budget.id, 'b');
    });

    test('ngân sách vượt thắng ngân sách gần hết dù số tiền nhỏ hơn', () {
      final picked = pickHomeBudget(
        [
          view(id: 'gan', spent: 950000),
          view(id: 'vuot', amount: 100000, spent: 150000),
        ],
        now,
      );
      expect(picked?.budget.id, 'vuot',
          reason: 'So theo TỈ LỆ, không theo số tiền: 150% căng hơn 95%.');
    });

    test('bỏ qua ngân sách đã hết hạn', () {
      final picked = pickHomeBudget(
        [
          view(id: 'chet', spent: 999999, start: DateTime(2026, 1, 1),
              recurrence: false),
          view(id: 'song', spent: 100000),
        ],
        now,
      );
      expect(picked?.budget.id, 'song',
          reason: 'Trang chủ nói về việc còn tiêu được bao nhiêu; ngân sách '
              'chết không còn gì để tiêu.');
    });

    test('không có ngân sách nào đang chạy thì null', () {
      expect(pickHomeBudget(const [], now), isNull);
      expect(
        pickHomeBudget(
          [view(id: 'chet', spent: 0, start: DateTime(2026, 1, 1),
              recurrence: false)],
          now,
        ),
        isNull,
      );
    });
  });

  group('HomeBudgetCard', () {
    Future<void> dung(
      WidgetTester tester, {
      required List<BudgetView> budgets,
      VoidCallback? onTap,
    }) async {
      tester.view.physicalSize = const Size(411, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: HomeBudgetCard(budgets: budgets, now: now, onTap: onTap),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('hiện tên danh mục, đã dùng / hạn mức và phần trăm',
        (tester) async {
      await dung(tester, budgets: [
        view(id: 'a', amount: 3000000, spent: 2100000, name: 'Ăn uống'),
      ]);

      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.textContaining('Đã dùng'), findsOneWidget);
      expect(find.textContaining('2.100.000'), findsOneWidget);
      expect(find.textContaining('3.000.000'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget,
          reason: 'Stitch màn Home ghi phần trăm ĐÃ DÙNG bên phải tên.');
    });

    testWidgets('không tràn ở 411dp với tên danh mục dài và số tiền lớn',
        (tester) async {
      await dung(tester, budgets: [
        view(
          id: 'a',
          amount: 123456789000,
          spent: 98765432100,
          name: 'Một danh mục có cái tên dài quá mức cần thiết để thử tràn',
        ),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chưa có ngân sách thì chỉ đường sang trang Ngân sách',
        (tester) async {
      await dung(tester, budgets: const []);

      expect(find.textContaining('Chưa thiết lập'), findsOneWidget);
      expect(find.textContaining('Đã dùng'), findsNothing);
    });

    testWidgets('bấm thẻ thì gọi onTap', (tester) async {
      var goi = false;
      await dung(tester,
          budgets: [view(id: 'a', spent: 1)], onTap: () => goi = true);

      await tester.tap(find.text('Ăn uống'));
      await tester.pump();

      expect(goi, isTrue);
    });
  });
}
