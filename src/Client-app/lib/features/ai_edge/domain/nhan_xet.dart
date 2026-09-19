import 'goi_so.dart';

enum MucNhanXet { binhThuong, canhBao, thieuDuLieu }

/// Một câu nhận xét kèm thẻ số liệu — đầu ra của mọi `BoDienGiai`.
///
/// Nhánh thiếu dữ liệu là một câu **thật** (không ẩn khối), và nền bằng 0
/// không bao giờ in phần trăm — bài học của so cùng kỳ năm trước.
class NhanXet {
  final String cau;
  final List<SoLieu> theSoLieu;
  final MucNhanXet muc;

  /// `true` khi câu do mô hình sinh (P3) — giao diện gắn nhãn "AI".
  final bool tuMoHinh;

  const NhanXet({
    required this.cau,
    required this.theSoLieu,
    required this.muc,
    this.tuMoHinh = false,
  });
}
