import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Canh chừng điều gì: danh mục có BA phân loại (chi / thu / vay_no) và trang
/// quản lý đã có đủ ba tab, nhưng bảng chọn danh mục khi tạo giao dịch từng
/// chỉ có hai — bốn danh mục vay/nợ mặc định vì thế tạo được mà không gán
/// được vào giao dịch nào (0 giao dịch ở cả server lẫn máy thật, 2026-09-05).
void main() {
  CategoryTree treeOf(List<Category> defaults) => CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: defaults,
      );

  FakeCategoryRepository repositoryWithAllThree() => FakeCategoryRepository(
        trees: {
          'chi': treeOf([
            makeCategory(id: 'food', name: 'Ăn uống', isDefault: true),
          ]),
          'thu': treeOf([
            makeCategory(
                id: 'salary', name: 'Lương', classify: 'thu', isDefault: true),
          ]),
          'vay_no': treeOf([
            makeCategory(
                id: 'lend', name: 'Cho vay', classify: 'vay_no', isDefault: true),
            makeCategory(
                id: 'borrow', name: 'Đi vay', classify: 'vay_no', isDefault: true),
          ]),
        },
      );

  Widget page(FakeCategoryRepository repository, {String classify = 'chi'}) =>
      MaterialApp(
        home: ChooseCategoryPage(
          repository: repository,
          idaccount: 1,
          classify: classify,
        ),
      );

  testWidgets('hiện đủ ba tab: Khoản chi, Khoản thu, Vay / nợ', (tester) async {
    await tester.pumpWidget(page(repositoryWithAllThree()));
    await tester.pumpAndSettle();

    expect(find.text('Khoản chi'), findsOneWidget);
    expect(find.text('Khoản thu'), findsOneWidget);
    expect(find.text('Vay / nợ'), findsOneWidget,
        reason: 'Thiếu tab này là danh mục vay/nợ không bao giờ chọn được '
            'khi tạo giao dịch.');
  });

  testWidgets('bấm tab Vay / nợ thì tải cây vay_no và hiện đúng danh mục ấy',
      (tester) async {
    final repository = repositoryWithAllThree();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống'), findsOneWidget);

    await tester.tap(find.text('Vay / nợ'));
    await tester.pumpAndSettle();

    expect(repository.loadedClassifies.last, 'vay_no',
        reason: 'Tab phải hỏi tầng dữ liệu đúng classify; DAO lọc so bằng '
            'chính xác nên gửi sai chuỗi là danh sách rỗng, không báo lỗi.');
    expect(find.text('Cho vay'), findsOneWidget);
    expect(find.text('Đi vay'), findsOneWidget);
    expect(find.text('Ăn uống'), findsNothing);
  });

  testWidgets('mở sẵn với classify vay_no thì tab ấy được chọn ngay',
      (tester) async {
    await tester.pumpWidget(
        page(repositoryWithAllThree(), classify: 'vay_no'));
    await tester.pumpAndSettle();

    expect(find.text('Cho vay'), findsOneWidget,
        reason: 'Trang thêm giao dịch mở bảng chọn ở tab của danh mục đang '
            'chọn; trước đây mọi giá trị khác "thu" đều rơi về tab chi.');
    expect(find.text('Ăn uống'), findsNothing);
  });
}
