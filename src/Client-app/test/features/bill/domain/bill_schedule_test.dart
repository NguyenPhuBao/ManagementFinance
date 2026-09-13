import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_schedule.dart';

void main() {
  final batDau = DateTime(2026, 9, 1);

  BillSchedule lich({
    DateTime? start,
    String chuKy = kBillCycleMonth,
    bool repeat = true,
    DateTime? hanCu,
  }) {
    return BillSchedule(
      startDate: start ?? batDau,
      timeRecurrence: chuKy,
      repeat: repeat,
      hanCuKhongKhop: hanCu,
    );
  }


  // Không đặt tên gạch dưới đầu cho hàm cục bộ: lint
  // `no_leading_underscores_for_local_identifiers` sẽ đội số issue của analyze.
  Bill hoaDonMau({
    required DateTime start,
    required DateTime due,
    DateTime? periodEnd,
    int? anchorDay,
  }) =>
      Bill(
        id: 'b',
        idaccount: 7,
        name: 'Tiền điện',
        amount: 1,
        startDate: start,
        periodEnd: periodEnd,
        dueDate: due,
        anchorDay: anchorDay,
        payStatus: 'Pending',
        isPaid: false,
        autoPayEnabled: false,
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

  group('ngày đến hạn luôn do chu kỳ quyết định', () {
    test('hàng tháng: đến hạn là một tháng sau ngày bắt đầu', () {
      expect(lich().dueDate, DateTime(2026, 10, 1),
          reason: 'Hoá đơn không còn chế độ tự nhập hạn trả — chu kỳ quyết '
              'định, người dùng chỉ chọn ngày bắt đầu.');
    });

    test('tuần, quý, năm đều suy từ cùng một hàm chu kỳ', () {
      expect(lich(chuKy: kBillCycleWeek).dueDate, DateTime(2026, 9, 8));
      expect(lich(chuKy: kBillCycleQuarter).dueDate, DateTime(2026, 12, 1));
      expect(lich(chuKy: kBillCycleYear).dueDate, DateTime(2027, 9, 1));
    });

    test('ngày bắt đầu cuối tháng thì đến hạn cũng cuối tháng', () {
      expect(lich(start: DateTime(2026, 1, 31)).dueDate, DateTime(2026, 2, 28),
          reason: 'Dùng chung nextBillDueDate nên phép kẹp ngày áp ở đây luôn '
              '— không có phép tính ngày thứ hai trong dự án.');
    });

    test('ngày bắt đầu luôn nằm trước ngày đến hạn, mọi chu kỳ', () {
      for (final ck in const [
        kBillCycleWeek,
        kBillCycleMonth,
        kBillCycleQuarter,
        kBillCycleYear
      ]) {
        final s = lich(start: DateTime(2026, 1, 31), chuKy: ck);
        expect(s.startDate.isBefore(s.dueDate), true, reason: 'chu kỳ $ck');
        expect(s.dateError, isNull, reason: 'chu kỳ $ck');
      }
    });
  });

  group('công tắc lặp lại — trục độc lập với chu kỳ', () {
    test('bật = hoá đơn định kỳ', () {
      expect(lich(repeat: true).isRecurring, true);
    });

    test('tắt = chạy đúng một kỳ rồi thôi, hạn trả vẫn theo chu kỳ', () {
      final s = lich(repeat: false);
      expect(s.isRecurring, false);
      expect(s.dueDate, DateTime(2026, 10, 1),
          reason: 'Tắt lặp KHÔNG làm mất cách tính ngày đến hạn — đây vẫn là '
              'một kỳ dài đúng một tháng.');
    });
  });

  group('hạn trả cũ không khớp chu kỳ', () {
    test('không có hạn lệch thì không cảnh báo', () {
      expect(lich().canhBaoHanCu, isNull);
    });

    test('có hạn lệch thì cảnh báo nêu cả ngày cũ lẫn ngày mới', () {
      final s = lich(
        start: DateTime(2026, 9, 4),
        hanCu: DateTime(2026, 9, 11),
      );
      final canhBao = s.canhBaoHanCu;
      expect(canhBao, isNotNull);
      expect(canhBao, contains('11/09/2026'),
          reason: 'Không nhắc ngày cũ thì người dùng không biết mình sắp mất gì.');
      expect(canhBao, contains('04/10/2026'),
          reason: 'Và phải nói rõ lưu lại sẽ thành ngày nào.');
    });
  });

  group('fromBill — mở form Sửa', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Future<Bill> seed({
      required DateTime start,
      required DateTime due,
      required bool isRecurrence,
      String timeRecurrence = kBillCycleMonth,
    }) async {
      await db.billDao.insert(BillsCompanion.insert(
        id: 'b1',
        idaccount: 7,
        name: 'Hoá đơn',
        amount: 1000,
        startDate: Value(start),
        dueDate: due,
        isRecurrence: Value(isRecurrence),
        timeRecurrence: Value(timeRecurrence),
        updatedAt: DateTime.now(),
      ));
      return (await db.billDao.getAll(7)).single;
    }

    test('hoá đơn khớp chu kỳ mở ra bình thường, không cảnh báo', () async {
      final bill = await seed(
        start: DateTime(2026, 9, 1),
        due: DateTime(2026, 10, 1),
        isRecurrence: true,
      );
      final s = BillSchedule.fromBill(bill);
      expect(s.timeRecurrence, kBillCycleMonth);
      expect(s.repeat, true);
      expect(s.canhBaoHanCu, isNull);
    });

    test('hoá đơn KHÔNG khớp chu kỳ thì cảnh báo, không đổi ngầm', () async {
      // Hoá đơn do bản client cũ (hoặc Admin-web) tạo: cửa sổ trả 7 ngày
      // nhưng chu kỳ tháng.
      final bill = await seed(
        start: DateTime(2026, 9, 4),
        due: DateTime(2026, 9, 11),
        isRecurrence: true,
      );
      final s = BillSchedule.fromBill(bill);

      expect(s.dueDate, DateTime(2026, 10, 4),
          reason: 'Hạn trả nay luôn suy từ chu kỳ.');
      expect(s.canhBaoHanCu, isNotNull,
          reason: 'Đổi hạn trả của người dùng mà không nói gì đúng là lớp lỗi '
              'âm thầm mà dự án này dính nhiều lần. Phải báo ra.');
      expect(s.canhBaoHanCu, contains('11/09/2026'));
    });

    test('hoá đơn thiếu ngày bắt đầu thì lấy chính ngày đến hạn làm mốc',
        () async {
      final bill = await seed(
        start: DateTime(2026, 9, 4),
        due: DateTime(2026, 10, 4),
        isRecurrence: false,
      );
      final s = BillSchedule.fromBill(bill);
      expect(s.repeat, false);
      expect(s.startDate, DateTime(2026, 9, 4));
    });
  });

  group('ngày gốc trên form', () {
    test('bắt đầu 28/02 thì đến hạn 28/03, KHÔNG phải 31/03', () {
      expect(
        lich(start: DateTime(2026, 2, 28)).dueDate,
        DateTime(2026, 3, 28),
        reason: 'Đây là lỗi người dùng báo 2026-09-08: đăng ký lần đầu vào '
            'ngày cuối tháng 2 thì hạn bị đẩy tới cuối tháng sau. Ô hạn trên '
            'form là CHỈ ĐỌC nên họ không có cách nào sửa lại.',
      );
    });

    test('không phụ thuộc năm nhuận', () {
      expect(
        lich(start: DateTime(2026, 2, 28)).dueDate.day,
        lich(start: DateTime(2028, 2, 28)).dueDate.day,
        reason: 'Bản trước cho 28/02/2026 ra 31/03 nhưng 28/02/2028 ra 28/03, '
            'vì năm nhuận thì 28/02 không phải cuối tháng. Cùng một ngày người '
            'dùng chọn mà hai kết quả khác nhau là thứ không ai đoán được.',
      );
    });

    test('bắt đầu 31/01 vẫn kẹp về 28/02 ở kỳ đầu', () {
      expect(
        lich(start: DateTime(2026, 1, 31)).dueDate,
        DateTime(2026, 2, 28),
        reason: 'Tháng Hai không có ngày 31; kẹp là đúng. Ngày gốc 31 được giữ '
            'lại để kỳ SAU quay về 31 — việc đó do chuỗi lo, không phải form.',
      );
    });

    test('ngày gốc mặc định lấy theo ngày bắt đầu', () {
      expect(lich(start: DateTime(2026, 2, 28)).anchorDayHieuLuc, 28);
      expect(lich(start: DateTime(2026, 1, 31)).anchorDayHieuLuc, 31);
    });

    test('đổi ngày bắt đầu thì ngày gốc đi theo', () {
      final s = lich(start: DateTime(2026, 1, 31))
          .copyWith(startDate: DateTime(2026, 3, 15));
      expect(
        s.anchorDayHieuLuc,
        15,
        reason: 'Chọn một ngày bắt đầu khác là người dùng vừa nói lại ý định. '
            'Giữ ngày gốc cũ ở đây là hoá đơn vừa đổi sang ngày 15 vẫn đến hạn '
            'vào ngày 31.',
      );
      expect(s.dueDate, DateTime(2026, 4, 15));
    });
  });

  group('form SỬA không được đổi hạn của hoá đơn đang đúng', () {
    Bill hoaDon({
      required DateTime start,
      required DateTime han,
      int? goc,
    }) {
      return Bill(
        id: 'b1',
        idaccount: 1,
        name: 'Tiền nhà',
        amount: 1000,
        startDate: start,
        dueDate: han,
        payStatus: 'Pending',
        isPaid: false,
        isRecurrence: true,
        timeRecurrence: kBillCycleMonth,
        recurrence: 'monthly',
        anchorDay: goc,
        icon: 'receipt',
        colour: '#4CAF50',
        note: '',
        autoPayEnabled: false,
        isDeleted: false,
        syncStatus: 'synced',
        syncRetryCount: 0,
        updatedAt: DateTime(2026, 2, 28),
      );
    }

    test('kỳ giữa chuỗi ngày 31 mở ra không bị cảnh báo lệch hạn', () {
      // Kỳ thứ ba của chuỗi bắt đầu 31/01: bắt đầu 28/02, hạn 31/03, gốc 31.
      final s = BillSchedule.fromBill(
        hoaDon(start: DateTime(2026, 2, 28), han: DateTime(2026, 3, 31), goc: 31),
      );
      expect(
        s.dueDate,
        DateTime(2026, 3, 31),
        reason: 'Suy ngày gốc lại từ ngày bắt đầu (28) sẽ ra 28/03, tức mở '
            'form rồi lưu là HẠ hoá đơn này xuống ngày 28 — đúng lớp lỗi âm '
            'thầm mà canhBaoHanCu sinh ra để chặn.',
      );
      expect(s.canhBaoHanCu, isNull);
    });

    test('hoá đơn cũ chưa có ngày gốc thì neo vào ngày bắt đầu', () {
      final s = BillSchedule.fromBill(
        hoaDon(start: DateTime(2026, 2, 28), han: DateTime(2026, 3, 28)),
      );
      expect(
        s.dueDate,
        DateTime(2026, 3, 28),
        reason: 'Hàng kéo từ server không có cột cục bộ này. Neo vào ngày bắt '
            'đầu là lựa chọn an toàn nhất khi không biết ý định gốc.',
      );
      expect(s.canhBaoHanCu, isNull);
    });

    test('hạn thật sự lệch chu kỳ thì VẪN phải cảnh báo', () {
      final s = BillSchedule.fromBill(
        hoaDon(start: DateTime(2026, 2, 28), han: DateTime(2026, 3, 11), goc: 28),
      );
      expect(
        s.canhBaoHanCu,
        isNotNull,
        reason: 'Hoá đơn do Admin-web hoặc bản client cũ tạo có thể mang cửa '
            'sổ trả bất kỳ. Ngày gốc không được làm tắt lời cảnh báo ấy.',
      );
    });
  });
  group('ân hạn — hạn trả muộn hơn ngày kết thúc kỳ', () {
    test('mặc định 0: kết thúc kỳ TRÙNG hạn trả, y hệt trước v21', () {
      final s = lich();
      expect(s.anHanNgay, 0);
      expect(s.ketThucKy, DateTime(2026, 10, 1));
      expect(s.dueDate, DateTime(2026, 10, 1));
    });

    test('15 ngày: kết thúc 01/10, hạn 16/10', () {
      final s = lich().copyWith(anHanNgay: 15);
      expect(s.ketThucKy, DateTime(2026, 10, 1),
          reason: 'Ân hạn KHÔNG đổi kỳ tính tiền, chỉ đổi hạn trả.');
      expect(s.dueDate, DateTime(2026, 10, 16));
      expect(s.dateError, isNull);
    });

    test('gốc 31 qua tháng Hai: kết thúc 28/02, hạn 15/03', () {
      final s = lich(start: DateTime(2026, 1, 31)).copyWith(anHanNgay: 15);
      expect(s.ketThucKy, DateTime(2026, 2, 28));
      expect(s.dueDate, DateTime(2026, 3, 15));
    });

    test('đổi ân hạn KHÔNG đụng ngày gốc', () {
      final s = lich(start: DateTime(2026, 1, 31)).copyWith(anHanNgay: 7);
      expect(s.anchorDayHieuLuc, 31,
          reason: 'Ngày gốc chỉ đi theo ngày bắt đầu. Đổi số ngày ân hạn mà '
              'ngày gốc đổi theo là hoá đơn "ngày 31" tụt xuống 28.');
    });

    test('ân hạn chồng kỳ kế tiếp thì dateError báo, không im lặng', () {
      final s = lich().copyWith(anHanNgay: 31);
      expect(s.dateError, 'Hạn trả phải trước ngày kết thúc kỳ kế tiếp (01/11)');
    });

    test('chu kỳ tuần: 7 ngày ân hạn bị từ chối, 6 thì không', () {
      expect(lich(chuKy: kBillCycleWeek).copyWith(anHanNgay: 7).dateError,
          isNotNull);
      expect(lich(chuKy: kBillCycleWeek).copyWith(anHanNgay: 6).dateError,
          isNull);
    });

    test('fromBill: hàng cũ (periodEnd NULL) ra ân hạn 0, không cảnh báo', () {
      final b = hoaDonMau(start: DateTime(2026, 9, 1), due: DateTime(2026, 10, 1));
      final s = BillSchedule.fromBill(b);
      expect(s.anHanNgay, 0);
      expect(s.canhBaoHanCu, isNull,
          reason: 'Mở form Sửa rồi lưu KHÔNG được đổi hạn của hoá đơn cũ.');
    });

    test('fromBill: hàng có ân hạn 15 ra đúng 15, hạn khớp, không cảnh báo', () {
      final b = hoaDonMau(
          start: DateTime(2026, 9, 1),
          periodEnd: DateTime(2026, 10, 1),
          due: DateTime(2026, 10, 16));
      final s = BillSchedule.fromBill(b);
      expect(s.anHanNgay, 15);
      expect(s.dueDate, DateTime(2026, 10, 16));
      expect(s.canhBaoHanCu, isNull);
    });
  });
}
