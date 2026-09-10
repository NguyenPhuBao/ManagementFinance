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

  /// Bật/tắt **lưu trữ** cho một ví — đóng băng, không phải xoá.
  ///
  /// Hai chốt chặn (không lưu trữ ví mặc định, không lưu trữ ví hoạt động cuối
  /// cùng) nằm ở datasource và ném `CacheException`; nơi gọi phải để lỗi ấy
  /// lên tới màn hình chứ không nuốt lặng.
  Future<void> setArchived(String id, {required bool luuTru});

  /// Tổng số dư các ví được **tính vào tổng tài sản** — xem `viTinhVaoTong`:
  /// nó lọc cả cờ `includeInTotal` lẫn ví đã lưu trữ (ví đã xoá thì không có
  /// mặt từ đầu).
  Future<double> getTotalBalance(int idaccount);
}
