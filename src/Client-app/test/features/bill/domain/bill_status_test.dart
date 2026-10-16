/// Trạng thái hiển thị của một hoá đơn, và số liệu thẻ tổng đầu trang.
///
/// Vì sao cần: `bill_page.dart` tự tính cả hai ngay trong `build`, và tính
/// sai ở bốn chỗ cùng lúc — hoá đơn **đã quá hạn** bị gắn nhãn "SẮP ĐẾN HẠN",
/// hoá đơn thật sự sắp đến hạn thì không có nhãn riêng nào, thanh tiến độ là
/// hằng số `0.66`, và tổng tiền gộp cả những kỳ của tháng sau. Tách ra hàm
/// thuần để bốn quyết định ấy có một chỗ đúng duy nhất và kiểm được.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';

import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/domain/bill_status.dart';

BillEntity _bill({
  String id = 'b1',
  required DateTime dueDate,
  double amount = 100000,
  bool isPaid = false,
  String payStatus = 'Pending',
  String? timeNotification = '3',
}) =>
    BillEntity(
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
        reason: 'Dùng lại `billLeadDays` (`bill_nhac_truoc.dart`, cũng là mốc '
            'của dải nhắc) thay vì tự đặt một mốc thứ hai — hai mốc lệch nhau thì dải nhắc và nhãn trên '
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
      ], now);

      expect(s.chuaDong.map((b) => b.id), ['chua']);
      expect(
        s.daDong.map((b) => b.id),
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
      ], now);

      expect(s.chuaDong.map((b) => b.id), ['quahan', 'gan', 'xa'],
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
      ], now);

      expect(s.daDong.map((b) => b.id), ['moi', 'cu'],
          reason: 'Lịch sử đọc ngược: kỳ vừa trả xong là thứ người dùng tìm.');
    });

    test('đọc cả hai cột trạng thái khi chia nhóm', () {
      final s = splitBills([
        _bill(id: 'a', dueDate: DateTime(2026, 9, 20), payStatus: 'Payed'),
      ], now);

      expect(s.daDong.map((b) => b.id), ['a']);
      expect(s.chuaDong, isEmpty);
    });

    test('không đụng danh sách gốc', () {
      final goc = [
        _bill(id: 'b', dueDate: DateTime(2026, 9, 25)),
        _bill(id: 'a', dueDate: DateTime(2026, 9, 8)),
      ];

      splitBills(goc, now);

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

  group('kỳ bị bỏ qua', () {
    test('đọc ra skipped, KHÔNG phải overdue, kể cả khi đã trễ hạn', () {
      final s = billDisplayStatusOf(
        _bill(dueDate: DateTime(2026, 8, 1), payStatus: 'Skipped'),
        now,
      );

      expect(s, BillDisplayStatus.skipped,
          reason: 'Nhánh bỏ qua phải đứng TRƯỚC mọi phép so ngày. Đặt sau thì '
              'một kỳ người dùng đã chủ động bỏ lại hiện nhãn đỏ "QUÁ HẠN".');
    });

    test('không phải "đã thanh toán"', () {
      final s = billDisplayStatusOf(
        _bill(dueDate: DateTime(2026, 9, 20), payStatus: 'Skipped'),
        now,
      );

      expect(s, isNot(BillDisplayStatus.paid),
          reason: 'Không có khoản chi nào được ghi, nên trang chi tiết không '
              'được bày nút Hoàn tác thanh toán cho nó.');
    });

    test('nằm ở nhóm "đã đóng", không nằm ở nhóm "chưa đóng"', () {
      final s = splitBills([
        _bill(id: 'chua', dueDate: DateTime(2026, 9, 20)),
        _bill(id: 'boqua', dueDate: DateTime(2026, 9, 10), payStatus: 'Skipped'),
      ], now);

      expect(s.chuaDong.map((b) => b.id), ['chua'],
          reason: 'Kỳ bỏ qua không còn là việc phải làm; để nó ở tab thứ nhất '
              'là bắt người dùng nhìn lại một quyết định họ đã ra.');
      expect(s.daDong.map((b) => b.id), ['boqua'],
          reason: 'Tab thứ hai là LỊCH SỬ: mọi kỳ đã đóng sổ, dù bằng cách trả '
              'hay bằng cách bỏ qua.');
    });

    test('không vào CẢ HAI vế của thẻ tổng', () {
      final s = summarizeBills([
        _bill(id: 'no', dueDate: DateTime(2026, 9, 20), amount: 100000),
        _bill(
            id: 'boqua',
            dueDate: DateTime(2026, 9, 10),
            amount: 900000,
            payStatus: 'Skipped'),
      ], now);

      expect(s.unpaidAmount, 100000,
          reason: 'Kỳ bỏ qua không phải nợ — cộng vào là thẻ đầu trang báo một '
              'con số người dùng không nợ ai.');
      expect(s.unpaidCount, 1, reason: 'Cùng lý do, cho số đếm.');
      expect(s.paidAmount, 0,
          reason: 'Cũng KHÔNG phải tiền đã trả. Cộng vào paidAmount là thổi '
              'phồng thanh tiến độ bằng 900.000 đ chưa bao giờ chi ra — cùng '
              'loại lỗi với thanh hằng số 0,66 ngày trước, chỉ tinh vi hơn.');
      expect(s.progress, 0,
          reason: 'Chưa trả đồng nào thì tiến độ là 0, không phải 90%.');
    });
  });

  // Tab "Cần thanh toán (N)" từng đếm MỌI kỳ chưa đóng trong khi thẻ tổng chỉ
  // đếm kỳ này — mỗi lần trả một hoá đơn lặp, `payBill` sinh ngay kỳ tháng
  // sau, nên tab nói (4) khi thẻ nói "3 hóa đơn". Người dùng chốt 2026-10-16:
  // tab đếm theo kỳ này, kỳ các tháng sau nằm dưới tiêu đề nhóm riêng.
  group('thuocKyNay', () {
    test('23:59:59 ngày cuối tháng vẫn thuộc kỳ này', () {
      expect(thuocKyNay(_bill(dueDate: DateTime(2026, 9, 30, 23, 59, 59)), now),
          isTrue);
    });

    test('00:00 ngày 1 tháng sau KHÔNG thuộc kỳ này', () {
      expect(thuocKyNay(_bill(dueDate: DateTime(2026, 10, 1)), now), isFalse,
          reason: 'Biên MỞ ở đầu tháng sau — cùng mốc `summarizeBills` đã dùng.');
    });

    test('nợ quá hạn từ tháng trước vẫn thuộc kỳ này', () {
      expect(thuocKyNay(_bill(dueDate: DateTime(2026, 7, 15)), now), isTrue,
          reason: 'Cắt nợ cũ khỏi kỳ này là giấu đúng khoản đáng lo nhất.');
    });

    test('tháng 12 sang tháng 1 năm sau', () {
      final thangMuoiHai = DateTime(2026, 12, 6);
      expect(thuocKyNay(_bill(dueDate: DateTime(2026, 12, 31)), thangMuoiHai),
          isTrue);
      expect(thuocKyNay(_bill(dueDate: DateTime(2027, 1, 1)), thangMuoiHai),
          isFalse);
    });
  });

  group('splitBills — kỳ các tháng sau', () {
    test('kỳ chưa trả của các tháng sau vào nhóm riêng, không vào chuaDong', () {
      final s = splitBills([
        _bill(id: 'thangnay', dueDate: DateTime(2026, 9, 20)),
        _bill(id: 'thang11', dueDate: DateTime(2026, 11, 2)),
        _bill(id: 'thang10', dueDate: DateTime(2026, 10, 4)),
        _bill(
            id: 'datra',
            dueDate: DateTime(2026, 9, 4),
            isPaid: true,
            payStatus: 'Payed'),
      ], now);

      expect(s.chuaDong.map((b) => b.id), ['thangnay'],
          reason: 'Số trên tab đếm chuaDong — kỳ tháng sau lọt vào là tab lại '
              'nói nhiều hơn thẻ tổng.');
      expect(s.chuaDongCacThangSau.map((b) => b.id), ['thang10', 'thang11'],
          reason: 'Kỳ các tháng sau vẫn phải hiện (người dùng trả trước được), '
              'xếp hạn gần nhất lên đầu như nhóm kỳ này.');
      expect(s.daDong.map((b) => b.id), ['datra']);
    });

    test('kỳ tháng sau đã trả trước hoặc đã bỏ qua vẫn vào Lịch sử', () {
      final s = splitBills([
        _bill(
            id: 'tratruoc',
            dueDate: DateTime(2026, 10, 4),
            isPaid: true,
            payStatus: 'Payed'),
        _bill(id: 'boqua', dueDate: DateTime(2026, 10, 9), payStatus: 'Skipped'),
      ], now);

      expect(s.chuaDongCacThangSau, isEmpty,
          reason: 'Nhóm các tháng sau chỉ chứa kỳ CÒN PHẢI TRẢ; kỳ đã đóng sổ '
              'thuộc Lịch sử bất kể hạn.');
      expect(s.daDong.map((b) => b.id), ['boqua', 'tratruoc']);
    });

    test('số trên tab LUÔN bằng số trên thẻ tổng', () {
      final hon = [
        _bill(id: 'quahan', dueDate: DateTime(2026, 7, 15), amount: 70000),
        _bill(id: 'nay1', dueDate: DateTime(2026, 9, 11), amount: 50000),
        _bill(
            id: 'cuoithang',
            dueDate: DateTime(2026, 9, 30, 23, 59),
            amount: 20000),
        _bill(id: 'dauthangsau', dueDate: DateTime(2026, 10, 1), amount: 9000),
        _bill(id: 'thang12', dueDate: DateTime(2026, 12, 31), amount: 40000),
        _bill(id: 'nam27', dueDate: DateTime(2027, 1, 2), amount: 90000),
        _bill(
            id: 'datra',
            dueDate: DateTime(2026, 9, 4),
            amount: 30000,
            isPaid: true,
            payStatus: 'Payed'),
        _bill(id: 'chiPayed', dueDate: DateTime(2026, 9, 25), payStatus: 'Payed'),
        _bill(id: 'boqua', dueDate: DateTime(2026, 9, 10), payStatus: 'Skipped'),
        _bill(id: 'nhuan', dueDate: DateTime(2028, 2, 29), amount: 11000),
      ];

      for (final moc in [
        now,
        DateTime(2026, 12, 6),
        DateTime(2027, 1, 1),
        DateTime(2028, 2, 6),
      ]) {
        final tab = splitBills(hon, moc).chuaDong;
        final the = summarizeBills(hon, moc);
        expect(tab.length, the.unpaidCount,
            reason: 'Mốc $moc: tab "Cần thanh toán (N)" và dòng "N hóa đơn chưa '
                'thanh toán" của thẻ tổng là CÙNG một câu hỏi — hai định nghĩa '
                'là hai con số khác nhau trên cùng một màn.');
        expect(tab.fold<double>(0, (t, b) => t + b.amount), the.unpaidAmount,
            reason: 'Mốc $moc: tổng tiền thẻ phải đúng bằng tổng các dòng tab.');
      }
    });
  });
}
