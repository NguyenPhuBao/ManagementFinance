/// Cổng cho Sổ giao dịch / Trang chủ hiện khoản của NHÀ do tôi ghi (spec 2026-11-16 mục 3): tên ví chung + danh mục nhà để
/// tra tên dòng, và quyền sửa / xoá một khoản nhà từ Sổ. Mảng giao dịch không import gia đình — hàm thật ở
/// `household/application/khoan_nha_cho_so.dart`, nối ở DI (khuôn `CapGopQuyNguon`).
library;

import '../../category/data/models/category_entity.dart';
import '../../wallet/data/models/wallet_entity.dart';
import 'models/transaction_entity.dart';

/// Bảng tra tên của nhà hiện tại. [rong] = không ở nhà nào (hoặc đọc hỏng): dòng nhà — nếu còn — hiện "Ví đã xoá".
class TraTenNha {
  const TraTenNha({this.idNha, this.tenNha, this.vi = const [], this.danhMuc = const []});

  static const rong = TraTenNha();

  final int? idNha;
  final String? tenNha;

  /// Ví chung của nhà (kể cả lưu trữ — khoản cũ vẫn trỏ vào nó).
  final List<WalletEntity> vi;

  /// Bảng tra tên danh mục có cả danh mục của nhà.
  final List<CategoryEntity> danhMuc;

  /// `{idNha: tenNha}` cho `TransactionLookup.tenNha`.
  Map<int, String> get tenTheoId => idNha == null ? const {} : {idNha!: tenNha ?? ''};
}

class KhoanNhaChoSoNguon {
  const KhoanNhaChoSoNguon({
    required Stream<TraTenNha> Function(int idaccount) traTen,
    required Future<({bool sua, bool xoa})> Function(TransactionEntity) quyen,
    required Future<void> Function(TransactionEntity) xoa,
  })  : _traTen = traTen,
        _quyen = quyen,
        _xoa = xoa;

  final Stream<TraTenNha> Function(int idaccount) _traTen;
  final Future<({bool sua, bool xoa})> Function(TransactionEntity) _quyen;
  final Future<void> Function(TransactionEntity) _xoa;

  /// Lỗi của stream bị nuốt (giữ bảng tra lần trước — dòng vẫn hiện), không đỏ màn.
  Stream<TraTenNha> traTen(int idaccount) => _traTen(idaccount).handleError((Object _) {});

  /// Lỗi đọc quyền → không sửa / xoá được (an toàn hơn mở nhầm).
  Future<({bool sua, bool xoa})> quyen(TransactionEntity t) async {
    try {
      return await _quyen(t);
    } catch (_) {
      return (sua: false, xoa: false);
    }
  }

  /// Ném tiếp: trang báo lỗi, không nuốt.
  Future<void> xoa(TransactionEntity t) => _xoa(t);
}
