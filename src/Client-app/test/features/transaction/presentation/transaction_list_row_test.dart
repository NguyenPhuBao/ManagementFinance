import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/transaction_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Hàng trong sổ giao dịch: vuốt trái để xoá, NHƯNG khoản thuộc mục tiêu hay
/// hoá đơn thì bật lại và chỉ đường thay vì xoá. Tách thành widget riêng vì
/// `TransactionPage` nối thẳng vào `sl` và `AuthBloc`, không dựng được trong
/// test.
void main() {
  TransactionEntity tx({String? goalId, String note = '', String type = 'chi'}) =>
      TransactionEntity(
        id: 'tx-$note-$goalId',
        walletId: 'w',
        idaccount: 1,
        goalId: goalId,
        amount: 25000,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

  Future<int> vuotXoa(WidgetTester tester, TransactionEntity transaction) async {
    var deleted = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: transaction,
          onDelete: () => deleted++,
        ),
      ),
    ));
    // Tìm theo key chứ không theo kiểu: SnackBar của Material cũng là một
    // Dismissible, nên sau khi báo lỗi thì `byType` thấy hai.
    await tester.drag(find.byKey(Key(transaction.id)), const Offset(-600, 0));
    await tester.pumpAndSettle();
    return deleted;
  }

  testWidgets('giao dịch thường: vuốt là xoá và báo đã xoá', (tester) async {
    final deleted = await vuotXoa(tester, tx(note: 'Cà phê'));

    expect(deleted, 1);
    expect(find.text('Đã xóa giao dịch'), findsOneWidget);
  });

  testWidgets('khoản của mục tiêu: KHÔNG xoá, hàng bật lại, chỉ sang trang mục tiêu',
      (tester) async {
    final khoanNap = tx(goalId: 'g1', type: 'transfer');
    final deleted = await vuotXoa(tester, khoanNap);

    expect(deleted, 0,
        reason: 'Xoá ở sổ chỉ hoàn ví; current_amount của mục tiêu đứng nguyên '
            'nên tiến độ và lịch sử nói ngược nhau.');
    expect(find.byKey(Key(khoanNap.id)), findsOneWidget,
        reason: 'confirmDismiss trả false thì hàng phải còn đó.');
    expect(find.textContaining('mục tiêu'), findsWidgets);
    expect(find.text('Đã xóa giao dịch'), findsNothing);
  });

  testWidgets('khoản trả hoá đơn: KHÔNG xoá, báo lý do', (tester) async {
    final khoanTra = tx(note: 'Thanh toán hóa đơn: Tiền điện');
    final deleted = await vuotXoa(tester, khoanTra);

    expect(deleted, 0,
        reason: 'Trả hoá đơn là bốn bước trong một transaction (Payed, giao '
            'dịch, trừ ví, kỳ kế tiếp); xoá một bước thì ba bước kia còn nguyên.');
    expect(find.byKey(Key(khoanTra.id)), findsOneWidget);
    expect(find.textContaining('hoá đơn'), findsWidgets);
  });

  testWidgets('hàng không ghi chú hiện nhãn theo loại', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: tx(type: 'transfer'),
          onDelete: () {},
        ),
      ),
    ));
    expect(find.text('Chuyển khoản'), findsOneWidget);
  });

  testWidgets('bấm vào dòng gọi onTap — đường vào bảng chi tiết', (tester) async {
    var taps = 0;
    final khoanChi = tx(note: 'Cà phê');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: khoanChi,
          onDelete: () {},
          onTap: () => taps++,
        ),
      ),
    ));

    await tester.tap(find.byKey(Key(khoanChi.id)));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('có lookup thì hiện tên ví và danh mục, không bao giờ in UUID',
      (tester) async {
    final lookup = TransactionLookup(
      wallets: [makeWallet(id: 'w', name: 'Tiền mặt')],
      categories: [makeCategory(id: 'c-food', name: 'Ăn uống')],
    );
    final khoanChi = TransactionEntity(
      id: '6f8e6b7a-5a61-4089-be4b-eb7ef8ae9426',
      walletId: 'w',
      idaccount: 1,
      categoryId: 'c-food',
      amount: 25000,
      type: 'chi',
      note: 'Cà phê',
      date: DateTime(2026, 9, 6),
      updatedAt: DateTime(2026, 9, 6),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: khoanChi,
          onDelete: () {},
          lookup: lookup,
        ),
      ),
    ));

    expect(find.text('Cà phê'), findsOneWidget);
    expect(find.text('Ăn uống • Tiền mặt'), findsOneWidget);
    expect(find.textContaining('6f8e6b7a'), findsNothing,
        reason: 'Trước 2026-09-06 dòng phụ là "Ví: <UUID>".');
    expect(find.text('-25.000đ'), findsOneWidget);
  });
}
