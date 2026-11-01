/// Hoạt động của nhà (đợt 1B, Task 6): lọc, sắp, tiêu đề, dấu tiền và quyền trên MỘT khoản. Dart thuần — tên người do trang
/// truyền (cần tra `thanhVien` / `thanhVienCu`). Luật loại khoản ở `phanLoaiKhoanNha`, quyền ở `quyen_nha.dart`: đừng chép lại.
library;

import '../../../core/utils/date_formatter.dart';
import '../../transaction/data/models/transaction_entity.dart';
import 'loai_khoan_nha.dart';
import 'quyen_nha.dart';
import 'vai_nha.dart';

class TenNguoi {
  const TenNguoi(this.ten, {this.daRoi = false});

  final String ten;

  /// Người đã rời / bị mời ra: khoản của họ ở lại nhà, tên hiện kèm *(đã rời)*.
  final bool daRoi;
}

/// Khoản hiện trong Hoạt động, Chi tiết ví: bỏ hàng đã xoá và `LoaiKhoanNha.khongTinh` (neo, điều chỉnh). Luật loại nằm ở
/// `phanLoaiKhoanNha`, đừng chép lại; [dauTienKhoanNha] và [tieuDeKhoanNha] cũng rẽ theo `LoaiKhoanNha`.
bool hienTrongHoatDong(TransactionEntity t) =>
    t.deletedAt == null && !t.isDeleted && phanLoaiKhoanNha(t) != LoaiKhoanNha.khongTinh;

/// `watchTheoNha` trả cả neo. Mới nhất trước theo ngày rồi giờ sửa; lọc theo người, ví (ví đích của khoản chuyển cũng tính).
List<TransactionEntity> locHoatDong(Iterable<TransactionEntity> ds, {int? nguoi, String? vi}) {
  final kq = ds
      .where(hienTrongHoatDong)
      .where((t) => nguoi == null || t.idaccount == nguoi)
      .where((t) => vi == null || t.walletId == vi || t.walletTransfer == vi)
      .toList();
  kq.sort((a, b) {
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
  });
  return kq;
}

/// `An chi`, `Minh góp`, `Bình rút`, `An chuyển`, `An thu`; khoản không đọc được loại vẫn trả tên. Chưa kèm số tiền.
String tieuDeKhoanNha(TransactionEntity t, TenNguoi nguoi) {
  final ten = nguoi.daRoi ? '${nguoi.ten} (đã rời)' : nguoi.ten;
  final dong = switch (phanLoaiKhoanNha(t)) {
    LoaiKhoanNha.chiNha => 'chi',
    LoaiKhoanNha.thuKhac => 'thu',
    LoaiKhoanNha.chuyen => 'chuyển',
    LoaiKhoanNha.gopNha || LoaiKhoanNha.gopRieng => 'góp',
    LoaiKhoanNha.rutNha || LoaiKhoanNha.rutRieng => 'rút',
    LoaiKhoanNha.khoanThuong => switch (t.type) { 'thu' => 'thu', 'chi' => 'chi', 'transfer' => 'chuyển', _ => null },
    LoaiKhoanNha.khongTinh => null,
  };
  return dong == null ? ten : '$ten $dong';
}

/// `true` thu / góp (dấu `+`), `false` chi / rút (dấu `-`), `null` chuyển (không dấu).
bool? dauTienKhoanNha(TransactionEntity t) => switch (phanLoaiKhoanNha(t)) {
      LoaiKhoanNha.thuKhac || LoaiKhoanNha.gopNha || LoaiKhoanNha.gopRieng => true,
      LoaiKhoanNha.chiNha || LoaiKhoanNha.rutNha || LoaiKhoanNha.rutRieng => false,
      LoaiKhoanNha.chuyen => null,
      LoaiKhoanNha.khoanThuong || LoaiKhoanNha.khongTinh => switch (t.type) { 'thu' => true, 'chi' => false, _ => null },
    };

/// Sửa / xoá được khoản này không. [idToi] `null` (chưa có phiên) thì khoản KHÔNG phải của tôi — không coi `null == null`.
({bool sua, bool xoa}) quyenKhoanNha(
  TransactionEntity t, {
  required VaiNha? vai,
  required TrangThaiNha? trangThai,
  required int? idToi,
}) {
  final cuaToi = idToi != null && t.idaccount == idToi;
  final laChuyen = t.type == 'transfer';
  return (
    sua: duocSuaKhoanNha(vai: vai, trangThai: trangThai, cuaToi: cuaToi, coMaCap: t.fundPairId != null, laChuyen: laChuyen),
    xoa: duocXoaKhoanNha(vai: vai, trangThai: trangThai, cuaToi: cuaToi, laChuyen: laChuyen),
  );
}

/// Tiêu đề nhóm ngày: `Hôm nay`, `Hôm qua`, còn lại `dd/MM/yyyy`. Chỉ so NGÀY lịch (bỏ giờ).
String nhanNhomNgay(DateTime ngay, DateTime bayGio) {
  final d = DateTime(ngay.year, ngay.month, ngay.day);
  final h = DateTime(bayGio.year, bayGio.month, bayGio.day);
  final lech = DateTime.utc(h.year, h.month, h.day).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
  if (lech == 0) return 'Hôm nay';
  if (lech == 1) return 'Hôm qua';
  return DateFormatter.formatDate(ngay);
}
