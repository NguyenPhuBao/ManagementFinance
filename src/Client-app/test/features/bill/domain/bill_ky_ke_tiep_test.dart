/// Kỳ kế tiếp của một hoá đơn — phép tính NGÀY, tách khỏi việc dựng hàng.
///
/// Canh chừng điều gì: đây là định nghĩa duy nhất mà cả `payBill` (sinh hàng
/// thật) lẫn dự báo 30 ngày (chiếu kỳ tương lai) cùng dùng. Hai bẫy đã vấp
/// thật: nối từ hạn trả thay vì kết thúc kỳ (hở đúng số ngày ân hạn, mỗi kỳ
/// trôi thêm), và cộng dồn ngày gốc (ngày 31 tụt về 28 vĩnh viễn sau tháng
/// Hai). Cả hai im lặng.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_ky_ke_tiep.dart';

Bill _hoaDon({
  required DateTime dueDate,
  DateTime? periodEnd,
  int? anchorDay,
  String chuKy = kBillCycleMonth,
}) =>
    Bill(
      id: 'b1',
      idaccount: 7,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: 250000,
      startDate: DateTime(2026, 9, 1),
      periodEnd: periodEnd,
      dueDate: dueDate,
      anchorDay: anchorDay,
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: chuKy,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  test('ân hạn 15 ngày: nối từ KẾT THÚC KỲ, hạn trả kỳ sau giữ đúng 15 ngày',
      () {
    final ky = kyKeTiepCua(_hoaDon(
      periodEnd: DateTime(2026, 10, 1),
      dueDate: DateTime(2026, 10, 16),
      anchorDay: 1,
    ));

    expect(ky.batDau, DateTime(2026, 10, 1),
        reason: 'Nối từ hạn trả 16/10 là hở 15 ngày và mỗi kỳ trôi thêm — '
            'bẫy §4.4 tài liệu xin backend, đã vấp thật.');
    expect(ky.ketThuc, DateTime(2026, 11, 1));
    expect(ky.hanTra, DateTime(2026, 11, 16));
    expect(ky.anchorDay, 1);
  });

  test('hàng cũ periodEnd NULL: kết thúc kỳ trùng hạn trả, ra y hệt trước v21',
      () {
    final ky =
        kyKeTiepCua(_hoaDon(dueDate: DateTime(2026, 9, 20), anchorDay: 20));

    expect(ky.batDau, DateTime(2026, 9, 20));
    expect(ky.ketThuc, DateTime(2026, 10, 20));
    expect(ky.hanTra, DateTime(2026, 10, 20),
        reason: 'ân hạn 0 → hạn trả = kết thúc kỳ');
  });

  test('anchorDay 31 đi qua tháng Hai NĂM NHUẬN rồi quay lại 31', () {
    // Kỳ hiện tại kết thúc 31/01/2028, ngày gốc 31.
    final k1 = kyKeTiepCua(_hoaDon(
      periodEnd: DateTime(2028, 1, 31),
      dueDate: DateTime(2028, 1, 31),
      anchorDay: 31,
    ));
    expect(k1.ketThuc, DateTime(2028, 2, 29),
        reason: '2028 nhuận: kẹp về 29, không phải 28');
    expect(k1.anchorDay, 31,
        reason: 'ngày gốc phải đi theo, không bị hạ xuống 29');

    // Kỳ sau nữa: dựng từ kỳ vừa tính, ngày gốc vẫn 31.
    final k2 = kyKeTiepCua(_hoaDon(
      periodEnd: k1.ketThuc,
      dueDate: k1.hanTra,
      anchorDay: k1.anchorDay,
    ));
    expect(k2.ketThuc, DateTime(2028, 3, 31),
        reason:
            'Cộng dồn từ 29/02 thì ra 29/03 và nhịp tụt xuống 29 vĩnh viễn.');
  });

  test('anchorDay NULL thì neo vào ngày của mốc bắt đầu — giữ hành vi cũ, không đoán',
      () {
    final ky = kyKeTiepCua(_hoaDon(
      periodEnd: DateTime(2026, 2, 28),
      dueDate: DateTime(2026, 2, 28),
    ));
    expect(ky.anchorDay, 28);
    expect(ky.ketThuc, DateTime(2026, 3, 28));
  });

  test('chu kỳ tuần: cộng đúng 7 ngày, anchorDay không áp dụng', () {
    final ky = kyKeTiepCua(_hoaDon(
      periodEnd: DateTime(2026, 9, 7),
      dueDate: DateTime(2026, 9, 9),
      anchorDay: 31,
      chuKy: kBillCycleWeek,
    ));
    expect(ky.ketThuc, DateTime(2026, 9, 14));
    expect(ky.hanTra, DateTime(2026, 9, 16), reason: 'ân hạn 2 ngày giữ nguyên');
  });
}
