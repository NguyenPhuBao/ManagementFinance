/// D1 Task 7 — màn Thêm giao dịch mở từ một hàng biến động số dư (spec D1 §3.3, Stitch `52d9d2ef…`).
///
/// Bốn điều đáng canh, cả bốn hỏng im lặng:
/// 1. **Không tự lưu** — form chỉ điền sẵn, người dùng bấm ✓ (bất biến ④ nhóm C).
/// 2. **Lần đầu của một nguồn + đuôi TK thì ví KHÔNG chọn sẵn**: để ví mặc định là để bảng *"nguồn → ví"* học
///    nhầm ví mặc định ở lần Lưu đầu, rồi chọn sẵn sai mãi.
/// 3. **Lưu / Bỏ qua xoá cứng hàng loại 20** (theo `khoa`) — không thì dòng *"biến động chưa ghi"* còn đó sau khi
///    đã ghi, và nội dung tin ngân hàng ở lại máy.
/// 4. **Nhắc trùng chỉ nhắc**, không chặn lưu.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
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
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true);
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt'); // ví MẶC ĐỊNH
  final mb = makeWallet(id: 'mb', name: 'MB').copyWith(type: 'bank', isDefault: false);

  const khoa = 'bienDong:MB Bank|45000|chi|2026-09-02T12:01';
  final tin = TinBienDong(
    soTien: 45000,
    chieu: 'chi',
    thoiGian: DateTime(2026, 9, 2, 12, 1),
    noiDung: 'PHO 24',
    nguon: kNguonMb,
    duoiTaiKhoan: '7777',
  );
  final bienDong = dienSanBienDongTuQuery(Uri.parse(deeplinkBienDong(tin, dedupeKey: khoa)).queryParameters)!;

  late FakeTransactionRepository repo;
  late InMemoryViTheoNguonStore store;
  late List<(int, String)> daXoa;

  setUp(() {
    repo = FakeTransactionRepository();
    store = InMemoryViTheoNguonStore();
    daXoa = [];
  });

  Widget app({List<KhoanSo> so = const []}) {
    final bloc = TransactionBloc(transactionRepository: repo);
    CategoryTree cay(List<Category> c) =>
        CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: c);
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
                  keywords: const {
                    'food': ['pho'],
                  },
                ),
                wallets: [tienMat, mb],
                idaccount: 1,
                budgetLookup: (_, __) async => null,
                bienDong: bienDong,
                viTheoNguon: store,
                xoaBienDong: (id, k) async => daXoa.add((id, k)),
                khoanTrongSo: (_) async => so,
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> mo(WidgetTester tester, {List<KhoanSo> so = const []}) async {
    await tester.pumpWidget(app(so: so));
    await tester.pumpAndSettle();
  }

  Future<void> luu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ điền tiền, chiều, ghi chú, danh mục (từ khoá trên nội dung tin), NGÀY GIỜ trong tin; dải nguồn; '
      'không ô Nhập nhanh; nút Bỏ qua', (tester) async {
    await mo(tester);
    expect(find.text('45.000 đ'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('ghi-chu-giao-dich'))).controller!.text, 'PHO 24');
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('02/09/2026 12:01'), findsOneWidget, reason: 'giờ trong tin là giờ giao dịch (spec §3.3)');
    expect(find.text('Từ thông báo MB Bank · TK ••7777 · 02/09 12:01'), findsOneWidget);
    expect(find.byKey(const Key('nhap-nhanh-o')), findsNothing,
        reason: 'form đã điền từ tin — ô Nhập nhanh là đường điền thứ hai chen vào (Stitch không vẽ)');
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(repo.added, isEmpty, reason: 'KHÔNG tự lưu — người dùng bấm ✓');
  });

  testWidgets('⭐ lần đầu nguồn + đuôi → ví KHÔNG chọn sẵn (kể cả ví mặc định); chọn tay + Lưu → nhớ cặp, xoá hàng',
      (tester) async {
    await mo(tester);
    expect(find.text('Chọn ví'), findsOneWidget,
        reason: 'để ví mặc định là bảng nguồn → ví học nhầm ví mặc định ở lần Lưu đầu');

    await tester.tap(find.text('Chọn ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MB').last);
    await tester.pumpAndSettle();
    await luu(tester);

    expect(repo.added.single.transaction.walletId, 'mb');
    expect(repo.added.single.transaction.amount, 45000);
    expect(repo.added.single.transaction.date, DateTime(2026, 9, 2, 12, 1));
    expect(await store.doc(1, kNguonMb, '7777'), 'mb');
    expect(daXoa, [(1, khoa)], reason: 'đã ghi thì hàng "biến động chưa ghi" phải biến mất (xoá cứng, spec §3.3)');
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('⭐ lần sau cùng nguồn + đuôi → chọn sẵn ví đã nhớ; ví đã nhớ không còn hoạt động → không chọn',
      (tester) async {
    await store.ghi(1, kNguonMb, '7777', 'mb');
    await mo(tester);
    expect(find.text('MB • 100.000 đ'), findsOneWidget);

    await store.ghi(1, kNguonMb, '7777', 'vi-da-luu-tru');
    await mo(tester);
    expect(find.text('Chọn ví'), findsOneWidget,
        reason: 'ví lưu trữ / đã xoá không có trong danh sách ví hoạt động — chọn nó là ghi vào ví đóng băng');
  });

  testWidgets('Lưu khi đã có ví nhớ → không ghi đè bảng nguồn → ví', (tester) async {
    await store.ghi(1, kNguonMb, '7777', 'mb');
    await mo(tester);
    await tester.tap(find.text('MB • 100.000 đ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiền mặt').last);
    await tester.pumpAndSettle();
    await luu(tester);
    expect(repo.added.single.transaction.walletId, 'cash');
    expect(await store.doc(1, kNguonMb, '7777'), 'mb', reason: 'spec §3.3: ghi ở lần Lưu ĐẦU của mỗi cặp');
  });

  testWidgets('⭐ Bỏ qua → xoá hàng, KHÔNG tạo giao dịch, quay về', (tester) async {
    await mo(tester);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(daXoa, [(1, khoa)]);
    expect(repo.added, isEmpty);
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('⭐ sổ có khoản cùng tiền + chiều + ngày → dòng nhắc + Xem liệt kê; KHÔNG chặn lưu', (tester) async {
    await store.ghi(1, kNguonMb, '7777', 'mb');
    await mo(tester, so: [
      (id: 't1', soTien: 45000, loai: 'chi', ngay: DateTime(2026, 9, 2, 8, 30), ghiChu: 'phở sáng'),
      (id: 't2', soTien: 45000, loai: 'thu', ngay: DateTime(2026, 9, 2, 9), ghiChu: 'khác chiều'),
    ]);
    expect(find.text('Có thể bạn đã ghi khoản này'), findsOneWidget);
    expect(find.text('45.000 đ chi hôm 02/09 đã có trong sổ'), findsOneWidget);

    await tester.ensureVisible(find.text('Xem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem'));
    await tester.pumpAndSettle();
    expect(find.text('phở sáng'), findsOneWidget);
    expect(find.text('khác chiều'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await luu(tester);
    expect(repo.added, hasLength(1), reason: 'người dùng tự quyết — nhắc, không chặn');
  });

  testWidgets('không có khoản trùng → không dòng nhắc', (tester) async {
    await mo(tester);
    expect(find.text('Có thể bạn đã ghi khoản này'), findsNothing);
  });

  testWidgets('bàn phím số ẨN (tin đã có số tiền); thanh tiêu đề: Bỏ qua · ✓', (tester) async {
    await store.ghi(1, kNguonMb, '7777', 'mb'); // có ví chọn sẵn — lưu được ngay
    await mo(tester);
    expect(find.byKey(const Key('ban-phim-so')), findsNothing,
        reason: 'Realme 360 dp: 16 phím chiếm nửa dưới màn khi thứ cần soát là ví / danh mục (nghiệm thu D1)');
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.byKey(const Key('luu-thanh-tieu-de')), findsOneWidget);
    await tester.tap(find.byKey(const Key('luu-thanh-tieu-de')));
    await tester.pumpAndSettle();
    expect(repo.added, hasLength(1));
  });

  testWidgets('không tràn ở 360 × 640 với dải nguồn + dòng nhắc', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await store.ghi(1, kNguonMb, '7777', 'mb');
    await mo(tester, so: [(id: 't1', soTien: 45000, loai: 'chi', ngay: DateTime(2026, 9, 2, 8), ghiChu: 'x')]);
    expect(tester.takeException(), isNull);
  });
}
