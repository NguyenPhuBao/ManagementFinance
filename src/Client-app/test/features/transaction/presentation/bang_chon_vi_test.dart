/// Bảng *Chọn ví thanh toán* của màn Thêm giao dịch — tràn đáy khi tài khoản có nhiều ví.
///
/// Đo trên OnePlus 13R 2026-09-30 (nghiệm thu D1): tài khoản có 5 ví → bảng **tràn 13 px**, ví thứ năm bị sọc vàng
/// đè và không chạm được. Bảng dựng một `Column` không cuộn trong bottom sheet mặc định (trần 9/16 màn) — cùng họ G60
/// (bảng chọn thứ tràn ở màn thấp). Có từ trước D1.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  List<Wallet> vi(int n) => [
        for (var i = 0; i < n; i++)
          makeWallet(id: 'w$i', name: 'Ví số $i').copyWith(isDefault: i == 0),
      ];

  Future<void> mo(WidgetTester tester, List<Wallet> ds) async {
    CategoryTree cay(List<Category> c) =>
        CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/add',
          builder: (_, __) => AddTransactionPage(
            transactionBloc: TransactionBloc(transactionRepository: FakeTransactionRepository()),
            categoryRepository: FakeCategoryRepository(
              trees: {'chi': cay(const []), 'thu': cay(const []), 'vay_no': cay(const [])},
              selectable: const [],
            ),
            wallets: ds,
            idaccount: 1,
            budgetLookup: (_, __) async => null,
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ví số 0 • 100.000 đ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ví số 0 • 100.000 đ'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn ví thanh toán'), findsOneWidget, reason: 'tiền đề: bảng đã mở');
  }

  for (final (ten, co, dpr) in [
    ('OnePlus 13R (1264 × 2780, dpr 3)', const Size(1264, 2780), 3.0),
    ('360 × 640', const Size(360, 640), 1.0),
  ]) {
    testWidgets('⭐ $ten: 5 ví không tràn, ví CUỐI chạm được', (tester) async {
      tester.view.physicalSize = co;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);

      await mo(tester, vi(5));
      expect(tester.takeException(), isNull, reason: 'đo thật: tràn 13 px, ví thứ năm bị sọc vàng đè');

      await tester.ensureVisible(find.text('Ví số 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ví số 4'));
      await tester.pumpAndSettle();
      expect(find.text('Ví số 4 • 100.000 đ'), findsOneWidget, reason: 'ví cuối phải chọn được');
    });
  }

  testWidgets('12 ví ở 360 × 640: bảng cuộn, không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mo(tester, vi(12));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ví số 11'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ví số 11'));
    await tester.pumpAndSettle();
    expect(find.text('Ví số 11 • 100.000 đ'), findsOneWidget);
  });
}
