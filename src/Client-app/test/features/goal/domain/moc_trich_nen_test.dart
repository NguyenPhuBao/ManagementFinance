/// Phần MỤC TIÊU của lịch lượt nền tự chuyển tiền (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.1) — ca dời từ
/// `test/core/nen/lich_nen_test.dart` 2026-10-15 cùng phép tính (G88 gạch 4); kỳ vọng giữ nguyên.
library;

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/moc_trich_nen.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  final now = DateTime(2026, 10, 10, 10);

  test('mục tiêu bật trích → kỳ kế (kyKeTiep), coTuDong true', () {
    final l = mocTrichNen([_mucTieu()], now: now);
    expect(l.moc, DateTime(2026, 10, 15, 7));
    expect(l.coTuDong, isTrue);
  });

  test('mục tiêu đã xong / tắt trích → bỏ', () {
    expect(mocTrichNen([_mucTieu(xong: true)], now: now), (moc: null, coTuDong: false));
    expect(mocTrichNen([_mucTieu(soTien: null)], now: now), (moc: null, coTuDong: false));
  });
}
