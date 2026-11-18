/// Lỗi của ba API bản sao dữ liệu (đơn client-app mục 52). Dart thuần để cubit / trang đọc mà không import
/// datasource API (quét 31) — khuôn `premium/domain/cau_loi_thanh_toan.dart`. Phép đổi `DioException` → lỗi này
/// ở `data/datasources/ban_sao_du_lieu_api.dart` (`loiBanSaoTu`).
library;

enum LoaiLoiBanSao { daGioiHan, hetHan, chuaXong, khongCo, matMang, khac }

class LoiBanSao implements Exception {
  const LoiBanSao(this.loai, {this.choThem});
  final LoaiLoiBanSao loai;

  /// Chỉ với [LoaiLoiBanSao.daGioiHan]: `Retry-After` (giây); thiếu / rác → `null`.
  final Duration? choThem;

  @override
  String toString() => 'LoiBanSao($loai)';
}
