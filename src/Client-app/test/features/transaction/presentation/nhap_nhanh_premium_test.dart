/// Ô Nhập nhanh là đặc quyền Premium (spec Premium 2026-10-06 mục 8.2, người
/// dùng chốt "khoá cả ô"): Basic thấy ô mờ không gõ được, không nút Điền, có
/// nút Nâng cấp; phần còn lại của form (số tiền, danh mục, ví, ghi chú) dùng
/// tay như cũ. Điền sẵn từ D1 / biên lai / C3 không qua ô này nên không đổi.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt');

  Widget app({required bool? laPremium}) {
    CategoryTree cay(List<Category> c) =>
        CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
    final bloc = TransactionBloc(transactionRepository: FakeTransactionRepository());
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/add',
          builder: (_, __) => AddTransactionPage(
            transactionBloc: bloc,
            categoryRepository: FakeCategoryRepository(
              trees: {'chi': cay([anUong]), 'thu': cay(const []), 'vay_no': cay(const [])},
              selectable: [anUong],
            ),
            wallets: [tienMat],
            idaccount: 1,
            budgetLookup: (_, __) async => null,
            laPremium: laPremium,
          ),
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router);
  }

  TextField oNhapNhanh(WidgetTester t) =>
      t.widget<TextField>(find.byKey(const Key('nhap-nhanh-o')));

  testWidgets('Basic: ô Nhập nhanh tắt, không nút Điền, có nút Nâng cấp; form còn lại vẫn dùng',
      (tester) async {
    await tester.pumpWidget(app(laPremium: false));
    await tester.pumpAndSettle();
    final o = oNhapNhanh(tester);
    expect(o.enabled, isFalse);
    expect(o.decoration?.hintText, 'Chỉ Premium');
    expect(find.byKey(const Key('nhap-nhanh-dien')), findsNothing);
    expect(find.byKey(const Key('nut-nang-cap')), findsOneWidget);
    expect(find.text('Nâng cấp để đọc câu bằng AI'), findsOneWidget);
    expect(find.byKey(const Key('ghi-chu-giao-dich')), findsOneWidget,
        reason: 'phần còn lại của form không đổi');
  });

  testWidgets('Premium: như cũ', (tester) async {
    await tester.pumpWidget(app(laPremium: true));
    await tester.pumpAndSettle();
    expect(oNhapNhanh(tester).enabled, isTrue);
    expect(find.byKey(const Key('nhap-nhanh-dien')), findsOneWidget);
    expect(find.byKey(const Key('nut-nang-cap')), findsNothing);
  });

  testWidgets('null + không GoiCubit trong cây = không khoá (test cũ)', (tester) async {
    await tester.pumpWidget(app(laPremium: null));
    await tester.pumpAndSettle();
    expect(oNhapNhanh(tester).enabled, isTrue);
  });

  testWidgets('360 × 640 Basic không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(laPremium: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
