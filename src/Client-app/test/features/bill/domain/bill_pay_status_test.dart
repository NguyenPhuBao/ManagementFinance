/// Bốn giá trị của `bills.payStatus`, và ba câu hỏi rút ra từ chúng.
///
/// Vì sao tách ra: trước 2026-09-12 câu "đã trả chưa" được chép tay ở **10**
/// chỗ thuộc 7 tệp (đếm bằng script). Ba trong số đó tình cờ đúng với giá trị
/// `'Skipped'` mới — do may, không do thiết kế. Một biểu thức chép mười lần
/// rồi trông vào may mắn là đúng loại hỏng im lặng mà quy tắc 4 của
/// `CLAUDE.md` nói tới.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_pay_status.dart';

Bill _bill({String payStatus = kBillPending, bool isPaid = false}) => Bill(
      id: 'b1',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: 100000,
      startDate: DateTime(2026, 8, 20),
      dueDate: DateTime(2026, 9, 20),
      payStatus: payStatus,
      isPaid: isPaid,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
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
  group('bốn giá trị hợp lệ', () {
    test('Pending là nợ, chưa có khoản chi, chưa bỏ qua', () {
      final b = _bill(payStatus: kBillPending);

      expect(conPhaiTra(b), isTrue,
          reason: 'Kỳ chờ trả vẫn là tiền phải trả.');
      expect(daCoKhoanChi(b), isFalse,
          reason: 'Chưa trả thì chưa có khoản chi.');
      expect(daBoQua(b), isFalse, reason: 'Chờ trả khác với bị bỏ qua.');
    });

    test('Overdue vẫn là nợ', () {
      final b = _bill(payStatus: kBillOverdue);

      expect(conPhaiTra(b), isTrue,
          reason: 'Quá hạn là khoản nợ đáng lo nhất, không được rơi khỏi tổng '
              'tiền cần thanh toán ở thẻ đầu trang.');
    });

    test('Payed hết nợ và có khoản chi', () {
      final b = _bill(payStatus: kBillPayed, isPaid: true);

      expect(conPhaiTra(b), isFalse, reason: 'Đã trả thì không còn nợ.');
      expect(daCoKhoanChi(b), isTrue,
          reason: 'Lần trả sinh ra một khoản chi để hoàn tác lần được về.');
    });

    test('Skipped hết nợ nhưng KHÔNG có khoản chi', () {
      final b = _bill(payStatus: kBillSkipped);

      expect(conPhaiTra(b), isFalse,
          reason: 'Người dùng đã chủ động bỏ kỳ này — nhắc nữa là giục trả một '
              'khoản họ vừa nói là không phải trả.');
      expect(daCoKhoanChi(b), isFalse,
          reason: 'Bỏ qua không trừ ví và không ghi giao dịch nào. Đi tìm '
              'transaction.billId cho nó là tìm một thứ không tồn tại.');
      expect(daBoQua(b), isTrue, reason: 'Đây chính là kỳ bị bỏ qua.');
    });
  });

  group('hàng lệch hai cột', () {
    test("payStatus 'Payed' mà isPaid còn false vẫn là đã trả", () {
      final b = _bill(payStatus: kBillPayed, isPaid: false);

      expect(daCoKhoanChi(b), isTrue,
          reason: 'Hàng kéo về từ backend chỉ mang pay_status; isPaid là cột '
              'cục bộ nên có thể còn false. Đọc một cột là giục trả lại một '
              'hoá đơn đã thanh toán.');
      expect(conPhaiTra(b), isFalse,
          reason: 'Và vì thế nó cũng không còn là nợ.');
    });

    test('isPaid true mà payStatus còn Pending vẫn là đã trả', () {
      final b = _bill(payStatus: kBillPending, isPaid: true);

      expect(daCoKhoanChi(b), isTrue,
          reason: 'Hàng do bản client cũ ghi chỉ đặt isPaid.');
    });
  });

  test('giá trị lạ đọc là CÒN PHẢI TRẢ', () {
    final b = _bill(payStatus: 'Cancelled');

    expect(conPhaiTra(b), isTrue,
        reason: 'Giá trị backend thêm về sau mà client chưa biết thì thà giục '
            'trả nhầm còn hơn im lặng giấu mất một khoản nợ thật.');
    expect(daBoQua(b), isFalse,
        reason: 'Chỉ đúng chuỗi Skipped mới là bỏ qua — đoán rộng ra là bịa.');
  });
}
