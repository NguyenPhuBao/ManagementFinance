import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../transaction/data/models/transaction_entity.dart';
import '../../transaction/data/repositories/transaction_repository.dart';
import '../../wallet/data/so_du_vi_service.dart';
import '../domain/ghi_chu_gop_quy.dart';

/// Ghi / sửa / xoá một cặp góp, rút của gia đình (`docs/Family/02A` mục 5–6): hai nửa, chung mã cặp, một giao tác.
///
/// - Nửa của nhà mang `idhousehold`; nửa riêng (khi có ví riêng) không — chiều tiền ngược nhau (góp: nhà `thu`, riêng `chi`).
/// - *Tiền mặt trao tay* (`viRiengId == null`): chỉ nửa của nhà, vẫn mang mã cặp để được nhận là góp.
/// - [idaccount] do tầng trên lấy từ PHIÊN (quy tắc 2), không có giá trị mặc định.
/// - ⚠️ Các hàm sửa / xoá KHÔNG kiểm quyền: ai được sửa (chỉ người ghi) hay xoá (người ghi, hoặc Chủ nhà với nửa của nhà)
///   là việc của tầng trên (`quyen_nha.dart`).
class GopQuyService {
  GopQuyService({
    required TransactionRepository giaoDich,
    required AppDatabase db,
    required SoDuViService soDuVi,
    required void Function() henDongBo,
  })  : _giaoDich = giaoDich,
        _db = db,
        _soDuVi = soDuVi,
        _henDongBo = henDongBo;

  final TransactionRepository _giaoDich;
  final AppDatabase _db;
  final SoDuViService _soDuVi;
  final void Function() _henDongBo;
  static const _uuid = Uuid();

  Future<String> gop({
    required int idNha,
    required int idaccount,
    required String viChungId,
    required String tenViChung,
    required double soTien,
    String? viRiengId,
    required DateTime ngay,
    String ghiChu = '',
  }) =>
      _ghi(idNha, idaccount, viChungId, tenViChung, soTien, viRiengId, ngay, ghiChu, gop: true);

  Future<String> rut({
    required int idNha,
    required int idaccount,
    required String viChungId,
    required String tenViChung,
    required double soTien,
    required String viRiengId,
    required DateTime ngay,
    String ghiChu = '',
  }) =>
      _ghi(idNha, idaccount, viChungId, tenViChung, soTien, viRiengId, ngay, ghiChu, gop: false);

  Future<String> _ghi(
    int idNha,
    int idaccount,
    String viChungId,
    String tenViChung,
    double soTien,
    String? viRiengId,
    DateTime ngay,
    String ghiChu, {
    required bool gop,
  }) async {
    await _kiemDauVao(idNha, viChungId, viRiengId, soTien);
    final maCap = _uuid.v4();
    final bay = DateTime.now();
    TransactionEntity hang({required String wallet, required int? nha, required String type, required String note}) =>
        TransactionEntity(
          id: _uuid.v4(),
          walletId: wallet,
          idaccount: idaccount,
          idhousehold: nha,
          fundPairId: maCap,
          amount: soTien,
          type: type,
          note: note,
          date: ngay,
          syncStatus: 'pending',
          updatedAt: bay,
        );
    // Một lời gọi `addTransactions` = một giao tác Drift, neo số dư trước khi ghi, tính lại số dư và xin đồng bộ sau.
    await _giaoDich.addTransactions([
      hang(wallet: viChungId, nha: idNha, type: gop ? 'thu' : 'chi', note: ghiChu),
      if (viRiengId != null)
        hang(
            wallet: viRiengId,
            nha: null,
            type: gop ? 'chi' : 'thu',
            note: ghiChuNuaRieng(gop: gop, tenViChung: tenViChung, ghiChu: ghiChu)),
    ]);
    return maCap;
  }

  /// Chốt phạm vi TRƯỚC khi ghi gì: nửa riêng trỏ ví nhà bị server từ chối vĩnh viễn (HOUSEHOLD_SCOPE_MISMATCH) trong khi quỹ vẫn
  /// nhận tiền; số tiền 0 là CONSTRAINT_VIOLATION vĩnh viễn; số âm làm máy và server khác dấu. Ví lưu trữ / banking KHÔNG
  /// chặn ở đây (bộ chọn ví lo).
  Future<void> _kiemDauVao(int idNha, String viChungId, String? viRiengId, double soTien) async {
    if (!(soTien > 0)) throw const CacheException('Số tiền phải lớn hơn 0.');
    final viChung = await _db.walletDao.getById(viChungId);
    if (viChung == null || viChung.deletedAt != null || viChung.isDeleted || viChung.idhousehold != idNha) {
      throw const CacheException('Ví chung không thuộc nhà đang chọn.');
    }
    if (viRiengId == null) return;
    final viRieng = await _db.walletDao.getById(viRiengId);
    if (viRieng == null || viRieng.deletedAt != null || viRieng.isDeleted || viRieng.idhousehold != null) {
      throw const CacheException('Ví riêng không hợp lệ.');
    }
  }

