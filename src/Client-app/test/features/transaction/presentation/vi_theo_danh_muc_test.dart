/// Trang Thêm giao dịch đổi ví chọn sẵn theo danh mục vừa chọn (chặng 1.2).
///
/// Luật đếm tần suất nằm ở `domain/vi_hay_dung.dart` và có bộ test riêng; ở đây
/// chỉ kiểm **chỗ nối**: trang có tra bảng không, và có biết lúc nào KHÔNG được
/// giành quyền khỏi tay người dùng không.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);
  final muaSam = makeCategory(id: 'shop', name: 'Mua sắm', isDefault: true);

  final tienMat = makeWallet();
  final nganHang = makeWallet(id: 'bank', name: 'Ngân hàng');

  CategoryTree treeOf(List<Category> defaults) => CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: defaults,
      );

  // Đủ ba phân loại: bảng chọn chỉ vẽ hàng tab khi có nhiều hơn một.
  FakeCategoryRepository categories() => FakeCategoryRepository(
        trees: {
          'chi': treeOf([anUong, muaSam]),
          'thu': treeOf(const []),
          'vay_no': treeOf(const []),
        },
      );

  Widget app({
    Map<String, String>? viHayDung,
    EditTransactionArgs? initial,
  }) {
    final bloc =
        TransactionBloc(transactionRepository: FakeTransactionRepository());
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
                wallets: [tienMat, nganHang],
                idaccount: 1,
                viHayDung: viHayDung,
                initial: initial,
              ),
            ),
          ],
        ),
        // ⚠️ Trang thêm `push` CỨNG '/add/category' (như `app_router` thật),
        // nên route này phải ở cấp gốc. Lồng nó dưới '/start/add' thì cú chạm
        // "Danh mục" không mở gì cả và ca test đỏ ở một chỗ trông chẳng liên
        // quan: không tìm thấy tab "Khoản chi".
        GoRoute(
          path: '/add/category',
          builder: (_, state) => ChooseCategoryPage(
            classify: state.extra as String? ?? 'chi',
            repository: categories(),
            idaccount: 1,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> chonDanhMuc(WidgetTester tester, String ten) async {
    await tester.ensureVisible(find.text('Danh mục'));
    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khoản chi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ten));
    await tester.pumpAndSettle();
  }

  testWidgets('chọn danh mục có ví hay dùng → ví chọn sẵn đổi theo',
      (tester) async {
    await tester.pumpWidget(app(viHayDung: {'food': 'bank'}));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tiền mặt •'), findsOneWidget,
        reason: 'mở trang vẫn là ví mặc định — chưa biết danh mục nào');

    await chonDanhMuc(tester, 'Ăn uống');
    expect(find.textContaining('Ngân hàng •'), findsOneWidget);
    expect(find.textContaining('Tiền mặt •'), findsNothing);
  });

  testWidgets('danh mục chưa đủ căn cứ → giữ nguyên ví mặc định',
      (tester) async {
    await tester.pumpWidget(app(viHayDung: {'food': 'bank'}));
    await tester.pumpAndSettle();

    await chonDanhMuc(tester, 'Mua sắm');
    expect(find.textContaining('Tiền mặt •'), findsOneWidget,
        reason: 'bảng không có "shop" nghĩa là CHƯA BIẾT, không phải "đổi đi"');
  });

  testWidgets('không có bảng nào → hành vi y hệt trước lượt này',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await chonDanhMuc(tester, 'Ăn uống');
    expect(find.textContaining('Tiền mặt •'), findsOneWidget);
  });

  testWidgets('người dùng đã tự chọn ví thì luật KHÔNG giành lại quyền',
      (tester) async {
    // Ví hay dùng của "Ăn uống" là TIỀN MẶT — đúng ví đang chọn sẵn. Người dùng
    // tự đổi sang Ngân hàng, nên nếu luật giành quyền thì nó sẽ kéo ngược về
    // Tiền mặt và ca này đỏ. Đặt ngược lại (hay dùng = Ngân hàng) thì ca không
    // canh được gì: hai bên cùng muốn một kết quả.
    await tester.pumpWidget(app(viHayDung: {'food': 'cash'}));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Tiền mặt •'));
    await tester.tap(find.textContaining('Tiền mặt •'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngân hàng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ngân hàng •'), findsOneWidget);

    await chonDanhMuc(tester, 'Ăn uống');
    expect(find.textContaining('Ngân hàng •'), findsOneWidget,
        reason: 'ví người dùng vừa đặt tay phải thắng phép đoán từ lịch sử');
  });

  testWidgets('chế độ sửa: ví của giao dịch thắng, luật không chen vào',
      (tester) async {
    final goc = TransactionEntity(
      id: 't1',
      idaccount: 1,
      walletId: 'cash',
      categoryId: 'food',
      amount: 25000,
      type: 'chi',
      date: DateTime(2026, 9, 21),
      note: '',
      updatedAt: DateTime(2026, 9, 21),
    );
    // ⚠️ Bảng trỏ 'shop' chứ không 'food': ca phải ĐỔI danh mục thì mới đi qua
    // `_apDungViHayDung`. Bản đầu của ca này chỉ mở trang rồi xem ví — nó xanh
    // cả khi bỏ sạch hai chốt, vì ở chế độ sửa danh mục đặt thẳng trong
    // `initState` chứ không qua `_chonDanhMuc`. Cùng họ bẫy G43.
    await tester.pumpWidget(app(
      viHayDung: {'shop': 'bank'},
      initial: EditTransactionArgs(transaction: goc, category: anUong),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tiền mặt •'), findsOneWidget,
        reason: 'giao dịch đã ghi ở ví nào thì sửa phải mở đúng ví ấy');

    await chonDanhMuc(tester, 'Mua sắm');
    expect(find.textContaining('Tiền mặt •'), findsOneWidget,
        reason: 'đổi danh mục khi đang sửa KHÔNG được đổi ví: nó quyết định ví '
            'nào bị trừ tiền, và người dùng không hề yêu cầu điều đó');
  });
}
