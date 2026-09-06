/// `BillDraft` mang cờ tự động thanh toán xuống CẢ HAI companion.
///
/// Vì sao cần: form từng có công tắc "Tự động tạo giao dịch" bật sẵn mà không
/// lưu ở đâu (gỡ ngày 06/09). Nay có cột thật, và lỗi dễ nhất là quên ghi nó
/// ở đường SỬA — `BillDao.updateFields` chỉ ghi cột có mặt, nên vắng mặt là
/// "giữ nguyên" và người dùng tắt công tắc mà app vẫn tiếp tục trừ tiền.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/features/bill/domain/bill_draft.dart';

void main() {
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
    final c = BillDraft(
      name: 'Tiền điện',
      amount: 250000,
      startDate: DateTime(2026, 9, 5),
      dueDate: DateTime(2026, 10, 5),
      walletId: 'wallet-1',
      categoryId: 'cat-dien',
      isRecurring: true,
      timeRecurrence: kBillCycleMonth,
      note: '',
    ).toInsertCompanion(id: 'b1', idaccount: 7, now: now);

    expect(c.autoPayEnabled.value, isFalse,
        reason: 'Tự chuyển tiền là quyết định người dùng phải bật, không phải '
            'thứ app mặc định làm hộ.');
  });

  test('companion TẠO mang cờ đã bật', () {
    final c = draft(autoPay: true)
        .toInsertCompanion(id: 'b1', idaccount: 7, now: now);
    expect(c.autoPayEnabled.value, isTrue);
  });

  test('companion SỬA có mặt cờ, kể cả khi tắt', () {
    final c = draft(autoPay: false)
        .toUpdateCompanion(id: 'b1', idaccount: 7, now: now);

    expect(c.autoPayEnabled.present, isTrue,
        reason: '`updateFields` chỉ ghi cột CÓ MẶT. Bỏ trống là tắt công tắc '
            'không có tác dụng và app tiếp tục trừ tiền.');
    expect(c.autoPayEnabled.value, isFalse);
  });
}
