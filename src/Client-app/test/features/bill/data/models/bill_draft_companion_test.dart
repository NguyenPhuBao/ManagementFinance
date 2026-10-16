/// Hai hàm dựng `BillsCompanion` từ `BillDraft` — rời `domain/` về `data/models/` (spec Entity Hoá đơn 2026-10-14 mục
/// 4.2). Ca test chép từ `bill_draft_test.dart` và `bill_draft_auto_pay_test.dart`; kỳ vọng giữ nguyên.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/bill/data/models/bill_draft_companion.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
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

  group('companionTaoTu', () {
    test('mang theo ví và danh mục người dùng đã chọn', () {
      final c = companionTaoTu(draft(), id: 'b1', idaccount: 7, now: now);

      expect(c.walletId.value, 'wallet-1',
          reason: 'Form từng hỏi ví rồi vứt đi. bill.Idwallet là NOT NULL phía '
              'backend nên hoá đơn thiếu ví bị /sync/push từ chối ở MỌI chu kỳ, '
              'kẹt vòng lặp thử lại.');
      expect(c.categoryId.value, 'cat-dien',
          reason:
              'bill.Idcategory cũng NOT NULL — thiếu là chặn hẳn đường đẩy.');
    });

    test('ghi chu kỳ vào cả hai cách biểu diễn, khớp nhau', () {
      final c = companionTaoTu(draft(timeRecurrence: kBillCycleYear),
          id: 'b1', idaccount: 7, now: now);

      expect(c.isRecurrence.value, true,
          reason: 'Nhánh đẩy gửi cờ isRecurrence chứ không gửi chuỗi cũ. Chỉ '
              'ghi chuỗi cũ thì backend luôn thấy recurrence = false.');
      expect(c.timeRecurrence.value, kBillCycleYear);
      expect(c.recurrence.value, 'yearly',
          reason: 'Hai cột lệch nhau là hai hành vi trên cùng một hàng.');
    });

    test('hoá đơn không lặp ghi cờ tắt và chuỗi cũ "once"', () {
      final c = companionTaoTu(draft(isRecurring: false),
          id: 'b1', idaccount: 7, now: now);

      expect(c.isRecurrence.value, false);
      expect(c.recurrence.value, 'once');
    });

    test('lấy startDate người dùng chọn, không phải thời điểm tạo', () {
      final c = companionTaoTu(draft(startDate: DateTime(2026, 9, 5)),
          id: 'b1', idaccount: 7, now: now);
      expect(c.startDate.value, DateTime(2026, 9, 5),
          reason: 'Trước đây cột này bị đặt cứng bằng thời điểm bấm Lưu, nên ô '
              '"Ngày bắt đầu" trên form có nhập gì cũng vô nghĩa.');
    });

    test('đặt payStatus Pending khớp với isPaid false', () {
      final c = companionTaoTu(draft(), id: 'b1', idaccount: 7, now: now);
      expect(c.isPaid.value, false);
      expect(c.payStatus.value, 'Pending');
    });
  });

  group('companionSuaTu', () {
    test('không đụng tới trạng thái thanh toán', () {
      final c = companionSuaTu(draft(), id: 'b1', idaccount: 7, now: now);

      expect(c.isPaid.present, false,
          reason: 'Form sửa không hỏi gì về việc đã trả hay chưa, nên nó cũng '
              'không được phép ghi đè trạng thái đó.');
      expect(c.payStatus.present, false);
    });

    test('ghi startDate vì form nay có ô đó, nhưng không đụng cờ xoá', () {
      final c = companionSuaTu(draft(startDate: DateTime(2026, 9, 5)),
          id: 'b1', idaccount: 7, now: now);

      expect(c.startDate.value, DateTime(2026, 9, 5),
          reason: 'Ô "Ngày bắt đầu" nằm trên cả form Thêm lẫn form Sửa nên '
              'đường sửa phải ghi được nó.');
      expect(c.isDeleted.present, false);
      expect(c.deletedAt.present, false);
    });

    test('vẫn ghi ví, danh mục và chu kỳ để sửa được hàng cũ đang kẹt', () {
      final c = companionSuaTu(draft(walletId: 'wallet-9', categoryId: 'cat-9'),
          id: 'b1', idaccount: 7, now: now);

      expect(c.walletId.value, 'wallet-9',
          reason: 'Hoá đơn tạo bởi bản client cũ có walletId null và đang kẹt '
              'trong hàng đợi đẩy. Màn Sửa là đường duy nhất để vá chúng.');
      expect(c.categoryId.value, 'cat-9');
      expect(c.isRecurrence.value, true);
      expect(c.recurrence.value, 'monthly');
    });

    test('đánh dấu chờ đồng bộ', () {
      final c = companionSuaTu(draft(), id: 'b1', idaccount: 7, now: now);
      expect(c.syncStatus.value, 'pending');
      expect(c.updatedAt.value, now);
    });
  });

  group('timeNotification — số ngày nhắc trước hạn', () {
    test('đường TẠO ghi xuống đúng giá trị người dùng chọn', () {
      final c = companionTaoTu(draft(nhacTruoc: '7'),
          id: 'b1', idaccount: 7, now: now);
      expect(c.timeNotification.value, '7',
          reason: 'Cột này tồn tại ở CẢ HAI đầu CSDL nhưng form trước đây thu '
              'thập rồi vứt đi — công tắc và chip chọn ngày là trang trí thuần '
              'tuý, payload đẩy luôn gửi null.');
    });

    test('đường SỬA cũng ghi được', () {
      final c = companionSuaTu(draft(nhacTruoc: '1'),
          id: 'b1', idaccount: 7, now: now);
      expect(c.timeNotification.value, '1');
    });

    test('tắt nhắc nhở thì ghi null, không phải chuỗi rỗng', () {
      final c = companionTaoTu(draft(nhacTruoc: null),
          id: 'b1', idaccount: 7, now: now);
      expect(c.timeNotification.value, isNull,
          reason: 'Backend ràng buộc Time_notification IN (1,3,5,7) hoặc NULL. '
              'Chuỗi rỗng vi phạm ràng buộc đó và bị từ chối ở /sync/push.');
    });

    test('đường SỬA phải GHI null chứ không bỏ trống companion', () {
      final c = companionSuaTu(draft(nhacTruoc: null),
          id: 'b1', idaccount: 7, now: now);
      expect(c.timeNotification.present, true,
          reason: 'updateFields chỉ ghi những cột CÓ MẶT. Vắng mặt nghĩa là '
              '"giữ nguyên", nên tắt nhắc nhở sẽ không có tác dụng gì.');
      expect(c.timeNotification.value, isNull);
    });
  });
  group('periodEnd — NULL chỉ một nghĩa', () {
    test('ân hạn 0: vẫn GHI periodEnd bằng dueDate, không để trống', () {
      final c = companionTaoTu(draft(), id: 'b1', idaccount: 7, now: now);
      expect(c.periodEnd.present, isTrue,
          reason: 'NULL phải chỉ còn nghĩa "hàng cũ, chưa biết". Hàng mới để '
              'trống là nhánh kéo về (Value.absent khi server null) không phân '
              'biệt được "chưa đẩy" với "ân hạn 0".');
      expect(c.periodEnd.value, dueDate);
    });

    test('ân hạn 15: ghi đúng ngày kết thúc kỳ', () {
      final c = companionTaoTu(draft(periodEnd: DateTime(2026, 9, 20)),
          id: 'b1', idaccount: 7, now: now);
      expect(c.periodEnd.value, DateTime(2026, 9, 20));
      expect(c.dueDate.value, dueDate);
    });

    test('đường Sửa cũng ghi periodEnd', () {
      final c = companionSuaTu(draft(periodEnd: DateTime(2026, 9, 20)),
          id: 'b1', idaccount: 7, now: now);
      expect(c.periodEnd.present, isTrue,
          reason: 'updateFields chỉ ghi cột CÓ MẶT — vắng mặt là giữ nguyên, '
              'nên hạ ân hạn về 0 sẽ không có tác dụng gì.');
      expect(c.periodEnd.value, DateTime(2026, 9, 20));
    });
  });

  group('autoPayEnabled — cờ tự trả xuống cả hai companion', () {
    // Nguyên văn từ bill_draft_auto_pay_test.dart: `now` và `draft` riêng của
    // tệp ấy, che cái của `main`.
    final now = DateTime(2026, 9, 6, 8, 30);

    BillDraft draft({bool autoPay = false}) => BillDraft(
          name: 'Tiền điện',
          amount: 250000,
          startDate: DateTime(2026, 9, 5),
          dueDate: DateTime(2026, 10, 5),
          walletId: 'wallet-1',
          categoryId: 'cat-dien',
          isRecurring: true,
          timeRecurrence: kBillCycleMonth,
          note: '',
          autoPayEnabled: autoPay,
        );

    test('mặc định là TẮT', () {
      final c = companionTaoTu(
          BillDraft(
            name: 'Tiền điện',
            amount: 250000,
            startDate: DateTime(2026, 9, 5),
            dueDate: DateTime(2026, 10, 5),
            walletId: 'wallet-1',
            categoryId: 'cat-dien',
            isRecurring: true,
            timeRecurrence: kBillCycleMonth,
            note: '',
          ),
          id: 'b1',
          idaccount: 7,
          now: now);

      expect(c.autoPayEnabled.value, isFalse,
          reason:
              'Tự chuyển tiền là quyết định người dùng phải bật, không phải '
              'thứ app mặc định làm hộ.');
    });

    test('companion TẠO mang cờ đã bật', () {
      final c = companionTaoTu(draft(autoPay: true),
          id: 'b1', idaccount: 7, now: now);
      expect(c.autoPayEnabled.value, isTrue);
    });

    test('companion SỬA có mặt cờ, kể cả khi tắt', () {
      final c = companionSuaTu(draft(autoPay: false),
          id: 'b1', idaccount: 7, now: now);

      expect(c.autoPayEnabled.present, isTrue,
          reason: '`updateFields` chỉ ghi cột CÓ MẶT. Bỏ trống là tắt công tắc '
              'không có tác dụng và app tiếp tục trừ tiền.');
      expect(c.autoPayEnabled.value, isFalse);
    });
  });
}