  /// Hai nửa CÒN SỐNG của cặp trên máy này; nửa nào vắng thì `null` (tiền mặt trao tay, hoặc một nửa đã bị gỡ).
  Future<({TransactionEntity? rieng, TransactionEntity? nha})> docCap(String maCap) async {
    final hang = await _db.transactionDao.theoMaCap(maCap);
    TransactionEntity? tim(bool nha) {
      for (final h in hang) {
        if ((h.idhousehold != null) == nha) return TransactionEntity.fromDrift(h);
      }
      return null;
    }

    return (rieng: tim(false), nha: tim(true));
  }

  /// Đổi số tiền, ngày, ghi chú của CẢ HAI nửa trong một giao tác. Ví và chiều tiền không đổi.
  ///
  /// Trả `false` khi máy không còn nửa nào của mã ấy (cặp đã bị gỡ ở máy khác rồi kéo về) — tầng trên báo cho người dùng thay vì
  /// im lặng coi là đã sửa.
  Future<bool> sua({required String maCap, required double soTien, required DateTime ngay, required String ghiChu}) async {
    if (!(soTien > 0)) throw const CacheException('Số tiền phải lớn hơn 0.');
    final cap = await docCap(maCap);
    if (cap.rieng == null && cap.nha == null) return false;
    final vi = _viCuaCap(cap);
    final noteRieng = await _ghiChuRieng(cap, ghiChu);
    await _soDuVi.datNeoNhieuVi(vi);
    final bay = DateTime.now();
    await _db.transaction(() async {
      for (final h in [cap.rieng, cap.nha]) {
        if (h == null) continue;
        final sua = h.copyWith(
          amount: soTien,
          date: ngay,
          note: h.idhousehold != null ? ghiChu : noteRieng,
          syncStatus: 'pending',
          updatedAt: bay,
        );
        await _db.transactionDao.updateRow(h.id, sua.toCompanion());
      }
    });
    await _soDuVi.tinhLaiNhieuVi(vi);
    _henDongBo();
    return true;
  }

  /// Ghi chú mới của nửa riêng: dựng lại từ tiền tố + TÊN ví chung (đọc từ ví), không tách ghi chú cũ theo dấu `·` —
  /// tên ví có thể chứa chính dấu ấy. Không đọc được tên (máy chỉ còn nửa riêng) thì giữ nguyên ghi chú cũ.
  Future<String> _ghiChuRieng(({TransactionEntity? rieng, TransactionEntity? nha}) cap, String ghiChu) async {
    final rieng = cap.rieng;
    final nha = cap.nha;
    if (rieng == null) return '';
    if (nha == null) return rieng.note;
    final viChung = await _db.walletDao.getById(nha.walletId);
    if (viChung == null) return rieng.note;
    // Nửa riêng `chi` = người dùng góp; `thu` = rút.
    return ghiChuNuaRieng(gop: rieng.type == 'chi', tenViChung: viChung.name, ghiChu: ghiChu);
  }

  /// Xoá mềm cả hai nửa còn trên máy, rồi tính lại hai ví. Máy chỉ còn một nửa (Chủ nhà xoá hộ, hoặc tiền mặt trao tay)
  /// thì xoá nửa ấy. Trả `false` khi máy không còn nửa nào của mã ấy.
  Future<bool> xoa(String maCap) async {
    final cap = await docCap(maCap);
    if (cap.rieng == null && cap.nha == null) return false;
    final vi = _viCuaCap(cap);
    await _soDuVi.datNeoNhieuVi(vi);
    await _db.transaction(() async {
      for (final h in [cap.rieng, cap.nha]) {
        if (h != null) await _db.transactionDao.softDelete(h.id);
      }
    });
    await _soDuVi.tinhLaiNhieuVi(vi);
    _henDongBo();
    return true;
  }

  Set<String> _viCuaCap(({TransactionEntity? rieng, TransactionEntity? nha}) cap) =>
      {if (cap.rieng != null) cap.rieng!.walletId, if (cap.nha != null) cap.nha!.walletId};
}
