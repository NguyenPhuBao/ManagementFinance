import '../../domain/trang_thai_don.dart';

/// Một dòng của `GET /payment/history` (spec Premium 9.4; số liệu đối soát spec G94 2026-10-18 mục 5.1). Rác → `null`
/// cho đúng trường ấy, không ném.
class DongLichSu {
  const DongLichSu({
    required this.orderCode,
    required this.soTien,
    required this.trangThai,
    this.taoLuc,
    this.traLuc,
    this.soDaChuyen,
    this.soDaHoan,
    this.hoanLuc,
  });

  final int orderCode;

  /// Giá gói của đơn (`amount`).
  final int soTien;
  final TrangThaiDon trangThai;

  /// `created_at`.
  final DateTime? taoLuc;

  /// `paid_at`.
  final DateTime? traLuc;

  /// `amount_received` — `null` khi server chưa nhận (mặc định 0.00).
  final int? soDaChuyen;

  /// `refunded_amount` — số admin đã hoàn.
  final int? soDaHoan;

  /// `refunded_at`.
  final DateTime? hoanLuc;

  /// Ngày hiện ở dòng Lịch sử: `paid_at ?? created_at`.
  DateTime? get luc => traLuc ?? taoLuc;
}

/// Bỏ phần tử thiếu `order_code`; không ném với bất kỳ JSON nào.
List<DongLichSu> dongLichSuTu(List<Map<String, Object?>> items) {
  DateTime? ngay(Object? v) => v is String ? DateTime.tryParse(v) : null;
  int? soDuong(Object? v) => v is num && v > 0 ? v.toInt() : null;
  return [
    for (final m in items)
      if (m['order_code'] case final num code)
        DongLichSu(
          orderCode: code.toInt(),
          soTien: soDuong(m['amount']) ?? 0,
          trangThai: trangThaiDonTuChuoi(m['status']),
          taoLuc: ngay(m['created_at']),
          traLuc: ngay(m['paid_at']),
          soDaChuyen: soDuong(m['amount_received']),
          soDaHoan: soDuong(m['refunded_amount']),
          hoanLuc: ngay(m['refunded_at']),
        ),
  ];
}
