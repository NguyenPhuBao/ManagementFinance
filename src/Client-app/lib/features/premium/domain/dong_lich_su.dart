import 'don_thanh_toan.dart';

/// Một dòng của `GET /payment/history` (spec Premium 9.4). [luc] = `paid_at`
/// nếu có, không thì `created_at`; rác → `null`.
class DongLichSu {
  const DongLichSu({
    required this.orderCode,
    required this.soTien,
    required this.trangThai,
    this.luc,
  });

  final int orderCode;
  final int soTien;
  final TrangThaiDon trangThai;
  final DateTime? luc;
}

/// Bỏ phần tử thiếu `order_code`; không ném với bất kỳ JSON nào.
List<DongLichSu> dongLichSuTu(List<Map<String, Object?>> items) {
  DateTime? ngay(Object? v) => v is String ? DateTime.tryParse(v) : null;
  return [
    for (final m in items)
      if (m['order_code'] case final num code)
        DongLichSu(
          orderCode: code.toInt(),
          soTien: switch (m['amount']) {
            final num a when a > 0 => a.toInt(),
            _ => 0,
          },
          trangThai: trangThaiDonTuChuoi(m['status']),
          luc: ngay(m['paid_at']) ?? ngay(m['created_at']),
        ),
  ];
}

/// Chữ trạng thái do client chọn — hằng tiếng Việt, không lấy từ payload.
String chuTrangThaiDon(TrangThaiDon t) => switch (t) {
      TrangThaiDon.paid => 'Đã thanh toán',
      TrangThaiDon.pending => 'Chờ thanh toán',
      TrangThaiDon.cancelled => 'Đã huỷ',
      TrangThaiDon.expired => 'Hết hạn',
    };
