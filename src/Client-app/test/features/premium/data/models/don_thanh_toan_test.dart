/// `DonThanhToan` đọc từ `POST /payment/create-order` (spec Premium 5.4 & Payment Reconciliation). Trạng thái đơn
/// của `GET /payment/order-status`: `test/features/premium/domain/trang_thai_don_test.dart`.
library;

import 'package:flowmoney/features/premium/data/models/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10);

  test('đọc data của create-order đầy đủ trường đối soát và mã nhận diện 6 ký tự', () {
    final d = donTuJson({
      'orderCode': 200370869,
      'checkoutUrl': 'https://pay.payos.vn/web/abc',
      'amount': 49000,
      'expiredAt': '2026-10-06T03:39:30.000Z',
      'recognitionCode': 'A8K9M2',
      'transferContent': 'CSCYDEZ2N10 A8K9M2',
      'bin': '970422',
      'accountNumber': '2512070399999',
      'accountName': 'NGUYEN PHU BAO',
      'amountReceived': 49000,
      'fee': 0,
    }, now: now)!;
    expect(d.orderCode, 200370869);
    expect(d.checkoutUrl, Uri.parse('https://pay.payos.vn/web/abc'));
    expect(d.soTien, 49000);
    expect(d.hetHanLuc, DateTime.utc(2026, 10, 6, 3, 39, 30));
    expect(d.recognitionCode, 'A8K9M2');
    expect(d.transferContent, 'CSCYDEZ2N10 A8K9M2');
    expect(d.amountReceived, 49000);
    expect(d.fee, 0);
    expect(d.qrUrl, isNotNull);
    expect(d.qrUrl.toString(), contains('2512070399999'));
  });

  test('thiếu orderCode hoặc checkoutUrl không hợp lệ → null', () {
    expect(donTuJson({'checkoutUrl': 'https://x'}, now: now), isNull);
    expect(donTuJson({'orderCode': 1, 'checkoutUrl': 'khong phai url'}, now: now),
        isNull);
    expect(donTuJson({}, now: now), isNull);
  });

  test('amount / expiredAt thiếu → giá mặc định, hạn now + 10 phút', () {
    final d = donTuJson(
        {'orderCode': 1, 'checkoutUrl': 'https://pay.payos.vn/web/x'},
        now: now)!;
    expect(d.soTien, kGiaPremium);
    expect(d.hetHanLuc, now.add(const Duration(minutes: 10)));
  });
}
