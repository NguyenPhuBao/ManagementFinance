import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';

void main() {
  group('nextBillDueDate — kẹp vào ngày cuối tháng', () {
    test('31/01 + 1 tháng ra 28/02, KHÔNG nhảy sang tháng 3', () {
      expect(
        nextBillDueDate(DateTime(2026, 1, 31), kBillCycleMonth),
        DateTime(2026, 2, 28),
        reason: 'DateTime(y, 2, 31) tràn thành 03/03 — hoá đơn nhảy qua luôn '
            'tháng 2 và người dùng mất một kỳ thanh toán.',
      );
    });

    test('31/01 năm nhuận ra 29/02', () {
      expect(
        nextBillDueDate(DateTime(2028, 1, 31), kBillCycleMonth),
        DateTime(2028, 2, 29),
        reason: 'Kẹp ngày phải theo số ngày thật của tháng đích, không phải '
            'hằng số 28.',
      );
    });

    test('31/03 + 1 tháng ra 30/04', () {
      expect(
        nextBillDueDate(DateTime(2026, 3, 31), kBillCycleMonth),
        DateTime(2026, 4, 30),
        reason: 'Tháng 30 ngày cũng phải kẹp, không chỉ tháng 2.',
      );
    });

    test('31/12 + 1 tháng ra 31/01 năm sau', () {
      expect(
        nextBillDueDate(DateTime(2026, 12, 31), kBillCycleMonth),
        DateTime(2027, 1, 31),
        reason: 'Vắt qua năm phải tăng năm, không được cho tháng = 13.',
      );
    });

    test('29/02 năm nhuận + 1 năm ra 28/02', () {
      expect(
        nextBillDueDate(DateTime(2028, 2, 29), kBillCycleYear),
        DateTime(2029, 2, 28),
        reason: 'DateTime(2029, 2, 29) tràn thành 01/03 — cùng một lỗi tràn '
            'ngày, chỉ khác chu kỳ.',
      );
    });

    test('30/11 + 1 quý ra 28/02 năm sau', () {
      expect(
        nextBillDueDate(DateTime(2026, 11, 30), kBillCycleQuarter),
        DateTime(2027, 2, 28),
        reason: "'Quarter' nằm trong bộ giá trị của cột timeRecurrence nhưng "
            'trước đây payBill không xử lý — hoá đơn quý đứng im ngày đến hạn.',
      );
    });

    test('chu kỳ tuần cộng đúng 7 ngày, vắt qua năm', () {
      expect(
        nextBillDueDate(DateTime(2026, 12, 28), kBillCycleWeek),
        DateTime(2027, 1, 4),
        reason: 'Chu kỳ tuần không liên quan tới độ dài tháng.',
      );
    });

    test('giữ nguyên giờ và phút của mốc cũ', () {
      expect(
        nextBillDueDate(DateTime(2026, 1, 31, 9, 30), kBillCycleMonth),
        DateTime(2026, 2, 28, 9, 30),
        reason: 'Mất giờ/phút thì hoá đơn đến hạn lúc 00:00, lệch với mốc '
            'người dùng đã đặt.',
      );
    });

    test('chu kỳ lạ thì giữ nguyên mốc cũ thay vì đoán bừa', () {
      expect(
        nextBillDueDate(DateTime(2026, 1, 31), 'Fortnight'),
        DateTime(2026, 1, 31),
        reason: 'Backend có thể thêm giá trị mới; đoán bừa một chu kỳ sai còn '
            'tệ hơn là không đổi mốc.',
      );
    });
  });

  group('quy đổi hai cách biểu diễn chu kỳ', () {
    test('chuỗi cũ đổi sang bộ giá trị của timeRecurrence', () {
      expect(timeRecurrenceFromLegacy('weekly'), kBillCycleWeek);
      expect(timeRecurrenceFromLegacy('monthly'), kBillCycleMonth);
      expect(timeRecurrenceFromLegacy('quarterly'), kBillCycleQuarter);
      expect(timeRecurrenceFromLegacy('yearly'), kBillCycleYear);
    });

    test("'once' không phải một chu kỳ nên trả về null", () {
      expect(
        timeRecurrenceFromLegacy('once'),
        isNull,
        reason: 'Cột timeRecurrence không có giá trị nào nghĩa là "không lặp"; '
            'việc đó do cờ isRecurrence biểu diễn.',
      );
    });

    test('quy đổi ngược lại về chuỗi cũ', () {
      expect(legacyFromTimeRecurrence(kBillCycleWeek), 'weekly');
      expect(legacyFromTimeRecurrence(kBillCycleMonth), 'monthly');
      expect(legacyFromTimeRecurrence(kBillCycleQuarter), 'quarterly');
      expect(legacyFromTimeRecurrence(kBillCycleYear), 'yearly');
    });
  });

  group('quy tắc ngày cuối tháng', () {
    // Chuỗi hoá đơn giờ nối đuôi nhau (bắt đầu kỳ sau = đến hạn kỳ trước) nên
    // không còn mốc gốc để neo. Không có quy tắc này thì mốc "ngày 31 hàng
    // tháng" đi qua tháng Hai một lần là tụt về 28 vĩnh viễn.
    test('31/01 đi qua tháng Hai rồi quay lại được ngày cuối tháng', () {
      var d = DateTime(2026, 1, 31);
      final chuoi = <DateTime>[];
      for (var i = 0; i < 5; i++) {
        d = nextBillDueDate(d, kBillCycleMonth);
        chuoi.add(d);
      }
      expect(
        chuoi,
        [
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 31),
          DateTime(2026, 4, 30),
          DateTime(2026, 5, 31),
          DateTime(2026, 6, 30),
        ],
        reason: 'Chỉ kẹp ngày mà không có quy tắc cuối tháng thì chuỗi đứng '
            'im ở 28 kể từ kỳ thứ hai.',
      );
    });

    test('năm nhuận: 31/01 → 29/02 → 31/03', () {
      final thangHai = nextBillDueDate(DateTime(2028, 1, 31), kBillCycleMonth);
      expect(thangHai, DateTime(2028, 2, 29));
      expect(nextBillDueDate(thangHai, kBillCycleMonth), DateTime(2028, 3, 31));
    });

    test('ngày KHÔNG phải cuối tháng thì giữ nguyên số ngày', () {
      expect(
        nextBillDueDate(DateTime(2026, 1, 15), kBillCycleMonth),
        DateTime(2026, 2, 15),
        reason: 'Quy tắc cuối tháng chỉ được kích hoạt khi mốc đúng là ngày '
            'cuối cùng của tháng nó.',
      );
      expect(
        nextBillDueDate(DateTime(2026, 3, 30), kBillCycleMonth),
        DateTime(2026, 4, 30),
        reason: '30/03 không phải cuối tháng Ba nên đây chỉ là cộng tháng '
            'bình thường, tình cờ trùng ngày cuối tháng Tư.',
      );
    });

    test('áp cho cả chu kỳ quý và năm', () {
      expect(nextBillDueDate(DateTime(2026, 2, 28), kBillCycleQuarter),
          DateTime(2026, 5, 31),
          reason: '28/02 là cuối tháng Hai nên kỳ quý sau phải là cuối tháng Năm.');
      expect(nextBillDueDate(DateTime(2026, 2, 28), kBillCycleYear),
          DateTime(2027, 2, 28));
      expect(nextBillDueDate(DateTime(2028, 2, 29), kBillCycleYear),
          DateTime(2029, 2, 28),
          reason: 'Cuối tháng Hai năm nhuận sang cuối tháng Hai năm thường.');
    });

    test('KHÔNG áp cho chu kỳ tuần', () {
      expect(
        nextBillDueDate(DateTime(2026, 1, 31), kBillCycleWeek),
        DateTime(2026, 2, 7),
        reason: 'Tuần không có khái niệm cuối tháng; cộng đúng 7 ngày.',
      );
    });
  });
}
