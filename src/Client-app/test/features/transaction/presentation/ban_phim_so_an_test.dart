/// Bàn phím số ẨN khi màn Thêm giao dịch mở với số tiền đã có (2026-09-30, việc sau D1).
///
/// Nghiệm thu D1 trên Realme (360 dp): form mở từ biến động số dư đã có số tiền mà 16 phím vẫn chiếm nửa dưới màn,
/// thẻ form — chỗ người dùng thật sự cần soát (ví, danh mục, ghi chú) — bị ép về một dải hẹp.
///
/// Luật (người dùng chốt 2026-09-30):
/// 1. Mở ở `0 đ` → bàn phím như nay. Mở với số tiền (sửa · biến động) → bàn phím ẨN. Ô Nhập nhanh điền được số
///    tiền → bàn phím ẨN.
/// 2. Chạm khối số tiền → bàn phím hiện / ẩn (đảo).
/// 3. **Một luật cho nút lưu**: 16 phím không trên màn (ẩn theo cờ, hoặc bàn phím HỆ THỐNG đang mở — G58) thì ✓ ở
///    thanh tiêu đề. Thiếu vế G58 là lúc gõ ghi chú không có nút lưu nào.
/// 4. Bàn phím ẩn thì dưới số tiền là *"Chạm để sửa số tiền"* — không có nó thì không ai biết con số chạm được.
library;

