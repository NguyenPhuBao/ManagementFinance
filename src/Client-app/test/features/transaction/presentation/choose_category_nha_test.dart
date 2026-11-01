/// Bộ chọn danh mục ở chế độ nhà (gia đình 1B, Task 3): cây do `napCay` cấp, không đọc repository cá nhân, không cần phiên;
/// nút dưới đẩy `duongQuanLy` hoặc ẩn khi `null`.
library;

import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  CategoryTree cay(String ten, {String classify = 'chi'}) => CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: [makeCategory(id: 'id-$ten', name: ten, classify: classify)],
      );

  testWidgets('hiện danh mục của napCay theo tab; chạm tab truyền classify mới; không cần repository lẫn phiên', (t) async {
    final goi = <String>[];
    await t.pumpWidget(MaterialApp(
      home: ChooseCategoryPage(
        classify: 'chi',
        // Cố ý KHÔNG truyền `repository`, `idaccount`, không có AuthBloc: trang mà đọc `sl<CategoryManagementRepository>()`
        // thì ném ở đây.
        napCay: (c) async {
          goi.add(c);
          return cay('Tiền chợ nhà $c', classify: c);
        },
        duongQuanLy: null,
      ),
    ));
    await t.pumpAndSettle();
    expect(goi, ['chi']);
    expect(find.text('Tiền chợ nhà chi'), findsOneWidget, reason: 'phải đòi có, không chỉ đòi vắng');
    await t.tap(find.byKey(const Key('category-classify-thu')));
    await t.pumpAndSettle();
    expect(goi, ['chi', 'thu'], reason: 'đổi tab nạp lại cây với classify mới');
    expect(find.text('Tiền chợ nhà thu'), findsOneWidget);
    expect(find.text('Tiền chợ nhà chi'), findsNothing);
  });

  testWidgets('duongQuanLy null ẩn nút Quản lý danh mục', (t) async {
    await t.pumpWidget(MaterialApp(
      home: ChooseCategoryPage(napCay: (c) async => cay('A'), duongQuanLy: null),
    ));
    await t.pumpAndSettle();
    expect(find.text('Quản lý danh mục'), findsNothing,
        reason: 'T3 chưa có route quản lý danh mục nhà: nút trỏ route chưa có là màn đỏ');
  });

  testWidgets('nút dưới push đúng duongQuanLy', (t) async {
    final router = GoRouter(initialLocation: '/chon', routes: [
      GoRoute(
        path: '/chon',
        builder: (_, __) => ChooseCategoryPage(napCay: (c) async => cay('A'), duongQuanLy: '/quan-ly'),
      ),
      GoRoute(path: '/quan-ly', builder: (_, __) => const Scaffold(body: Text('QUAN LY NHA'))),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    await t.tap(find.text('Quản lý danh mục'));
    await t.pumpAndSettle();
    expect(find.text('QUAN LY NHA'), findsOneWidget);
  });
}
