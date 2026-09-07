import '../../../core/database/app_database.dart';

/// Tra tên ví và danh mục theo id cho các dòng trong sổ giao dịch.
///
/// Giao dịch chỉ lưu id; tên/icon/màu nằm ở bảng `wallets` và `categories`.
/// Trang xây một bản từ hai stream `watchAll` rồi chuyền xuống từng dòng, thay
/// vì mỗi dòng tự truy vấn.
class TransactionLookup {
  TransactionLookup({
    Iterable<Wallet> wallets = const [],
    Iterable<Category> categories = const [],
  })  : _wallets = {for (final w in wallets) w.id: w},
        _categories = {for (final c in categories) c.id: c};

  static final TransactionLookup empty = TransactionLookup();

  /// Ví không còn trong danh sách (đã xoá mềm, hoặc của tài khoản khác).
  /// Cố ý là chữ chứ không phải id: trước 2026-09-06 sổ in thẳng UUID.
  static const String tenViDaXoa = 'Ví đã xoá';

  final Map<String, Wallet> _wallets;
  final Map<String, Category> _categories;

  Wallet? wallet(String? id) => id == null ? null : _wallets[id];

  Category? category(String? id) => id == null ? null : _categories[id];

  String walletName(String? id) => wallet(id)?.name ?? tenViDaXoa;
}
