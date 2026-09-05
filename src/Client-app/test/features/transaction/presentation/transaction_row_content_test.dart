import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/transaction_row_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Nội dung một dòng trong sổ giao dịch, theo bố cục Stitch màn Home:
/// tiêu đề = ghi chú (không có thì tên danh mục), dòng phụ = "Danh mục • Ví",
/// icon/màu của danh mục, số tiền có dấu. Trước 2026-09-06 dòng phụ in thẳng
/// UUID của ví và không có danh mục ở đâu cả.
void main() {
  final anUong = makeCategory(id: 'c-food', name: 'Ăn uống', isDefault: true);
  final lookup = TransactionLookup(
    wallets: [
      makeWallet(id: 'w-cash', name: 'Tiền mặt'),
      makeWallet(id: 'w-save', name: 'Tiết kiệm'),
    ],
    categories: [anUong],
  );

  TransactionEntity tx({
    String type = 'chi',
    String note = '',
    String? categoryId,
    String walletId = 'w-cash',
    String? walletTransfer,
  }) =>
      TransactionEntity(
        id: 't',
        walletId: walletId,
        idaccount: 1,
        categoryId: categoryId,
        walletTransfer: walletTransfer,
        amount: 25000,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

  test('khoản chi có ghi chú: ghi chú là tiêu đề, dòng phụ là Danh mục • Ví',
      () {
    final c = buildTransactionRowContent(
        tx(note: 'Cà phê sáng', categoryId: 'c-food'), lookup);

    expect(c.title, 'Cà phê sáng');
    expect(c.subtitle, 'Ăn uống • Tiền mặt');
    expect(c.amountText, '-25.000đ');
  });

  test('không ghi chú: tên danh mục lên làm tiêu đề, dòng phụ chỉ còn ví', () {
    final c = buildTransactionRowContent(tx(categoryId: 'c-food'), lookup);

    expect(c.title, 'Ăn uống');
    expect(c.subtitle, 'Tiền mặt');
  });

  test('icon và màu lấy từ danh mục, không còn mũi tên chung chung', () {
    final c = buildTransactionRowContent(tx(categoryId: 'c-food'), lookup);

    expect(c.icon, Icons.category_outlined,
        reason: 'makeCategory dùng icon "category" — không nằm trong bộ tên '
            'quen thuộc nên về mặc định là đúng; điểm chính là KHÔNG phải '
            'arrow_downward.');
    expect(c.colour, const Color(0xFF10B981),
        reason: 'Màu danh mục (#10B981) chứ không phải màu đỏ của khoản chi.');
  });

  test('khoản thu không có danh mục: nhãn theo loại, dấu cộng, màu thu', () {
    final c = buildTransactionRowContent(tx(type: 'thu'), lookup);

    expect(c.title, 'Khoản thu');
    expect(c.subtitle, 'Tiền mặt');
    expect(c.amountText, '+25.000đ');
  });

  test('chuyển khoản: tiêu đề "Chuyển khoản", dòng phụ Ví nguồn → Ví đích, không dấu',
      () {
    final c = buildTransactionRowContent(
        tx(type: 'transfer', walletTransfer: 'w-save'), lookup);

    expect(c.title, 'Chuyển khoản');
    expect(c.subtitle, 'Tiền mặt → Tiết kiệm');
    expect(c.amountText, '25.000đ',
        reason: 'Chuyển ví không phải thu hay chi; gắn dấu là gợi sai rằng '
            'nó nằm trong tổng tháng.');
    expect(c.icon, Icons.swap_horiz);
  });

  test('khoản nạp mục tiêu giữ ghi chú làm tiêu đề, vẫn có chiều ví', () {
    final c = buildTransactionRowContent(
      tx(
        type: 'transfer',
        note: 'Tích lũy mục tiêu: MuaXe',
        walletTransfer: 'w-save',
      ),
      lookup,
    );

    expect(c.title, 'Tích lũy mục tiêu: MuaXe');
    expect(c.subtitle, 'Tiền mặt → Tiết kiệm');
  });

  test('ví không còn trong danh sách thì ghi "Ví đã xoá", không bao giờ in UUID',
      () {
    final c = buildTransactionRowContent(
        tx(walletId: '6f8e6b7a-5a61-4089-be4b-eb7ef8ae9426'), lookup);

    expect(c.subtitle, isNot(contains('6f8e6b7a')));
    expect(c.subtitle, contains('Ví đã xoá'));
  });
}
