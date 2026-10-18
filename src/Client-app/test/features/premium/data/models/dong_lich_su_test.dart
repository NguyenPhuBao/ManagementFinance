/// `dongLichSuTu` đọc `items` của `GET /payment/history` (spec Premium 9.4):
/// bỏ phần tử thiếu `order_code`; `luc` = `paid_at ?? created_at`; chữ trạng
/// thái do client chọn.
library;

import 'package:flowmoney/features/premium/domain/trang_thai_don.dart';
import 'package:flowmoney/features/premium/data/models/dong_lich_su.dart';
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

  test('đọc thêm số đã chuyển · số đã hoàn · ngày hoàn · ngày tạo / trả (spec G94 mục 5.1)', () {
    final d = dongLichSuTu([
      {
        'order_code': 9,
        'amount': 49000,
        'status': 'REFUNDED',
        'created_at': '2026-10-18T07:05:00.000Z',
        'paid_at': null,
        'amount_received': 60000,
        'refunded_amount': 60000,
        'refunded_at': '2026-10-20T02:00:00.000Z',
      }
    ]).single;
    expect(d.taoLuc, DateTime.utc(2026, 10, 18, 7, 5));
    expect(d.traLuc, isNull);
    expect(d.luc, d.taoLuc, reason: 'dòng Lịch sử vẫn hiện paid_at ?? created_at');
    expect(d.soDaChuyen, 60000);
    expect(d.soDaHoan, 60000);
    expect(d.hoanLuc, DateTime.utc(2026, 10, 20, 2));
  });

  test('amount_received 0 / rác → null (server mặc định 0.00 khi chưa nhận)', () {
    final d = dongLichSuTu([
      {'order_code': 1, 'amount': 49000, 'status': 'PENDING', 'amount_received': 0, 'refunded_amount': 'x'}
    ]).single;
    expect(d.soDaChuyen, isNull);
    expect(d.soDaHoan, isNull);
  });
}
