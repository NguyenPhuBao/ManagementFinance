/// `DonThanhToan` đọc từ `POST /payment/create-order` và trạng thái đơn của
/// `GET /payment/order-status` (spec Premium 5.4). Chuỗi trạng thái lạ KHÔNG
/// bao giờ được coi là "đã trả".
library;

import 'package:flowmoney/features/premium/domain/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10);

  test('đọc data của create-order', () {
    final d = donTuJson({
      'orderCode': 200370869,
      'checkoutUrl': 'https://pay.payos.vn/web/abc',
      'amount': 49000,
      'expiredAt': '2026-10-06T03:39:30.000Z',
    }, now: now)!;
    expect(d.orderCode, 200370869);
    expect(d.checkoutUrl, Uri.parse('https://pay.payos.vn/web/abc'));
    expect(d.soTien, 49000);
    expect(d.hetHanLuc, DateTime.utc(2026, 10, 6, 3, 39, 30));
  });

  test('thiếu orderCode hoặc checkoutUrl không hợp lệ → null', () {
    expect(donTuJson({'checkoutUrl': 'https://x'}, now: now), isNull);
    expect(donTuJson({'orderCode': 1, 'checkoutUrl': 'khong phai url'}, now: now),
        isNull);
    expect(donTuJson({}, now: now), isNull);
  });

  test('amount / expiredAt thiếu → giá mặc định, hạn now + 30 phút', () {
    final d = donTuJson(
        {'orderCode': 1, 'checkoutUrl': 'https://pay.payos.vn/web/x'},
        now: now)!;
    expect(d.soTien, kGiaPremium);
    expect(d.hetHanLuc, now.add(const Duration(minutes: 30)));
  });

  test('trạng thái đơn: PAID/CANCELLED/EXPIRED; lạ → pending', () {
    expect(trangThaiDonTuChuoi('PAID'), TrangThaiDon.paid);
    expect(trangThaiDonTuChuoi('paid'), TrangThaiDon.paid);
    expect(trangThaiDonTuChuoi('CANCELLED'), TrangThaiDon.cancelled);
    expect(trangThaiDonTuChuoi('EXPIRED'), TrangThaiDon.expired);
    expect(trangThaiDonTuChuoi('PENDING'), TrangThaiDon.pending);
    expect(trangThaiDonTuChuoi('SUCCESS'), TrangThaiDon.pending,
        reason: 'chuỗi không biết không được coi là đã trả');
    expect(trangThaiDonTuChuoi(null), TrangThaiDon.pending);
  });
}
