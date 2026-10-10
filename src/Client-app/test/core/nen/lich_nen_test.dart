/// Mốc lượt nền kế tiếp của hai bộ tự chuyển tiền (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.1).
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/nen/kenh_tu_chuyen_tien.dart';
import 'package:flowmoney/core/nen/lich_nen.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _hoaDon({
  required DateTime han,
  bool tuTra = true,
  bool daTra = false,
  String? viId = 'w1',
  bool daXoa = false,
}) =>
    Bill(
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
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 5),
    );

GoalEntity _mucTieu({
  DateTime? mocNeo,
  DateTime? sanChay,
  String? chuKy = 'Month',
  bool xong = false,
  double? soTien = 100000,
}) =>
    GoalEntity(
      id: 'g1',
      idaccount: 7,
      name: 'MuaXe',
      targetAmount: 10000000,
      currentAmount: 0,
      startDate: DateTime(2026, 1, 1),
      targetDate: DateTime(2027, 12, 31),
      cycleTakeMoney: chuKy,
      timeCycleTakeMoney: mocNeo ?? DateTime(2026, 9, 15, 7),
      autoDepositAmount: soTien,
      autoDepositWalletId: 'w_nguon',
      autoDepositLastRun: sanChay ?? DateTime(2026, 9, 15, 7),
      isCompleted: xong,
      updatedAt: DateTime(2026, 9, 1),
    );

class _KenhGhi implements KenhTuChuyenTien {
  final lan = <LichNenKeTiep>[];
  @override
  Future<void> henNen(LichNenKeTiep l) async => lan.add(l);
}

void main() {
  final now = DateTime(2026, 10, 10, 10);

  group('lichNenKeTiep', () {
    test('hoá đơn tự trả hạn ngày mai → mốc = ngày mai lúc giờ nhắc chung', () {
      final l = lichNenKeTiep(
          bills: [_hoaDon(han: DateTime(2026, 10, 11, 23))], goals: const [], now: now, gioNhac: 8, phutNhac: 30);
      expect(l.moc, DateTime(2026, 10, 11, 8, 30));
      expect(l.coTuDong, isTrue);
    });

    test('hạn HÔM NAY mà giờ nhắc đã qua → không hẹn (lượt định kỳ thử lại), coTuDong vẫn true', () {
      final l =
          lichNenKeTiep(bills: [_hoaDon(han: DateTime(2026, 10, 10))], goals: const [], now: now, gioNhac: 8, phutNhac: 0);
      expect(l.moc, isNull, reason: 'hẹn "ngay" khi ví không đủ là lượt một-lần tự hẹn lại ngay — vòng lặp tốn pin');
      expect(l.coTuDong, isTrue, reason: 'còn hoá đơn tự trả thì phải giữ lượt định kỳ');
    });

    test('hạn hôm nay, giờ nhắc CHƯA tới → hẹn hôm nay', () {
      final l = lichNenKeTiep(
          bills: [_hoaDon(han: DateTime(2026, 10, 10))], goals: const [], now: now, gioNhac: 20, phutNhac: 0);
      expect(l.moc, DateTime(2026, 10, 10, 20));
    });

    test('tắt tự trả / đã trả / thiếu ví / đã xoá → bỏ hẳn', () {
      for (final b in [
        _hoaDon(han: DateTime(2026, 10, 11), tuTra: false),
        _hoaDon(han: DateTime(2026, 10, 11), daTra: true),
        _hoaDon(han: DateTime(2026, 10, 11), viId: null),
        _hoaDon(han: DateTime(2026, 10, 11), daXoa: true),
      ]) {
        final l = lichNenKeTiep(bills: [b], goals: const [], now: now, gioNhac: 8, phutNhac: 0);
        expect(l, (moc: null, coTuDong: false));
      }
    });

    test('mục tiêu → kỳ kế (kyKeTiep); lấy mốc SỚM NHẤT giữa hoá đơn và mục tiêu', () {
      final l = lichNenKeTiep(
        bills: [_hoaDon(han: DateTime(2026, 10, 20))],
        goals: [_mucTieu()],
        now: now,
        gioNhac: 8,
        phutNhac: 0,
      );
      expect(l.moc, DateTime(2026, 10, 15, 7));
      expect(l.coTuDong, isTrue);
    });

    test('mục tiêu đã xong / tắt trích → bỏ', () {
      expect(lichNenKeTiep(bills: const [], goals: [_mucTieu(xong: true)], now: now, gioNhac: 8, phutNhac: 0),
          (moc: null, coTuDong: false));
      expect(lichNenKeTiep(bills: const [], goals: [_mucTieu(soTien: null)], now: now, gioNhac: 8, phutNhac: 0),
          (moc: null, coTuDong: false));
    });

    test('không quyền gói → loại cả hai vế (Basic không cần đánh thức máy)', () {
      final l = lichNenKeTiep(
        bills: [_hoaDon(han: DateTime(2026, 10, 11))],
        goals: [_mucTieu()],
        now: now,
        gioNhac: 8,
        phutNhac: 0,
        traDuoc: false,
        trichDuoc: false,
      );
      expect(l, (moc: null, coTuDong: false));
    });
  });

  group('LichNen', () {
    test('henNeuDoi chỉ gọi kênh khi lịch ĐỔI (resync chạy sau mọi chu kỳ đồng bộ)', () async {
      final kenh = _KenhGhi();
      var l = (moc: DateTime(2026, 10, 11, 8), coTuDong: true);
      final lich = LichNen(tinh: (_, __) async => l, kenh: kenh);
      await lich.henNeuDoi(1);
      await lich.henNeuDoi(1);
      expect(kenh.lan, hasLength(1));
      l = (moc: DateTime(2026, 10, 12, 8), coTuDong: true);
      await lich.henNeuDoi(1);
      expect(kenh.lan, hasLength(2));
    });

    test('huy → gửi (null, false) và quên lịch đã hẹn', () async {
      final kenh = _KenhGhi();
      final lich = LichNen(tinh: (_, __) async => (moc: DateTime(2026, 10, 11, 8), coTuDong: true), kenh: kenh);
      await lich.henNeuDoi(1);
      await lich.huy();
      expect(kenh.lan.last, (moc: null, coTuDong: false));
      await lich.henNeuDoi(1);
      expect(kenh.lan, hasLength(3), reason: 'sau khi huỷ, lần hẹn kế phải gửi lại dù mốc trùng lần trước');
    });

    test('lichSangKenh: null → 0 mili-giây', () {
      expect(lichSangKenh((moc: null, coTuDong: false)), {'moc': 0, 'coTuDong': false});
      final m = DateTime(2026, 10, 11, 8);
      expect(lichSangKenh((moc: m, coTuDong: true)), {'moc': m.millisecondsSinceEpoch, 'coTuDong': true});
    });
  });
}
