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

  group('ngày gốc (anchor day) — thay cho quy tắc đoán cuối tháng', () {
    // Bản trước đoán ý định từ dữ liệu: "mốc đang xét rơi đúng ngày cuối tháng
    // thì kỳ sau cũng rơi vào ngày cuối tháng". Cú đoán ấy sai với người bắt
    // đầu đúng vào 28/02 — họ muốn NGÀY 28, và nhận về 31/03.
    //
    // Nay ngày gốc là **dữ liệu thật** do người dùng cung cấp, nên hai chuỗi
    // cùng đi qua 28/02 vẫn tách được nhau. Đây là mô hình `advancePeriodFrom`
    // bên ngân sách đã dùng từ đầu (neo vào mốc gốc, không cộng dồn).

    test('28/02 + 1 tháng ra 28/03 khi không có ngày gốc nào khác', () {
      expect(
        nextBillDueDate(DateTime(2026, 2, 28), kBillCycleMonth),
        DateTime(2026, 3, 28),
        reason: 'Người đăng ký lần đầu vào 28/02 muốn NGÀY 28 hàng tháng. Bản '
            'trước trả về 31/03 vì đoán 28/02 nghĩa là "cuối tháng" — đó là '
            'lỗi người dùng báo ngày 2026-09-08.',
      );
    });

    test('28/02 với ngày gốc 31 thì ra 31/03', () {
      expect(
        nextBillDueDate(DateTime(2026, 2, 28), kBillCycleMonth, anchorDay: 31),
        DateTime(2026, 3, 31),
        reason: 'Chuỗi bắt đầu từ 31/01 bị kẹp về 28/02 ở tháng ngắn, nhưng '
            'ngày gốc vẫn là 31 nên kỳ sau phải quay lại 31 — không được tụt '
            'lại vĩnh viễn ở 28.',
      );
    });

    test('CÙNG mốc 28/02, hai ngày gốc khác nhau cho hai kết quả khác nhau',
        () {
      final goc28 =
          nextBillDueDate(DateTime(2026, 2, 28), kBillCycleMonth, anchorDay: 28);
      final goc31 =
          nextBillDueDate(DateTime(2026, 2, 28), kBillCycleMonth, anchorDay: 31);
      expect(
        [goc28, goc31],
        [DateTime(2026, 3, 28), DateTime(2026, 3, 31)],
        reason: 'Đây là cả lý do ngày gốc tồn tại. Nhìn vào một mốc 28/02 đơn '
            'độc thì KHÔNG có cách nào biết nó từ 31/01 tới hay do người dùng '
            'tự chọn — bản trước phải đoán, và đoán sai một nửa số ca.',
      );
    });

    test('chuỗi ngày gốc 31 giữ được ngày cuối tháng qua nhiều kỳ', () {
      var d = DateTime(2026, 1, 31);
      final chuoi = <DateTime>[];
      for (var i = 0; i < 5; i++) {
        d = nextBillDueDate(d, kBillCycleMonth, anchorDay: 31);
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
        reason: 'Tiền nhà "ngày 31 hàng tháng" phải quay lại 31 sau tháng Hai. '
            'Không giữ ngày gốc thì chuỗi đứng im ở 28 kể từ kỳ thứ hai.',
      );
    });

    test('chuỗi ngày gốc 28 KHÔNG bị kéo lên cuối tháng', () {
      var d = DateTime(2026, 2, 28);
      final chuoi = <DateTime>[];
      for (var i = 0; i < 4; i++) {
        d = nextBillDueDate(d, kBillCycleMonth, anchorDay: 28);
        chuoi.add(d);
      }
      expect(
        chuoi,
        [
          DateTime(2026, 3, 28),
          DateTime(2026, 4, 28),
          DateTime(2026, 5, 28),
          DateTime(2026, 6, 28),
        ],
        reason: 'Đối xứng với ca trên: giữ ngày gốc 28 thì mọi kỳ đều là 28. '
            'Bản trước cho ra 31/03, 30/04, 31/05 — trôi theo độ dài tháng.',
      );
    });

    test('ngày gốc 31 kẹp đúng 29 ở tháng Hai năm nhuận', () {
      expect(
        nextBillDueDate(DateTime(2028, 1, 31), kBillCycleMonth, anchorDay: 31),
        DateTime(2028, 2, 29),
        reason: 'Kẹp phải theo số ngày thật của tháng đích, không phải hằng '
            'số 28.',
      );
    });

    test('ngày gốc lớn hơn mọi tháng vẫn kẹp, không tràn sang tháng sau', () {
      expect(
        nextBillDueDate(DateTime(2026, 4, 30), kBillCycleMonth, anchorDay: 31),
        DateTime(2026, 5, 31),
        reason: 'DateTime(y, m, 31) tràn im lặng sang tháng sau khi tháng đó '
            'ngắn hơn — đúng lớp lỗi mà cả file này canh.',
      );
    });

    test('chu kỳ quý và năm cũng theo ngày gốc', () {
      expect(
        nextBillDueDate(DateTime(2026, 2, 28), kBillCycleQuarter, anchorDay: 31),
        DateTime(2026, 5, 31),
        reason: 'Ngày gốc áp cho mọi chu kỳ tính theo tháng, không riêng tháng.',
      );
      expect(
        nextBillDueDate(DateTime(2026, 2, 28), kBillCycleQuarter),
        DateTime(2026, 5, 28),
        reason: 'Không có ngày gốc thì giữ nguyên số ngày của mốc hiện tại.',
      );
    });

    test('ngày gốc KHÔNG áp cho chu kỳ tuần', () {
      expect(
        nextBillDueDate(DateTime(2026, 1, 31), kBillCycleWeek, anchorDay: 31),
        DateTime(2026, 2, 7),
        reason: 'Tuần không có khái niệm ngày trong tháng; cộng đúng 7 ngày.',
      );
    });

    test('giữ nguyên giờ và phút khi có ngày gốc', () {
      expect(
        nextBillDueDate(DateTime(2026, 2, 28, 9, 30), kBillCycleMonth,
            anchorDay: 31),
        DateTime(2026, 3, 31, 9, 30),
        reason: 'Mốc đến hạn là một thời điểm, không phải một ngày.',
      );
    });
  });
}
