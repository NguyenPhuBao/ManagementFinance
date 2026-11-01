/// Bảng ai góp bao nhiêu (`docs/Family/02A` mục 8). Tên người do trang tra từ `thanhVien` + `thanhVienCu`.
library;

import '../../transaction/data/models/transaction_entity.dart';
import 'loai_khoan_nha.dart';

class DongBangGop {
  const DongBangGop({required this.idaccount, this.gopThangNay = 0, this.gopTuTruoc = 0, this.daRut = 0, this.chiThangNay = 0});
  final int idaccount;
  final double gopThangNay;
  final double gopTuTruoc;
  final double daRut;
  final double chiThangNay;
}

List<DongBangGop> bangGop(Iterable<TransactionEntity> ds, {required DateTime now, String? walletId}) {
  final dauThang = DateTime(now.year, now.month);
  final dauThangSau = DateTime(now.year, now.month + 1);
  bool thangNay(TransactionEntity t) => !t.date.isBefore(dauThang) && t.date.isBefore(dauThangSau);
  final theoNguoi = <int, DongBangGop>{};
  for (final t in ds) {
    if (t.isDeleted || t.deletedAt != null) continue;
    if (walletId != null && t.walletId != walletId) continue;
    final cu = theoNguoi[t.idaccount] ?? DongBangGop(idaccount: t.idaccount);
    switch (phanLoaiKhoanNha(t)) {
      case LoaiKhoanNha.gopNha:
        theoNguoi[t.idaccount] = DongBangGop(
            idaccount: t.idaccount,
            gopThangNay: cu.gopThangNay + (thangNay(t) ? t.amount : 0),
            gopTuTruoc: cu.gopTuTruoc + t.amount,
            daRut: cu.daRut,
            chiThangNay: cu.chiThangNay);
      case LoaiKhoanNha.rutNha:
        theoNguoi[t.idaccount] = DongBangGop(
            idaccount: t.idaccount,
            gopThangNay: cu.gopThangNay,
            gopTuTruoc: cu.gopTuTruoc,
            daRut: cu.daRut + t.amount,
            chiThangNay: cu.chiThangNay);
      case LoaiKhoanNha.chiNha when thangNay(t):
        theoNguoi[t.idaccount] = DongBangGop(
            idaccount: t.idaccount,
            gopThangNay: cu.gopThangNay,
            gopTuTruoc: cu.gopTuTruoc,
            daRut: cu.daRut,
            chiThangNay: cu.chiThangNay + t.amount);
      default:
        break;
    }
  }
  return theoNguoi.values.toList();
}
