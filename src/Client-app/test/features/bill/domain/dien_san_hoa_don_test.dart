/// Điền sẵn form tạo hoá đơn từ một khoản lặp (B2) — query của route `/bills/add`.
///
/// Spec 2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md mục 5: query hỏng thì bỏ
/// trường ấy, không ném.
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/features/bill/domain/dien_san_hoa_don.dart';
import 'package:flowmoney/features/transaction/domain/khoan_lap.dart';
import 'package:flutter_test/flutter_test.dart';

final _k = KhoanLap(
  khoaNhom: 'tien nha|c-nha',
  ten: 'Tiền nhà',
  soTien: 3100000,
  chuKy: kBillCycleMonth,
  ngayGoc: 31,
  ngayGanNhat: DateTime(2026, 11, 30),
  categoryId: 'c-nha',
  walletId: 'v1',
  soLan: 3,
);

void main() {
  test('khứ hồi queryTuKhoanLap → dienSanTuQuery giữ đúng bảy giá trị', () {
    final q = queryTuKhoanLap(_k);
    expect(q['start'], '2026-11-30');
    expect(q['amount'], '3100000', reason: 'số nguyên thô — ô tiền đọc bằng double.tryParse');
    final d = dienSanTuQuery(q)!;
    expect(d.ten, 'Tiền nhà');
    expect(d.soTien, 3100000);
    expect(d.chuKy, kBillCycleMonth);
    expect(d.ngayGoc, 31);
    expect(d.batDau, DateTime(2026, 11, 30));
    expect(d.categoryId, 'c-nha');
    expect(d.walletId, 'v1');
  });

  test('khoản lặp tuần: không có khoá anchor', () {
    final q = queryTuKhoanLap(KhoanLap(
      khoaNhom: 'gui xe|',
      ten: 'Gửi xe',
      soTien: 50000,
      chuKy: kBillCycleWeek,
      ngayGoc: null,
      ngayGanNhat: DateTime(2026, 11, 17),
      categoryId: null,
      walletId: 'v1',
      soLan: 3,
    ));
    expect(q.containsKey('anchor'), isFalse);
    expect(q.containsKey('category'), isFalse);
    final d = dienSanTuQuery(q)!;
    expect(d.chuKy, kBillCycleWeek);
    expect(d.ngayGoc, isNull);
    expect(d.categoryId, isNull);
  });

  test('query không có khoá nào của mình → null (form trống như cũ)', () {
    expect(dienSanTuQuery(const {}), isNull);
    expect(dienSanTuQuery(const {'khac': '1'}), isNull);
  });

  test('giá trị hỏng → đúng trường ấy null, trường khác giữ', () {
    final d = dienSanTuQuery(const {
      'name': 'Netflix',
      'amount': 'abc',
      'cycle': 'Daily',
      'anchor': '0',
      'start': '30-11-2026',
    })!;
    expect(d.ten, 'Netflix');
    expect(d.soTien, isNull);
    expect(d.chuKy, isNull, reason: 'chỉ nhận bốn chu kỳ của hoá đơn');
    expect(d.ngayGoc, isNull);
    expect(d.batDau, isNull);
    expect(dienSanTuQuery(const {'anchor': '32'})!.ngayGoc, isNull);
    expect(dienSanTuQuery(const {'anchor': '1'})!.ngayGoc, 1);
    expect(dienSanTuQuery(const {'amount': '-5'})!.soTien, isNull,
        reason: 'số tiền âm hoặc 0 không phải số tiền hoá đơn');
  });

  test('tên chỉ có khoảng trắng → null', () {
    expect(dienSanTuQuery(const {'name': '   '})!.ten, isNull);
  });
}
