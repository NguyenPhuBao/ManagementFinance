/// B1 — thẻ "Gợi ý danh mục" của màn Thêm giao dịch: mô hình HỌC đi trước, bảng từ khoá chỉ khi mô hình chưa đủ để
/// nói, và dòng lý do đổi chữ theo nguồn.
///
/// Phép tính Naive Bayes có bộ test riêng (`category/domain/phan_loai_ghi_chu_test.dart`); ở đây chỉ kiểm CHỖ NỐI.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

MauGhiChu _m(String c, String ghiChu) =>
    MauGhiChu(categoryId: c, amTiet: amTietCua(ghiChu), ngay: DateTime(2026, 9, 1));

/// Mười mẫu của `phan_loai_ghi_chu_test.dart`, id đổi theo danh mục giả: *"grab"* là Di chuyển 4/4 lần.
final _muoiMau = [
  _m('move', 'grab đi làm'), _m('move', 'grab về nhà'), _m('move', 'Grab'), _m('move', 'xăng xe'),
  _m('move', 'grab sân bay'),
  _m('food', 'cafe sáng'), _m('food', 'cafe'), _m('food', 'cơm trưa'), _m('food', 'ăn sáng'), _m('food', 'cafe chiều'),
];

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final diChuyen = makeCategory(id: 'move', name: 'Di chuyển', isDefault: true);

  CategoryTree treeOf(List<Category> defaults) => CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: defaults,
      );

  FakeCategoryRepository categories({Map<String, List<String>> keywords = const {}}) => FakeCategoryRepository(
        trees: {
          'chi': treeOf([anUong, diChuyen]),
          'thu': treeOf(const []),
          'vay_no': treeOf(const []),
        },
        selectable: [anUong, diChuyen],
        keywords: keywords,
      );

  Widget app({
    BoPhanLoaiGhiChu? boPhanLoai,
    Map<String, List<String>> keywords = const {},
    EditTransactionArgs? initial,
  }) {
    final bloc = TransactionBloc(transactionRepository: FakeTransactionRepository());
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
                categoryRepository: categories(keywords: keywords),
                wallets: [makeWallet()],
                idaccount: 1,
                boPhanLoai: boPhanLoai,
                initial: initial,
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> goGhiChu(WidgetTester tester, String ghiChu) async {
    await tester.enterText(find.byType(TextField), ghiChu);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ gợi ý HỌC hiện kèm câu lý do theo nguồn học', (tester) async {
    await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau)));
    await tester.pumpAndSettle();

    await goGhiChu(tester, 'grab tối');
    expect(find.text('Gợi ý danh mục'), findsOneWidget);
    expect(find.text('Di chuyển'), findsOneWidget);
    expect(find.text('Bạn thường ghi “grab” cho Di chuyển (4/4 lần).'), findsOneWidget);
    expect(find.textContaining('Khớp với'), findsNothing, reason: 'câu của nguồn từ khoá không được in cho nguồn học');
  });

  testWidgets('⭐ mô hình học ĐI TRƯỚC từ khoá — cùng ghi chú mà từ khoá chỉ sang danh mục khác', (tester) async {
    await tester.pumpWidget(app(
      boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau),
      keywords: {
        'food': ['grab'],
      },
    ));
    await tester.pumpAndSettle();

    await goGhiChu(tester, 'grab tối');
    expect(find.text('Di chuyển'), findsOneWidget);
    expect(find.text('Ăn uống'), findsNothing);
  });

  testWidgets('mô hình chưa đủ để nói (null) → thẻ từ khoá như cũ', (tester) async {
    await tester.pumpWidget(app(
      boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau),
      keywords: {
        'food': ['điện'],
      },
    ));
    await tester.pumpAndSettle();

    await goGhiChu(tester, 'điện thoại');
    expect(find.text('Gợi ý danh mục'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Khớp với “điện” trong ghi chú.'), findsOneWidget);
  });

  testWidgets('bấm "Chọn danh mục này" → danh mục được chọn là Di chuyển', (tester) async {
    await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau)));
    await tester.pumpAndSettle();

    await goGhiChu(tester, 'grab tối');
    await tester.ensureVisible(find.text('Chọn danh mục này'));
    await tester.tap(find.text('Chọn danh mục này'));
    await tester.pumpAndSettle();
    expect(find.text('Gợi ý danh mục'), findsNothing);
    expect(find.text('Di chuyển'), findsOneWidget, reason: 'hàng Danh mục nay mang tên danh mục đã chọn');
  });

  testWidgets('chế độ sửa (đã có danh mục) → gõ ghi chú không hiện thẻ', (tester) async {
    final goc = TransactionEntity(
      id: 't1',
      walletId: 'cash',
      idaccount: 1,
      categoryId: 'food',
      amount: 25000,
      type: 'chi',
      note: 'cafe',
      date: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    await tester.pumpWidget(app(
      boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau),
      initial: EditTransactionArgs(transaction: goc, category: anUong),
    ));
    await tester.pumpAndSettle();

    await goGhiChu(tester, 'grab tối');
    expect(find.text('Gợi ý danh mục'), findsNothing);
  });
}
