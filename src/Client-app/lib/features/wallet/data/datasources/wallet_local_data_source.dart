import 'package:drift/drift.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../models/wallet_entity.dart';

/// Abstract — cho phép mock trong test
abstract class WalletLocalDataSource {
  Future<List<WalletEntity>> getAll(int idaccount);
  Stream<List<WalletEntity>> watchAll(int idaccount);
  Future<List<WalletEntity>> getActive(int idaccount);
  Stream<List<WalletEntity>> watchActive(int idaccount);
  Future<WalletEntity?> getById(String id);
  Future<WalletEntity?> getDefault(int idaccount);
  Future<void> insert(WalletEntity wallet);
  Future<void> update(WalletEntity wallet);
  Future<void> softDelete(String id);
  Future<void> setArchived(String id, {required bool luuTru});
  Future<void> updateBalance(String id, double newBalance);
}

class WalletLocalDataSourceImpl implements WalletLocalDataSource {
  final AppDatabase _db;

  WalletLocalDataSourceImpl({required AppDatabase db}) : _db = db;

  // ── Helpers ──────────────────────────────────────────────────────────────

  WalletEntity _toEntity(Wallet w) => WalletEntity(
    id:             w.id,
    idaccount:      w.idaccount,
    name:           w.name,
    type:           w.type,
    balance:        w.balance,
    currency:       w.currency,
    icon:           w.icon,
    colour:         w.colour,
    isDefault:      w.isDefault,
    isDeleted:      w.isDeleted,
    includeInTotal: w.includeInTotal,
    status:         w.status,
    syncStatus:     w.syncStatus,
    updatedAt:      w.updatedAt,
  );

  WalletsCompanion _toCompanion(WalletEntity e) => WalletsCompanion(
    id:             Value(e.id),
    idaccount:      Value(e.idaccount),
    name:           Value(e.name),
    type:           Value(e.type),
    balance:        Value(e.balance),
    currency:       Value(e.currency),
    icon:           Value(e.icon),
    colour:         Value(e.colour),
    isDefault:      Value(e.isDefault),
    isDeleted:      Value(e.isDeleted),
    includeInTotal: Value(e.includeInTotal),
    // Thiếu cột này thì mỗi lần người dùng sửa tên ví là ví tự bỏ lưu trữ —
    // im lặng, vì `update_` chỉ ghi những cột companion có mang.
    status:         Value(e.status),
    syncStatus:     Value(e.syncStatus),
    updatedAt:      Value(e.updatedAt),
  );

  // ── READ ─────────────────────────────────────────────────────────────────

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async {
    try {
      final rows = await _db.walletDao.getAll(idaccount);
      return rows.map(_toEntity).toList();
    } catch (e) {
      throw CacheException('Không thể tải danh sách ví: $e');
    }
  }

