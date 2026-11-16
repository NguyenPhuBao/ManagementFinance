import '../../domain/trang_thai_ban_sao.dart';

/// Một yêu cầu bản sao (`GET /account/data-export/latest` hoặc `data` của `POST` 202). Chỉ giữ trường app dùng.
class YeuCauBanSao {
  const YeuCauBanSao({
    required this.id,
    required this.trangThai,
    this.expiresAt,
    this.files = const [],
    this.email,
  });

  final String id;
  final TrangThaiBanSao trangThai;

  /// Giờ máy. Chỉ có khi `READY` / `EXPIRED`.
  final DateTime? expiresAt;

  /// `json` / `csv` — chỉ có phần tử khi `READY`.
  final List<String> files;

  /// Email đã che (`an***@gmail.com`) — chỉ có ở phản hồi 202.
  final String? email;
}

/// `data` của bao `{success, data}`. Không phải Map → `null` = chưa từng yêu cầu.
YeuCauBanSao? yeuCauBanSaoTuJson(Object? data) {
  if (data is! Map) return null;
  final m = data.cast<String, Object?>();
  final status = m['status'];
  final hanThuc = m['expiresAt'];
  final files = m['files'];
  final email = m['email'];
  return YeuCauBanSao(
    id: m['id']?.toString() ?? '',
    trangThai: trangThaiTuChuoi(status is String ? status : null),
    expiresAt: hanThuc is String ? DateTime.tryParse(hanThuc)?.toLocal() : null,
    files: files is List ? [for (final f in files) if (f == 'json' || f == 'csv') f as String] : const [],
    email: email is String ? email : null,
  );
}
