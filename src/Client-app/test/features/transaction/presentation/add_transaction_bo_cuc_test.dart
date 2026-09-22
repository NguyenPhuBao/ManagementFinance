/// Bố cục màn Thêm giao dịch theo màn Stitch *"Thêm giao dịch - Bàn phím neo
/// đáy"* (`acf6f17e65b84132ae6b18bba16a606a`, 2026-09-19) — nhóm C của lượt
/// đánh giá UX.
///
/// Máy ảo 411dp đo được: màn đầu chỉ thấy hai hàng phím 7-8-9 / 4-5-6, phải
/// cuộn mới tới 1-2-3, 0, 000 và ✓; cuộn tới thì con số đang gõ trôi khỏi màn.
/// Và thanh chọn đầu màn chỉ có "Giao dịch / Chuyển khoản" trong khi Stitch
/// (cả bản gốc lẫn bản sửa) vẽ "Chi tiêu · Thu nhập · Chuyển khoản".
///
/// Bốn luật, mỗi luật một ca, đo ở khổ **411×914** (Pixel logic của máy ảo):
/// (1) cả 16 phím và con số nằm trọn trong màn, không cuộn; (2) phím ✓ là nút
/// lưu; (3) ba đoạn Chi/Thu/Chuyển, chọn Thu thì bảng danh mục mở đúng tab thu
/// và danh mục chi đang chọn bị bỏ; (4) mở trang với chiều đặt sẵn (nút tắt
/// Trang chủ) thì đoạn ấy được chọn ngay.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  CategoryTree treeOf(List<Category> defaults) => CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: defaults,
      );
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final luong =
      makeCategory(id: 'salary', name: 'Lương', classify: 'thu', isDefault: true);

  FakeCategoryRepository categories() => FakeCategoryRepository(
        trees: {
          'chi': treeOf([anUong]),
          'thu': treeOf([luong]),
          'vay_no': treeOf(const []),
        },
      );

  /// `classify` mà bảng chọn danh mục nhận qua `extra` ở lần mở gần nhất.
  String? classifyDaMo;

  Widget app({
    required FakeCategoryRepository categoryRepository,
    required FakeTransactionRepository transactionRepository,
    String? huongBanDau,
  }) {
    final bloc = TransactionBloc(transactionRepository: transactionRepository);
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
                categoryRepository: categoryRepository,
                wallets: [makeWallet()],
                idaccount: 1,
                huongBanDau: huongBanDau,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/add/category',
          builder: (_, state) {
            classifyDaMo = state.extra as String?;
            return ChooseCategoryPage(
              classify: classifyDaMo ?? 'chi',
              repository: categoryRepository,
              idaccount: 1,
            );
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  /// Khổ máy ảo: 1080×2400 ở tỉ lệ 2,625 → 411×914 logic.
  void khoMayAo(WidgetTester tester) {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  setUp(() => classifyDaMo = null);

  testWidgets('411×914: cả 16 phím và con số nằm trọn trong màn, không cuộn',
      (tester) async {
    khoMayAo(tester);
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();

    final man = tester.getRect(find.byType(Scaffold).first);
    for (final phim in ['7', '1', '0', '000', '00']) {
      final r = tester.getRect(find.text(phim));
      expect(r.bottom, lessThanOrEqualTo(man.bottom + 0.5),
          reason: 'Phím "$phim" nằm dưới mép màn — máy ảo phải cuộn mới thấy '
              '1-2-3, 0, 000 và ✓ (UX C1).');
      expect(r.top, greaterThanOrEqualTo(man.top));
    }
    expect(tester.getRect(find.byIcon(Icons.check)).bottom,
        lessThanOrEqualTo(man.bottom + 0.5));
    // Con số đang gõ nằm trên và cũng trong màn (UX C2).
    final so = tester.getRect(find.text('0 đ'));
    expect(so.top, greaterThanOrEqualTo(man.top));
    expect(so.bottom, lessThan(tester.getRect(find.text('7')).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phím ✓ là nút lưu; không còn nút "Lưu giao dịch" riêng',
      (tester) async {
    khoMayAo(tester);
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: repo,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Lưu giao dịch'), findsNothing,
        reason: 'Stitch bản sửa bỏ nút riêng vì ✓ đã là nút lưu.');

    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.tap(find.text('000'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.added, hasLength(1),
        reason: 'Phím ✓ từng là phím chết: `themPhimSoTien` trả nguyên chuỗi.');
    expect(repo.added.single.transaction.amount, 5000);
  });

  testWidgets('ba đoạn Chi tiêu · Thu nhập · Chuyển khoản; chọn Thu thì bảng '
      'danh mục mở tab thu và bỏ danh mục chi đang chọn', (tester) async {
    khoMayAo(tester);
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();

    for (final nhan in ['Chi tiêu', 'Thu nhập', 'Chuyển khoản']) {
      expect(find.text(nhan), findsOneWidget, reason: 'Stitch có đoạn "$nhan".');
    }
    expect(find.text('Giao dịch'), findsNothing);

    // Chọn danh mục chi trước.
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    expect(classifyDaMo, 'chi', reason: 'Đoạn Chi tiêu đang chọn → tab chi.');
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống'), findsOneWidget);

    // Đổi sang Thu nhập: danh mục chi không còn đúng, phải bỏ.
    await tester.tap(find.text('Thu nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống'), findsNothing,
        reason: 'Giữ danh mục chi dưới đoạn Thu là hai sự thật trái nhau; '
            'chiều tiền vẫn suy từ danh mục (luật 2026-09-05).');
    expect(find.text('Chọn danh mục'), findsOneWidget);

    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    expect(classifyDaMo, 'thu', reason: 'Đoạn Thu nhập → bảng mở tab thu.');
    await tester.tap(find.text('Lương'));
    await tester.pumpAndSettle();
    expect(find.text('Lương'), findsOneWidget);
  });

  testWidgets('chọn danh mục thu khi đang ở đoạn Chi thì đoạn nhảy theo',
      (tester) async {
    khoMayAo(tester);
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-classify-thu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lương'));
    await tester.pumpAndSettle();

    final thu = tester.widget<Container>(find.descendant(
      of: find.byKey(const Key('transaction-type-thu')),
      matching: find.byType(Container),
    ));
    expect((thu.decoration as BoxDecoration).color, isNot(Colors.transparent),
        reason: 'Danh mục là sự thật; đoạn phải phản ánh nó, không được nói ngược.');
  });

  testWidgets('mở với huongBanDau: "thu" thì đoạn Thu nhập được chọn sẵn',
      (tester) async {
    khoMayAo(tester);
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
      huongBanDau: 'thu',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    expect(classifyDaMo, 'thu',
        reason: 'Nút "Thêm thu" ở Trang chủ từng mở màn trần, không đặt gì (UX C4).');
  });

  testWidgets('bảng chọn danh mục: hàng lá không chevron, không icon nhãn',
      (tester) async {
    khoMayAo(tester);
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsNothing,
        reason: 'Chevron ở hàng lá nói "còn cấp con" — Stitch màn Chọn danh mục '
            'vẽ hàng lá trần (UX C5).');
    expect(find.byIcon(Icons.label_outline), findsNothing,
        reason: 'Một icon tag xanh cho mọi danh mục không mang thông tin.');
  });

  testWidgets('mở với huongBanDau: "transfer" thì đoạn Chuyển khoản được chọn',
      (tester) async {
    khoMayAo(tester);
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
      huongBanDau: 'transfer',
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ví đích (Đến ví)'), findsOneWidget);
  });
}
