/// Phím `+` `−` của màn Thêm giao dịch làm phép tính thật — 2026-09-19.
///
/// Văn phạm và các phép kẹp nằm ở `domain/ban_phim_so_tien.dart` và có tệp
/// test riêng; ở đây chỉ canh **ba mối nối** mà tầng domain không với tới:
///
/// 1. `_saveTransaction` phải **rút gọn** biểu thức, không `double.tryParse`
///    thẳng — `"50000+30000"` parse thẳng ra `null` rồi rơi về `0`, và chốt
///    `amount <= 0` báo *"Vui lòng nhập số tiền hợp lệ"* cho một con số người
///    dùng vừa gõ đúng.
/// 2. Dòng số hiện **biểu thức**, và dòng dưới nó hiện **kết quả** — nhờ vậy
///    ✓ vừa rút gọn vừa lưu trong một nhịp mà người dùng **vẫn thấy tổng
///    trước khi nó được ghi**. Không có phím `=` nào trên lưới Stitch, nên
///    đây là chỗ duy nhất tổng ấy hiện ra được.
/// 3. Phím trừ vẽ dấu trừ thật `−`, cùng ký hiệu với dòng số.
library;

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

  Widget app(FakeTransactionRepository repo) {
    final bloc = TransactionBloc(transactionRepository: repo);
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
                budgetLookup: (_, __) async => null,
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

  Future<void> goPhim(WidgetTester tester, List<String> phim) async {
    for (final p in phim) {
      await tester.tap(find.text(p));
      await tester.pump();
    }
  }

  testWidgets('gõ 50000 + 30000 rồi ✓ thì lưu ĐÚNG 80.000', (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();

    await goPhim(tester, ['5', '0', '000', '+', '3', '0', '000']);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.added, hasLength(1));
    expect(repo.added.single.transaction.amount, 80000,
        reason: '`double.tryParse("50000+30000")` trả null rồi rơi về 0, và '
            'chốt `amount <= 0` báo "Vui lòng nhập số tiền hợp lệ" cho một '
            'con số người dùng vừa gõ đúng. Đường lưu phải rút gọn biểu thức.');
  });

  testWidgets('gõ 50000 − 30000 rồi ✓ thì lưu 20.000', (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();

    await goPhim(tester, ['5', '0', '000', '−', '3', '0', '000']);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.added.single.transaction.amount, 20000);
  });

  testWidgets('⚠️ đang gõ thì dòng số là biểu thức, dòng dưới là kết quả',
      (tester) async {
    await tester.pumpWidget(app(FakeTransactionRepository()));
    await tester.pumpAndSettle();

    await goPhim(tester, ['5', '0', '000']);
    expect(find.text('50.000 đ'), findsOneWidget);
    expect(find.text('VNĐ - VIỆT NAM ĐỒNG'), findsOneWidget,
        reason: 'Chưa có phép toán nào thì dòng dưới vẫn là nhãn tiền tệ.');

    await goPhim(tester, ['+']);
    expect(find.text('50.000 +'), findsOneWidget,
        reason: 'Toán tử lẻ vẫn hiện, để người dùng thấy mình đang gõ dở.');
    expect(find.text('VNĐ - VIỆT NAM ĐỒNG'), findsOneWidget,
        reason: 'Chưa đủ hai vế thì dòng "= …" trống nghĩa.');

    await goPhim(tester, ['3', '0', '000']);
    expect(find.text('50.000 + 30.000'), findsOneWidget);
    expect(find.text('= 80.000 đ'), findsOneWidget,
        reason: 'Lưới Stitch KHÔNG có phím `=`, nên ✓ vừa rút gọn vừa lưu '
            'trong một nhịp. Dòng này là chỗ duy nhất tổng hiện ra được '
            'TRƯỚC khi giao dịch được ghi — thiếu nó là người dùng bấm lưu '
            'một con số chưa từng nhìn thấy.');
    expect(find.text('VNĐ - VIỆT NAM ĐỒNG'), findsNothing);
  });

  testWidgets('phím trừ vẽ dấu trừ thật `−`, không phải gạch nối',
      (tester) async {
    await tester.pumpWidget(app(FakeTransactionRepository()));
    await tester.pumpAndSettle();

    expect(find.text('−'), findsOneWidget,
        reason: 'Dòng số dùng `−` (U+2212); lưới dùng `-` là hai ký hiệu cho '
            'cùng một phép.');
    expect(find.text('-'), findsNothing);
  });
}
