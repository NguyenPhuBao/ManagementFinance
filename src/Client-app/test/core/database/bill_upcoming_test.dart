/// `BillDao.getUpcoming` — nguồn dữ liệu cho nhắc hoá đơn.
///
/// Hàm này tồn tại từ lâu nhưng **chưa nơi nào gọi**, nên khiếm khuyết của nó
/// chưa gây hại: nó lọc `isPaid` mà **không** lọc `payStatus`.
///
/// `markPaid()` cẩn thận đặt cả hai cột, nhưng hàng **kéo về từ backend** thì
/// không: nhánh pull suy `isPaid` từ `payStatus`, và một hàng do Admin-web
/// hoặc bản client cũ ghi có thể mang `payStatus = 'Payed'` trong khi `isPaid`
/// vẫn là false. Khi đó hoá đơn đã trả vẫn lọt vào danh sách nhắc và người
/// dùng bị giục trả tiền lần thứ hai — không exception, không log.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  const accountId = 7;
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> seed({
    required String id,
    required DateTime dueDate,
    bool isPaid = false,
    String payStatus = 'Pending',
    bool deleted = false,
  }) async {
    await db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: accountId,
      name: 'Hoá đơn $id',
      amount: 100000,
      dueDate: dueDate,
      isPaid: Value(isPaid),
      payStatus: Value(payStatus),
      deletedAt: Value(deleted ? now : null),
      updatedAt: now,
    ));
  }

  Future<List<String>> sapDenHan({int days = 7}) async {
    final rows = await db.billDao.getUpcoming(accountId, days: days, now: now);
    return rows.map((b) => b.id).toList()..sort();
  }

  test('trả hoá đơn chưa thanh toán trong khoảng ngày', () async {
    await seed(id: 'trong', dueDate: DateTime(2026, 9, 18));
    await seed(id: 'ngoai', dueDate: DateTime(2026, 10, 30));

    expect(await sapDenHan(), ['trong']);
  });

  test('BỎ QUA hoá đơn có payStatus = Payed dù isPaid còn false', () async {
    await seed(
      id: 'da-tra-tu-backend',
      dueDate: DateTime(2026, 9, 18),
      isPaid: false,
      payStatus: 'Payed',
    );

    expect(await sapDenHan(), isEmpty,
        reason: 'Đây chính là hình dạng của hàng kéo về từ backend hoặc do bản '
            'client cũ ghi. Lọt qua là người dùng bị giục trả một hoá đơn đã '
            'thanh toán rồi.');
  });

  test('BỎ QUA hoá đơn có isPaid = true dù payStatus còn Pending', () async {
    await seed(
      id: 'da-tra-cuc-bo',
      dueDate: DateTime(2026, 9, 18),
      isPaid: true,
      payStatus: 'Pending',
    );

    expect(await sapDenHan(), isEmpty,
        reason: 'Phải lọc CẢ HAI chiều — hai cột này từng lệch nhau theo cả '
            'hai hướng trong lịch sử dự án.');
  });

  test('bỏ qua hoá đơn đã xoá mềm', () async {
    await seed(id: 'da-xoa', dueDate: DateTime(2026, 9, 18), deleted: true);
    expect(await sapDenHan(), isEmpty);
  });

  test('GỒM cả hoá đơn đã quá hạn', () async {
    await seed(id: 'qua-han', dueDate: DateTime(2026, 9, 1));

    expect(await sapDenHan(), ['qua-han'],
        reason: 'Quá hạn là thứ đáng báo nhất. Chặn dưới bằng thời điểm hiện '
            'tại sẽ loại đúng những hoá đơn cần nhắc gấp nhất.');
  });

  test('không trả hoá đơn của tài khoản khác', () async {
    await db.billDao.insert(BillsCompanion.insert(
      id: 'nguoi-khac',
      idaccount: 9,
      name: 'Hoá đơn người khác',
      amount: 100000,
      dueDate: DateTime(2026, 9, 18),
      updatedAt: now,
    ));

    expect(await sapDenHan(), isEmpty);
  });

  test('now tiêm được để test không phụ thuộc đồng hồ máy', () async {
    await seed(id: 'thang-sau', dueDate: DateTime(2026, 10, 20));

    final rows = await db.billDao
        .getUpcoming(accountId, days: 7, now: DateTime(2026, 10, 15));
    expect(rows.single.id, 'thang-sau');
  });

  group('markOverdue', () {
    Future<Bill> doc(String id) async =>
        (await db.billDao.getById(id))!;

    test('hoá đơn quá hạn chuyển sang Overdue và vào hàng đợi đẩy', () async {
      await seed(id: 'qua-han', dueDate: DateTime(2026, 9, 10));

      final doi = await db.billDao.markOverdue(accountId, now);

      expect(doi, 1);
      final b = await doc('qua-han');
      expect(b.payStatus, 'Overdue',
          reason: "Giá trị 'Overdue' tồn tại trong bộ giá trị của cột và được "
              'backend chấp nhận, nhưng chưa bao giờ được ghi ở client.');
      expect(b.syncStatus, 'pending');
    });

    test('CHẠY LẠI không ghi đè lần nữa', () async {
      await seed(id: 'qua-han', dueDate: DateTime(2026, 9, 10));
      await db.billDao.markOverdue(accountId, now);
      final lan1 = await doc('qua-han');

      final doi = await db.billDao.markOverdue(accountId, now);

      expect(doi, 0,
          reason: 'Quét chạy sau MỌI lần đồng bộ. Ghi lại mỗi lượt là bản ghi '
              'luôn ở trạng thái pending, đẩy lên rồi lại pending — một vòng '
              'lặp đẩy vô tận mà không có lỗi nào báo ra.');
      expect((await doc('qua-han')).updatedAt, lan1.updatedAt);
    });

    test('chưa tới hạn thì không đụng', () async {
      await seed(id: 'chua-toi', dueDate: DateTime(2026, 9, 20));
      expect(await db.billDao.markOverdue(accountId, now), 0);
      expect((await doc('chua-toi')).payStatus, 'Pending');
    });

    test('đến hạn ĐÚNG hôm nay chưa phải quá hạn', () async {
      await seed(id: 'hom-nay', dueDate: DateTime(2026, 9, 15, 23));
      expect(await db.billDao.markOverdue(accountId, now), 0,
          reason: 'Người dùng vẫn còn cả ngày để trả.');
    });

    test('đã thanh toán thì không đụng, theo cả hai cột', () async {
      await seed(
          id: 'da-tra', dueDate: DateTime(2026, 9, 10), isPaid: true);
      await seed(
          id: 'da-tra-2',
          dueDate: DateTime(2026, 9, 10),
          payStatus: 'Payed');

      expect(await db.billDao.markOverdue(accountId, now), 0);
      expect((await doc('da-tra-2')).payStatus, 'Payed');
    });

    test('không đụng hoá đơn của tài khoản khác', () async {
      await db.billDao.insert(BillsCompanion.insert(
        id: 'nguoi-khac',
        idaccount: 9,
        name: 'Hoá đơn người khác',
        amount: 100000,
        dueDate: DateTime(2026, 9, 10),
        updatedAt: now,
      ));

      expect(await db.billDao.markOverdue(accountId, now), 0);
      expect((await doc('nguoi-khac')).payStatus, 'Pending');
    });

    test('không đụng hoá đơn đã xoá mềm', () async {
      await seed(
          id: 'da-xoa', dueDate: DateTime(2026, 9, 10), deleted: true);
      expect(await db.billDao.markOverdue(accountId, now), 0);
    });
  });
}
