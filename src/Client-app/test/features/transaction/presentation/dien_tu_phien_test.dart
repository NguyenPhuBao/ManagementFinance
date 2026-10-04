/// Nhắc ghi sau khi dùng app ngân hàng — màn Thêm giao dịch mở từ một DÒNG NHẮC (spec 2026-10-03 §3.4).
///
/// Ba điều đáng canh, cả ba hỏng im lặng:
/// 1. **Số tiền trống, 16 phím hiện, giờ = lúc mở app** — dòng nhắc không biết số tiền.
/// 2. **Ví chọn sẵn theo NGUỒN** (`docTheoNguon`) chỉ khi chắc; không chắc thì TRỐNG, không ví mặc định (bẫy 4 D1).
/// 3. **Lưu / Bỏ qua xoá cứng dòng** — không thì dòng nhắc còn đó sau khi đã ghi.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/phien_ngan_hang.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt'); // ví MẶC ĐỊNH
  final mb = makeWallet(id: 'mb', name: 'MB').copyWith(type: 'bank', isDefault: false);

  final p = PhienNganHang(
      goi: 'com.mbmobile',
      batDau: DateTime(2026, 10, 3, 11, 19),
      ketThuc: DateTime(2026, 10, 3, 11, 20, 35),
      trenMan: const Duration(seconds: 95));
  final khoa = dedupeKeyPhien(kNguonMb, p.batDau);
  final phien = dienSanBienDongTuQuery(Uri.parse(deeplinkPhien(p, nguon: kNguonMb, dedupeKey: khoa)).queryParameters)!;

  late FakeTransactionRepository repo;
  late InMemoryViTheoNguonStore store;
  late List<(int, String)> daXoa;

  setUp(() {
    repo = FakeTransactionRepository();
    store = InMemoryViTheoNguonStore();
    daXoa = [];
  });

  Widget app() {
    final bloc = TransactionBloc(transactionRepository: repo);
    CategoryTree cay(List<Category> c) =>
        CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
    final danhMuc = FakeCategoryRepository(
      trees: {'chi': cay([anUong]), 'thu': cay([luong]), 'vay_no': cay(const [])},
      selectable: [anUong, luong],
      keywords: const {},
    );
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
                categoryRepository: danhMuc,
                wallets: [tienMat, mb],
                idaccount: 1,
                budgetLookup: (_, __) async => null,
                bienDong: phien,
                viTheoNguon: store,
                xoaBienDong: (id, k) async => daXoa.add((id, k)),
                khoanTrongSo: (_) async => const [],
                hangBienDongCho: (_) async => const [],
              ),
            ),
          ],
        ),
        // Hàng "Danh mục" của form `push('/add/category')` — khuôn của `phep_tinh_ban_phim_test`.
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: danhMuc,
            idaccount: 1,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> mo(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  /// Đúng MỘT ✓ trên màn ở mọi lúc (`ban_phim_so_an_test`: bàn phím hiện thì ✓ ở lưới phím, ẩn thì ở thanh tiêu đề).
  Future<void> luu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  /// Form BẮT BUỘC có danh mục (`'Vui lòng chọn danh mục'`) — dòng nhắc không có chữ nào để đoán, người dùng tự chọn.
  /// `ensureVisible`: dải nguồn đẩy dòng "Danh mục" xuống (bẫy của nhóm C, `add_transaction_bo_cuc_test`). Hàng ấy mở
  /// TRANG `/add/category` chứ không phải bảng chọn — router của test phải khai route ấy (kế hoạch ban đầu thiếu).
  Future<void> chonAnUong(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Danh mục'));
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ số tiền trống, 16 phím, giờ lúc mở app, dải "Dùng MB Bank · …"; không tự lưu', (tester) async {
    await mo(tester);
    expect(find.text('0 đ'), findsOneWidget);
    expect(find.byKey(const Key('ban-phim-so')), findsOneWidget, reason: 'chưa có số tiền thì phải gõ được ngay');
    expect(find.text('03/10/2026 11:19'), findsOneWidget);
    expect(find.text('Dùng MB Bank · 03/10 11:19'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(repo.added, isEmpty);
  });

  testWidgets('⭐ chưa nhớ gì cho MB Bank → ví TRỐNG (không ví mặc định)', (tester) async {
    await mo(tester);
    expect(find.text('Chọn ví'), findsOneWidget);
  });

  testWidgets('⭐ nhớ MỘT ví cho MB Bank (từ tin có đuôi TK) → chọn sẵn ví ấy', (tester) async {
    await store.ghi(1, kNguonMb, '7777', 'mb');
    await mo(tester);
    expect(find.text('Chọn ví'), findsNothing);
    await chonAnUong(tester);
    await tester.tap(find.text('5'));
    await tester.pump();
    await luu(tester);
    expect(repo.added.single.transaction.walletId, 'mb');
  });

  testWidgets('hai ví khác nhau cho MB Bank → không đoán', (tester) async {
    await store.ghi(1, kNguonMb, '7777', 'mb');
    await store.ghi(1, kNguonMb, '1234', 'cash');
    await mo(tester);
    expect(find.text('Chọn ví'), findsOneWidget);
  });

  testWidgets('⭐ Lưu → giao dịch giờ lúc mở app, xoá cứng dòng nhắc, nhớ ví cho MB Bank (đuôi trống)', (tester) async {
    await mo(tester);
    await tester.tap(find.text('Chọn ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MB').last);
    await tester.pumpAndSettle();
    await chonAnUong(tester);
    await tester.tap(find.text('5'));
    await tester.pump();
    await luu(tester);
    expect(repo.added.single.transaction.date, DateTime(2026, 10, 3, 11, 19));
    expect(daXoa, [(1, khoa)]);
    expect(await store.doc(1, kNguonMb, null), 'mb');
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('Bỏ qua → xoá cứng dòng, không lưu gì', (tester) async {
    await mo(tester);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(daXoa, [(1, khoa)]);
    expect(repo.added, isEmpty);
  });
}
