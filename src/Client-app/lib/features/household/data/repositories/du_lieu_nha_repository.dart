import '../../../transaction/data/models/transaction_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';

/// Đọc / ghi ví chung và khoản của nhà (gia đình 1A). Mọi phép lọc theo NHÀ, không theo tài khoản: `idaccount` của hàng thuộc nhà
/// chỉ nghĩa người tạo / người ghi.
abstract class DuLieuNhaRepository {
  /// Ví chung của nhà, kể cả ví lưu trữ (để còn bỏ lưu trữ được).
  Stream<List<WalletEntity>> theoDoiViChung(int idNha);

  /// Ví chung **đang hoạt động** — bộ chọn ví của chế độ nhà. Bộ chọn ví cá nhân KHÔNG được thấy ví chung (quét 2).
  Future<List<WalletEntity>> viChungDangDung(int idNha);

  /// Mọi khoản sống của nhà, kể cả do người khác ghi. Có [walletId] thì gồm cả khoản chuyển ĐẾN ví ấy.
  Stream<List<TransactionEntity>> theoDoiKhoan(int idNha, {String? walletId});

  /// [idaccount] là người tạo — tầng trên lấy từ phiên, không có mặc định.
  Future<WalletEntity> taoViChung({
    required int idNha,
    required int idaccount,
    required String ten,
    required String loai,
    required double soDuBanDau,
    required String icon,
    required String mau,
  });

  Future<void> suaViChung(WalletEntity vi);
}
