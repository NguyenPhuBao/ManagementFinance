import 'dart:async';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/presentation/pages/category_add_page.dart';
import 'package:flowmoney/features/category/presentation/pages/category_group_page.dart';
import 'package:flowmoney/features/category/presentation/pages/category_page.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'category_test_fakes.dart';

void main() {
  final now = DateTime(2026, 8, 21);

  Category category({
    required String id,
    required String name,
    int idaccount = 1,
    String classify = 'chi',
    bool isGroup = false,
    bool isDefault = false,
    String? parentId,
  }) =>
      Category(
        id: id,
        idaccount: idaccount,
        name: name,
        classify: classify,
        icon: 'category',
        colour: '#10B981',
        parentId: parentId,
        isGroup: isGroup,
        isDefault: isDefault,
        isDeleted: false,
        isLocalOnly: !isDefault,
        syncStatus: 'pending',
        syncRetryCount: 0,
        updatedAt: now,
      );

  Widget app(Widget child) => MaterialApp(home: child);

  Widget categoryRouter(FakeCategoryRepository repository) {
    final router = GoRouter(
      initialLocation: '/categories',
      routes: [
        GoRoute(
          path: '/categories',
          builder: (_, __) =>
              CategoryPage(repository: repository, accountId: 1),
        ),
        GoRoute(
          path: '/categories/:id/keywords',
          builder: (_, state) => CategoryAddPage(
            categoryId: state.pathParameters['id']!,
            keywordOnly: true,
            repository: repository,
            accountId: 1,
          ),
        ),
        GoRoute(
          path: '/categories/child/new',
          builder: (_, __) => const Scaffold(body: Text('Tạo danh mục con')),
        ),
        GoRoute(
          path: '/categories/group/new',
          builder: (_, __) => const Scaffold(body: Text('Tạo nhóm danh mục')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets(
      'renders management tree sections and keeps defaults keyword-only',
      (tester) async {
    final group = category(id: 'group-home', name: 'Nhóm nhà', isGroup: true);
    final child = category(
      id: 'rent',
      name: 'Tiền nhà',
      idaccount: 0,
      isDefault: true,
    );
    final ungrouped = category(id: 'coffee', name: 'Cà phê');
    final defaultCategory = category(
      id: 'default-food',
      name: 'Ăn uống',
      isDefault: true,
    );
    final repository = FakeCategoryRepository(
      tree: CategoryTree(
        groups: [
          CategoryGroupNode(group: group, children: [child])
        ],
        ungroupedChildren: [ungrouped],
        defaultChildren: [defaultCategory],
      ),
    );

    await tester.pumpWidget(categoryRouter(repository));
    await tester.pump();

    expect(find.text('Nhóm của bạn'), findsOneWidget);
    expect(find.text('Chưa nhóm'), findsOneWidget);
    expect(find.text('Danh mục mặc định'), findsWidgets);
    expect(find.text('Từ khóa của tôi'), findsWidgets);
    expect(find.byTooltip('Sửa danh mục mặc định'), findsNothing);
    expect(find.byTooltip('Xóa danh mục mặc định'), findsNothing);

    await tester.tap(find.text('Nhóm nhà'));
    await tester.pump();
    expect(find.text('Tiền nhà'), findsOneWidget);

    await tester.tap(find.text('Tiền nhà'));
    await tester.pumpAndSettle();
    expect(find.text('Từ khóa của tôi'), findsWidgets);
    expect(find.text('Tên danh mục'), findsNothing);
    expect(find.text('Loại giao dịch'), findsNothing);
    expect(find.text('Nhóm cha'), findsNothing);
  });

  testWidgets('add menu opens the parent-group creation route', (tester) async {
    final repository = FakeCategoryRepository();

    await tester.pumpWidget(categoryRouter(repository));
    await tester.pump();

    await tester.tap(find.byTooltip('Thêm danh mục'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo danh mục con'), findsOneWidget);
    expect(find.text('Tạo nhóm danh mục'), findsOneWidget);

    await tester.tap(find.text('Tạo nhóm danh mục'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo nhóm danh mục'), findsOneWidget);
  });

  testWidgets('tên danh mục dừng ở độ rộng cột trên server — G31',
      (tester) async {
    await tester.pumpWidget(app(CategoryAddPage(
      repository: FakeCategoryRepository(),
      accountId: 1,
    )));
    await tester.pumpAndSettle();
    final oTen = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'e.g. Thuê nhà');
    final boDieuKhien = tester.widget<TextField>(oTen).controller!;

    await tester.enterText(oTen, 'a' * (DoRongCot.tenDanhMuc + 50));
    await tester.pump();

    expect(boDieuKhien.text.length, DoRongCot.tenDanhMuc,
        reason: '`category.NameCategory` là varchar(200). Tên dài hơn vỡ P2000 '
            'ở /sync/push và danh mục bị gửi lại ở mọi chu kỳ đồng bộ.');
  });

  testWidgets('tên nhóm danh mục cũng dừng ở độ rộng cột — G31',
      (tester) async {
    await tester.pumpWidget(app(CategoryGroupPage(
      repository: FakeCategoryRepository(),
      accountId: 1,
    )));
    await tester.pumpAndSettle();
    final oTen = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.hintText == 'e.g. Chi tiêu Sinh hoạt');
    final boDieuKhien = tester.widget<TextField>(oTen).controller!;

    await tester.enterText(oTen, 'a' * (DoRongCot.tenDanhMuc + 50));
    await tester.pump();

    expect(boDieuKhien.text.length, DoRongCot.tenDanhMuc,
        reason: 'Nhóm cũng là một hàng `category` (Is_group = true), ghi vào '
            'cùng cột NameCategory — màn này là đường ghi thứ hai.');
  });

  testWidgets(
      'keyword-only child route omits category fields and saves keywords',
      (tester) async {
    final repository = FakeCategoryRepository();

    await tester.pumpWidget(app(CategoryAddPage(
      categoryId: 'default-food',
      keywordOnly: true,
      repository: repository,
      accountId: 1,
    )));
    await tester.pump();

    expect(find.text('Từ khóa của tôi'), findsWidgets);
    expect(find.text('Tên danh mục'), findsNothing);
    expect(find.text('Loại giao dịch'), findsNothing);
    expect(find.text('Nhóm cha'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('keyword-input')), 'GrabFood, đồ ăn');
    await tester.pump();
    expect(find.text('GrabFood'), findsOneWidget);
    expect(find.text('đồ ăn'), findsOneWidget);

    await tester.tap(find.text('Lưu từ khóa'));
    await tester.pump();
    expect(repository.savedKeywords, ['GrabFood', 'đồ ăn']);
  });

  testWidgets('direct default child edit opens keyword-only UI',
      (tester) async {
    final defaultCategory = category(
      id: 'default-food',
      name: 'Ăn uống',
      idaccount: 0,
      isDefault: true,
    );
    final repository = FakeCategoryRepository(
      tree: CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: [defaultCategory],
      ),
    );

    await tester.pumpWidget(app(CategoryAddPage(
      categoryId: defaultCategory.id,
      repository: repository,
      accountId: 1,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Từ khóa của tôi'), findsWidgets);
    expect(find.text('Tên danh mục'), findsNothing);
    expect(find.text('Loại giao dịch'), findsNothing);
    expect(find.text('Nhóm cha'), findsNothing);
  });

  testWidgets(
      'default category is a selectable read-only member in the group form',
      (tester) async {
    final defaultCategory = category(
      id: 'default-food',
      name: 'Ăn uống',
      idaccount: 0,
      isDefault: true,
    );
    final repository = FakeCategoryRepository(selectable: [defaultCategory]);

    await tester.pumpWidget(app(CategoryGroupPage(
      repository: repository,
      accountId: 1,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Ăn uống'), findsOneWidget);
    expect(
      find.text('Danh mục mặc định • Chỉ có thể sửa từ khóa'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ăn uống'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Chi tiêu hàng ngày');
    await tester.tap(find.text('Lưu Nhóm Danh Mục'));
    await tester.pump();

    expect(repository.savedGroup?.childIds, [defaultCategory.id]);
  });

  testWidgets('confirming a different-type parent applies its type once',
      (tester) async {
    final incomeGroup = category(
      id: 'income-group',
      name: 'Nhóm thu',
      classify: 'thu',
      isGroup: true,
    );
    final repository = FakeCategoryRepository(
      trees: {
        'chi': CategoryTree(
          groups: const [],
          ungroupedChildren: const [],
          defaultChildren: const [],
        ),
        'thu': CategoryTree(
          groups: [CategoryGroupNode(group: incomeGroup, children: const [])],
          ungroupedChildren: const [],
          defaultChildren: const [],
        ),
        'vay_no': CategoryTree(
          groups: const [],
          ungroupedChildren: const [],
          defaultChildren: const [],
        ),
      },
    );

    await tester.pumpWidget(app(CategoryAddPage(
      repository: repository,
      accountId: 1,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('parent-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhóm thu').last);
    await tester.pumpAndSettle();

    expect(find.text('Đổi loại giao dịch?'), findsOneWidget);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Khoản thu'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Lương');
    await tester.tap(find.text('Lưu danh mục'));
    await tester.pump();
    expect(repository.savedChild?.parentId, incomeGroup.id);
    expect(repository.savedChild?.classify, 'thu');
  });

  testWidgets('cancelling a different-type parent keeps the child ungrouped',
      (tester) async {
    final incomeGroup = category(
      id: 'income-group',
      name: 'Nhóm thu',
      classify: 'thu',
      isGroup: true,
    );
    final repository = FakeCategoryRepository(
      trees: {
        'chi': CategoryTree(
          groups: const [],
          ungroupedChildren: const [],
          defaultChildren: const [],
        ),
        'thu': CategoryTree(
          groups: [CategoryGroupNode(group: incomeGroup, children: const [])],
          ungroupedChildren: const [],
          defaultChildren: const [],
        ),
        'vay_no': CategoryTree(
          groups: const [],
          ungroupedChildren: const [],
          defaultChildren: const [],
        ),
      },
    );

    await tester.pumpWidget(app(CategoryAddPage(
      repository: repository,
      accountId: 1,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('parent-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhóm thu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Cà phê');
    await tester.tap(find.text('Lưu danh mục'));
    await tester.pump();
    expect(repository.savedChild?.parentId, isNull);
    expect(repository.savedChild?.classify, 'chi');
  });

  testWidgets('grouped default remains a transaction-picker leaf target',
      (tester) async {
    final group = category(id: 'group-food', name: 'Ăn uống', isGroup: true);
    final child = category(
      id: 'grab-food',
      name: 'GrabFood',
      idaccount: 0,
      isDefault: true,
    );
    final repository = FakeCategoryRepository(
      tree: CategoryTree(
        groups: [
          CategoryGroupNode(group: group, children: [child])
        ],
        ungroupedChildren: const [],
        defaultChildren: const [],
      ),
    );
    Category? returned;
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  returned = await context.push<Category>('/category');
                },
                child: const Text('Mở chọn danh mục'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/category',
          builder: (context, state) => ChooseCategoryPage(
            repository: repository,
            idaccount: 1,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Mở chọn danh mục'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ăn uống'));
    await tester.pump();
    expect(returned, isNull);
    expect(find.text('GrabFood'), findsOneWidget);

    await tester.tap(find.text('GrabFood'));
    await tester.pumpAndSettle();
    expect(returned?.id, child.id);
  });

  testWidgets('suggestion is shown without selection and applies on acceptance',
      (tester) async {
    final food = category(id: 'food', name: 'Ăn uống');
    final repository = FakeCategoryRepository(
      selectable: [food],
      keywords: {
        food.id: ['grabfood']
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTransactionPage(
          transactionBloc: TransactionBloc(
            transactionRepository: FakeTransactionRepository(),
          ),
          categoryRepository: repository,
          wallets: [makeWallet()],
          idaccount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Thanh toán GrabFood');
    // Ô ghi chú có debounce 300ms (xem `_doTreGoiY`): phải chờ qua mốc đó thì
    // việc tra cứu gợi ý mới bắt đầu.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Gợi ý danh mục'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Chọn danh mục'), findsOneWidget);

    await tester.tap(find.text('Chọn danh mục này'));
    await tester.pump();
    expect(find.text('Gợi ý danh mục'), findsNothing);
    expect(find.text('Ăn uống'), findsOneWidget);
  });

  testWidgets('ignores a delayed suggestion after the transaction type changes',
      (tester) async {
    final food = category(id: 'food', name: 'Ăn uống');
    final expenseCategories = Completer<List<Category>>();
    final repository = FakeCategoryRepository(
      selectableLoader: (_, classify) =>
          classify == 'chi' ? expenseCategories.future : Future.value(const []),
      keywords: {
        food.id: ['grabfood']
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTransactionPage(
          transactionBloc: TransactionBloc(
            transactionRepository: FakeTransactionRepository(),
          ),
          categoryRepository: repository,
          wallets: [makeWallet()],
          idaccount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Thanh toán GrabFood');
    // Chờ qua debounce để việc tra cứu THẬT SỰ bắt đầu — đó mới là tình huống
    // test này canh: một kết quả về muộn sau khi người dùng đã đổi loại giao dịch.
    await tester.pump(const Duration(milliseconds: 350));
    tester
        .widget<GestureDetector>(find.byKey(const Key('transaction-type-1')))
        .onTap!();
    await tester.pump();

    expenseCategories.complete([food]);
    await tester.pumpAndSettle();

    expect(find.text('Gợi ý danh mục'), findsNothing);
  });

  testWidgets('gõ liên tiếp chỉ tra cứu MỘT lần sau khi ngừng gõ',
      (tester) async {
    final food = category(id: 'food', name: 'Ăn uống');
    final repository = FakeCategoryRepository(
      selectable: [food],
      keywords: {
        food.id: ['grabfood']
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTransactionPage(
          transactionBloc: TransactionBloc(
            transactionRepository: FakeTransactionRepository(),
          ),
          categoryRepository: repository,
          wallets: [makeWallet()],
          idaccount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.soLanDocDanhMuc = 0;
    repository.soLanDocTuKhoa = 0;

    // Mô phỏng người dùng gõ từng ký tự. `TextEditingController` phát tín hiệu
    // ở MỖI ký tự, nên trước bản vá này mỗi ký tự là một lượt đọc CSDL đầy đủ.
    for (final chu in ['T', 'Th', 'Tha', 'Than', 'Thanh']) {
      await tester.enterText(find.byType(TextField), chu);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(
      repository.soLanDocDanhMuc,
      0,
      reason: 'Trong lúc người dùng còn đang gõ thì chưa được tra cứu gì. '
          'Không có debounce thì gõ một ghi chú 30 ký tự sinh 30 lượt đọc, mỗi '
          'lượt lại đọc thêm từ khoá — trên máy yếu là giật thấy rõ.',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      repository.soLanDocDanhMuc,
      1,
      reason: 'Ngừng gõ thì tra cứu đúng MỘT lần.',
    );
    expect(
      repository.soLanDocTuKhoa,
      1,
      reason: 'Và từ khoá phải đọc bằng MỘT truy vấn gộp cho cả tài khoản, '
          'không phải một truy vấn cho mỗi danh mục. Trước bản vá này chỗ gọi '
          'là `categories.map((c) => loadKeywords(categoryId: c.id))` — tài '
          'khoản có 20 danh mục là 20 truy vấn, nhân với mỗi ký tự gõ vào.',
    );
  });
}

