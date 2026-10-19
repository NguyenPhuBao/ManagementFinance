import '../data/models/dong_lich_su.dart';
import 'trang_thai_don.dart';

/// Đơn cần người dùng biết / xử lý (spec G94 2026-10-18 mục 5.1, 5.7) — MỘT định nghĩa cho thẻ ở màn Nâng cấp và lý do
/// hoàn tiền ở màn Chi tiết đơn.
enum LyDoHoanTien { chuyenThieu, daTuChoi, khongRo }

/// Đơn `WAITING_CONFIRMATION`, mới nhất trước.
List<DongLichSu> donChoXacNhan(List<DongLichSu> ds) => _loc(ds, TrangThaiDon.waitingConfirmation);

/// Đơn `REFUND_PENDING`, mới nhất trước.
List<DongLichSu> donChoHoanTien(List<DongLichSu> ds) => _loc(ds, TrangThaiDon.refundPending);

List<DongLichSu> _loc(List<DongLichSu> ds, TrangThaiDon t) {
  final ra = [for (final d in ds) if (d.trangThai == t) d];
  final xa = DateTime.utc(0);
  ra.sort((a, b) => (b.taoLuc ?? xa).compareTo(a.taoLuc ?? xa));
  return ra;
}

/// Đã chuyển − giá gói; `null` khi server chưa ghi số đã chuyển.
int? soTienLech(DongLichSu d) {
  final c = d.soDaChuyen;
  return c == null ? null : c - d.soTien;
}

/// Suy từ số liệu, không đọc chữ `refund_reason` của server: thiếu → chuyển thiếu; thừa mà đơn đang chờ hoàn → người
/// dùng đã từ chối kích hoạt; bằng / thiếu số → không rõ.
LyDoHoanTien lyDoHoanTien(DongLichSu d) {
  final l = soTienLech(d);
  if (l == null || l == 0) return LyDoHoanTien.khongRo;
  return l < 0 ? LyDoHoanTien.chuyenThieu : LyDoHoanTien.daTuChoi;
}
