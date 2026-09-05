/// Form thêm giao dịch phải hỏi ngân sách của danh mục trước khi ghi khoản chi.
///
/// Vì sao cần: lựa chọn "Chặn" tồn tại trên form ngân sách từ 2026-09-03 mà
/// không nơi nào đọc — người dùng chọn, bấm Lưu, không có gì khác. Từ
/// 2026-09-06: "Chặn" = hỏi xác nhận khi khoản làm vượt; "Cảnh báo" = ghi
/// luôn rồi báo bằng snackbar chung chung, không con số.
library;

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);

  FakeCategoryRepository categories() => FakeCategoryRepository(
        trees: {
          'chi': CategoryTree(
            groups: const [],
            ungroupedChildren: const [],
            defaultChildren: [anUong],
          ),
        },
      );

  /// Ngân sách của "Ăn uống" đang chạy tháng này.
  BudgetView nganSach({
    required double amount,
    required double spent,
    String overSpending = BudgetOverSpending.over,
  }) {
    final now = DateTime.now();
    return BudgetView(
      budget: BudgetEntity(
        id: 'b1',
        idaccount: 1,
        categoryId: 'food',
        amount: amount,
        spent: spent,
        overSpending: overSpending,
        startDate: DateTime(now.year, now.month, 1),
        recurrence: true,
        updatedAt: now,
      ),
      categoryName: 'Ăn uống',
    );
  }

  Widget app({
    required FakeTransactionRepository transactionRepository,
    BudgetView? budget,
  }) {
    final bloc = TransactionBloc(transactionRepository: transactionRepository);
    final categoryRepository = categories();
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
                categoryRepository: categoryRepository,
                wallets: [makeWallet()],
                idaccount: 1,
                // Tiêm thẳng, không qua `sl`: test không dựng DI.
                budgetLookup: (_, __) async => budget,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: categoryRepository,
            idaccount: 1,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  /// Chọn Ăn uống và gõ 5.000.
  Future<void> dienForm(WidgetTester tester) async {
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khoản chi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('000'));
    await tester.tap(find.text('000'));
    await tester.pump();
  }

  Future<void> luu(WidgetTester tester) async {
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
  }

  testWidgets('không có ngân sách thì lưu như cũ', (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(transactionRepository: repo));
    await tester.pumpAndSettle();
    await dienForm(tester);
    await luu(tester);

    expect(repo.added, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('ngân sách Chặn + khoản làm vượt → hỏi; Huỷ thì không ghi',
      (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(
      transactionRepository: repo,
      budget: nganSach(
          amount: 10000, spent: 8000, overSpending: BudgetOverSpending.stop),
    ));
    await tester.pumpAndSettle();
    await dienForm(tester);
    await luu(tester);

    expect(find.byType(AlertDialog), findsOneWidget,
        reason: '8.000 + 5.000 = 13.000 > 10.000 và ngân sách đặt Chặn.');
    expect(find.textContaining('3.000'), findsOneWidget,
        reason: 'Hộp thoại là điểm quyết định nên nêu rõ vượt bao nhiêu.');

    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();

    expect(repo.added, isEmpty,
        reason: 'Huỷ là không ghi. Ghi rồi mới hỏi là hỏi cho có.');
  });

  testWidgets('ngân sách Chặn + khoản làm vượt → "Vẫn ghi" thì ghi',
      (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(
      transactionRepository: repo,
      budget: nganSach(
          amount: 10000, spent: 8000, overSpending: BudgetOverSpending.stop),
    ));
    await tester.pumpAndSettle();
    await dienForm(tester);
    await luu(tester);
    await tester.tap(find.text('Vẫn ghi'));
    await tester.pumpAndSettle();

    expect(repo.added, hasLength(1),
        reason: 'Không bao giờ từ chối ghi một khoản đã tiêu thật ngoài đời.');
  });

  testWidgets('ngân sách Chặn nhưng khoản không làm vượt → không hỏi',
      (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(
      transactionRepository: repo,
      budget: nganSach(
          amount: 10000, spent: 1000, overSpending: BudgetOverSpending.stop),
    ));
    await tester.pumpAndSettle();
    await dienForm(tester);
    await luu(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.added, hasLength(1));
  });

  testWidgets('ngân sách Cảnh báo + khoản làm vượt → ghi luôn, báo chung chung',
      (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(
      transactionRepository: repo,
      budget: nganSach(amount: 10000, spent: 8000),
    ));
    await tester.pumpAndSettle();
    await dienForm(tester);
    // SnackBar treo trên ScaffoldMessenger gốc nên còn đó sau khi trang pop;
    // hẹn giờ tự tắt không phải animation nên `pumpAndSettle` không chờ nó.
    await luu(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.added, hasLength(1));
    final snack = tester.widget<Text>(
      find.descendant(
          of: find.byType(SnackBar), matching: find.byType(Text)),
    );
    expect(snack.data, contains('vượt'));
    expect(snack.data, isNot(matches(RegExp(r'\d'))),
        reason: 'Banner tạm thời không nêu số liệu — con số ở trang ngân sách.');
  });
}
