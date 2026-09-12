/// Ân hạn hoá đơn: số ngày giữa NGÀY KẾT THÚC KỲ và HẠN TRẢ.
///
/// Con số này không được lưu — nó suy từ hai cột, ở đúng một chỗ. Hai cột đi
/// qua đồng bộ như ngày (`@db.Date`), nên phép trừ phải tính theo NGÀY LỊCH,
/// không theo mili-giây: một hàng kéo về mang 00:00 UTC còn hàng ghi tại chỗ
/// mang 10:15 giờ máy, trừ thô ra 14,4 ngày rồi làm tròn tuỳ hứng.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_an_han.dart';

Bill _bill({DateTime? periodEnd, required DateTime dueDate}) => Bill(
      id: 'b',
      idaccount: 7,
      name: 'Tiền điện',
      amount: 1,
      startDate: DateTime(2026, 9, 1),
      periodEnd: periodEnd,
      dueDate: dueDate,
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: false,
      isRecurrence: true,
      timeRecurrence: 'Month',
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
  group('anHanCua', () {
    test('periodEnd NULL → 0 (hàng cũ: kết thúc kỳ trùng hạn trả)', () {
      expect(anHanCua(_bill(dueDate: DateTime(2026, 10, 1))), 0);
    });

    test('15 ngày', () {
      expect(
        anHanCua(_bill(
            periodEnd: DateTime(2026, 10, 1), dueDate: DateTime(2026, 10, 16))),
        15,
      );
    });

    test('tính theo ngày lịch, giờ trong ngày không làm lệch', () {
      expect(
        anHanCua(_bill(
            periodEnd: DateTime(2026, 10, 1, 23, 59),
            dueDate: DateTime(2026, 10, 16, 0, 5))),
        15,
        reason: 'Hàng kéo về từ server mang 00:00 UTC, hàng ghi tại chỗ mang '
            'giờ máy — trừ theo mili-giây rồi lấy inDays sẽ ra 14.',
      );
    });

    test('dữ liệu hỏng (periodEnd sau dueDate) → 0, không âm', () {
      expect(
        anHanCua(_bill(
            periodEnd: DateTime(2026, 10, 20), dueDate: DateTime(2026, 10, 1))),
        0,
      );
    });
  });

  group('hanTraTu', () {
    test('0 ngày trả về đúng mốc, giữ nguyên giờ phút', () {
      final k = DateTime(2026, 10, 1, 9, 30, 15);
      expect(hanTraTu(k, 0), k,
          reason: 'Ân hạn 0 phải cho kết quả Y HỆT trước v21 — kể cả giờ.');
    });

    test('qua cuối tháng và qua năm', () {
      expect(hanTraTu(DateTime(2026, 9, 20), 15), DateTime(2026, 10, 5));
      expect(hanTraTu(DateTime(2026, 12, 25), 10), DateTime(2027, 1, 4));
    });

    test('năm nhuận: 29/02 + 15', () {
      expect(hanTraTu(DateTime(2028, 2, 29), 15), DateTime(2028, 3, 15));
      expect(hanTraTu(DateTime(2027, 2, 28), 15), DateTime(2027, 3, 15));
    });
  });

  group('loiAnHan', () {
    final ketThuc = DateTime(2026, 10, 1);
    final keTiep = DateTime(2026, 11, 1);

    test('0 và 15 hợp lệ với chu kỳ tháng', () {
      expect(loiAnHan(anHanNgay: 0, ketThucKy: ketThuc, ketThucKyKeTiep: keTiep),
          isNull);
      expect(
          loiAnHan(anHanNgay: 15, ketThucKy: ketThuc, ketThucKyKeTiep: keTiep),
          isNull);
    });

    test('âm bị từ chối', () {
      expect(
          loiAnHan(anHanNgay: -1, ketThucKy: ketThuc, ketThucKyKeTiep: keTiep),
          'Số ngày ân hạn không được âm');
    });

    test('quá 365 bị từ chối', () {
      expect(
          loiAnHan(
              anHanNgay: 366,
              ketThucKy: ketThuc,
              ketThucKyKeTiep: DateTime(2028, 10, 1)),
          'Ân hạn tối đa 365 ngày');
    });

    test('hạn trả ĐÚNG BẰNG kết thúc kỳ kế tiếp cũng bị từ chối', () {
      expect(
        loiAnHan(anHanNgay: 31, ketThucKy: ketThuc, ketThucKyKeTiep: keTiep),
        'Hạn trả phải trước ngày kết thúc kỳ kế tiếp (01/11)',
        reason: 'Bằng nhau là hai kỳ cùng mở đúng một ngày: bộ tự trả và thẻ '
            'tổng đếm hai khoản.',
      );
    });

    test('chu kỳ tuần: 6 ngày được, 7 ngày không', () {
      final k = DateTime(2026, 9, 8);
      final kt = DateTime(2026, 9, 15);
      expect(loiAnHan(anHanNgay: 6, ketThucKy: k, ketThucKyKeTiep: kt), isNull);
      expect(loiAnHan(anHanNgay: 7, ketThucKy: k, ketThucKyKeTiep: kt),
          isNotNull);
    });
  });
}
