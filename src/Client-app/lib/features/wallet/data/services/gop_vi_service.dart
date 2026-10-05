import 'package:drift/drift.dart' show Value;

import '../../../../core/database/app_database.dart';
import '../../../transaction/data/vi_theo_nguon_store.dart';
import '../../domain/gop_vi.dart';
import '../../domain/wallet_status.dart';
import 'so_du_vi_service.dart';

/// Kế hoạch đã cũ: tập giao dịch / hoá đơn / mục tiêu của ví đã đổi từ lúc
/// người dùng đọc hộp xác nhận.
class KeHoachGopCuException implements Exception {
  const KeHoachGopCuException();

  @override
  String toString() => 'Dữ liệu ví vừa đổi — hãy bấm Gộp lại.';
}

/// Gộp ví R (trên máy này, bị server từ chối vì trùng tên) vào ví P (đã đồng
/// bộ) — G63, spec 2026-10-05 mục 6.
///
/// Hai việc: [lapKeHoach] đọc CSDL rồi gọi `keHoachGop`; [gop] thi hành ĐÚNG kế
/// hoạch ấy trong một giao tác. Dịch vụ này **cố ý đi vòng** bốn ràng buộc của
/// `WalletLocalDataSourceImpl.softDelete` (còn số dư, có giao dịch, gắn mục
/// tiêu, gắn hoá đơn): nó tự dời hết phụ thuộc trước khi xoá. Chỉ nó được làm
/// vậy.
class GopViService {
  GopViService({
    required AppDatabase db,
    required SoDuViService soDuVi,
    ViTheoNguonStore? viTheoNguon,
    void Function()? henDongBo,
  })  : _db = db,
        _soDuVi = soDuVi,
        _viTheoNguon = viTheoNguon,
        _henDongBo = henDongBo;

  final AppDatabase _db;
  final SoDuViService _soDuVi;
  final ViTheoNguonStore? _viTheoNguon;
  final void Function()? _henDongBo;

  Future<KeHoachGop> lapKeHoach({
    required String idViBo,
    required String idViGiu,
  }) async {
    final bo = await _db.walletDao.getById(idViBo);
    final giu = await _db.walletDao.getById(idViGiu);
    if (bo == null ||
        giu == null ||
        bo.deletedAt != null ||
        giu.deletedAt != null) {
      throw StateError('Không tìm thấy ví cần gộp.');
    }
    // Bước 0 — neo của P TRƯỚC khi đọc sổ (bẫy 6). Ví chưa có khoản "Số dư ban
    // đầu" mà số dư khác sổ thì phần chênh phải thành một giao dịch trước, nếu
    // không kế hoạch tính trên một tổng sổ khác con số `tinhLaiSoDu` cho ra sau
    // gộp. Phép này KHÔNG đổi số dư P — nó vốn xảy ra ở lần ghi kế tiếp vào P (id
    // tất định nên máy kia sinh cùng một hàng); với ví kéo về (số dư đã suy từ
    // sổ) nó không làm gì. `gop` gọi lại hàm này trong giao tác nên cũng có bước 0.
    await _soDuVi.datNeoNhieuVi({idViGiu});
    final giaoDich = await _db.transactionDao.giaoDichLienQuan(idViBo);
    final hoaDon = (await _db.billDao.getAll(bo.idaccount))
        .where((b) => b.walletId == idViBo);
    final mucTieu = (await _db.goalDao.getAll(bo.idaccount)).where(
        (g) => g.walletId == idViBo || g.autoDepositWalletId == idViBo);

    return keHoachGop(
      viBo: ViChoGop(
        id: bo.id,
        loai: bo.type,
        soDu: bo.balance,
        tongSo: await _db.transactionDao.tongTheoVi(bo.id),
        macDinh: bo.isDefault,
        luuTru: !WalletStatus.laHoatDong(bo.status),
      ),
      viGiu: ViChoGop(
        id: giu.id,
        loai: giu.type,
        soDu: giu.balance,
        tongSo: await _db.transactionDao.tongTheoVi(giu.id),
        macDinh: giu.isDefault,
        luuTru: !WalletStatus.laHoatDong(giu.status),
      ),
      giaoDich: [
        for (final t in giaoDich)
          (
            id: t.id,
            walletId: t.walletId,
            viNhan: t.walletTransfer,
            loai: t.type,
            soTien: t.amount,
          ),
      ],
      hoaDon: [for (final b in hoaDon) (id: b.id)],
      mucTieu: [
        for (final g in mucTieu)
          (
            id: g.id,
            ten: g.name,
            walletId: g.walletId,
            viNguonTrich: g.autoDepositWalletId,
          ),
      ],
    );
  }