import 'package:flowmoney/core/ui/bao_che_day_toast.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);

  FakeCategoryRepository categories() => FakeCategoryRepository(
        trees: {
          'chi': CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: [anUong]),
        },
      );

  TransactionEntity khoan({double amount = 50000}) => TransactionEntity(
        id: 'tx-1',
        walletId: 'cash',
        idaccount: 1,
        categoryId: 'food',
        amount: amount,
        type: 'chi',
        note: 'Phở',
        date: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
      );

  late FakeTransactionRepository repo;
  setUp(() => repo = FakeTransactionRepository());

  Widget app({EditTransactionArgs? initial}) {
    final bloc = TransactionBloc(transactionRepository: repo);
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
                categoryRepository: categories(),
                wallets: [makeWallet()],
                idaccount: 1,
                initial: initial,
                budgetLookup: (_, __) async => null,
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  final banPhim = find.byKey(const Key('ban-phim-so'));
  final luuTieuDe = find.byKey(const Key('luu-thanh-tieu-de'));
  final soTien = find.byKey(const Key('so-tien-cham'));
  const goiY = 'Chạm để sửa số tiền';

  Future<void> suaKhoan(WidgetTester tester, {double amount = 50000}) async {
    await tester.pumpWidget(app(initial: EditTransactionArgs(transaction: khoan(amount: amount), category: anUong)));
    await tester.pumpAndSettle();
  }

  testWidgets('mở ở 0 đ: bàn phím như nay, ✓ ở lưới — thanh tiêu đề không có ✓, không có dòng gợi ý', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(banPhim, findsOneWidget, reason: 'màn trống giữ nguyên — việc đầu tiên là gõ số');
    expect(luuTieuDe, findsNothing, reason: 'hai nút lưu cùng lúc là hai chỗ để bấm cho một việc');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text(goiY), findsNothing);
  });

  testWidgets('⭐ 16 phím hiện → báo chiều cao cho toast; ẩn → về 0 (Stitch fb68baba…)', (tester) async {
    await suaKhoan(tester);
    await tester.pump();
    expect(cheDayToast.value, 0, reason: 'bàn phím ẩn — không che gì');

    await tester.tap(soTien);
    await tester.pumpAndSettle();
    final banPhimRect = tester.getRect(banPhim);
    final cao = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(cheDayToast.value, greaterThanOrEqualTo(cao - banPhimRect.top - 0.5),
        reason: 'viên lỗi lúc bấm ✓ phải nổi TRÊN 16 phím, không đè hai hàng dưới (000 · 0 · ⌫)');

    await tester.tap(soTien);
    await tester.pumpAndSettle();
    expect(cheDayToast.value, 0);
  });

  testWidgets('⭐ sửa giao dịch: bàn phím ẨN, ✓ ở thanh tiêu đề lưu được thật', (tester) async {
    await suaKhoan(tester);

    expect(banPhim, findsNothing, reason: 'đã có số tiền — 16 phím chiếm nửa màn mà không có việc gì');
    expect(luuTieuDe, findsOneWidget, reason: 'bàn phím ẩn mang theo phím ✓ — phải có nút lưu khác');
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'đúng MỘT nút lưu trên màn');
    expect(find.text(goiY), findsOneWidget, reason: 'không có gợi ý thì không ai biết con số chạm được');

    await tester.tap(luuTieuDe);
    await tester.pumpAndSettle();
    expect(repo.updated, hasLength(1));
    expect(repo.updated.single.after.amount, 50000);
  });

  testWidgets('chạm số tiền → bàn phím hiện (✓ về lưới); gõ được; chạm lần nữa → ẩn, ✓ về thanh tiêu đề',
      (tester) async {
    await suaKhoan(tester);

    await tester.tap(soTien);
    await tester.pumpAndSettle();
    expect(banPhim, findsOneWidget);
    expect(luuTieuDe, findsNothing);
    expect(find.text(goiY), findsNothing, reason: 'bàn phím đã hiện — dòng gợi ý trở về nhãn đơn vị');

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('500.005 đ'), findsOneWidget, reason: 'phím gõ tiếp vào số đang có, như trước');

    await tester.tap(soTien);
    await tester.pumpAndSettle();
    expect(banPhim, findsNothing);
    expect(luuTieuDe, findsOneWidget);

    await tester.tap(luuTieuDe);
    await tester.pumpAndSettle();
    expect(repo.updated.single.after.amount, 500005, reason: 'ẩn bàn phím không làm mất số vừa gõ');
  });

  testWidgets('✓ ở thanh tiêu đề rút gọn biểu thức gõ dở, như phím ✓ ở lưới', (tester) async {
    await suaKhoan(tester);
    await tester.tap(soTien);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('000'));
    await tester.pump();
    await tester.tap(soTien);
    await tester.pumpAndSettle();

    await tester.tap(luuTieuDe);
    await tester.pumpAndSettle();
    expect(repo.updated.single.after.amount, 55000, reason: 'cùng `_saveTransaction` — không đường lưu thứ hai');
  });

  testWidgets('Nhập nhanh điền được số tiền → bàn phím ẩn, ✓ lên thanh tiêu đề', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('nhap-nhanh-o')), 'ăn phở 45k');
    await tester.ensureVisible(find.byKey(const Key('nhap-nhanh-dien')));
    await tester.tap(find.byKey(const Key('nhap-nhanh-dien')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('45.000 đ'), findsOneWidget, reason: 'tiền đề: câu đã điền số tiền');
    expect(banPhim, findsNothing, reason: 'người dùng chốt: điền xong thì soát thẻ form, không gõ số');
    expect(luuTieuDe, findsOneWidget);
  });

  testWidgets('Nhập nhanh KHÔNG đọc ra số tiền → bàn phím giữ nguyên', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('nhap-nhanh-o')), 'hôm qua');
    await tester.ensureVisible(find.byKey(const Key('nhap-nhanh-dien')));
    await tester.tap(find.byKey(const Key('nhap-nhanh-dien')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('0 đ'), findsOneWidget, reason: 'tiền đề: câu không có số tiền');
    expect(banPhim, findsOneWidget, reason: 'số tiền vẫn phải gõ — ẩn bàn phím là bắt người dùng chạm thêm một lần');
  });

  testWidgets('G58 — bàn phím HỆ THỐNG mở ở màn 0 đ: 16 phím ẩn, ✓ ở thanh tiêu đề (một luật)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 303);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(banPhim, findsNothing);
    expect(luuTieuDe, findsOneWidget, reason: 'trước đây gõ ghi chú là không còn nút lưu nào trên màn');
    expect(find.text(goiY), findsNothing,
        reason: 'bàn phím số ẩn vì bàn phím hệ thống, không phải vì cờ — chạm số tiền lúc này không đổi gì thấy được');

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(banPhim, findsOneWidget);
    expect(luuTieuDe, findsNothing);
  });

  testWidgets('360 × 640: sửa giao dịch không tràn, cả khi ẩn lẫn khi hiện bàn phím', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await suaKhoan(tester, amount: 9999999999999);
    expect(tester.takeException(), isNull, reason: 'Flutter báo tràn qua reportError, không ném ra chỗ gọi');

    await tester.tap(soTien);
    await tester.pumpAndSettle();
    expect(banPhim, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
