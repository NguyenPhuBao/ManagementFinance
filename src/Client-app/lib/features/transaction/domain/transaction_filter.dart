import '../../../core/category/category_name.dart';
import '../data/models/transaction_entity.dart';

enum TransactionTypeFilter { all, thu, chi, transfer }

/// Điều kiện lọc của sổ giao dịch. Chạy trên danh sách tháng đã có sẵn trong
/// bloc — thuần Dart, không truy vấn lại — nên đổi điều kiện là thấy ngay.
class TransactionFilter {
  const TransactionFilter({
    this.type = TransactionTypeFilter.all,
    this.walletId,
    this.categoryId,
    this.query = '',
  });

  final TransactionTypeFilter type;
  final String? walletId;
  final String? categoryId;
  final String query;

  bool get isActive =>
      type != TransactionTypeFilter.all ||
      walletId != null ||
      categoryId != null ||
      query.trim().isNotEmpty;

  TransactionFilter copyWith({
    TransactionTypeFilter? type,
    String? walletId,
    bool clearWallet = false,
    String? categoryId,
    bool clearCategory = false,
    String? query,
  }) =>
      TransactionFilter(
        type: type ?? this.type,
        walletId: clearWallet ? null : (walletId ?? this.walletId),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        query: query ?? this.query,
      );
}

// Tìm kiếm là chỗ ĐÚNG để bỏ dấu (xem chú thích `removeVietnameseTones`):
// đoán sai chỉ tốn một lần gõ lại.
String _khoaTimKiem(String value) =>
    removeVietnameseTones(value).toLowerCase().trim();

List<TransactionEntity> applyTransactionFilter(
  List<TransactionEntity> transactions,
  TransactionFilter filter,
) {
  final query = _khoaTimKiem(filter.query);
  return transactions.where((t) {
    final typeOk = switch (filter.type) {
      TransactionTypeFilter.all => true,
      TransactionTypeFilter.thu => t.type == 'thu',
      TransactionTypeFilter.chi => t.type == 'chi',
      TransactionTypeFilter.transfer => t.type == 'transfer',
    };
    if (!typeOk) return false;
    // Khoản chuyển khớp ở CẢ ví nguồn lẫn ví đích: xem ví Tiết kiệm phải thấy
    // tiền chuyển VÀO nó.
    final walletId = filter.walletId;
    if (walletId != null &&
        t.walletId != walletId &&
        t.walletTransfer != walletId) {
      return false;
    }
    final categoryId = filter.categoryId;
    if (categoryId != null && t.categoryId != categoryId) return false;
    if (query.isNotEmpty && !_khoaTimKiem(t.note).contains(query)) return false;
    return true;
  }).toList();
}

class TransactionSummary {
  const TransactionSummary({required this.income, required this.expense});

  final double income;
  final double expense;

  double get net => income - expense;
}

/// Tổng thu / chi của một danh sách; chuyển khoản không tính (không phải thu
/// hay chi — cùng quy ước với bloc và trang chủ).
TransactionSummary summarizeTransactions(Iterable<TransactionEntity> list) {
  var income = 0.0;
  var expense = 0.0;
  for (final t in list) {
    if (t.type == 'thu') income += t.amount;
    if (t.type == 'chi') expense += t.amount;
  }
  return TransactionSummary(income: income, expense: expense);
}
