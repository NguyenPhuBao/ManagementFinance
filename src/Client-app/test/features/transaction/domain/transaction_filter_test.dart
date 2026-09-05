import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bộ lọc của sổ giao dịch chạy trên danh sách tháng đã có sẵn trong bloc —
/// thuần Dart, không truy vấn lại — nên test bằng `expect` thường.
void main() {
  TransactionEntity tx(
    String id, {
    String type = 'chi',
    String note = '',
    String walletId = 'w-cash',
    String? categoryId,
    String? walletTransfer,
    double amount = 10000,
  }) =>
      TransactionEntity(
        id: id,
        walletId: walletId,
        idaccount: 1,
        categoryId: categoryId,
        walletTransfer: walletTransfer,
        amount: amount,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

  final list = [
    tx('a', note: 'Cà phê Highlands', categoryId: 'c-food', amount: 55000),
    tx('b', type: 'thu', note: 'Lương tháng 9', categoryId: 'c-salary',
        amount: 9000000),
    tx('c', type: 'transfer', walletTransfer: 'w-save', amount: 200000),
    tx('d', note: 'Xăng xe', categoryId: 'c-move', walletId: 'w-save',
        amount: 45000),
  ];

  test('bộ lọc rỗng trả nguyên danh sách, và không được coi là đang lọc', () {
    const filter = TransactionFilter();
    expect(applyTransactionFilter(list, filter), list);
    expect(filter.isActive, isFalse);
  });

  test('lọc theo loại: thu / chi / chuyển khoản', () {
    expect(
      applyTransactionFilter(
              list, const TransactionFilter(type: TransactionTypeFilter.thu))
          .map((t) => t.id),
      ['b'],
    );
    expect(
      applyTransactionFilter(
              list, const TransactionFilter(type: TransactionTypeFilter.chi))
          .map((t) => t.id),
      ['a', 'd'],
    );
    expect(
      applyTransactionFilter(list,
              const TransactionFilter(type: TransactionTypeFilter.transfer))
          .map((t) => t.id),
      ['c'],
    );
  });

  test('lọc theo ví: khoản chuyển khớp ở CẢ ví nguồn lẫn ví đích', () {
    final result = applyTransactionFilter(
        list, const TransactionFilter(walletId: 'w-save'));
    expect(result.map((t) => t.id), ['c', 'd'],
        reason: 'Người dùng xem ví Tiết kiệm phải thấy tiền chuyển VÀO nó, '
            'không chỉ tiền đi ra.');
  });

  test('lọc theo danh mục', () {
    expect(
      applyTransactionFilter(
              list, const TransactionFilter(categoryId: 'c-food'))
          .map((t) => t.id),
      ['a'],
    );
  });

  test('tìm theo ghi chú: không phân biệt hoa/thường và dấu', () {
    expect(
      applyTransactionFilter(list, const TransactionFilter(query: 'ca phe'))
          .map((t) => t.id),
      ['a'],
      reason: 'Người dùng gõ nhanh thường bỏ dấu — đây là chỗ đúng để dùng '
          'removeVietnameseTones (chỉ là tìm kiếm, sai thì gõ lại).',
    );
    expect(
      applyTransactionFilter(list, const TransactionFilter(query: 'LƯƠNG'))
          .map((t) => t.id),
      ['b'],
    );
    expect(
      applyTransactionFilter(list, const TransactionFilter(query: '   ')),
      list,
      reason: 'Toàn khoảng trắng là chưa gõ gì.',
    );
  });

  test('các điều kiện kết hợp bằng VÀ', () {
    final result = applyTransactionFilter(
      list,
      const TransactionFilter(
          type: TransactionTypeFilter.chi, walletId: 'w-save'),
    );
    expect(result.map((t) => t.id), ['d']);
  });

  test('summarize: tổng thu, tổng chi của danh sách đã lọc; chuyển khoản không tính',
      () {
    final s = summarizeTransactions(list);
    expect(s.income, 9000000);
    expect(s.expense, 100000);
    expect(s.net, 8900000);
  });

  test('copyWith với clear để bỏ một điều kiện', () {
    const f = TransactionFilter(walletId: 'w-save', categoryId: 'c-food');
    final g = f.copyWith(clearWallet: true);
    expect(g.walletId, isNull);
    expect(g.categoryId, 'c-food');
    expect(g.isActive, isTrue);
  });
}
