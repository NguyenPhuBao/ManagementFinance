import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../wallet/data/datasources/wallet_local_data_source.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/data/so_du_vi_service.dart';
import 'du_lieu_nha_repository.dart';

class DuLieuNhaRepositoryImpl implements DuLieuNhaRepository {
  final AppDatabase _db;
  final WalletLocalDataSource _local;
  final SoDuViService _soDuVi;
  final SyncEngine _syncEngine;

  static const _uuid = Uuid();

  DuLieuNhaRepositoryImpl({
    required AppDatabase db,
    required WalletLocalDataSource localDataSource,
    required SoDuViService soDuVi,
    required SyncEngine syncEngine,
  })  : _db = db,
        _local = localDataSource,
        _soDuVi = soDuVi,
        _syncEngine = syncEngine;

  @override
  Stream<List<WalletEntity>> theoDoiViChung(int idNha) =>
      _db.walletDao.watchViNha(idNha).map((rows) => rows.map(WalletEntity.fromDrift).toList());

  @override
  Future<List<WalletEntity>> viChungDangDung(int idNha) async =>
      (await _db.walletDao.getViNhaDangDung(idNha)).map(WalletEntity.fromDrift).toList();

  @override
  Stream<List<TransactionEntity>> theoDoiKhoan(int idNha, {String? walletId}) => _db.transactionDao
      .watchTheoNha(idNha, walletId: walletId)
      .map((rows) => rows.map(TransactionEntity.fromDrift).toList());

  @override
  Future<WalletEntity> taoViChung({
    required int idNha,
    required int idaccount,
    required String ten,
    required String loai,
    required double soDuBanDau,
    required String icon,
    required String mau,
  }) async {
    // Ví nhà không mặc định (index `chk_wallet_household_not_default`) và không cộng vào tổng tài sản cá nhân.
    final vi = WalletEntity(
      id: _uuid.v4(),
      idaccount: idaccount,
      idhousehold: idNha,
      name: ten,
      type: loai,
      balance: soDuBanDau,
      icon: icon,
      colour: mau,
      isDefault: false,
      includeInTotal: false,
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    );
    // Một giao tác: chết giữa insert ví và đặt neo thì ví ở lại mang số dư mà không có khoản mở sổ, tính lại sau này đưa số
    // dư về 0 — mất số dư ban đầu.
    await _db.transaction(() async {
      await _local.insert(vi);
      // Neo trước khi có khoản nào của ví; số dư 0 thì không sinh neo (xem `SoDuViService`). Neo kế thừa `idhousehold` của ví.
      await _soDuVi.datNeoNhieuVi({vi.id});
    });
    _syncEngine.scheduleSync();
    return vi;
  }

  @override
  Future<void> suaViChung(WalletEntity vi) async {
    // Đọc lại hàng: `balance` trên entity có thể cũ (form mở lâu, lượt kéo về đã đổi số dư). Bất biến ⑥: số dư chỉ
    // `SoDuViService` ghi — ghi đè số cũ là lần ghi kế sinh neo `thu` `pending` cho cả nhà.
    //
    // Đọc + ghi nằm trong MỘT giao tác: `tinhLaiSoDu` cuối lượt kéo về chen được giữa hai bước và số dư cũ quay lại.
    // `ThaViBiGiu.tha` (khi đổi tên) thành giao tác lồng — Drift dùng savepoint.
    await _db.transaction(() async {
      final hang = await _db.walletDao.getById(vi.id);
      // `getById` trả cả hàng xoá mềm.
      if (hang == null || hang.deletedAt != null) {
        throw const CacheException('Không tìm thấy ví chung cần sửa.');
      }
      if (hang.idhousehold == null || hang.idhousehold != vi.idhousehold) {
        throw const CacheException('Ví này không thuộc nhà đang sửa.');
      }
      // Ép lại hai cờ: ví nhà mang cờ mặc định đẩy lên vỡ `chk_wallet_household_not_default` (CONSTRAINT_VIOLATION, kẹt hàng đợi).
      await _local.update(vi.copyWith(
        balance: hang.balance,
        isDefault: false,
        includeInTotal: false,
        syncStatus: 'pending',
        updatedAt: DateTime.now(),
      ));
    });
    _syncEngine.scheduleSync();
  }
}