  @override
  Stream<List<WalletEntity>> watchAll(int idaccount) {
    return _db.walletDao
        .watchAll(idaccount)
        .map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<List<WalletEntity>> getActive(int idaccount) async {
    try {
      final rows = await _db.walletDao.getActive(idaccount);
      return rows.map(_toEntity).toList();
    } catch (e) {
      throw CacheException('Không thể tải danh sách ví: $e');
    }
  }

  @override
  Stream<List<WalletEntity>> watchActive(int idaccount) {
    return _db.walletDao
        .watchActive(idaccount)
        .map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<WalletEntity?> getById(String id) async {
    final row = await _db.walletDao.getById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<WalletEntity?> getDefault(int idaccount) async {
    final row = await _db.walletDao.getDefault(idaccount);
    return row == null ? null : _toEntity(row);
  }

  // ── WRITE ────────────────────────────────────────────────────────────────

  /// Giữ bất biến "mỗi tài khoản có nhiều nhất MỘT ví mặc định".
  ///
  /// Đặt ở đây, không ở `WalletRepositoryImpl`: cả đường thêm và đường sửa đều
  /// đi qua datasource, còn repository trước bản này chỉ chặn ở đường thêm —
  /// nên sửa một ví thứ hai thành mặc định là có hai hàng cùng cờ, và
  /// `getDefault` ném `StateError` ở lần thêm ví tiếp theo.
  ///
  /// Gọi SAU khi ghi, không phải trước: ví vừa ghi là ví được giữ cờ.
  Future<void> _giuMotViMacDinh(WalletEntity wallet) async {
    if (!wallet.isDefault) return;
    await _db.walletDao.clearDefaultExcept(
      idaccount: wallet.idaccount,
      keepId: wallet.id,
    );
  }

  @override
  Future<void> insert(WalletEntity wallet) async {
    try {
      await _db.walletDao.insert(_toCompanion(wallet));
      await _giuMotViMacDinh(wallet);
    } catch (e) {
      throw CacheException('Không thể lưu ví: $e');
    }
  }

  @override
  Future<void> update(WalletEntity wallet) async {
    try {
      await _db.walletDao.update_(_toCompanion(wallet));
      await _giuMotViMacDinh(wallet);
    } catch (e) {
      throw CacheException('Không thể cập nhật ví: $e');
    }
  }

  @override
  Future<void> softDelete(String id) async {
    try {
      final wallet = await _db.walletDao.getById(id);
      if (wallet != null) {
        // 1. Ràng buộc 1: Ví có tiền (balance != 0)
        if (wallet.balance != 0) {
          final formatted = CurrencyFormatter.format(wallet.balance);
          throw CacheException('Ví "${wallet.name}" đang có số dư ($formatted). Vui lòng điều chuyển số dư về 0đ trước khi xóa!');
        }

        // 2. Ràng buộc 2: Ví đã có giao dịch phát sinh
        final txs = await _db.transactionDao.getByWallet(id);
        if (txs.isNotEmpty) {
          throw CacheException('Ví "${wallet.name}" đã có ${txs.length} giao dịch phát sinh. Không thể xóa ví để bảo toàn lịch sử tài chính!');
        }

        // 3. Ràng buộc 3: Ví đang liên kết với Mục tiêu tiết kiệm
        final goals = await _db.goalDao.getAll(wallet.idaccount);
        final linkedGoals = goals.where((g) => g.walletId == id).toList();
        if (linkedGoals.isNotEmpty) {
          // Nói rõ lối thoát Ở ĐÂU. Trước đây câu này bảo "vui lòng gỡ liên
          // kết" trong khi app không hề có chỗ nào làm việc đó — người dùng
          // đọc xong vẫn kẹt. Mục tiêu luôn phải có ví nhận nên lối thoát là
          // ĐỔI sang ví khác, không phải bỏ trống.
          throw CacheException(
              'Ví "${wallet.name}" đang là ví tích lũy của mục tiêu '
              '"${linkedGoals.first.name}". Mở mục tiêu đó, bấm biểu tượng '
              'đổi ví ở góc trên để chọn ví khác, rồi xóa ví này.');
        }
      }

      await _db.walletDao.softDelete(id);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Không thể xóa ví: $e');
    }
  }

  /// Bật/tắt lưu trữ cho một ví.
  ///
  /// Hai chốt chặn ở đây cố ý **khác hẳn** ba ràng buộc của [softDelete] (còn
  /// số dư / đã có giao dịch / đang gắn mục tiêu). Lưu trữ sinh ra chính là
  /// **lối thoát** cho ba ràng buộc ấy — ví dùng thật gần như không bao giờ
  /// xoá được — nên bắt nó cũng đòi số dư 0 là làm nó vô dụng.
  ///
  /// Hai chốt còn lại là chốt về *tính dùng được của app*:
  ///
  /// 1. **Ví mặc định** được chọn sẵn mỗi lần ghi giao dịch (`vi_chon_san.dart`),
  ///    nên lưu trữ nó là màn thêm giao dịch mở ra với một ví không còn trong
  ///    danh sách chọn.
  /// 2. **Ví hoạt động cuối cùng**: lưu trữ hết thì không ghi được giao dịch
  ///    nào nữa, và không màn nào nói vì sao.
  ///
  /// Hai chốt độc lập nhau — một tài khoản có thể không có ví nào mang cờ mặc
  /// định, vì trạng thái ấy đến được từ server — nên chốt 1 không bao hàm chốt
  /// 2. Cả hai chỉ canh chiều **lưu trữ**; bỏ lưu trữ thì không gì cản.
  ///
  /// Ví đang gắn mục tiêu hoặc hoá đơn tự động vẫn lưu trữ được: cảnh báo là
  /// việc của hộp thoại xác nhận, không phải của chốt chặn.
  @override
  Future<void> setArchived(String id, {required bool luuTru}) async {
    try {
      if (luuTru) {
        final wallet = await _db.walletDao.getById(id);
        if (wallet == null) {
          throw const CacheException('Không tìm thấy ví cần lưu trữ.');
        }
        if (wallet.isDefault) {
          throw CacheException(
              'Ví "${wallet.name}" đang là ví mặc định. Hãy đặt một ví khác '
              'làm mặc định trước khi lưu trữ ví này.');
        }
        final conLai = (await _db.walletDao.getActive(wallet.idaccount))
            .where((w) => w.id != id)
            .toList();
        if (conLai.isEmpty) {
          throw const CacheException(
              'Đây là ví đang hoạt động cuối cùng. Lưu trữ nó thì không ghi '
              'được giao dịch nào nữa — hãy tạo ví khác trước.');
        }
      }

      await _db.walletDao.setStatus(id, luuTru: luuTru);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Không thể đổi trạng thái lưu trữ của ví: $e');
    }
  }

  @override
  Future<void> updateBalance(String id, double newBalance) async {
    try {
      await _db.walletDao.updateBalance(id, newBalance);
    } catch (e) {
      throw CacheException('Không thể cập nhật số dư: $e');
    }
  }
}
