import '../../domain/hang_goi.dart';

/// Đơn vừa tạo (`POST /payment/create-order`) — số tiền, hạn, mã nhận diện, ảnh VietQR server dựng và thông tin chuyển
/// khoản cho người chuyển tay (spec Premium 5.4; spec G94 2026-10-18 mục 5.1).
class DonThanhToan {
  const DonThanhToan({
    required this.orderCode,
    required this.checkoutUrl,
    required this.soTien,
    required this.hetHanLuc,
    this.recognitionCode,
    this.qrUrl,
    this.noiDung,
    this.soTaiKhoan,
    this.chuTaiKhoan,
  });

  final int orderCode;
  final Uri checkoutUrl;
  final int soTien;

  /// Hạn thanh toán (server: 10 phút sau khi tạo). Chỉ để HIỆN đếm ngược — server quyết hết hạn (G94 việc 1).
  final DateTime hetHanLuc;

  /// Mã nhận diện 6 ký tự (VD "A8K9M2") — phần cuối của [noiDung].
  final String? recognitionCode;

  /// Ảnh VietQR server dựng (`img.vietqr.io`, nhúng số tiền + nội dung). `null` → màn không ảnh, không nút Lưu.
  final Uri? qrUrl;

  /// Nội dung chuyển khoản đầy đủ PayOS cấp (`transferContent` ?? `description`), VD "CSCYDEZ2N10 A8K9M2".
  final String? noiDung;

  /// Số tài khoản nhận (`accountNumber` của PayOS).
  final String? soTaiKhoan;

  /// Tên chủ tài khoản nhận (`accountName` của PayOS) — dữ liệu server, client không ghi cứng.
  final String? chuTaiKhoan;
}

/// `null` khi thiếu `orderCode` hoặc `checkoutUrl` không phải URL có scheme và host — không dựng được màn Đang chờ từ một
/// đơn như thế. Trường tuỳ chọn rác / rỗng → `null` cho đúng trường ấy. KHÔNG tự dựng URL ảnh QR (spec G94 mục 5.1 —
/// server luôn gửi `qrUrl`; bản tự dựng cũ ghi cứng tên chủ tài khoản ở client).
DonThanhToan? donTuJson(Map<String, Object?> json, {required DateTime now}) {
  final code = json['orderCode'];
  final url = json['checkoutUrl'];
  if (code is! num || url is! String) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final tien = json['amount'];
  final het = json['expiredAt'];

  String? chuoi(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  final qr = chuoi(json['qrUrl']);
  final qrUri = qr == null ? null : Uri.tryParse(qr);

  return DonThanhToan(
    orderCode: code.toInt(),
    checkoutUrl: uri,
    soTien: tien is num && tien > 0 ? tien.toInt() : kGiaPremium,
    hetHanLuc: (het is String ? DateTime.tryParse(het) : null) ?? now.add(const Duration(minutes: 10)),
    recognitionCode: chuoi(json['recognitionCode']),
    qrUrl: qrUri != null && qrUri.hasScheme && qrUri.host.isNotEmpty ? qrUri : null,
    noiDung: chuoi(json['transferContent']) ?? chuoi(json['description']),
    soTaiKhoan: chuoi(json['accountNumber']),
    chuTaiKhoan: chuoi(json['accountName']),
  );
}
