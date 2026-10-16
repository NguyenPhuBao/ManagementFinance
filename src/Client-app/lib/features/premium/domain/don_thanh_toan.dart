import 'trang_thai_goi.dart';

/// Đơn vừa tạo (`POST /payment/create-order`) — chứa thông tin thanh toán VietQR,
/// mã nhận diện 6 ký tự, số tiền, và thời hạn (spec Premium 5.4 & Payment spec).
class DonThanhToan {
  const DonThanhToan({
    required this.orderCode,
    required this.checkoutUrl,
    required this.soTien,
    required this.hetHanLuc,
    this.recognitionCode,
    this.qrUrl,
    this.transferContent,
    this.amountReceived,
    this.fee,
  });

  final int orderCode;
  final Uri checkoutUrl;
  final int soTien;

  /// Hạn thanh toán (10-30 phút sau khi tạo).
  final DateTime hetHanLuc;

  /// Mã nhận diện 6 ký tự sinh tự động từ chữ và số (VD: "A8K9M2").
  final String? recognitionCode;

  /// Đường dẫn hình ảnh VietQR.
  final Uri? qrUrl;

  /// Nội dung chuyển khoản theo chuẩn PayOS + mã nhận diện.
  final String? transferContent;

  /// Số tiền thực tế người dùng đã chuyển.
  final int? amountReceived;

  /// Phí giao dịch ngân hàng.
  final int? fee;
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

  final recCode = json['recognitionCode'] as String?;
  final content = (json['transferContent'] ?? json['description']) as String?;

  Uri? qrUri;
  final rawQr = json['qrUrl'] as String?;
  if (rawQr != null && rawQr.isNotEmpty) {
    qrUri = Uri.tryParse(rawQr);
  } else if (json['bin'] != null && json['accountNumber'] != null) {
    final bin = json['bin'];
    final accNo = json['accountNumber'];
    final accName = Uri.encodeComponent((json['accountName'] as String?) ?? 'NGUYEN PHU BAO');
    final addInfo = Uri.encodeComponent(content ?? recCode ?? 'PFM $code');
    qrUri = Uri.tryParse(
      'https://img.vietqr.io/image/$bin-$accNo-compact2.png?amount=$tien&addInfo=$addInfo&accountName=$accName',
    );
  }

  return DonThanhToan(
    orderCode: code.toInt(),
    checkoutUrl: uri,
    soTien: tien is num && tien > 0 ? tien.toInt() : kGiaPremium,
    hetHanLuc: (het is String ? DateTime.tryParse(het) : null) ??
        now.add(const Duration(minutes: 10)),
    recognitionCode: recCode,
    qrUrl: qrUri,
    transferContent: content,
    amountReceived: (json['amountReceived'] as num?)?.toInt(),
    fee: (json['fee'] as num?)?.toInt(),
  );
}

enum TrangThaiDon {
  pending,
  paid,
  waitingConfirmation,
  refundPending,
  refunded,
  cancelled,
  expired,
}

/// Chuỗi `status` của `GET /payment/order-status`.
TrangThaiDon trangThaiDonTuChuoi(Object? s) =>
    switch (s?.toString().toUpperCase()) {
      'PAID' => TrangThaiDon.paid,
      'WAITING_CONFIRMATION' => TrangThaiDon.waitingConfirmation,
      'REFUND_PENDING' => TrangThaiDon.refundPending,
      'REFUNDED' => TrangThaiDon.refunded,
      'CANCELLED' => TrangThaiDon.cancelled,
      'EXPIRED' => TrangThaiDon.expired,
      _ => TrangThaiDon.pending,
    };
