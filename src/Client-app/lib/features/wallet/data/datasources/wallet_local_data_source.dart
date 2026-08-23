import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../models/wallet_entity.dart';

/// Abstract — cho phép mock trong test
abstract class WalletLocalDataSource {
  Future<List<WalletEntity>> getAll(int idaccount);
  Stream<List<WalletEntity>> watchAll(int idaccount);
  Future<WalletEntity?> getById(String id);
  Future<WalletEntity?> getDefault(int idaccount);
  Future<void> insert(WalletEntity wallet);
  Future<void> update(WalletEntity wallet);
  Future<void> softDelete(String id);
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

  @override
  Future<void> insert(WalletEntity wallet) async {
    try {
      await _db.walletDao.insert(_toCompanion(wallet));
    } catch (e) {
      throw CacheException('Không thể lưu ví: $e');
    }
  }

  @override
  Future<void> update(WalletEntity wallet) async {
    try {
      await _db.walletDao.update_(_toCompanion(wallet));
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
          final formatted = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(wallet.balance);
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
          throw CacheException('Ví "${wallet.name}" đang liên kết với mục tiêu "${linkedGoals.first.name}". Vui lòng gỡ liên kết trước khi xóa!');
        }
      }

      await _db.walletDao.softDelete(id);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Không thể xóa ví: $e');
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
