/// Số tiền có phần lẻ ở màn Thêm/Sửa giao dịch — **A12**, lượt UX 2026-09-19.
///
/// ## Lỗi này canh chừng điều gì
///
/// `_amountString` là chuỗi **thô** người dùng đang gõ, không phải chuỗi đã
/// định dạng — phép ngăn nghìn chỉ áp ở `_getFormattedAmount`. Nhưng
/// `_saveTransaction` lại đọc nó bằng
/// `double.tryParse(_amountString.replaceAll('.', ''))`, tức **coi dấu chấm là
/// dấu ngăn nghìn** theo thói quen Việt Nam. Hậu quả: một chuỗi có dấu thập
/// phân bị mất dấu chấm rồi đọc tiếp, nên `12.5` lưu xuống thành **125** —
/// sai gấp mười, không exception, không log.
///
/// ## Hai cửa, không phải một
///
/// 1. **Bàn phím**: lưới 4×4 có phím `.`, gõ ra được `12.5` ngay trên màn thêm
///    mới. Đóng bằng cách bỏ phím ấy (người dùng chốt 2026-09-19 — app làm
///    tròn về đồng chẵn ở mọi chỗ hiển thị, xem `CurrencyFormatter.format`),
///    và `themPhimSoTien` giữ nhánh vô hiệu cho `.`.
/// 2. ⚠️ **Chế độ sửa**: `initState` điền `_amountString` bằng
///    `editing.amount.toString()` khi số tiền **không tròn đồng**, nên chuỗi có
///    dấu chấm vẫn vào được dù bàn phím đã hết phím `.`. Và số lẻ tồn tại
///    thật: `transaction."Amount"` là `numeric(15,2)`, còn
///    `dieu_chinh_so_du_service` sinh khoản bù với ngưỡng nửa đồng. Cửa này
///    **chỉ đóng được ở `_saveTransaction`** — bỏ phím thôi là chưa đủ, và đây
///    là cửa nặng hơn vì nó nhân mười một khoản **đã có thật** trong sổ.
library;

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
          'chi': CategoryTree(
            groups: const [],
            ungroupedChildren: const [],
            defaultChildren: [anUong],
          ),
        },
      );

  /// Giao dịch đã có trong sổ, số tiền **không tròn đồng**.
  TransactionEntity khoanLe({double amount = 12.5}) => TransactionEntity(
        id: 'tx-le',
        walletId: 'cash',
        idaccount: 1,
        categoryId: 'food',
        amount: amount,
        type: 'chi',
        note: 'Khoản có phần lẻ',
        date: DateTime(2026, 9, 19),
        updatedAt: DateTime(2026, 9, 19),
      );

  /// ⚠️ Phải dựng trong `GoRouter` thật: lưu xong trang gọi `context.pop()`,
  /// mà `MaterialApp` trần thì lời gọi ấy ném "No GoRouter found in context"
  /// và ca test đỏ vì một lý do chẳng liên quan gì tới số tiền.
  Widget app({
    required FakeTransactionRepository transactionRepository,
    EditTransactionArgs? initial,
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
                categoryRepository: categories(),
                wallets: [makeWallet()],
                idaccount: 1,
                initial: initial,
                // Tiêm thẳng, không qua `sl`: test không dựng DI.
                budgetLookup: (_, __) async => null,
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('lưới bàn phím không còn phím `.`; chỗ ấy là phím `00`',
      (tester) async {
    await tester.pumpWidget(
        app(transactionRepository: FakeTransactionRepository()));
    await tester.pumpAndSettle();

    expect(find.text('.'), findsNothing,
        reason: 'Phím `.` sinh ra một chuỗi mà `_saveTransaction` đọc sai gấp '
            'mười. App làm tròn về đồng chẵn ở mọi chỗ hiển thị nên phím này '
            'không có việc gì để làm (người dùng chốt 2026-09-19).');
    expect(find.text('00'), findsOneWidget,
        reason: 'Lưới là 4×4 = 16 ô; bỏ một phím mà không thay chỗ thì hàng '
            'cuối còn ba ô và cả bàn phím lệch cột.');
    // Cụm số 0 kia vẫn còn — `00` không thay `000`.
    expect(find.text('000'), findsOneWidget);
  });

  testWidgets(
      '⚠️ sửa một khoản có phần lẻ rồi bấm ✓ thì số tiền GIỮ NGUYÊN, không '
      'nhân mười', (tester) async {
    final repo = FakeTransactionRepository();
    final goc = khoanLe();
    await tester.pumpWidget(app(
      transactionRepository: repo,
      initial: EditTransactionArgs(transaction: goc, category: anUong),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.updated, hasLength(1),
        reason: 'Bấm ✓ ở chế độ sửa phải phát UpdateTransactionEvent.');
    expect(repo.updated.single.after.amount, 12.5,
        reason: '`_saveTransaction` strip dấu chấm vì tưởng nó là dấu ngăn '
            'nghìn, nên 12.5 thành 125 — người dùng mở một khoản cũ ra xem rồi '
            'bấm lưu là số tiền tự nhân mười, im lặng. Bỏ phím `.` KHÔNG đóng '
            'được cửa này: chuỗi có dấu chấm đến từ `initState`.');
  });

  testWidgets('⚠️ khoản có phần lẻ hiện bằng DẤU PHẨY, qua CurrencyFormatter',
      (tester) async {
    await tester.pumpWidget(app(
      transactionRepository: FakeTransactionRepository(),
      initial: EditTransactionArgs(transaction: khoanLe(), category: anUong),
    ));
    await tester.pumpAndSettle();

    expect(find.text('12,50 đ'), findsOneWidget,
        reason: 'Nửa HIỂN THỊ của cùng một lỗi: "12.5 đ" in thẳng chuỗi thô, '
            'mà khắp app dấu chấm là dấu ngăn nghìn (quy ước Việt Nam, xem '
            '`CurrencyFormatter`) — người dùng đọc ra một con số khác hẳn, '
            'ngay cạnh nút lưu. `formatCoLe` là chỗ duy nhất được phép hiện '
            'phần lẻ và nó ngăn bằng dấu phẩy.');
    expect(find.text('12.5 đ'), findsNothing);
  });

  testWidgets('sửa một khoản tròn đồng thì vẫn lưu đúng như cũ',
      (tester) async {
    final repo = FakeTransactionRepository();
    await tester.pumpWidget(app(
      transactionRepository: repo,
      initial: EditTransactionArgs(
          transaction: khoanLe(amount: 50000), category: anUong),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.updated.single.after.amount, 50000,
        reason: 'Đường thường không được đổi hành vi: khoản tròn đồng vào '
            '`_amountString` dưới dạng "50000", không dấu chấm nào.');
  });
}
