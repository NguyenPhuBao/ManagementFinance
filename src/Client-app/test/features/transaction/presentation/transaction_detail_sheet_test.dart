import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/transaction_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Bảng chi tiết mở khi bấm một dòng trong sổ: đọc đủ thông tin, và là nơi
/// duy nhất có nút Sửa. Khoản thuộc mục tiêu/hoá đơn chỉ đọc — cùng quy tắc
/// với chặn xoá (xem `transactionOwnerOf`).
void main() {
  final lookup = TransactionLookup(
    wallets: [
      makeWallet(id: 'w-cash', name: 'Tiền mặt'),
      makeWallet(id: 'w-save', name: 'Tiết kiệm'),
    ],
    categories: [makeCategory(id: 'c-food', name: 'Ăn uống')],
  );

  TransactionEntity tx({
    String type = 'chi',
    String note = '',
    String? categoryId,
    String? goalId,
    String? walletTransfer,
  }) =>
      TransactionEntity(
        id: 'tx',
        walletId: 'w-cash',
        idaccount: 1,
        categoryId: categoryId,
        goalId: goalId,
        walletTransfer: walletTransfer,
        amount: 25000,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6, 14, 30),
        updatedAt: DateTime(2026, 9, 6),
      );

  Widget harness(TransactionEntity transaction,
          {VoidCallback? onEdit, VoidCallback? onDelete}) =>
      MaterialApp(
        home: Scaffold(
          body: TransactionDetailSheet(
            transaction: transaction,
            lookup: lookup,
            onEdit: onEdit ?? () {},
            onDelete: onDelete ?? () {},
          ),
        ),
      );

  testWidgets('khoản chi: đủ số tiền, danh mục, ví, ngày giờ, ghi chú',
      (tester) async {
    await tester.pumpWidget(
        harness(tx(note: 'Cà phê sáng', categoryId: 'c-food')));

    expect(find.text('-25.000đ'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.text('Cà phê sáng'), findsOneWidget);
    expect(find.text('06/09/2026 14:30'), findsOneWidget);
    expect(find.text('Khoản chi'), findsOneWidget);
  });

  testWidgets('khoản chuyển: hiện ví nguồn và ví đích', (tester) async {
    await tester.pumpWidget(
        harness(tx(type: 'transfer', walletTransfer: 'w-save')));

    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.text('Tiết kiệm'), findsOneWidget);
    expect(find.text('Chuyển khoản'), findsOneWidget);
  });

  testWidgets('giao dịch thường: có Sửa và Xoá, bấm gọi đúng callback',
      (tester) async {
    var edits = 0;
    var deletes = 0;
    await tester.pumpWidget(harness(
      tx(categoryId: 'c-food'),
      onEdit: () => edits++,
      onDelete: () => deletes++,
    ));

    await tester.tap(find.text('Sửa giao dịch'));
    await tester.pump();
    expect(edits, 1);

    await tester.tap(find.text('Xoá giao dịch'));
    await tester.pump();
    expect(deletes, 1);
  });

  testWidgets('khoản của mục tiêu: KHÔNG có Sửa/Xoá, hiện lý do', (tester) async {
    await tester.pumpWidget(harness(
        tx(type: 'transfer', goalId: 'g1', walletTransfer: 'w-save')));

    expect(find.text('Sửa giao dịch'), findsNothing,
        reason: 'Sửa số tiền của khoản nạp mà không qua mục tiêu là làm lệch '
            'current_amount y như xoá.');
    expect(find.text('Xoá giao dịch'), findsNothing);
    expect(find.textContaining('mục tiêu'), findsWidgets);
  });
}
