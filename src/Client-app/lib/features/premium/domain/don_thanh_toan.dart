import 'trang_thai_goi.dart';

/// Đơn vừa tạo (`POST /payment/create-order`) — chỉ bốn trường màn Đang chờ
/// thanh toán cần (spec Premium 5.4). `qrCode`, `accountNumber`… backend có trả
/// nhưng client không vẽ QR (câu 7).
class DonThanhToan {
  const DonThanhToan({
    required this.orderCode,
    required this.checkoutUrl,
    required this.soTien,
    required this.hetHanLuc,
  });

  final int orderCode;
  final Uri checkoutUrl;
  final int soTien;

  /// Backend đặt 30 phút sau khi tạo (`payment.service.js:16`).
  final DateTime hetHanLuc;
}

/// `null` khi thiếu `orderCode` hoặc `checkoutUrl` không phải URL có scheme và
/// host — không dựng được màn Đang chờ từ một đơn như thế.
DonThanhToan? donTuJson(Map<String, Object?> json, {required DateTime now}) {
  final code = json['orderCode'];
  final url = json['checkoutUrl'];
  if (code is! num || url is! String) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final tien = json['amount'];
  final het = json['expiredAt'];
  return DonThanhToan(
    orderCode: code.toInt(),
    checkoutUrl: uri,
    soTien: tien is num && tien > 0 ? tien.toInt() : kGiaPremium,
    hetHanLuc: (het is String ? DateTime.tryParse(het) : null) ??
        now.add(const Duration(minutes: 30)),
  );
}

enum TrangThaiDon { pending, paid, cancelled, expired }

/// Chuỗi `status` của `GET /payment/order-status` (`PENDING · PAID · CANCELLED
/// · EXPIRED`). Chuỗi lạ → `pending`: không bao giờ coi một chuỗi không biết là
/// "đã trả".
TrangThaiDon trangThaiDonTuChuoi(Object? s) =>
    switch (s?.toString().toUpperCase()) {
      'PAID' => TrangThaiDon.paid,
      'CANCELLED' => TrangThaiDon.cancelled,
      'EXPIRED' => TrangThaiDon.expired,
      _ => TrangThaiDon.pending,
    };
