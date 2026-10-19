import '../../transaction/domain/transaction_owner.dart' show kGhiChuTraHoaDon;

/// Ghi chú của khoản chi sinh ra khi trả hoá đơn [tenHoaDon].
///
/// [ghiChuLanTra] là phần người dùng gõ trên bảng thanh toán cho riêng lần
/// này; rỗng hoặc toàn khoảng trắng thì bỏ. Luôn giữ tiền tố ở đầu.
///
/// Tiền tố [kGhiChuTraHoaDon] định nghĩa ở `transaction/domain/transaction_owner.dart` từ 2026-10-16 (quét 29) — xem lý
/// do ở chú thích của hằng.
String ghiChuTraHoaDon(String tenHoaDon, String? ghiChuLanTra) {
  final them = ghiChuLanTra?.trim() ?? '';
  return them.isEmpty
      ? '$kGhiChuTraHoaDon$tenHoaDon'
      : '$kGhiChuTraHoaDon$tenHoaDon — $them';
}
