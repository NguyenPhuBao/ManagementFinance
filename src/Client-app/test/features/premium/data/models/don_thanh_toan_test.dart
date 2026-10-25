/// `DonThanhToan` đọc từ `POST /payment/create-order` (spec Premium 5.4; spec G94 2026-10-18 mục 5.1 — thông tin
/// chuyển khoản cho người chuyển tay, ảnh QR server dựng, không tự dựng URL). Trạng thái đơn của
/// `GET /payment/order-status`: `test/features/premium/domain/trang_thai_don_test.dart`.
library;

import 'package:flowmoney/features/premium/data/models/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 10);

  test('đọc create-order: số tài khoản · chủ tài khoản · nội dung đầy đủ · ảnh QR server dựng', () {
    final d = donTuJson({
      'orderCode': 200370869,
      'checkoutUrl': 'https://pay.payos.vn/web/abc',
      'amount': 49000,
      'expiredAt': '2026-10-06T03:39:30.000Z',
      'recognitionCode': 'A8K9M2',
      'transferContent': 'CSCYDEZ2N10 A8K9M2',
      'description': 'khác — transferContent thắng',
      'accountNumber': '0123456789',
      'accountName': 'NGUYEN VAN A',
      'qrUrl': 'https://img.vietqr.io/image/970422-0123456789-compact2.png?amount=49000',
    }, now: now)!;
    expect(d.orderCode, 200370869);
    expect(d.checkoutUrl, Uri.parse('https://pay.payos.vn/web/abc'));
    expect(d.soTien, 49000);
    expect(d.hetHanLuc, DateTime.utc(2026, 10, 6, 3, 39, 30));
    expect(d.recognitionCode, 'A8K9M2');
    expect(d.noiDung, 'CSCYDEZ2N10 A8K9M2');
    expect(d.soTaiKhoan, '0123456789');
    expect(d.chuTaiKhoan, 'NGUYEN VAN A');
    expect(d.qrUrl, Uri.parse('https://img.vietqr.io/image/970422-0123456789-compact2.png?amount=49000'));
  });

  test('KHÔNG tự dựng URL ảnh QR khi server không gửi qrUrl — client không ghi cứng tên chủ tài khoản', () {
    final d = donTuJson({
      'orderCode': 1,
      'checkoutUrl': 'https://pay.payos.vn/web/x',
      'bin': '970422',
      'accountNumber': '0123',
      'description': 'CS1 ABC123',
    }, now: now)!;
    expect(d.qrUrl, isNull, reason: 'bản cũ dựng img.vietqr.io từ bin + accountNumber với tên ghi cứng ở domain/');
    expect(d.noiDung, 'CS1 ABC123', reason: 'description dự phòng cho transferContent');
    expect(d.soTaiKhoan, '0123');
    expect(d.chuTaiKhoan, isNull);
  });

  test('trường tuỳ chọn rác / rỗng → null cho đúng trường ấy, đơn vẫn đọc được', () {
    final d = donTuJson({
      'orderCode': 1,
      'checkoutUrl': 'https://x.vn/a',
      'qrUrl': 'khong phai url',
      'accountName': '   ',
      'transferContent': '',
      'description': 'CS1 X',
      'recognitionCode': '',
    }, now: now)!;
    expect(d.qrUrl, isNull);
    expect(d.chuTaiKhoan, isNull);
    expect(d.noiDung, 'CS1 X', reason: 'transferContent rỗng thì rơi về description');
    expect(d.recognitionCode, isNull);
  });

  test('thiếu orderCode hoặc checkoutUrl không hợp lệ → null', () {
    expect(donTuJson({'checkoutUrl': 'https://x'}, now: now), isNull);
    expect(donTuJson({'orderCode': 1, 'checkoutUrl': 'khong phai url'}, now: now), isNull);
    expect(donTuJson({}, now: now), isNull);
  });

  test('checkoutUrl không phải https → null (siết bảo mật đợt 2, 2026-10-24)', () {
    for (final url in ['http://pay.payos.vn/web/x', 'intent://pay/#Intent;scheme=momo;end', 'momo://pay/x']) {
      expect(donTuJson({'orderCode': 1, 'checkoutUrl': url}, now: now), isNull,
          reason: '"$url": link này mở ra app ngoài (url_launcher) — trước chỉ kiểm có scheme + host nên intent:// '
              'hay http đều lọt; câu trả lời bị sửa trên đường truyền là đưa người dùng tới trang giả');
    }
  });

  test('qrUrl không phải https → không hiện ảnh QR, đơn vẫn đọc được', () {
    final d = donTuJson({
      'orderCode': 1,
      'checkoutUrl': 'https://pay.payos.vn/web/x',
      'qrUrl': 'http://img.vietqr.io/image/x.png',
    }, now: now)!;
    expect(d.qrUrl, isNull, reason: 'ảnh QR là thứ app ngân hàng quét để chuyển tiền — ảnh tải qua http thì ai '
        'cùng mạng cũng thay được bằng QR tài khoản khác');
  });

  test('amount / expiredAt thiếu → giá mặc định, hạn now + 10 phút', () {
    final d = donTuJson({'orderCode': 1, 'checkoutUrl': 'https://pay.payos.vn/web/x'}, now: now)!;
    expect(d.soTien, kGiaPremium);
    expect(d.hetHanLuc, now.add(const Duration(minutes: 10)));
  });
}
