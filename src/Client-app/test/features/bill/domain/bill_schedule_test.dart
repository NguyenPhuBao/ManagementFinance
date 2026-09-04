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
          reason: 'Dùng chung nextBillDueDate nên quy tắc ngày cuối tháng áp ở '
              'đây luôn — không có phép tính ngày thứ hai trong dự án.');
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
}
