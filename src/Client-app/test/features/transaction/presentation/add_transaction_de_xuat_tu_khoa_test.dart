/// Đề xuất thêm từ khoá ở màn Thêm giao dịch (spec `2026-09-30-de-xuat-them-tu-khoa-design.md`, màn Stitch
/// `8ca1338e…`) — chỉ kiểm CHỖ NỐI; phép chọn cụm có bộ test riêng (`category/domain/de_xuat_tu_khoa_test.dart`).
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/goi_y_phan_hoi_store.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
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

/// Hai lần "trà sữa" cho Ăn uống, hai lần "grab" cho Di chuyển — lần nhập thứ ba đủ ngưỡng. Dưới 10 mẫu nên thẻ gợi ý
/// B1 im, không lẫn vào ca.
final _mau = [_m('food', 'trà sữa'), _m('food', 'trà sữa'), _m('move', 'grab'), _m('move', 'grab')];

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

  CategoryTree treeOf(List<Category> defaults) =>
      CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: defaults);

  late FakeCategoryRepository repo;

  Widget app({Map<String, List<String>> keywords = const {}, GoiYPhanHoiStore? store, ThemeData? theme}) {
    repo = FakeCategoryRepository(
      trees: {'chi': treeOf([anUong, diChuyen]), 'thu': treeOf(const []), 'vay_no': treeOf(const [])},
      selectable: [anUong, diChuyen],
      keywords: keywords,
    );
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
                categoryRepository: repo,
                wallets: [makeWallet()],
                idaccount: 1,
                boPhanLoai: BoPhanLoaiGhiChu.hoc(_mau),
                phanHoiGoiY: store,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/add/category',
          builder: (_, state) =>
              ChooseCategoryPage(classify: state.extra as String? ?? 'chi', repository: repo, idaccount: 1),
        ),
      ],
    );
    return MaterialApp.router(theme: theme, routerConfig: router);
  }

  Future<void> goGhiChu(WidgetTester tester, String ghiChu) async {
    await tester.enterText(find.byKey(const Key('ghi-chu-giao-dich')), ghiChu);
    await tester.pump(const Duration(milliseconds: 350));
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

  /// Record chứa `List` so theo danh tính — so bằng chuỗi.
  List<String> luot() => [for (final (id, k) in repo.luotLuuTuKhoa) '$id: ${k.join(', ')}'];

  final dongThem = find.text('Thêm ‘trà sữa’ làm từ khoá của Ăn uống?', findRichText: true);
  final khoiDeXuat = find.byKey(const Key('de-xuat-tu-khoa'));

  testWidgets('⭐ theme THẬT, 360 × 640: dòng hiện dưới hàng Danh mục, không tràn (bẫy 4.11)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(theme: AppTheme.lightTheme));
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'trà sữa');
    expect(khoiDeXuat, findsNothing, reason: 'chưa có danh mục thì chưa đề xuất');
    await chonQuaBang(tester, 'Ăn uống');
    expect(dongThem, findsOneWidget);
    expect(tester.takeException(), isNull);
    final nut = find.widgetWithText(ElevatedButton, 'Thêm');
    await tester.ensureVisible(nut);
    expect(tester.getSize(nut).width, lessThan(120), reason: 'nút rộng vô hạn là dấu hiệu bẫy 4.11');
  });

  testWidgets('⭐ Thêm → ghi từ khoá + phản hồi chon, dòng thành "Đã thêm" rồi tự ẩn sau 2 giây', (tester) async {
    final store = _StoreGia();
    await tester.pumpWidget(app(keywords: {'food': ['cơm']}, store: store));
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'trà sữa');
    await chonQuaBang(tester, 'Ăn uống');
    final nut = find.widgetWithText(ElevatedButton, 'Thêm');
    await tester.ensureVisible(nut);
    await tester.tap(nut);
    await tester.pumpAndSettle();
    expect(luot(), ['food: cơm, trà sữa']);
    expect(store.hang.single,
        (nguon: 'de_xuat_tu_khoa', amTietChinh: 'tra sua', goiY: 'food', ketQua: 'chon', chon: 'food'));
    expect(find.text('Đã thêm ‘trà sữa’ vào Ăn uống'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(khoiDeXuat, findsNothing, reason: 'tự ẩn, và cụm nay đã là từ khoá nên dòng đề xuất không quay lại');
  });

  testWidgets('⭐ Chuyển → bỏ ở danh mục cũ TRƯỚC, rồi thêm vào danh mục đang chọn', (tester) async {
    await tester.pumpWidget(app(keywords: {
      'food': ['grab', 'cơm']
    }));
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'grab');
    await chonQuaBang(tester, 'Di chuyển');
    expect(find.text('‘grab’ đang là từ khoá của Ăn uống — chuyển sang Di chuyển?', findRichText: true),
        findsOneWidget);
    final nut = find.widgetWithText(ElevatedButton, 'Chuyển');
    await tester.ensureVisible(nut);
    await tester.tap(nut);
    await tester.pumpAndSettle();
    expect(luot(), ['food: cơm', 'move: grab'], reason: 'không có khoảnh khắc cụm thuộc hai danh mục — bộ so coi đó là hoà');
    expect(find.text('Đã chuyển ‘grab’ sang Di chuyển'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('✕ → phản hồi bo_qua, dòng ẩn cả lượt này kể cả khi gõ lại cùng ghi chú', (tester) async {
    final store = _StoreGia();
    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'trà sữa');
    await chonQuaBang(tester, 'Ăn uống');
    await tester.ensureVisible(find.byTooltip('Bỏ qua đề xuất'));
    await tester.tap(find.byTooltip('Bỏ qua đề xuất'));
    await tester.pumpAndSettle();
    expect(store.hang.single,
        (nguon: 'de_xuat_tu_khoa', amTietChinh: 'tra sua', goiY: 'food', ketQua: 'bo_qua', chon: null));
    expect(khoiDeXuat, findsNothing);
    await goGhiChu(tester, 'điện thoại');
    await goGhiChu(tester, 'trà sữa');
    expect(khoiDeXuat, findsNothing);
    expect(repo.luotLuuTuKhoa, isEmpty);
  });

  testWidgets('lưu giao dịch mà không bấm gì → không ghi phản hồi nào, không ghi từ khoá', (tester) async {
    final store = _StoreGia();
    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'trà sữa');
    await chonQuaBang(tester, 'Ăn uống');
    expect(dongThem, findsOneWidget);
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('000'));
    await tester.tap(find.text('000'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Trang trước'), findsOneWidget, reason: 'tiền đề: đã lưu và rời màn');
    expect(store.hang, isEmpty);
    expect(repo.luotLuuTuKhoa, isEmpty);
  });

  testWidgets('ghi chú đổi sang chữ khác → dòng biến mất; đổi lại → hiện lại', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'trà sữa');
    await chonQuaBang(tester, 'Ăn uống');
    expect(dongThem, findsOneWidget);
    await goGhiChu(tester, 'điện thoại');
    expect(khoiDeXuat, findsNothing);
    await goGhiChu(tester, 'trà sữa');
    expect(dongThem, findsOneWidget);
  });

  testWidgets('đổi sang Chuyển khoản → dòng biến mất', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'trà sữa');
    await chonQuaBang(tester, 'Ăn uống');
    expect(dongThem, findsOneWidget);
    await tester.tap(find.byKey(const Key('transaction-type-transfer')));
    await tester.pumpAndSettle();
    expect(khoiDeXuat, findsNothing);
  });

  testWidgets('hai lần bo_qua đề xuất (tra sua, Ăn uống) trong store → dòng không hiện', (tester) async {
    final bq = [
      for (final d in [10, 11])
        PhanHoiGoiY(
          nguon: kNguonDeXuatTuKhoa,
          amTietChinh: 'tra sua',
          goiYCategoryId: 'food',
          ketQua: 'bo_qua',
          createdAt: DateTime(2026, 9, d),
        ),
    ];
    await tester.pumpWidget(app(store: _StoreGia(bq)));
    await tester.pumpAndSettle();
    await goGhiChu(tester, 'trà sữa');
    await chonQuaBang(tester, 'Ăn uống');
    expect(khoiDeXuat, findsNothing);
  });
}
