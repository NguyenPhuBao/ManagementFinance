/// `dongLichSuTu` đọc `items` của `GET /payment/history` (spec Premium 9.4):
/// bỏ phần tử thiếu `order_code`; `luc` = `paid_at ?? created_at`; chữ trạng
/// thái do client chọn.
library;

import 'package:flowmoney/features/premium/domain/don_thanh_toan.dart';
import 'package:flowmoney/features/premium/domain/dong_lich_su.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đọc items: order_code · amount · status · paid_at ?? created_at', () {
    final ds = dongLichSuTu([
      {
        'order_code': 1,
        'amount': 49000,
        'status': 'PAID',
        'created_at': '2026-10-05T18:39:30.000Z',
        'paid_at': '2026-10-05T18:40:15.000Z',
      },
      {
        'order_code': 2,
        'amount': 49000,
        'status': 'EXPIRED',
        'created_at': '2026-10-01T10:00:00.000Z',
        'paid_at': null,
      },
      {'amount': 1, 'status': 'PAID'}, // thiếu order_code → bỏ
    ]);
    expect(ds.length, 2);
    expect(ds[0].orderCode, 1);
    expect(ds[0].soTien, 49000);
    expect(ds[0].trangThai, TrangThaiDon.paid);
    expect(ds[0].luc, DateTime.utc(2026, 10, 5, 18, 40, 15));
    expect(ds[1].trangThai, TrangThaiDon.expired);
    expect(ds[1].luc, DateTime.utc(2026, 10, 1, 10));
  });

  test('amount rác → 0; ngày rác → null; không ném', () {
    final d = dongLichSuTu([
      {'order_code': 3, 'amount': 'x', 'status': 'PENDING', 'created_at': 'hom qua'}
    ]).single;
    expect(d.soTien, 0);
    expect(d.luc, isNull);
    expect(d.trangThai, TrangThaiDon.pending);
  });

  test('chữ trạng thái tiếng Việt', () {
    expect(chuTrangThaiDon(TrangThaiDon.paid), 'Đã thanh toán');
    expect(chuTrangThaiDon(TrangThaiDon.pending), 'Chờ thanh toán');
    expect(chuTrangThaiDon(TrangThaiDon.cancelled), 'Đã huỷ');
    expect(chuTrangThaiDon(TrangThaiDon.expired), 'Hết hạn');
  });
}
