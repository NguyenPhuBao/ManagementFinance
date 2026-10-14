import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/domain/bill_draft.dart';

void main() {
  final dueDate = DateTime(2026, 10, 5);

  BillDraft draft({
    bool isRecurring = true,
    String timeRecurrence = kBillCycleMonth,
    String walletId = 'wallet-1',
    String categoryId = 'cat-dien',
    DateTime? startDate,
    DateTime? due,
    String? nhacTruoc = '3',
    DateTime? periodEnd,
  }) {
    return BillDraft(
      name: 'Tiền điện',
      amount: 250000,
      timeNotification: nhacTruoc,
      startDate: startDate ?? DateTime(2026, 9, 5),
      dueDate: due ?? dueDate,
      periodEnd: periodEnd,
      walletId: walletId,
      categoryId: categoryId,
      isRecurring: isRecurring,
      timeRecurrence: timeRecurrence,
      note: 'Ghi chú',
    );
  }

  group('dateError — bất biến ngày bắt đầu trước ngày đến hạn', () {
    test('ngày bắt đầu sau ngày đến hạn thì báo lỗi', () {
      final d = draft(
        startDate: DateTime(2026, 10, 6),
        due: DateTime(2026, 10, 5),
      );
      expect(d.dateError, isNotNull,
          reason: 'Kỳ hoá đơn chạy từ ngày bắt đầu tới ngày đến hạn; đảo '
              'ngược là một kỳ có độ dài âm.');
    });

    test('trùng ngày cũng không hợp lệ', () {
      final d = draft(
        startDate: DateTime(2026, 10, 5),
        due: DateTime(2026, 10, 5),
      );
      expect(d.dateError, isNotNull,
          reason: 'Kỳ dài 0 ngày không có nghĩa, và kỳ sau sẽ bắt đầu đúng '
              'chỗ kỳ này bắt đầu — chuỗi giậm chân tại chỗ.');
    });

    test('bắt đầu trước đến hạn thì không lỗi', () {
      final d = draft(
        startDate: DateTime(2026, 9, 5),
        due: DateTime(2026, 10, 5),
      );
      expect(d.dateError, isNull);
    });
  });
}
