import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flowmoney/features/wallet/domain/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Mô hình từ 2026-09-05: chỉ còn HAI loại giao dịch — *Giao dịch* (biến động
/// số dư, có danh mục thuộc một trong ba phân loại chi / thu / vay-nợ) và
/// *Chuyển khoản* (giữa hai ví, không danh mục). Chiều tiền không còn do
/// segment quyết định mà suy từ danh mục; riêng vay/nợ gom cả hai chiều nên
/// form hỏi thêm bằng một công tắc.
///
/// SQLite vẫn lưu `type = chi | thu | transfer` — hợp đồng đồng bộ, DAO và
/// thống kê không đổi. Các test ở đây kiểm đúng entity mà trang gửi xuống.
void main() {
  CategoryTree treeOf(List<Category> defaults) => CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: defaults,
      );

  final choVay = makeCategory(
      id: 'lend', name: 'Cho vay', classify: 'vay_no', isDefault: true);
  final diVay = makeCategory(
      id: 'borrow', name: 'Đi vay', classify: 'vay_no', isDefault: true);
  final anUong =
      makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final luong = makeCategory(
      id: 'salary', name: 'Lương', classify: 'thu', isDefault: true);

  FakeCategoryRepository categories({
    List<Category> selectable = const [],
    Map<String, List<String>> keywords = const {},
  }) =>
      FakeCategoryRepository(
        trees: {
          'chi': treeOf([anUong]),
          'thu': treeOf([luong]),
          'vay_no': treeOf([choVay, diVay]),
        },
        selectable: selectable,
        keywords: keywords,
      );

  /// Dựng trang qua GoRouter như app thật: bảng chọn danh mục là một route
  /// con nhận `classify` qua `extra`, và trang thêm giao dịch `pop` khi lưu
  /// xong — hai thứ này không có nếu chỉ `MaterialApp(home:)`.
  Widget app({
    required FakeCategoryRepository categoryRepository,
    required FakeTransactionRepository transactionRepository,
    List<Wallet>? wallets,
    EditTransactionArgs? initial,
  }) {
    final bloc = TransactionBloc(transactionRepository: transactionRepository);
    final router = GoRouter(
      // Trang thêm là route CON của /start để stack có hai trang: lưu xong
      // trang gọi `context.pop(true)`, không có gì bên dưới là GoError.
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
                wallets: wallets ??
                    [makeWallet(), makeWallet(id: 'bank', name: 'Ngân hàng')],
                idaccount: 1,
                initial: initial,
              ),
            ),
          ],
        ),
        // Trang thêm push cứng '/add/category' (như app_router thật).
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: categoryRepository,
            idaccount: 1,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> chonDanhMuc(WidgetTester tester,
      {required String tab, required String name}) async {
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> nhapSoTien(WidgetTester tester) async {
    // Bàn phím số nằm dưới mép khung 600px của bộ test: bấm mà không cuộn tới
    // thì tap trượt trong im lặng, số tiền vẫn 0 và hàm lưu dừng ở bước kiểm.
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('000'));
    await tester.tap(find.text('000'));
    await tester.pump();
  }

  Future<void> luu(WidgetTester tester) async {
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
  }

  testWidgets('chỉ còn hai loại: Giao dịch và Chuyển khoản', (tester) async {
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Giao dịch'), findsOneWidget);
    expect(find.text('Chuyển khoản'), findsOneWidget);
    expect(find.text('Chi tiêu'), findsNothing,
        reason: 'Chiều tiền nay suy từ danh mục, không còn là một loại.');
    expect(find.text('Thu nhập'), findsNothing);
    expect(find.byKey(const Key('transaction-type-2')), findsNothing);
  });

  testWidgets('danh mục vay/nợ hiện hàng Chiều tiền; danh mục chi thì không',
      (tester) async {
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chiều tiền'), findsNothing);

    await chonDanhMuc(tester, tab: 'Vay / nợ', name: 'Cho vay');
    expect(find.text('Cho vay'), findsOneWidget);
    expect(find.text('Chiều tiền'), findsOneWidget,
        reason: 'vay_no gom cả hai chiều (cho vay là tiền ra, đi vay là tiền '
            'vào) và không có cột nào ghi chiều — phải hỏi người dùng.');

    await chonDanhMuc(tester, tab: 'Khoản chi', name: 'Ăn uống');
    expect(find.text('Chiều tiền'), findsNothing,
        reason: 'Khoản chi tự nói lên chiều tiền; công tắc chỉ thêm rối.');
  });

  testWidgets('Cho vay gợi sẵn tiền ra → lưu với type chi', (tester) async {
    final transactions = FakeTransactionRepository();
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: transactions,
    ));
    await tester.pumpAndSettle();

    await chonDanhMuc(tester, tab: 'Vay / nợ', name: 'Cho vay');
    await nhapSoTien(tester);
    await luu(tester);

    final saved = transactions.added.single.transaction;
    expect(saved.type, 'chi',
        reason: 'Cho vay là tiền rời ví; lên server thành Transaction với '
            'amount âm.');
    expect(saved.categoryId, 'lend');
    expect(saved.amount, 5000);
    expect(saved.walletTransfer, isNull);
  });

  testWidgets('Đi vay gợi sẵn tiền vào → lưu với type thu', (tester) async {
    final transactions = FakeTransactionRepository();
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: transactions,
    ));
    await tester.pumpAndSettle();

    await chonDanhMuc(tester, tab: 'Vay / nợ', name: 'Đi vay');
    await nhapSoTien(tester);
    await luu(tester);

    expect(transactions.added.single.transaction.type, 'thu');
  });

  testWidgets('đổi công tắc sang Tiền vào thì type theo công tắc, không theo tên',
      (tester) async {
    final transactions = FakeTransactionRepository();
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: transactions,
    ));
    await tester.pumpAndSettle();

    await chonDanhMuc(tester, tab: 'Vay / nợ', name: 'Cho vay');
    await tester.ensureVisible(find.byKey(const Key('debt-direction-thu')));
    await tester.tap(find.byKey(const Key('debt-direction-thu')));
    await tester.pump();
    await nhapSoTien(tester);
    await luu(tester);

    expect(transactions.added.single.transaction.type, 'thu',
        reason: 'Gợi ý theo tên chỉ là gợi ý; người dùng là người quyết.');
  });

  testWidgets('danh mục thu thường lưu type thu, không cần công tắc',
      (tester) async {
    final transactions = FakeTransactionRepository();
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: transactions,
    ));
    await tester.pumpAndSettle();

    await chonDanhMuc(tester, tab: 'Khoản thu', name: 'Lương');
    expect(find.text('Chiều tiền'), findsNothing);
    await nhapSoTien(tester);
    await luu(tester);

    expect(transactions.added.single.transaction.type, 'thu');
  });

  testWidgets('mở lại bảng chọn thì đứng ở tab của danh mục đang chọn',
      (tester) async {
    final repository = categories();
    await tester.pumpWidget(app(
      categoryRepository: repository,
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();

    await chonDanhMuc(tester, tab: 'Vay / nợ', name: 'Đi vay');
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();

    expect(repository.loadedClassifies.last, 'vay_no',
        reason: 'Người dùng đổi ý trong cùng nhóm thì không phải bấm lại tab.');
    expect(find.text('Đi vay'), findsOneWidget);
  });

  testWidgets('chuyển khoản: type transfer, không danh mục, có ví đích',
      (tester) async {
    final transactions = FakeTransactionRepository();
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: transactions,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transaction-type-1')));
    await tester.pumpAndSettle();
    expect(find.text('Ví nguồn (Từ ví)'), findsOneWidget);
    expect(find.text('Ví đích (Đến ví)'), findsOneWidget);
    expect(find.text('Danh mục'), findsNothing);

    await nhapSoTien(tester);
    await luu(tester);

    final saved = transactions.added.single;
    expect(saved.transaction.type, 'transfer');
    expect(saved.transaction.categoryId, isNull,
        reason: "Trước đây gán 'cat_transfer' — id không tồn tại — nên "
            'SyncEngine hoãn đẩy hàng này VĨNH VIỄN mà không báo gì.');
    expect(saved.transaction.walletTransfer, 'bank',
        reason: 'Ví đích phải nằm trên entity để xuống SQLite và lên server.');
    expect(saved.destinationWalletId, 'bank');
  });

  testWidgets('bảng chọn ví hiện nhãn loại ví, không hiện khoá lưu thô',
      (tester) async {
    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
      wallets: [
        makeWallet(id: 'cash', name: 'Ví chính'),
        makeWallet(id: 'vcb', name: 'VCB').copyWith(type: 'bank'),
        makeWallet(id: 'quy', name: 'Quỹ dự phòng').copyWith(type: 'saving'),
      ],
    ));
    await tester.pumpAndSettle();

    // Neo bằng biểu tượng của hàng "Ví thanh toán": ở chế độ Giao dịch chỉ
    // hàng ấy dùng nó.
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    for (final khoa in ['cash', 'bank', 'saving']) {
      expect(find.text(khoa), findsNothing,
          reason: 'Khoá lưu SQLite không phải chữ cho người đọc: dòng dưới tên '
              'ví từng in thẳng wallet.type nên hiện "$khoa".');
    }
    for (final loai in [WalletType.cash, WalletType.bank, WalletType.saving]) {
      expect(find.text(loai.nhan), findsOneWidget,
          reason: 'Nhãn loại ví có một nguồn duy nhất: WalletType.nhan.');
    }
  });

  testWidgets('gợi ý theo ghi chú tìm trên cả ba phân loại', (tester) async {
    await tester.pumpWidget(app(
      categoryRepository: categories(
        selectable: [luong],
        keywords: {
          luong.id: ['lương']
        },
      ),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nhận lương tháng 9');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Gợi ý danh mục'), findsOneWidget,
        reason: 'Không còn segment chi/thu nên bộ gợi ý không được khoá vào '
            'một phân loại; trước đây nó chỉ tìm trong khoản chi.');
    expect(find.text('Lương'), findsOneWidget);
  });

  group('chế độ sửa', () {
    final goc = TransactionEntity(
      id: 'tx-goc',
      walletId: 'bank',
      idaccount: 1,
      categoryId: 'food',
      amount: 25000,
      type: 'chi',
      note: 'Cà phê',
      date: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

    testWidgets('điền sẵn số tiền, danh mục, ví, ghi chú và đổi tiêu đề',
        (tester) async {
      await tester.pumpWidget(app(
        categoryRepository: categories(),
        transactionRepository: FakeTransactionRepository(),
        initial: EditTransactionArgs(transaction: goc, category: anUong),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sửa giao dịch'), findsOneWidget);
      expect(find.text('25.000đ'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.textContaining('Ngân hàng'), findsOneWidget,
          reason: 'Ví phải là ví của giao dịch, không phải ví đầu danh sách.');
      expect(find.text('Cà phê'), findsOneWidget);
    });

    testWidgets('lưu gửi UpdateTransactionEvent: cùng id, giữ before, đổi after',
        (tester) async {
      final transactions = FakeTransactionRepository();
      await tester.pumpWidget(app(
        categoryRepository: categories(),
        transactionRepository: transactions,
        initial: EditTransactionArgs(transaction: goc, category: anUong),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cà phê chiều');
      await luu(tester);

      expect(transactions.added, isEmpty,
          reason: 'Sửa không được tạo hàng mới — trùng giao dịch.');
      final u = transactions.updated.single;
      expect(u.before.id, 'tx-goc');
      expect(u.after.id, 'tx-goc');
      expect(u.after.note, 'Cà phê chiều');
      expect(u.after.amount, 25000);
      expect(u.after.walletId, 'bank');
      expect(u.after.categoryId, 'food');
    });

    testWidgets('sửa khoản chuyển: mở sẵn tab Chuyển khoản với đúng hai ví',
        (tester) async {
      final chuyen = TransactionEntity(
        id: 'tx-chuyen',
        walletId: 'cash',
        idaccount: 1,
        walletTransfer: 'bank',
        amount: 5000,
        type: 'transfer',
        date: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      final transactions = FakeTransactionRepository();
      await tester.pumpWidget(app(
        categoryRepository: categories(),
        transactionRepository: transactions,
        initial: EditTransactionArgs(transaction: chuyen),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ví nguồn (Từ ví)'), findsOneWidget);
      expect(find.textContaining('Ngân hàng'), findsOneWidget);
      await luu(tester);

      final u = transactions.updated.single;
      expect(u.after.type, 'transfer');
      expect(u.after.walletTransfer, 'bank');
      expect(u.after.categoryId, isNull);
    });
  });

  testWidgets('màn 411dp có hàng Chiều tiền không tràn bố cục', (tester) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(
      categoryRepository: categories(),
      transactionRepository: FakeTransactionRepository(),
    ));
    await tester.pumpAndSettle();
    await chonDanhMuc(tester, tab: 'Vay / nợ', name: 'Cho vay');

    expect(find.text('Chiều tiền'), findsOneWidget);
    // Flutter báo tràn qua FlutterError.reportError chứ không ném ra chỗ gọi,
    // nên phải hỏi thẳng; bộ test mặc định chạy ở 800px nên không thấy gì.
    expect(tester.takeException(), isNull);
  });
}
