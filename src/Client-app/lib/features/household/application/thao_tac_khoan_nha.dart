import '../../../core/errors/app_exceptions.dart';
import '../../transaction/data/models/transaction_entity.dart';
import '../../transaction/data/repositories/transaction_repository.dart';
import 'gop_quy_service.dart';

/// Thao tác trên MỘT khoản của nhà từ Hoạt động (đợt 1B, Task 6). Chỉ xoá: sửa đi qua form `/nha/khoan`.
///
/// ⚠️ KHÔNG kiểm quyền: ai được xoá là việc của tầng trên (`quyenKhoanNha`).
class ThaoTacKhoanNha {
  ThaoTacKhoanNha({required TransactionRepository giaoDich, required GopQuyService gopQuy})
      : _giaoDich = giaoDich,
        _gopQuy = gopQuy;

  final TransactionRepository _giaoDich;
  final GopQuyService _gopQuy;

  /// Khoản có mã cặp xoá CẢ HAI nửa còn trên máy (`GopQuyService.xoa`); khoản thường xoá một hàng và hoàn hệ quả lên ví
  /// (khoản chuyển cần ví đích). Cặp không còn nửa nào trên máy (đã gỡ ở máy khác rồi kéo về) thì ném thay vì im lặng.
  Future<void> xoa(TransactionEntity t) async {
    final maCap = t.fundPairId;
    if (maCap != null) {
      if (!await _gopQuy.xoa(maCap)) throw const CacheException('Khoản này không còn trên máy.');
      return;
    }
    await _giaoDich.deleteTransaction(t, destinationWalletId: t.walletTransfer);
  }
}
