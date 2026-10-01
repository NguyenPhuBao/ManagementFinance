import '../../../core/category/category_name.dart';
import '../../analytics/domain/khoan_vao_thong_ke.dart';
import '../data/models/transaction_entity.dart';
import 'khoang_tien.dart';

enum TransactionTypeFilter { all, thu, chi, transfer }

/// Điều kiện lọc của sổ giao dịch. Chạy trên danh sách tháng đã có sẵn trong
/// bloc — thuần Dart, không truy vấn lại — nên đổi điều kiện là thấy ngay.
class TransactionFilter {
  const TransactionFilter({
    this.type = TransactionTypeFilter.all,
    this.walletId,
    this.categoryId,
    this.query = '',
    this.khoangTien,
  });

  final TransactionTypeFilter type;
  final String? walletId;
  final String? categoryId;
  final String query;

  /// Khoảng số tiền; `null` = không lọc theo tiền. Xem `khoang_tien.dart` —
  /// phép so nằm trong chính lớp ấy, không chép ra đây.
  final KhoangTien? khoangTien;

  bool get isActive =>
      type != TransactionTypeFilter.all ||
      walletId != null ||
      categoryId != null ||
      khoangTien != null ||
      query.trim().isNotEmpty;

  TransactionFilter copyWith({
    TransactionTypeFilter? type,
    String? walletId,
    bool clearWallet = false,
    String? categoryId,
    bool clearCategory = false,
    String? query,
    KhoangTien? khoangTien,
    bool clearKhoangTien = false,
  }) =>
      TransactionFilter(
        type: type ?? this.type,
        walletId: clearWallet ? null : (walletId ?? this.walletId),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        query: query ?? this.query,
        khoangTien: clearKhoangTien ? null : (khoangTien ?? this.khoangTien),
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
    // `amount` luôn dương ở SQLite client (chiều tiền nằm ở `type`), nên khoảng
    // tiền áp cho cả thu, chi lẫn khoản chuyển — "khoản trên 500k" không phân
    // biệt chiều.
    final khoangTien = filter.khoangTien;
    if (khoangTien != null && !khoangTien.chua(t.amount)) return false;
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

/// Tổng thu / chi của một danh sách — thẻ tổng của Sổ giao dịch.
///
/// Hàng được tính theo **đúng một** luật `khoanVaoThongKe` — cùng luật với Trang chủ (`thuChiThangCua`), trang Phân
/// tích và trợ lý AI (`tongThuChi`): bỏ khoản chuyển, khoản điều chỉnh số dư, khoản "Số dư ban đầu"; khoản chưa phân
/// loại thật **vẫn** tính. Trước 2026-09-29 vòng này cộng **thô** theo `type`, nên thẻ tổng nói Thu nhập 15.145.000 đ
/// trong khi Trang chủ nói 15.135.000 đ (lệch đúng một khoản điều chỉnh +10.000 đ, đo trên Realme) — bước 1a
/// (2026-09-23) sửa Trang chủ mà để sót chỗ này. Hệ quả **cố ý**: hàng điều chỉnh vẫn hiện trong danh sách nhưng không
/// cộng vào thẻ (người dùng chốt con số của Phân tích). ⚠️ Đừng viết lại vòng cộng theo `type` ở nơi khác.
TransactionSummary summarizeTransactions(Iterable<TransactionEntity> list) {
  var income = 0.0;
  var expense = 0.0;
  for (final t in list) {
    if (!khoanVaoThongKe(loai: t.type, categoryId: t.categoryId, ghiChu: t.note)) continue;
    if (t.type == 'thu') income += t.amount;
    if (t.type == 'chi') expense += t.amount;
  }
  return TransactionSummary(income: income, expense: expense);
}
