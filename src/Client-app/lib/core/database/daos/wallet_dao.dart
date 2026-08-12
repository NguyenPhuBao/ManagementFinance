import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/wallets_table.dart';

part 'wallet_dao.g.dart';

@DriftAccessor(tables: [Wallets])
class WalletDao extends DatabaseAccessor<AppDatabase> with _$WalletDaoMixin {
  WalletDao(super.db);

  // ── READ ──────────────────────────────────────────────────────────────────

  /// Lấy tất cả ví của user (không xóa mềm)
  Future<List<Wallet>> getAll(int idaccount) {
    return (select(wallets)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Lấy tất cả ví chưa bị xóa (fallback nếu không khớp idaccount)
  Future<List<Wallet>> getAllNonDeleted() {
    return (select(wallets)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Stream tất cả ví chưa bị xóa realtime
  Stream<List<Wallet>> watchAllNonDeleted() {
    return (select(wallets)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Stream theo dõi thay đổi realtime — dùng trong BlocBuilder
  Stream<List<Wallet>> watchAll(int idaccount) {
    return (select(wallets)
          ..where((t) => t.idaccount.equals(idaccount) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Lấy ví theo id
  Future<Wallet?> getById(String id) {
    return (select(wallets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Lấy ví mặc định của user
  Future<Wallet?> getDefault(int idaccount) {
    return (select(wallets)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.isDefault.equals(true) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Lấy các record chưa sync (pending)
  Future<List<Wallet>> getPending(int idaccount) {
    return (select(wallets)
          ..where((t) =>
              t.idaccount.equals(idaccount) & t.syncStatus.equals('pending')))
        .get();
  }

  // ── WRITE ─────────────────────────────────────────────────────────────────

  /// Thêm ví mới — id đã được tạo trước (UUID)
  Future<void> insert(WalletsCompanion entry) async {
    await into(wallets).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Cập nhật ví
  Future<void> update_(WalletsCompanion entry) async {
    await (update(wallets)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  /// Xoá mềm ví (isDeleted = true, syncStatus = 'pending')
  Future<void> softDelete(String id) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Đánh dấu đã sync thành công
  Future<void> markSynced(String id) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      const WalletsCompanion(syncStatus: Value('synced')),
    );
  }

  /// Cập nhật balance sau khi giao dịch
  Future<void> updateBalance(String id, double newBalance) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        balance: Value(newBalance),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Upsert nhiều wallets (dùng khi sync từ server về)
  Future<void> upsertAll(List<WalletsCompanion> entries) async {
    await batch((b) {
      b.insertAll(wallets, entries, mode: InsertMode.insertOrReplace);
    });
  }
}
