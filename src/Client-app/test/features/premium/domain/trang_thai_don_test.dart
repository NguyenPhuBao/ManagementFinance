/// Trạng thái đơn — phép dịch chuỗi `status` của server và chữ trạng thái do client chọn (spec Premium 5.4 / 9.4;
/// tách khỏi hai test model ở G94 lát 1 khi `TrangThaiDon` sang `domain/trang_thai_don.dart`).
library;

import 'package:flowmoney/features/premium/domain/trang_thai_don.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trạng thái đơn: đầy đủ 6 trạng thái nghiệp vụ; lạ → pending', () {
    expect(trangThaiDonTuChuoi('PAID'), TrangThaiDon.paid);
    expect(trangThaiDonTuChuoi('paid'), TrangThaiDon.paid);
    expect(trangThaiDonTuChuoi('WAITING_CONFIRMATION'), TrangThaiDon.waitingConfirmation);
    expect(trangThaiDonTuChuoi('REFUND_PENDING'), TrangThaiDon.refundPending);
    expect(trangThaiDonTuChuoi('REFUNDED'), TrangThaiDon.refunded);
    expect(trangThaiDonTuChuoi('CANCELLED'), TrangThaiDon.cancelled);
    expect(trangThaiDonTuChuoi('EXPIRED'), TrangThaiDon.expired);
    expect(trangThaiDonTuChuoi('PENDING'), TrangThaiDon.pending);
    expect(trangThaiDonTuChuoi('SUCCESS'), TrangThaiDon.pending,
        reason: 'chuỗi không biết không được coi là đã trả');
    expect(trangThaiDonTuChuoi(null), TrangThaiDon.pending);
  });

  test('chữ trạng thái tiếng Việt', () {
    expect(chuTrangThaiDon(TrangThaiDon.paid), 'Đã thanh toán');
    expect(chuTrangThaiDon(TrangThaiDon.pending), 'Chờ thanh toán');
    expect(chuTrangThaiDon(TrangThaiDon.cancelled), 'Đã huỷ');
    expect(chuTrangThaiDon(TrangThaiDon.expired), 'Hết hạn');
    expect(chuTrangThaiDon(TrangThaiDon.refundPending), 'Chờ hoàn tiền',
        reason: 'người dùng không phải làm gì — "Cần hoàn tiền" đọc như việc của họ (spec G94 mục 5.1)');
    expect(chuTrangThaiDon(TrangThaiDon.waitingConfirmation), 'Chờ xác nhận');
    expect(chuTrangThaiDon(TrangThaiDon.refunded), 'Đã hoàn tiền');
  });
}
