import '../../category/data/models/category_entity.dart';
import '../../wallet/data/models/wallet_entity.dart';

/// Tra tên ví và danh mục theo id cho các dòng trong sổ giao dịch.
///
/// Giao dịch chỉ lưu id; tên/icon/màu nằm ở bảng `wallets` và `categories`.
/// Trang xây một bản từ hai stream `watchAll` rồi chuyền xuống từng dòng, thay
/// vì mỗi dòng tự truy vấn.
///
/// Ví là `WalletEntity` từ 2026-10-14, danh mục là `CategoryEntity` từ 2026-10-15 —
/// hai mảng, hai Entity, một bảng tra.
class TransactionLookup {
  TransactionLookup({
    Iterable<WalletEntity> wallets = const [],
    Iterable<CategoryEntity> categories = const [],
  })  : _wallets = {for (final w in wallets) w.id: w},
        _categories = {for (final c in categories) c.id: c};

  static final TransactionLookup empty = TransactionLookup();

  /// Ví không còn trong danh sách (đã xoá mềm, hoặc của tài khoản khác).
  /// Cố ý là chữ chứ không phải id: trước 2026-09-06 sổ in thẳng UUID.
  static const String tenViDaXoa = 'Ví đã xoá';

  final Map<String, WalletEntity> _wallets;
  final Map<String, CategoryEntity> _categories;

  WalletEntity? wallet(String? id) => id == null ? null : _wallets[id];

  CategoryEntity? category(String? id) => id == null ? null : _categories[id];

  String walletName(String? id) => wallet(id)?.name ?? tenViDaXoa;
}
