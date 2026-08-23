import '../models/wallet_entity.dart';

/// Repository interface — UI/Cubit chỉ biết đến interface này,
/// không phụ thuộc trực tiếp vào Drift hay bất kỳ datasource cụ thể.
abstract class WalletRepository {
  /// Lấy tất cả ví của user
  Future<List<WalletEntity>> getAll(int idaccount);

  /// Stream realtime — dùng với StreamBuilder hoặc BlocObserver
  Stream<List<WalletEntity>> watchAll(int idaccount);

  /// Lấy theo ID (cho trang edit)
  Future<WalletEntity?> getById(String id);

  /// Lấy ví mặc định
  Future<WalletEntity?> getDefault(int idaccount);

  /// Thêm ví mới (tự tạo UUID, ghi local ngay)
  Future<WalletEntity> addWallet({
    required int idaccount,
    required String name,
    required String type,
    required double balance,
    String currency,
    String icon,
    String colour,
    bool isDefault,
    bool includeInTotal,
  });

  /// Cập nhật ví
  Future<void> updateWallet(WalletEntity wallet);

  /// Xoá mềm ví
  Future<void> deleteWallet(String id);

  /// Tổng số dư các ví có includeInTotal = true (không tính ví đã xoá)
  Future<double> getTotalBalance(int idaccount);
}
