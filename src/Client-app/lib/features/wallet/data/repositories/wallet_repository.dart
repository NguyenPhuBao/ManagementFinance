import '../../../../core/database/app_database.dart';
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
    bool allowNegative,
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

  // ── Hàng Drift cho trang (spec 2026-10-10 bịt điểm rò, mục 4.3) ───────────
  // Bốn lối CHUYỂN TIẾP, không luật. Trang cầm `List<Wallet>` (bộ chọn ví, bảng tra tên) nên repository trả đúng kiểu
  // ấy; đổi sang Entity là lan kiểu sang `TransactionLookup`, `BillPaymentSheet`… — nợ ghi ở G88.

  /// Ví đang hoạt động cho **bộ chọn** — `walletDao.getActive`.
  Future<List<Wallet>> getActiveRows(int idaccount);

  /// Mọi ví chưa xoá, **kể cả lưu trữ** — chỉ cho bảng tra tên. `walletDao.getAll`.
  Future<List<Wallet>> getAllRows(int idaccount);

  /// Như [getAllRows], dạng stream. `walletDao.watchAll`.
  Stream<List<Wallet>> watchAllRows(int idaccount);

  /// Một hàng ví, kể cả đã xoá mềm (tra tên cho giao dịch cũ). `walletDao.getById`.
  Future<Wallet?> getRowById(String id);
}