  /// Thi hành [kh]. Ném `StateError` khi không gộp được,
  /// [KeHoachGopCuException] khi dữ liệu đã khác bản người dùng vừa đọc; lỗi
  /// giữa chừng hoàn nguyên cả giao tác.
  Future<void> gop(KeHoachGop kh) async {
    if (!kh.coTheGop) throw StateError(kh.lyDoKhongGop!);
    var idaccount = 0;

    await _db.transaction(() async {
      final moi = await lapKeHoach(idViBo: kh.idViBo, idViGiu: kh.idViGiu);
      if (!kh.cungTapVoi(moi)) throw const KeHoachGopCuException();
      idaccount = (await _db.walletDao.getById(kh.idViBo))!.idaccount;
      final now = DateTime.now();

      // 0. Neo của P đã đặt bởi `lapKeHoach` ngay trên — TRƯỚC khi đụng sổ (bẫy 6).

      // 1. Giao dịch: cả vai ví nguồn lẫn ví nhận.
      for (final id in kh.giaoDichDoiVi) {
        final t = await _db.transactionDao.getById(id);
        if (t == null) continue;
        await _db.transactionDao.updateRow(
          id,
          TransactionsCompanion(
            walletId: t.walletId == kh.idViBo
                ? Value(kh.idViGiu)
                : const Value.absent(),
            walletTransfer: t.walletTransfer == kh.idViBo
                ? Value(kh.idViGiu)
                : const Value.absent(),
            syncStatus: const Value('pending'),
            updatedAt: Value(now),
          ),
        );
      }

      // 2. Khoản "Số dư ban đầu" của R — cùng một tài khoản thật, giữ hai số dư
      // mở sổ là đếm đôi.
      final neo = kh.idKhoanMoSoBo;
      if (neo != null) await _db.transactionDao.softDelete(neo);

      // 3. Khoản chuyển giữa R và P — sau gộp là chuyển từ ví sang chính nó.
      for (final id in kh.khoanChuyenNoiBo) {
        await _db.transactionDao.softDelete(id);
      }

      // 4. Hoá đơn và mục tiêu.
      for (final id in kh.hoaDonDoiVi) {
        await _db.billDao.updateFields(BillsCompanion(
          id: Value(id),
          walletId: Value(kh.idViGiu),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ));
      }
      for (final m in kh.mucTieu) {
        await _db.goalDao.updateFields(GoalsCompanion(
          id: Value(m.id),
          walletId: m.doiViNhan ? Value(kh.idViGiu) : const Value.absent(),
          // Tắt trích: ba cột `auto_deposit_*` về NULL CÙNG NHAU (G21 — chúng
          // phải đi cùng nhau).
          autoDepositWalletId: m.tatTrich
              ? const Value(null)
              : (m.doiViNguon ? Value(kh.idViGiu) : const Value.absent()),
          autoDepositAmount:
              m.tatTrich ? const Value(null) : const Value.absent(),
          autoDepositLastRun:
              m.tatTrich ? const Value(null) : const Value.absent(),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ));
      }

      // 6. R: gỡ cờ + mốc chặn (bẫy 1) rồi xoá mềm. Lệnh xoá vẫn đẩy lên —
      // server coi "không có sẵn" là xong (`Already absent`).
      await _db.walletDao.goCoTrungTen(kh.idViBo);
      await _db.walletDao.softDelete(kh.idViBo);

      // 8. Cờ mặc định.
      if (kh.chuyenCoMacDinh) {
        await _db.walletDao.update_(WalletsCompanion(
          id: Value(kh.idViGiu),
          isDefault: const Value(true),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ));
        await _db.walletDao
            .clearDefaultExcept(idaccount: idaccount, keepId: kh.idViGiu);
      }

      // 7. Số dư P — đi qua SoDuViService, nơi duy nhất ghi `balance`.
      await _soDuVi.tinhLaiSoDu(kh.idViGiu);

      // 9. Thông báo số dư còn mở của R.
      await _db.notificationDao.goTheoDoiTuong(
        idaccount,
        subjectType: 'wallet',
        subjectId: kh.idViBo,
      );
    });

    // 5. Bảng nguồn → ví nằm ở secure storage, ngoài giao tác: ghi SAU khi giao
    // tác xong.
    await _viTheoNguon?.doiVi(idaccount, kh.idViBo, kh.idViGiu);
    _henDongBo?.call();
  }
}
