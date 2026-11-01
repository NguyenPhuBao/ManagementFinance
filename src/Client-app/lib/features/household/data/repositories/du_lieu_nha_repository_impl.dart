import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../category/data/models/category_entity.dart';
import '../../../category/data/models/category_tree.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../wallet/data/datasources/wallet_local_data_source.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/data/so_du_vi_service.dart';
import '../../../wallet/domain/wallet_status.dart';
import '../../domain/hang_chua_day.dart';
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
        // Giữ trạng thái của hàng: entity mở lâu mang status cũ, ghi đè là bỏ lưu trữ im lặng.
        status: hang.status,
        isDefault: false,
        includeInTotal: false,
        syncStatus: 'pending',
        updatedAt: DateTime.now(),
      ));
    });
    _syncEngine.scheduleSync();
  }

  @override
  Future<List<WalletEntity>> viChungChoForm(int idNha, {Set<String> giuLai = const {}, String? uuTien}) async {
    final rows = await _db.walletDao.watchViNha(idNha).first;
    final ds = [
      for (final v in rows)
        if (WalletStatus.laHoatDong(v.status) || giuLai.contains(v.id)) WalletEntity.fromDrift(v),
    ];
    // Ví ưu tiên đã lưu trữ (và không ở giuLai) thì không có trong `ds`: bỏ qua, form chọn ví đầu danh sách.
    final i = uuTien == null ? -1 : ds.indexWhere((v) => v.id == uuTien);
    if (i > 0) ds.insert(0, ds.removeAt(i));
    return ds;
  }

  @override
  Future<CategoryTree> napCayDanhMuc(int idNha, String classify) async =>
      _cay(await _db.categoryDao.getCuaNha(idNha, classify: classify));

  @override
  Stream<CategoryTree> theoDoiCayDanhMuc(int idNha, String classify) =>
      _db.categoryDao.watchCuaNha(idNha, classify: classify).map(_cay);

  /// Danh mục của nhà không có khuôn mặc định và không có "đang tạm ngừng": chỉ nhóm, con theo nhóm và con chưa nhóm (con của
  /// nhóm không còn trong nhà cũng xếp vào chưa nhóm).
  CategoryTree _cay(List<Category> rows) {
    final ds = rows.map(CategoryEntity.fromDrift).toList();
    final nhom = ds.where((c) => c.isGroup).toList();
    final con = ds.where((c) => !c.isGroup).toList();
    final idNhom = nhom.map((g) => g.id).toSet();
    return CategoryTree(
      groups: [
        for (final g in nhom) CategoryGroupNode(group: g, children: con.where((c) => c.parentId == g.id).toList()),
      ],
      ungroupedChildren: con.where((c) => c.parentId == null || !idNhom.contains(c.parentId)).toList(),
      defaultChildren: const [],
      dangTamNgung: const [],
    );
  }

  /// Hàng sống của nhà [idNha]; ném khi ví không thuộc nhà (ví riêng, nhà khác, đã xoá, không có).
  Future<Wallet> _viCuaNha(int idNha, String id) async {
    final hang = await _db.walletDao.getById(id);
    // `getById` trả cả hàng xoá mềm.
    if (hang == null || hang.deletedAt != null || hang.idhousehold != idNha) {
      throw const CacheException('Không tìm thấy ví chung của nhà này.');
    }
    return hang;
  }

  @override
  Future<void> luuTruViChung({required int idNha, required String id, required bool luuTru}) async {
    // Không qua `WalletLocalDataSource.setArchived`: chốt "ví hoạt động cuối cùng" của nó đếm ví của TÀI KHOẢN (ví riêng),
    // còn ví chung duy nhất của nhà vẫn phải lưu trữ được.
    await _db.transaction(() async {
      await _viCuaNha(idNha, id);
      await _db.walletDao.setStatus(id, luuTru: luuTru);
    });
    _syncEngine.scheduleSync();
  }

  @override
  Future<void> xoaViChung({required int idNha, required String id}) async {
    // Không qua `WalletLocalDataSource.softDelete`: ràng buộc mục tiêu của nó đọc `goalDao.getAll(idaccount)` (mục tiêu riêng).
    await _db.transaction(() async {
      final hang = await _viCuaNha(idNha, id);
      if (hang.balance != 0 || await _db.transactionDao.demGiaoDichLienQuan(id) > 0) {
        throw CacheException(
            'Ví "${hang.name}" đã có giao dịch. Hãy lưu trữ để cất khỏi bộ chọn mà vẫn giữ lịch sử.');
      }
      await _db.walletDao.softDelete(id);
    });
    _syncEngine.scheduleSync();
  }

  @override
  Future<HangChuaDayNha> hangChuaDay(int idNha, {required int? idaccount}) async {
    final r = await _db.hangChuaDayCuaNha(idNha, idaccount: idaccount);
    return HangChuaDayNha(khoan: r.khoan, gop: r.gop, rut: r.rut, vi: r.vi, danhMuc: r.danhMuc, khac: r.khac);
  }
}
