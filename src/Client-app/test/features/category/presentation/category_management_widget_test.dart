import 'dart:async';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/presentation/pages/category_add_page.dart';
import 'package:flowmoney/features/category/presentation/pages/category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 21);

  Category category({
    required String id,
    required String name,
    String classify = 'chi',
    bool isGroup = false,
    bool isDefault = false,
    String? parentId,
  }) =>
      Category(
        id: id,
        idaccount: 1,
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
        updatedAt: now,
      );

  Widget app(Widget child) => MaterialApp(home: child);

  testWidgets(
      'renders management tree sections and keeps defaults keyword-only',
      (tester) async {
    final group = category(id: 'group-home', name: 'Nhóm nhà', isGroup: true);
    final child = category(
      id: 'rent',
      name: 'Tiền nhà',
      parentId: group.id,
    );
    final ungrouped = category(id: 'coffee', name: 'Cà phê');
    final defaultCategory = category(
      id: 'default-food',
      name: 'Ăn uống',
      isDefault: true,
    );
    final repository = _FakeCategoryRepository(
      tree: CategoryTree(
        groups: [
          CategoryGroupNode(group: group, children: [child])
        ],
        ungroupedChildren: [ungrouped],
        defaultChildren: [defaultCategory],
      ),
    );

    await tester.pumpWidget(app(CategoryPage(
      repository: repository,
      accountId: 1,
    )));
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
  });

  testWidgets(
      'keyword-only child route omits category fields and saves keywords',
      (tester) async {
    final repository = _FakeCategoryRepository();

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
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('GrabFood'), findsOneWidget);
    expect(find.text('đồ ăn'), findsOneWidget);

    await tester.tap(find.text('Lưu từ khóa'));
    await tester.pump();
    expect(repository.savedKeywords, ['GrabFood', 'đồ ăn']);
  });

  testWidgets('confirming a different-type parent applies its type once',
      (tester) async {
    final incomeGroup = category(
      id: 'income-group',
      name: 'Nhóm thu',
      classify: 'thu',
      isGroup: true,
    );
    final repository = _FakeCategoryRepository(
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
  });

  testWidgets('cancelling a different-type parent keeps the child ungrouped',
      (tester) async {
    final incomeGroup = category(
      id: 'income-group',
      name: 'Nhóm thu',
      classify: 'thu',
      isGroup: true,
    );
    final repository = _FakeCategoryRepository(
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
}

class _FakeCategoryRepository implements CategoryManagementRepository {
  _FakeCategoryRepository(
      {CategoryTree? tree, Map<String, CategoryTree>? trees})
      : _trees = trees ?? {'chi': tree ?? _emptyTree};

  static final _emptyTree = CategoryTree(
    groups: const [],
    ungroupedChildren: const [],
    defaultChildren: const [],
  );

  final Map<String, CategoryTree> _trees;
  List<String>? savedKeywords;
  CategoryChildDraft? savedChild;

  @override
  Stream<CategoryTree> watchTree({
    required int accountId,
    required String classify,
  }) =>
      Stream.value(_trees[classify] ?? _emptyTree);

  @override
  Future<CategoryTree> loadTree({
    required int accountId,
    required String classify,
  }) async =>
      _trees[classify] ?? _emptyTree;

  @override
  Future<void> saveKeywords({
    required int accountId,
    required String categoryId,
    required Iterable<String> keywords,
  }) async {
    savedKeywords = keywords.toList();
  }

  @override
  Future<List<String>> loadKeywords({
    required int accountId,
    required String categoryId,
  }) async =>
      const [];

  @override
  Future<void> saveChild(CategoryChildDraft draft) async {
    savedChild = draft;
  }

  @override
  Future<void> saveGroup(CategoryGroupDraft draft) async {}

  @override
  Future<void> deleteChild({
    required int accountId,
    required String childId,
  }) async {}

  @override
  Future<void> deleteGroup({
    required int accountId,
    required String groupId,
  }) async {}

  @override
  Future<List<Category>> selectableChildren({
    required int accountId,
    required String classify,
  }) async =>
      const [];
}
