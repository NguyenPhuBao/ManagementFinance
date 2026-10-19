import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/transaction_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Bảng chi tiết mở khi bấm một dòng trong sổ: đọc đủ thông tin, và là nơi
/// duy nhất có nút Sửa. Khoản thuộc mục tiêu, hay khoản trả của hoá đơn còn
/// sống, chỉ đọc — cùng quy tắc với chặn xoá (xem `transactionOwnerOf`); khoản
/// trả hoá đơn kiểu cũ / mồ côi (việc 4c) có Sửa · Xoá.
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
    String? billId,
  }) =>
      TransactionEntity(
        id: 'tx',
        walletId: 'w-cash',
        idaccount: 1,
        categoryId: categoryId,
        goalId: goalId,
        billId: billId,
        walletTransfer: walletTransfer,
        amount: 25000,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6, 14, 30),
        updatedAt: DateTime(2026, 9, 6),
      );

  Widget harness(TransactionEntity transaction,
          {VoidCallback? onEdit,
          VoidCallback? onDelete,
          bool hoaDonDaXoa = false}) =>
      MaterialApp(
        home: Scaffold(
          body: TransactionDetailSheet(
            transaction: transaction,
            lookup: lookup,
            onEdit: onEdit ?? () {},
            onDelete: onDelete ?? () {},
            hoaDonDaXoa: hoaDonDaXoa,
          ),
        ),
      );

  testWidgets('khoản chi: đủ số tiền, danh mục, ví, ngày giờ, ghi chú',
      (tester) async {
    await tester.pumpWidget(
        harness(tx(note: 'Cà phê sáng', categoryId: 'c-food')));

    expect(find.text('-25.000 đ'), findsOneWidget);
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

  group('việc 4c — khoản trả hoá đơn', () {
    const ghiChuTra = '${kGhiChuTraHoaDon}Tiền điện';

    testWidgets('hoá đơn còn (có billId): KHÔNG Sửa/Xoá, hiện lý do', (tester) async {
      await tester.pumpWidget(harness(tx(billId: 'b1', note: ghiChuTra)));

      expect(find.text('Xoá giao dịch'), findsNothing);
      expect(find.text('Sửa giao dịch'), findsNothing);
      expect(find.textContaining('không xoá được từ sổ giao dịch'), findsOneWidget,
          reason: 'Đòi kết quả, không chỉ đòi vắng mặt: bảng phải nói vì sao.');
    });

    testWidgets('mồ côi (hoaDonDaXoa: true): có Sửa và Xoá', (tester) async {
      await tester.pumpWidget(
          harness(tx(billId: 'b1', note: ghiChuTra), hoaDonDaXoa: true));

      expect(find.text('Xoá giao dịch'), findsOneWidget);
      expect(find.text('Sửa giao dịch'), findsOneWidget);
    });

    testWidgets('kiểu cũ (tiền tố, không billId): có Sửa và Xoá', (tester) async {
      await tester.pumpWidget(harness(tx(note: ghiChuTra)));

      expect(find.text('Xoá giao dịch'), findsOneWidget);
      expect(find.text('Sửa giao dịch'), findsOneWidget);
    });
  });
}
