/// B1 — thẻ "Gợi ý danh mục" của màn Thêm giao dịch: mô hình HỌC đi trước, bảng từ khoá chỉ khi mô hình chưa đủ để
/// nói, và dòng lý do đổi chữ theo nguồn.
///
/// Phép tính Naive Bayes có bộ test riêng (`category/domain/phan_loai_ghi_chu_test.dart`); ở đây chỉ kiểm CHỖ NỐI.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/goi_y_phan_hoi_store.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
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

/// Store trong bộ nhớ: ghi vào [hang], đọc trả [coSan].
class _StoreGia implements GoiYPhanHoiStore {
  _StoreGia([this.coSan = const []]);
  final List<PhanHoiGoiY> coSan;
  final List<({String nguon, String amTietChinh, String goiY, String ketQua, String? chon})> hang = [];

  @override
  Future<void> ghi({
    required int idaccount,
    required CategorySuggestion goiY,
    required String ketQua,
    String? chonCategoryId,
  }) async =>
      hang.add((
        nguon: goiY.nguon,
        amTietChinh: goiY.amTietChinh,
        goiY: goiY.categoryId,
        ketQua: ketQua,
        chon: chonCategoryId,
      ));

  @override
  Future<List<PhanHoiGoiY>> doc(int idaccount) async => coSan;
}

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
    GoiYPhanHoiStore? phanHoiGoiY,
    ThemeData? theme,
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
                phanHoiGoiY: phanHoiGoiY,
              ),
            ),
          ],
        ),
        // Trang thêm `push` CỨNG '/add/category' (như `app_router` thật) — route phải ở cấp gốc.
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: categories(keywords: keywords),
            idaccount: 1,
          ),
        ),
      ],
    );
    return MaterialApp.router(theme: theme, routerConfig: router);
  }

  Future<void> goGhiChu(WidgetTester tester, String ghiChu) async {
    await tester.enterText(find.byType(TextField), ghiChu);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ thẻ gợi ý dựng bằng THEME THẬT không tràn bố cục (bẫy 4.11)', (tester) async {
    // Theme của app ép mọi ElevatedButton rộng vô hạn (`app_theme.dart`); nút trần trong `Row` của thẻ làm trắng cả
    // vùng form mà không một dòng log nào. Nghiệm thu máy ảo 2026-09-29 bắt được (B1 Task 7) — lỗi có từ trước B1, thẻ
    // từ khoá cũng vỡ y hệt, và mọi ca khác của tệp này dựng MaterialApp trần nên mù.
    await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), theme: AppTheme.lightTheme));
    await tester.pumpAndSettle();

    await goGhiChu(tester, 'grab tối');
    expect(tester.takeException(), isNull);
    expect(find.text('Bạn thường ghi “grab” cho Di chuyển (4/4 lần).'), findsOneWidget);
    expect(find.text('Chọn danh mục này'), findsOneWidget);
  });

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

  group('B1 Task 5 — ghi phản hồi, thôi gợi ý cặp bị bỏ qua', () {
    Future<void> nhapVaLuu(WidgetTester tester) async {
      await tester.ensureVisible(find.text('5'));
      await tester.tap(find.text('5'));
      await tester.ensureVisible(find.text('000'));
      await tester.tap(find.text('000'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
    }

    Future<void> chonQuaBang(WidgetTester tester, String ten) async {
      await tester.ensureVisible(find.text('Danh mục'));
      await tester.tap(find.text('Danh mục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khoản chi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ten));
      await tester.pumpAndSettle();
    }

    testWidgets('⭐ bấm Chọn → một hàng chon, nguồn học, cụm "grab", gợi ý Di chuyển', (tester) async {
      final store = _StoreGia();
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: store));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      await tester.ensureVisible(find.text('Chọn danh mục này'));
      await tester.tap(find.text('Chọn danh mục này'));
      await tester.pumpAndSettle();
      expect(store.hang.single, (nguon: 'hoc', amTietChinh: 'grab', goiY: 'move', ketQua: 'chon', chon: 'move'));
      await nhapVaLuu(tester);
      expect(store.hang, hasLength(1), reason: 'đã phân xử ở nút Chọn — lúc lưu không ghi thêm hàng thứ hai');
    });

    testWidgets('⭐ bấm Bỏ qua → một hàng bo_qua, chon null', (tester) async {
      final store = _StoreGia();
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: store));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      await tester.ensureVisible(find.text('Bỏ qua'));
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();
      expect(store.hang.single, (nguon: 'hoc', amTietChinh: 'grab', goiY: 'move', ketQua: 'bo_qua', chon: null));
    });

    testWidgets('⭐ thẻ đang hiện → chọn danh mục KHÁC qua bảng → lưu → một hàng khac', (tester) async {
      final store = _StoreGia();
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: store));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      expect(find.text('Gợi ý danh mục'), findsOneWidget);
      await chonQuaBang(tester, 'Ăn uống');
      expect(store.hang, isEmpty, reason: 'chưa lưu thì chưa phân xử — chọn qua bảng rồi bỏ trang là không ghi');
      await nhapVaLuu(tester);
      expect(store.hang.single, (nguon: 'hoc', amTietChinh: 'grab', goiY: 'move', ketQua: 'khac', chon: 'food'),
          reason: '_chonDanhMuc xoá thẻ ngay khi chọn qua bảng — gợi ý chưa phân xử phải được nhớ ở trường riêng');
    });

    testWidgets('thẻ đang hiện → chọn qua bảng ĐÚNG danh mục gợi ý → lưu → hàng chon', (tester) async {
      final store = _StoreGia();
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: store));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      await chonQuaBang(tester, 'Di chuyển');
      await nhapVaLuu(tester);
      expect(store.hang.single.ketQua, 'chon');
    });

    testWidgets('thẻ đang hiện → sửa ghi chú thành chữ khác → KHÔNG ghi gì cho gợi ý cũ, kể cả khi lưu', (tester) async {
      final store = _StoreGia();
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: store));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      expect(find.text('Gợi ý danh mục'), findsOneWidget);
      await goGhiChu(tester, 'điện thoại');
      expect(find.text('Gợi ý danh mục'), findsNothing);
      await chonQuaBang(tester, 'Ăn uống');
      await nhapVaLuu(tester);
      expect(store.hang, isEmpty, reason: 'thẻ bị huỷ vì đổi ghi chú không phải phán xét của người dùng');
    });

    testWidgets('thẻ đang hiện → đổi đoạn (Thu nhập rồi về Chi tiêu) → lưu với danh mục khác → KHÔNG ghi', (tester) async {
      final store = _StoreGia();
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: store));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      expect(find.text('Gợi ý danh mục'), findsOneWidget);
      await tester.tap(find.byKey(const Key('transaction-type-thu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('transaction-type-chi')));
      await tester.pumpAndSettle();
      await chonQuaBang(tester, 'Ăn uống');
      await nhapVaLuu(tester);
      expect(store.hang, isEmpty, reason: 'thẻ bị huỷ vì đổi đoạn không phải phán xét của người dùng (spec 3.3)');
    });

    testWidgets('thẻ đang hiện → rời trang không lưu → không ghi', (tester) async {
      final store = _StoreGia();
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: store));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(store.hang, isEmpty);
    });

    testWidgets('⭐ hai lần bo_qua cho (grab, Di chuyển) trong store → gõ "grab tối" thì thẻ học KHÔNG hiện',
        (tester) async {
      final bq = [
        for (final d in [10, 11])
          PhanHoiGoiY(
            nguon: 'hoc', amTietChinh: 'grab', goiYCategoryId: 'move', ketQua: 'bo_qua',
            createdAt: DateTime(2026, 9, d),
          ),
      ];
      await tester.pumpWidget(app(boPhanLoai: BoPhanLoaiGhiChu.hoc(_muoiMau), phanHoiGoiY: _StoreGia(bq)));
      await tester.pumpAndSettle();
      await goGhiChu(tester, 'grab tối');
      expect(find.text('Gợi ý danh mục'), findsNothing,
          reason: 'không bảng từ khoá nào, và cặp đã bị bỏ qua hai lần → im');
    });
  });
}
