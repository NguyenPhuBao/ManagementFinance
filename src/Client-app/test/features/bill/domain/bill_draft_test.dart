import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/features/bill/domain/bill_draft.dart';

void main() {
  final now = DateTime(2026, 9, 4, 8, 30);
  final dueDate = DateTime(2026, 10, 5);

  BillDraft draft({
    bool isRecurring = true,
    String timeRecurrence = kBillCycleMonth,
    String walletId = 'wallet-1',
    String categoryId = 'cat-dien',
    DateTime? startDate,
    DateTime? due,
  }) {
    return BillDraft(
      name: 'Tiền điện',
      amount: 250000,
      startDate: startDate ?? DateTime(2026, 9, 5),
      dueDate: due ?? dueDate,
      walletId: walletId,
      categoryId: categoryId,
      isRecurring: isRecurring,
      timeRecurrence: timeRecurrence,
      note: 'Ghi chú',
    );
  }

  group('toInsertCompanion', () {
    test('mang theo ví và danh mục người dùng đã chọn', () {
      final c = draft().toInsertCompanion(id: 'b1', idaccount: 7, now: now);

      expect(c.walletId.value, 'wallet-1',
          reason: 'Form từng hỏi ví rồi vứt đi. bill.Idwallet là NOT NULL phía '
              'backend nên hoá đơn thiếu ví bị /sync/push từ chối ở MỌI chu kỳ, '
              'kẹt vòng lặp thử lại.');
      expect(c.categoryId.value, 'cat-dien',
          reason: 'bill.Idcategory cũng NOT NULL — thiếu là chặn hẳn đường đẩy.');
    });

    test('ghi chu kỳ vào cả hai cách biểu diễn, khớp nhau', () {
      final c = draft(timeRecurrence: kBillCycleYear)
          .toInsertCompanion(id: 'b1', idaccount: 7, now: now);

      expect(c.isRecurrence.value, true,
          reason: 'Nhánh đẩy gửi cờ isRecurrence chứ không gửi chuỗi cũ. Chỉ '
              'ghi chuỗi cũ thì backend luôn thấy recurrence = false.');
      expect(c.timeRecurrence.value, kBillCycleYear);
      expect(c.recurrence.value, 'yearly',
          reason: 'Hai cột lệch nhau là hai hành vi trên cùng một hàng.');
    });

    test('hoá đơn không lặp ghi cờ tắt và chuỗi cũ "once"', () {
      final c =
          draft(isRecurring: false).toInsertCompanion(id: 'b1', idaccount: 7, now: now);

      expect(c.isRecurrence.value, false);
      expect(c.recurrence.value, 'once');
    });

    test('lấy startDate người dùng chọn, không phải thời điểm tạo', () {
      final c = draft(startDate: DateTime(2026, 9, 5))
          .toInsertCompanion(id: 'b1', idaccount: 7, now: now);
      expect(c.startDate.value, DateTime(2026, 9, 5),
          reason: 'Trước đây cột này bị đặt cứng bằng thời điểm bấm Lưu, nên ô '
              '"Ngày bắt đầu" trên form có nhập gì cũng vô nghĩa.');
    });

    test('đặt payStatus Pending khớp với isPaid false', () {
      final c = draft().toInsertCompanion(id: 'b1', idaccount: 7, now: now);
      expect(c.isPaid.value, false);
      expect(c.payStatus.value, 'Pending');
    });
  });

  group('toUpdateCompanion', () {
    test('không đụng tới trạng thái thanh toán', () {
      final c = draft().toUpdateCompanion(id: 'b1', idaccount: 7, now: now);

      expect(c.isPaid.present, false,
          reason: 'Form sửa không hỏi gì về việc đã trả hay chưa, nên nó cũng '
              'không được phép ghi đè trạng thái đó.');
      expect(c.payStatus.present, false);
    });

    test('ghi startDate vì form nay có ô đó, nhưng không đụng cờ xoá', () {
      final c = draft(startDate: DateTime(2026, 9, 5))
          .toUpdateCompanion(id: 'b1', idaccount: 7, now: now);

      expect(c.startDate.value, DateTime(2026, 9, 5),
          reason: 'Ô "Ngày bắt đầu" nằm trên cả form Thêm lẫn form Sửa nên '
              'đường sửa phải ghi được nó.');
      expect(c.isDeleted.present, false);
      expect(c.deletedAt.present, false);
    });

    test('vẫn ghi ví, danh mục và chu kỳ để sửa được hàng cũ đang kẹt', () {
      final c = draft(walletId: 'wallet-9', categoryId: 'cat-9')
          .toUpdateCompanion(id: 'b1', idaccount: 7, now: now);

      expect(c.walletId.value, 'wallet-9',
          reason: 'Hoá đơn tạo bởi bản client cũ có walletId null và đang kẹt '
              'trong hàng đợi đẩy. Màn Sửa là đường duy nhất để vá chúng.');
      expect(c.categoryId.value, 'cat-9');
      expect(c.isRecurrence.value, true);
      expect(c.recurrence.value, 'monthly');
    });

    test('đánh dấu chờ đồng bộ', () {
      final c = draft().toUpdateCompanion(id: 'b1', idaccount: 7, now: now);
      expect(c.syncStatus.value, 'pending');
      expect(c.updatedAt.value, now);
    });
  });

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
