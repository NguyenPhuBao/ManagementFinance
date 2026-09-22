/// Cờ "Cố định — AI không đề xuất cắt" (Edge-SLM P2, schema v24): đường ghi
/// qua `saveChild` và công tắc ở màn Thêm/Sửa danh mục.
///
/// ⚠️ `categoryDao.insert` là `insertOrReplace`: cột không gán thì về mặc định.
/// Ca "sửa lần hai giữ nguyên cờ" canh đúng chỗ ấy — thiếu `aiCoDinh` trong
/// companion là mỗi lần sửa tên lặng lẽ tắt cờ.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/presentation/pages/category_add_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'presentation/category_test_fakes.dart';

CategoryChildDraft _draft({String? id, required bool aiCoDinh, String ten = 'Tiền nhà'}) =>
    CategoryChildDraft(
      id: id,
      accountId: 7,
      name: ten,
      classify: 'chi',
      parentId: null,
      icon: 'home',
      colour: '#10B981',
      keywords: const [],
      aiCoDinh: aiCoDinh,
    );

void main() {
  group('repository', () {
    late AppDatabase db;
    late CategoryManagementRepositoryImpl repo;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CategoryManagementRepositoryImpl(db: db);
    });
    tearDown(() => db.close());

    test('saveChild ghi cờ; sửa lại với cờ tắt thì tắt', () async {
      await repo.saveChild(_draft(aiCoDinh: true));
      var rows = await db.categoryDao.getAll(7);
      expect(rows.single.aiCoDinh, isTrue);

      await repo.saveChild(_draft(id: rows.single.id, aiCoDinh: false));
      rows = await db.categoryDao.getAll(7);
      expect(rows.single.aiCoDinh, isFalse);
    });

    test('sửa tên mà vẫn truyền cờ bật → cờ còn (insertOrReplace không xoá)',
        () async {
      await repo.saveChild(_draft(aiCoDinh: true));
      final id = (await db.categoryDao.getAll(7)).single.id;
      await repo.saveChild(_draft(id: id, aiCoDinh: true, ten: 'Thuê nhà'));
      final row = (await db.categoryDao.getAll(7)).single;
      expect(row.name, 'Thuê nhà');
      expect(row.aiCoDinh, isTrue);
    });

    test('draft không nói gì về cờ → mặc định false', () {
      expect(
          CategoryChildDraft(
            accountId: 7,
            name: 'x',
            classify: 'chi',
            parentId: null,
            icon: 'home',
            colour: '#000000',
            keywords: const [],
          ).aiCoDinh,
          isFalse);
    });
  });

  group('màn Thêm/Sửa danh mục', () {
    final congTac = find.byKey(const ValueKey('cong-tac-ai-co-dinh'));

    testWidgets('bật công tắc rồi Lưu → draft mang aiCoDinh = true',
        (tester) async {
      final repository = FakeCategoryRepository();
      await tester.pumpWidget(MaterialApp(
          home: CategoryAddPage(repository: repository, accountId: 1)));
      await tester.pumpAndSettle();

      final oTen = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'e.g. Thuê nhà');
      await tester.enterText(oTen, 'Tiền nhà');

      // Công tắc nằm trong ListView lười dựng — ngoài khung 800×600 thì widget
      // CHƯA tồn tại, `ensureVisible` ném StateError. Phải cuộn tới.
      await tester.scrollUntilVisible(congTac, 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.widget<Switch>(congTac).value, isFalse,
          reason: 'mặc định tắt');
      await tester.tap(congTac);
      await tester.pump();
      expect(tester.widget<Switch>(congTac).value, isTrue);

      expect(find.text('Chỉ lưu trên máy này'), findsOneWidget);

      final nutLuu = find.widgetWithText(ElevatedButton, 'Lưu danh mục');
      await tester.ensureVisible(nutLuu);
      await tester.tap(nutLuu);
      await tester.pumpAndSettle();

      expect(repository.savedChild, isNotNull);
      expect(repository.savedChild!.aiCoDinh, isTrue);
    });

    testWidgets('không chạm công tắc → draft mang false', (tester) async {
      final repository = FakeCategoryRepository();
      await tester.pumpWidget(MaterialApp(
          home: CategoryAddPage(repository: repository, accountId: 1)));
      await tester.pumpAndSettle();
      final oTen = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'e.g. Thuê nhà');
      await tester.enterText(oTen, 'Ăn uống');
      final nutLuu = find.widgetWithText(ElevatedButton, 'Lưu danh mục');
      await tester.ensureVisible(nutLuu);
      await tester.tap(nutLuu);
      await tester.pumpAndSettle();
      expect(repository.savedChild!.aiCoDinh, isFalse);
    });

    testWidgets('màn chỉ-từ-khoá (danh mục mặc định) không có công tắc',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: CategoryAddPage(
        categoryId: 'default-food',
        keywordOnly: true,
        repository: FakeCategoryRepository(),
        accountId: 1,
      )));
      await tester.pump();
      expect(congTac, findsNothing);
    });

    testWidgets('không tràn bố cục ở 411dp với công tắc', (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
          home: CategoryAddPage(
              repository: FakeCategoryRepository(), accountId: 1)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(congTac, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
