/// Phần HOÁ ĐƠN của lịch lượt nền tự chuyển tiền (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.1) — ca dời từ
/// `test/core/nen/lich_nen_test.dart` 2026-10-15 cùng phép tính (G88 gạch 4); kỳ vọng giữ nguyên.
library;

import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/domain/moc_tu_tra_nen.dart';
import 'package:flutter_test/flutter_test.dart';

BillEntity _hoaDon({
  required DateTime han,
  bool tuTra = true,
  bool daTra = false,
  String? viId = 'w1',
  bool daXoa = false,
}) =>
    BillEntity(
      id: 'b1',
      idaccount: 7,
      walletId: viId,
      categoryId: 'c1',
      name: 'Netflix',
      amount: 260000,
      startDate: DateTime(2026, 9, 5),
      dueDate: han,
      payStatus: daTra ? 'Payed' : 'Pending',
      isPaid: daTra,
      autoPayEnabled: tuTra,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: daXoa,
      syncStatus: 'synced',
      updatedAt: DateTime(2026, 9, 5),
    );

void main() {
  final now = DateTime(2026, 10, 10, 10);

  test('hoá đơn tự trả hạn ngày mai → mốc = ngày mai lúc giờ nhắc chung', () {
    final l = mocTuTraNen([_hoaDon(han: DateTime(2026, 10, 11, 23))], now: now, gioNhac: 8, phutNhac: 30);
    expect(l.moc, DateTime(2026, 10, 11, 8, 30));
    expect(l.coTuDong, isTrue);
  });

  test('hạn HÔM NAY mà giờ nhắc đã qua → không hẹn (lượt định kỳ thử lại), coTuDong vẫn true', () {
    final l = mocTuTraNen([_hoaDon(han: DateTime(2026, 10, 10))], now: now, gioNhac: 8, phutNhac: 0);
    expect(l.moc, isNull, reason: 'hẹn "ngay" khi ví không đủ là lượt một-lần tự hẹn lại ngay — vòng lặp tốn pin');
    expect(l.coTuDong, isTrue, reason: 'còn hoá đơn tự trả thì phải giữ lượt định kỳ');
  });

  test('hạn hôm nay, giờ nhắc CHƯA tới → hẹn hôm nay', () {
    final l = mocTuTraNen([_hoaDon(han: DateTime(2026, 10, 10))], now: now, gioNhac: 20, phutNhac: 0);
    expect(l.moc, DateTime(2026, 10, 10, 20));
  });

  test('hai hoá đơn: mốc NHỎ NHẤT thắng dù đứng sau trong danh sách', () {
    final l = mocTuTraNen(
      [_hoaDon(han: DateTime(2026, 10, 20)), _hoaDon(han: DateTime(2026, 10, 12))],
      now: now,
      gioNhac: 8,
      phutNhac: 30,
    );
    expect(l.moc, DateTime(2026, 10, 12, 8, 30),
        reason: 'phép chọn mốc sớm nhất nằm TRONG xet (bản chép riêng của mỗi tệp, spec 3.3) — "phần tử đầu thắng" hay "mốc cuối thắng" đều sai');
    expect(l.coTuDong, isTrue);

    final dao = mocTuTraNen(
      [_hoaDon(han: DateTime(2026, 10, 12)), _hoaDon(han: DateTime(2026, 10, 20))],
      now: now,
      gioNhac: 8,
      phutNhac: 30,
    );
    expect(dao.moc, DateTime(2026, 10, 12, 8, 30),
        reason: 'thứ tự ĐẢO [sớm, muộn] bắt bản sai "phần tử cuối thắng"; thứ tự gốc [muộn, sớm] bắt "phần tử đầu thắng" — cần cả hai');
  });

  test('tắt tự trả / đã trả / thiếu ví / đã xoá → bỏ hẳn', () {
    for (final b in [
      _hoaDon(han: DateTime(2026, 10, 11), tuTra: false),
      _hoaDon(han: DateTime(2026, 10, 11), daTra: true),
      _hoaDon(han: DateTime(2026, 10, 11), viId: null),
      _hoaDon(han: DateTime(2026, 10, 11), daXoa: true),
    ]) {
      final l = mocTuTraNen([b], now: now, gioNhac: 8, phutNhac: 0);
      expect(l, (moc: null, coTuDong: false));
    }
  });
}
