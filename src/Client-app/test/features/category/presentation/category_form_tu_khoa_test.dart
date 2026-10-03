/// G61 (2026-10-01) — form Thêm / Chỉnh sửa danh mục phải có ô từ khoá.
///
/// Trang nhập từ khoá riêng (`keywordOnly`) chỉ mở được từ hàng của mục *Danh mục mặc định*, mà mục ấy rỗng với mọi
/// tài khoản từ 2026-09-07 (`watchTree` trả `defaultChildren: const []`). Form sửa danh mục thường nạp và gửi lại từ
/// khoá nhưng không vẽ ô nhập — người dùng không thêm, không gỡ được từ khoá nào. Màn Stitch *Sửa danh mục*
/// (`a5a6ecb3…`) vốn có khối từ khoá ngay dưới thẻ Cố định.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/presentation/pages/category_add_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'category_test_fakes.dart';

Category _anUong() => Category(
      id: 'au',
      idaccount: 1,
      name: 'Ăn uống',
      classify: 'chi',
      icon: 'restaurant',
      colour: '#10B981',
      isGroup: false,
      // Bản sao riêng của tài khoản: KHÔNG phải hàng mặc định — đúng thứ người dùng thật đang có.
      isDefault: false,
      isDeleted: false,
      isLocalOnly: false,
      aiCoDinh: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 10, 1),
    );

FakeCategoryRepository _kho({List<String> tuKhoa = const ['food', 'grab']}) => FakeCategoryRepository(
      tree: CategoryTree(groups: const [], ungroupedChildren: [_anUong()], defaultChildren: const []),
      keywords: {'au': tuKhoa},
    );

Future<void> _dung(WidgetTester tester, Widget trang, {Size kho = const Size(411, 1600), ThemeData? theme}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = kho;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: theme, home: trang));
  await tester.pumpAndSettle();
}

final _oTuKhoa = find.byKey(const Key('keyword-input'));

void main() {
  testWidgets('⭐ form SỬA danh mục thường hiện từ khoá đã có và ô nhập', (tester) async {
    await _dung(tester, CategoryAddPage(categoryId: 'au', repository: _kho(), accountId: 1));

    expect(find.text('Chỉnh sửa danh mục'), findsOneWidget, reason: 'tiền đề: đây là form đầy đủ, không phải trang từ khoá');
    expect(find.text('Tên danh mục'), findsOneWidget);
    expect(_oTuKhoa, findsOneWidget, reason: 'G61 — không có ô này thì người dùng không có chỗ nào để gõ từ khoá');
    expect(find.widgetWithText(InputChip, 'food'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'grab'), findsOneWidget);
  });

  testWidgets('⭐ thêm một từ khoá, gỡ một từ khoá → Lưu danh mục gửi đúng danh sách mới', (tester) async {
    final kho = _kho();
    await _dung(tester, CategoryAddPage(categoryId: 'au', repository: kho, accountId: 1));

    await tester.enterText(_oTuKhoa, 'trà sữa,');
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'trà sữa'), findsOneWidget);

    await tester.tap(find.byTooltip('Gỡ từ khóa grab'));
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'grab'), findsNothing);

    await tester.tap(find.text('Lưu danh mục'));
    await tester.pump();
    expect(kho.savedChild?.keywords.toList(), ['food', 'trà sữa']);
    expect(kho.savedChild?.id, 'au');
  });

  testWidgets('chữ đang gõ dở (chưa Enter, chưa dấu phẩy) vẫn được lưu khi bấm Lưu danh mục', (tester) async {
    final kho = _kho();
    await _dung(tester, CategoryAddPage(categoryId: 'au', repository: kho, accountId: 1));

    await tester.enterText(_oTuKhoa, 'bún bò');
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'bún bò'), findsNothing, reason: 'tiền đề: chưa thành thẻ');

    await tester.tap(find.text('Lưu danh mục'));
    await tester.pump();
    expect(kho.savedChild?.keywords.toList(), ['food', 'grab', 'bún bò'],
        reason: 'gõ xong bấm Lưu là thao tác thường gặp nhất trên điện thoại — mất chữ ấy là mất im lặng');
  });

  testWidgets('trang từ khoá riêng cũng không làm mất chữ đang gõ dở', (tester) async {
    final kho = _kho();
    await _dung(tester, CategoryAddPage(categoryId: 'au', keywordOnly: true, repository: kho, accountId: 1));

    await tester.enterText(_oTuKhoa, 'bún bò');
    await tester.pump();
    await tester.tap(find.text('Lưu từ khóa'));
    await tester.pump();
    expect(kho.savedKeywords, ['food', 'grab', 'bún bò']);
  });

  testWidgets('form TẠO MỚI cũng có ô từ khoá, và từ khoá đi theo danh mục mới', (tester) async {
    final kho = FakeCategoryRepository();
    await _dung(tester, CategoryAddPage(repository: kho, accountId: 1));

    expect(find.text('Thêm danh mục mới'), findsOneWidget);
    await tester.enterText(_oTuKhoa, 'highlands, phúc long');
    await tester.pump();
    await tester.tap(find.text('Lưu danh mục'));
    await tester.pump();
    expect(kho.savedChild?.keywords.toList(), ['highlands', 'phúc long']);
  });

  testWidgets('theme thật, 360 × 640, nhiều từ khoá dài: cuộn tới được ô nhập, không tràn', (tester) async {
    final kho = _kho(tuKhoa: [
      'an uong',
      'food',
      'trà sữa trân châu đường đen',
      'cà phê sữa đá',
      'bún bò huế đặc biệt nhiều chả',
      'highlands coffee nguyễn trãi',
    ]);
    await _dung(
      tester,
      CategoryAddPage(categoryId: 'au', repository: kho, accountId: 1),
      kho: const Size(360, 640),
      theme: AppTheme.lightTheme,
    );

    await tester.scrollUntilVisible(_oTuKhoa, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(_oTuKhoa, findsOneWidget);
    expect(tester.takeException(), isNull);
    final o = tester.getRect(_oTuKhoa);
    expect(o.right, lessThanOrEqualTo(360));
    expect(o.width, greaterThan(200), reason: 'ô nhập phải đủ rộng để gõ ở 360 dp');
  });
}
