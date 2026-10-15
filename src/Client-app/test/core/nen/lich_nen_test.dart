/// Mốc lượt nền kế tiếp của hai bộ tự chuyển tiền (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.1).
/// Từ 2026-10-15 (G88 gạch 4) phép tính của từng phần ở `features/bill/domain/moc_tu_tra_nen.dart` + `features/goal/domain/moc_trich_nen.dart` (ca riêng ở test của hai mảng); tệp này canh phép GỘP, chỗ DI chọn phần theo quyền, và lớp `LichNen`.
library;

import 'dart:io';

import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/domain/moc_tu_tra_nen.dart';
import 'package:flowmoney/core/nen/kenh_tu_chuyen_tien.dart';
import 'package:flowmoney/core/nen/lich_nen.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/moc_trich_nen.dart';
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

  group('gopLichNen', () {
    test('tổ hợp hoá đơn + mục tiêu → mốc SỚM NHẤT (hành vi của lichNenKeTiep trước 2026-10-15)', () {
      final l = gopLichNen([
        mocTuTraNen([_hoaDon(han: DateTime(2026, 10, 20))], now: now, gioNhac: 8, phutNhac: 0),
        mocTrichNen([_mucTieu()], now: now),
      ]);
      expect(l.moc, DateTime(2026, 10, 15, 7));
      expect(l.coTuDong, isTrue);
    });

    test('không phần nào (không quyền gói cả hai — DI không đưa phần vào) → (null, false): Basic không cần đánh thức máy', () {
      expect(gopLichNen(const []), (moc: null, coTuDong: false));
    });

    test('mốc = nhỏ nhất trong các mốc khác null; coTuDong = còn phần nào bật', () {
      final m = DateTime(2026, 10, 12, 8);
      expect(gopLichNen([(moc: null, coTuDong: true), (moc: m, coTuDong: false)]), (moc: m, coTuDong: true));
      expect(gopLichNen([(moc: DateTime(2026, 10, 13), coTuDong: true), (moc: m, coTuDong: true)]),
          (moc: m, coTuDong: true));
      expect(gopLichNen([(moc: m, coTuDong: true), (moc: DateTime(2026, 10, 13), coTuDong: false)]), (moc: m, coTuDong: true),
          reason: 'mốc sớm hơn đứng TRƯỚC vẫn phải thắng — DI đặt phần hoá đơn trước phần mục tiêu');
      expect(gopLichNen([(moc: null, coTuDong: false), (moc: null, coTuDong: false)]), (moc: null, coTuDong: false),
          reason: 'không phần nào bật tự động thì không giữ lượt định kỳ — không đánh thức máy vô cớ');
    });

    test('DI chỉ đưa phần có quyền gói vào (thay ca traDuoc / trichDuoc của lichNenKeTiep cũ — điều kiện nằm ở DI)', () {
      final di = File('lib/core/di/injection_container.dart').readAsStringSync();
      expect(RegExp(r'if \(coQuyenNen\(MaQuyen\.billAutoPay\)\)\s*mocTuTraNen\(').hasMatch(di), isTrue,
          reason: 'không quyền tự trả mà vẫn góp phần hoá đơn là đánh thức máy cho Basic');
      expect(RegExp(r'if \(coQuyenNen\(MaQuyen\.goalAutoDeposit\)\)\s*mocTrichNen\(').hasMatch(di), isTrue,
          reason: 'không quyền trích mục tiêu mà vẫn góp phần mục tiêu là đánh thức máy cho Basic');
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
