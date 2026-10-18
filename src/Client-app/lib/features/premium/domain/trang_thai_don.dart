/// Trạng thái đơn thanh toán (spec Premium 2026-10-06 mục 5.4; ba trạng thái đối soát từ gộp `d72ccd45`) — hằng và
/// câu chữ; model đơn ở `data/models/don_thanh_toan.dart`, dòng lịch sử ở `data/models/dong_lich_su.dart`.
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

/// Chữ trạng thái do client chọn — hằng tiếng Việt, không lấy từ payload.
String chuTrangThaiDon(TrangThaiDon t) => switch (t) {
      TrangThaiDon.paid => 'Đã thanh toán',
      TrangThaiDon.pending => 'Chờ thanh toán',
      TrangThaiDon.waitingConfirmation => 'Chờ xác nhận',
      TrangThaiDon.refundPending => 'Cần hoàn tiền',
      TrangThaiDon.refunded => 'Đã hoàn tiền',
      TrangThaiDon.cancelled => 'Đã huỷ',
      TrangThaiDon.expired => 'Hết hạn',
    };
