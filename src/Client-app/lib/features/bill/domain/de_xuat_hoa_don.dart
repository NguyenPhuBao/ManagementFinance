/// Chọn gợi ý tạo hoá đơn từ khoản lặp (B2). Trả `null` khi không có gì để gợi
/// ý — chỗ gọi ẩn hẳn thẻ; một danh sách rỗng buộc widget tự nghĩ ra luật ẩn
/// (cùng bài học thẻ *Chưa đặt ngân sách*).
///
/// Spec: docs/superpowers/specs/2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md
/// mục 2–4.
library;

import '../../../core/database/app_database.dart';
import '../../transaction/domain/khoan_lap.dart';
import 'bill_pay_status.dart';

/// Tối đa số dòng của thẻ.
const int kToiDaKhoanLap = 3;

/// Giá trị cột `goi_y_hoa_don_phan_hois.ket_qua` — chữ lưu trong bảng.
const String kGoiYBoQua = 'bo_qua';
const String kGoiYDaTao = 'da_tao';

/// Số khoản mới (sau lần Bỏ qua cuối) để mở lại một nhóm — cùng luật B1.
const int kKhoanMoiMoLai = 3;

List<KhoanLap>? chonDeXuatHoaDon({
  required List<KhoanLap> ds,
  required List<Bill> hoaDon,
  required List<GoiYHoaDonPhanHoi> phanHoi,
  required List<Transaction> giaoDich,
  required DateTime now,
  int toiDa = kToiDaKhoanLap,
}) {
  // Hoá đơn "đang sống": chưa xoá, và còn phải trả hoặc là hoá đơn lặp. So bằng
  // cùng phép chuẩn hoá với khoá nhóm — "Tiền nhà T10" trùng nhóm "tien nha".
  final tenDangSong = {
    for (final b in hoaDon)
      if (!b.isDeleted && b.deletedAt == null && (conPhaiTra(b) || b.isRecurrence))
        ghiChuChuanHoa(b.name),
  };

  bool biAn(String khoa) {
    final cua = phanHoi.where((p) => p.khoaNhom == khoa).toList();
    if (cua.any((p) => p.ketQua == kGoiYDaTao)) return true;
    final boQua = cua.where((p) => p.ketQua == kGoiYBoQua).toList();
    if (boQua.isEmpty) return false;
    final moc = boQua.map((p) => p.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    // Đếm GIAO DỊCH (spec: "≥ 3 khoản mới"), không gộp cùng ngày như timKhoanLap.
    // Khoá qua khoaNhomCua — định nghĩa duy nhất, đừng chép phép chuẩn hoá.
    final moi = giaoDich
        .where((t) => t.date.isAfter(moc) && khoaNhomCua(t, now: now) == khoa)
        .length;
    return moi < kKhoanMoiMoLai;
  }

  final con = [
    for (final k in ds)
      if (!tenDangSong.contains(phanGhiChuCuaKhoa(k.khoaNhom)) && !biAn(k.khoaNhom)) k,
  ];
  if (con.isEmpty) return null;
  con.sort((a, b) {
    final c = b.soLan.compareTo(a.soLan);
    return c != 0 ? c : b.ngayGanNhat.compareTo(a.ngayGanNhat);
  });
  return con.take(toiDa).toList();
}
