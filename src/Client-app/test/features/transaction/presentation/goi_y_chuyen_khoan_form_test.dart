/// Gợi ý Chuyển khoản trên form mở từ biến động số dư (spec `2026-09-30-goi-y-chuyen-khoan-bien-dong-design.md` §4–5).
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt'); // mặc định
  final mb = makeWallet(id: 'mb', name: 'Ví MB Bank').copyWith(type: 'bank', isDefault: false);
  final momo = makeWallet(id: 'momo', name: 'Ví MoMo').copyWith(isDefault: false);
  final vcb = makeWallet(id: 'vcb', name: 'VCB lương').copyWith(type: 'bank', isDefault: false);

  const quaMomo = '149346965345-TRAN QUANG DAT chuyen tien qua MoMo-CHUYEN TIEN-OQCH000LKkVs-MOMO149346965345MOMO';

  DienSanBienDong tin({
    String khoa = 'bienDong:MB Bank|10000|thu|2026-09-30T20:02|a',
    String nguon = kNguonMb,
    String ghiChu = quaMomo,
    String chieu = 'thu',
    String duoi = '262',
    DateTime? luc,
  }) =>
      DienSanBienDong(
          khoa: khoa,
          nguon: nguon,
          ghiChu: ghiChu,
          soTien: 10000,
          chieu: chieu,
          thoiGian: luc ?? DateTime(2026, 9, 30, 20, 2),
          duoi: duoi);

  late FakeTransactionRepository repo;
  late InMemoryViTheoNguonStore store;
  late List<(int, String)> daXoa;

  setUp(() {
    repo = FakeTransactionRepository();
    store = InMemoryViTheoNguonStore();
    daXoa = [];
  });

  Widget app(DienSanBienDong d, {List<DienSanBienDong>? cho}) {
    final bloc = TransactionBloc(transactionRepository: repo);
    CategoryTree cay(List<Category> c) => CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
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
                categoryRepository: FakeCategoryRepository(
                  trees: {'chi': cay([anUong]), 'thu': cay([luong]), 'vay_no': cay(const [])},
                  selectable: [anUong, luong],
                ),
                wallets: [tienMat, mb, momo, vcb],
                idaccount: 1,
                budgetLookup: (_, __) async => null,
                bienDong: d,
                viTheoNguon: store,
                xoaBienDong: (id, k) async => daXoa.add((id, k)),
                khoanTrongSo: (_) async => const [],
                hangBienDongCho: (_) async => cho ?? [d],
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> mo(WidgetTester tester, DienSanBienDong d, {List<DienSanBienDong>? cho}) async {
    await tester.pumpWidget(app(d, cho: cho));
    await tester.pumpAndSettle();
  }

  Future<void> apVaLuu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('goi-y-chuyen-khoan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('luu-thanh-tieu-de')));
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ tin MB "qua MoMo": thẻ gợi ý; bấm → đoạn Chuyển khoản, từ Ví MoMo (theo tên) sang Ví MB Bank (đã '
      'nhớ); chưa lưu gì', (tester) async {
    await store.ghi(1, kNguonMb, '262', 'mb');
    await mo(tester, tin());

    expect(find.text('Có vẻ là chuyển khoản'), findsOneWidget);
    expect(find.text('Từ MoMo sang MB Bank'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goi-y-chuyen-khoan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('the-goi-y-chuyen-khoan')), findsNothing);
    expect(find.text('Ví đích (Đến ví)'), findsOneWidget, reason: 'form đã ở đoạn Chuyển khoản');
    expect(find.textContaining('Ví MoMo'), findsOneWidget);
    expect(find.textContaining('Ví MB Bank'), findsOneWidget);
    expect(repo.added, isEmpty, reason: 'bất biến ④ nhóm C — không tự lưu');
  });

  testWidgets('Lưu → một khoản transfer MoMo → MB, xoá hàng, nhớ ví MoMo', (tester) async {
    await store.ghi(1, kNguonMb, '262', 'mb');
    await mo(tester, tin());
    await apVaLuu(tester);

    final tx = repo.added.single.transaction;
    expect((tx.type, tx.walletId, tx.walletTransfer, tx.categoryId), ('transfer', 'momo', 'mb', null));
    expect(daXoa, [(1, 'bienDong:MB Bank|10000|thu|2026-09-30T20:02|a')]);
    expect(store.values[1]!['$kNguonMomo|'], 'momo');
  });

  testWidgets('⚠️ lần đầu của MB · 262 (tin THU): ví của nguồn tin là ví ĐÍCH — nhớ đúng ví đích, không nhớ ví nguồn',
      (tester) async {
    await mo(tester, tin());
    await tester.tap(find.byKey(const Key('goi-y-chuyen-khoan')));
    await tester.pumpAndSettle();
    // Ví đích trống (lần đầu, không ví mặc định) — người dùng chọn.
    await tester.tap(find.text('Ví đích (Đến ví)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ví MB Bank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('luu-thanh-tieu-de')));
    await tester.pumpAndSettle();

    expect(repo.added.single.transaction.walletTransfer, 'mb');
    expect(store.values[1]!['$kNguonMb|262'], 'mb',
        reason: 'nhớ `_selectedWallet` (Ví MoMo) cho MB · 262 là mọi tin MB sau đó chọn sẵn sai ví, im lặng');
  });

  testWidgets('tin trần "TRAN QUANG DAT chuyen tien" → không thẻ', (tester) async {
    await mo(tester, tin(ghiChu: 'TRAN QUANG DAT chuyen tien', chieu: 'chi'));
    expect(find.byKey(const Key('the-goi-y-chuyen-khoan')), findsNothing);
  });

  testWidgets('⭐ cặp chi MB + thu VCB: từ MB sang VCB; Lưu xoá CẢ HAI hàng', (tester) async {
    await store.ghi(1, kNguonMb, '262', 'mb');
    await store.ghi(1, kNguonVcb, '1234', 'vcb');
    final chi = tin(khoa: 'bienDong:chi', ghiChu: 'chuyen tien', chieu: 'chi', luc: DateTime(2026, 9, 30, 20, 19));
    final thu = tin(
        khoa: 'bienDong:thu', nguon: kNguonVcb, ghiChu: 'nhan tien', duoi: '1234', luc: DateTime(2026, 9, 30, 20, 21));
    await mo(tester, chi, cho: [chi, thu]);

    expect(find.text('Từ MB Bank sang Vietcombank'), findsOneWidget);
    await apVaLuu(tester);

    final tx = repo.added.single.transaction;
    expect((tx.walletId, tx.walletTransfer), ('mb', 'vcb'));
    expect(daXoa.map((e) => e.$2).toSet(), {'bienDong:chi', 'bienDong:thu'},
        reason: 'hàng cặp còn chờ là người dùng ghi đôi');
  });

  testWidgets('tự chạm đoạn Chuyển khoản (không qua gợi ý) → Lưu giữ hành vi D1: chỉ xoá hàng đang mở', (tester) async {
    await store.ghi(1, kNguonMb, '262', 'mb');
    final chi = tin(khoa: 'bienDong:chi', ghiChu: 'chuyen tien', chieu: 'chi', luc: DateTime(2026, 9, 30, 20, 19));
    final thu = tin(
        khoa: 'bienDong:thu', nguon: kNguonVcb, ghiChu: 'nhan tien', duoi: '1234', luc: DateTime(2026, 9, 30, 20, 21));
    await mo(tester, chi, cho: [chi, thu]);
    await tester.tap(find.byKey(const Key('transaction-type-transfer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('the-goi-y-chuyen-khoan')), findsNothing, reason: 'đã ở đoạn Chuyển khoản');
    await tester.tap(find.text('Ví đích (Đến ví)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('VCB lương').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('luu-thanh-tieu-de')));
    await tester.pumpAndSettle();
    expect(daXoa.map((e) => e.$2), ['bienDong:chi']);
  });

  testWidgets('360 × 640: thẻ gợi ý không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mo(tester, tin());
    expect(find.byKey(const Key('the-goi-y-chuyen-khoan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
