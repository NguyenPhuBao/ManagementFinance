/// Trạng thái hiển thị của một hoá đơn, và số liệu thẻ tổng đầu trang.
///
/// Vì sao cần: `bill_page.dart` tự tính cả hai ngay trong `build`, và tính
/// sai ở bốn chỗ cùng lúc — hoá đơn **đã quá hạn** bị gắn nhãn "SẮP ĐẾN HẠN",
/// hoá đơn thật sự sắp đến hạn thì không có nhãn riêng nào, thanh tiến độ là
/// hằng số `0.66`, và tổng tiền gộp cả những kỳ của tháng sau. Tách ra hàm
/// thuần để bốn quyết định ấy có một chỗ đúng duy nhất và kiểm được.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_status.dart';

Bill _bill({
  String id = 'b1',
  required DateTime dueDate,
  double amount = 100000,
  bool isPaid = false,
  String payStatus = 'Pending',
  String? timeNotification = '3',
}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: amount,
      startDate: dueDate.subtract(const Duration(days: 30)),
      dueDate: dueDate,
      payStatus: payStatus,
      isPaid: isPaid,
      autoPayEnabled: false,
      timeNotification: timeNotification,
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
  final now = DateTime(2026, 9, 6, 10, 30);

  group('billDisplayStatusOf', () {
    test('quá hạn là "quá hạn", KHÔNG phải "sắp đến hạn"', () {
      final s = billDisplayStatusOf(_bill(dueDate: DateTime(2026, 9, 4)), now);

      expect(
        s,
        BillDisplayStatus.overdue,
        reason: 'Trang danh sách từng gắn nhãn "SẮP ĐẾN HẠN" cho đúng nhánh '
            'quá hạn — nói nhẹ đi một việc đã hỏng rồi, và vạch màu còn là '
            'màu xanh lá của khoản thu.',
      );
    });

    test('đến hạn đúng hôm nay thì CHƯA quá hạn — còn cả ngày để trả', () {
      final s =
          billDisplayStatusOf(_bill(dueDate: DateTime(2026, 9, 6, 8)), now);

      expect(s, BillDisplayStatus.dueSoon,
          reason: 'Cùng quy ước so theo NGÀY với `BillDao.markOverdue`.');
    });

    test('trong khoảng nhắc trước hạn thì "sắp đến hạn"', () {
      // Nhắc trước 3 ngày ⇒ hạn 08/09 nằm trong khoảng, hạn 10/09 thì không.
      expect(billDisplayStatusOf(_bill(dueDate: DateTime(2026, 9, 8)), now),
          BillDisplayStatus.dueSoon);
      expect(billDisplayStatusOf(_bill(dueDate: DateTime(2026, 9, 10)), now),
          BillDisplayStatus.pending);
    });

    test('số ngày nhắc riêng của hoá đơn thắng mặc định chung', () {
      final bayNgay = _bill(dueDate: DateTime(2026, 9, 10), timeNotification: '7');

      expect(
        billDisplayStatusOf(bayNgay, now),
        BillDisplayStatus.dueSoon,
        reason: 'Dùng lại `billLeadDays` của bộ luật thông báo thay vì tự đặt '
            'một mốc thứ hai — hai mốc lệch nhau thì dải nhắc và nhãn trên '
            'danh sách nói hai chuyện khác nhau về cùng một hoá đơn.',
      );
    });

    test('đã trả thì luôn là "đã trả", kể cả khi đã quá hạn', () {
      expect(
        billDisplayStatusOf(
            _bill(dueDate: DateTime(2026, 8, 1), isPaid: true, payStatus: 'Payed'),
            now),
        BillDisplayStatus.paid,
      );
    });

    test('đọc CẢ HAI cột trạng thái', () {
      // Hàng do bản client cũ ghi có thể mang `payStatus = 'Payed'` mà `isPaid`
      // còn false. `getUpcoming` đã lọc cả hai từ 04/09; danh sách thì chưa.
      expect(
        billDisplayStatusOf(
            _bill(dueDate: DateTime(2026, 9, 20), payStatus: 'Payed'), now),
        BillDisplayStatus.paid,
        reason: 'Chỉ đọc `isPaid` là bày nút "Thanh toán" cho hoá đơn đã trả, '
            'và cộng nó vào tổng tiền cần trả.',
      );
      expect(
        billDisplayStatusOf(
            _bill(dueDate: DateTime(2026, 9, 20), isPaid: true), now),
        BillDisplayStatus.paid,
      );
    });
  });

  group('splitBills', () {
    test('tách hai nhóm: còn phải trả và đã trả', () {
      final s = splitBills([
        _bill(id: 'chua', dueDate: DateTime(2026, 9, 20)),
        _bill(
            id: 'roi',
            dueDate: DateTime(2026, 9, 4),
            isPaid: true,
            payStatus: 'Payed'),
      ]);

      expect(s.unpaid.map((b) => b.id), ['chua']);
      expect(
        s.paid.map((b) => b.id),
        ['roi'],
        reason: 'Mỗi kỳ của hoá đơn lặp là MỘT hàng mới, nên danh sách phẳng '
            'lẫn cả lịch sử đã trả vào giữa những hoá đơn đang chờ. Hoá đơn '
            'tuần sinh 52 hàng mỗi năm.',
      );
    });

    test('nhóm còn phải trả xếp hạn gần nhất lên đầu', () {
      final s = splitBills([
        _bill(id: 'xa', dueDate: DateTime(2026, 9, 25)),
        _bill(id: 'quahan', dueDate: DateTime(2026, 8, 30)),
        _bill(id: 'gan', dueDate: DateTime(2026, 9, 8)),
      ]);

      expect(s.unpaid.map((b) => b.id), ['quahan', 'gan', 'xa'],
          reason: 'Quá hạn là thứ gấp nhất, phải nằm trên cùng.');
    });

    test('nhóm đã trả xếp kỳ mới nhất lên đầu', () {
      final s = splitBills([
        _bill(
            id: 'cu',
            dueDate: DateTime(2026, 7, 4),
            isPaid: true,
            payStatus: 'Payed'),
        _bill(
            id: 'moi',
            dueDate: DateTime(2026, 9, 4),
            isPaid: true,
            payStatus: 'Payed'),
      ]);

      expect(s.paid.map((b) => b.id), ['moi', 'cu'],
          reason: 'Lịch sử đọc ngược: kỳ vừa trả xong là thứ người dùng tìm.');
    });

    test('đọc cả hai cột trạng thái khi chia nhóm', () {
      final s = splitBills([
        _bill(id: 'a', dueDate: DateTime(2026, 9, 20), payStatus: 'Payed'),
      ]);

      expect(s.paid.map((b) => b.id), ['a']);
      expect(s.unpaid, isEmpty);
    });

    test('không đụng danh sách gốc', () {
      final goc = [
        _bill(id: 'b', dueDate: DateTime(2026, 9, 25)),
        _bill(id: 'a', dueDate: DateTime(2026, 9, 8)),
      ];

      splitBills(goc);

      expect(goc.map((b) => b.id), ['b', 'a'],
          reason: 'Sắp xếp tại chỗ danh sách của bloc là đổi thứ tự dưới chân '
              'mọi nơi khác đang đọc nó.');
    });
  });

  group('summarizeBills', () {
    test('chỉ tính tới hết tháng này, không gộp kỳ của tháng sau', () {
      final s = summarizeBills([
        _bill(id: 'a', dueDate: DateTime(2026, 9, 11), amount: 50000),
        _bill(id: 'b', dueDate: DateTime(2026, 9, 23), amount: 10000),
        _bill(id: 'c', dueDate: DateTime(2026, 10, 4), amount: 123000),
      ], now);

      expect(
        s.unpaidAmount,
        60000,
        reason: 'Thẻ nói "Tổng tiền cần thanh toán" nên phải là số phải trả '
            'trong kỳ này. Gộp cả kỳ tháng sau làm con số to lên vô cớ — trên '
            'máy thật nó hiện 183.000 đ trong khi tháng này chỉ nợ 60.000 đ.',
      );
      expect(s.unpaidCount, 2);
    });

    test('hoá đơn quá hạn từ tháng trước vẫn được tính', () {
      final s = summarizeBills([
        _bill(id: 'a', dueDate: DateTime(2026, 8, 20), amount: 70000),
      ], now);

      expect(s.unpaidAmount, 70000,
          reason: 'Nợ cũ chưa trả vẫn là tiền phải trả, không được rơi ra '
              'khỏi thẻ chỉ vì thuộc tháng trước.');
    });

    test('tiến độ là tỉ lệ tiền ĐÃ trả trong kỳ, không phải hằng số', () {
      final s = summarizeBills([
        _bill(
            id: 'a',
            dueDate: DateTime(2026, 9, 4),
            amount: 30000,
            isPaid: true,
            payStatus: 'Payed'),
        _bill(id: 'b', dueDate: DateTime(2026, 9, 20), amount: 70000),
      ], now);

      expect(
        s.progress,
        closeTo(0.3, 0.0001),
        reason: 'Thanh tiến độ từng là `0.66` cứng, chỉ có hai trạng thái 66% '
            'hoặc 0%. Một thanh không đo gì thì tệ hơn không có thanh.',
      );
      expect(s.paidAmount, 30000);
    });

    test('chưa có hoá đơn nào trong kỳ thì tiến độ bằng 0, không chia 0', () {
      final s = summarizeBills(const [], now);

      expect(s.progress, 0);
      expect(s.unpaidAmount, 0);
      expect(s.unpaidCount, 0);
    });

    test('trả hết thì tiến độ đầy', () {
      final s = summarizeBills([
        _bill(
            id: 'a',
            dueDate: DateTime(2026, 9, 4),
            amount: 30000,
            isPaid: true,
            payStatus: 'Payed'),
      ], now);

      expect(s.progress, 1.0);
    });

    test('tháng 12 không tràn sang năm sau', () {
      final thangMuoiHai = DateTime(2026, 12, 6);
      final s = summarizeBills([
        _bill(id: 'a', dueDate: DateTime(2026, 12, 31), amount: 40000),
        _bill(id: 'b', dueDate: DateTime(2027, 1, 2), amount: 90000),
      ], thangMuoiHai);

      expect(s.unpaidAmount, 40000,
          reason: 'Mốc cuối kỳ tính bằng `DateTime(y, m + 1, 1)`, tháng 12 '
              'phải sang tháng 1 năm sau chứ không phải tháng 13 cùng năm.');
    });

    test('tháng Hai năm nhuận: hạn 29/02 vẫn thuộc kỳ này', () {
      final s = summarizeBills([
        _bill(id: 'a', dueDate: DateTime(2028, 2, 29), amount: 40000),
      ], DateTime(2028, 2, 6));

      expect(s.unpaidAmount, 40000);
    });
  });
}
