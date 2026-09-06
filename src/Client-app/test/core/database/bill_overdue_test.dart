/// Cờ quá hạn của hoá đơn phải đi được **cả hai chiều**.
///
/// Vì sao cần: `markOverdue` chỉ có một chiều `Pending → Overdue`. Không có gì
/// đưa ngược lại, trong khi form Sửa đổi được ngày bắt đầu và ngày đến hạn
/// tính lại theo chu kỳ — đẩy hạn ra tương lai thì cờ `'Overdue'` ở lại vĩnh
/// viễn. `toUpdateCompanion` cố ý không đụng `payStatus` (form không hỏi gì về
/// nó), nên đường sửa không tự chữa được.
///
/// Client không lộ ra vì danh sách tự tính lại từ `dueDate`, nhưng cột này
/// **có đi đồng bộ**, nên Admin-web và mọi báo cáo đọc `pay_status` đều thấy
/// sai. Đo trên dữ liệu thật ngày 2026-09-06: hai hoá đơn của tài khoản 10
/// mang `'Overdue'` với hạn 11/09 và 04/10 — cả hai đều ở tương lai.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime(2026, 9, 6, 10);

  Future<void> themHoaDon({
    required String id,
    required DateTime dueDate,
    String payStatus = 'Pending',
    bool isPaid = false,
    int idaccount = 10,
  }) async {
    await db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: idaccount,
      walletId: const Value('w1'),
      categoryId: const Value('c1'),
      name: 'Tiền điện',
      amount: 100000,
      startDate: Value(dueDate.subtract(const Duration(days: 30))),
      dueDate: dueDate,
      payStatus: Value(payStatus),
      isPaid: Value(isPaid),
      isRecurrence: const Value(true),
      timeRecurrence: const Value(kBillCycleMonth),
      recurrence: const Value('monthly'),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2026, 9, 1),
    ));
  }

  Future<String> trangThai(String id) async =>
      (await db.billDao.getById(id))!.payStatus;

  test('hoá đơn quá hạn chuyển sang Overdue', () async {
    await themHoaDon(id: 'a', dueDate: DateTime(2026, 9, 4));

    await db.billDao.markOverdue(10, now);

    expect(await trangThai('a'), 'Overdue');
  });

  test('đến hạn đúng hôm nay thì CHƯA quá hạn', () async {
    await themHoaDon(id: 'a', dueDate: DateTime(2026, 9, 6, 23));

    await db.billDao.markOverdue(10, now);

    expect(await trangThai('a'), 'Pending',
        reason: 'Người dùng vẫn còn cả ngày để trả.');
  });

  test('cờ Overdue được GỠ khi hạn đã dời sang tương lai', () async {
    await themHoaDon(id: 'a', dueDate: DateTime(2026, 10, 4), payStatus: 'Overdue');

    await db.billDao.markOverdue(10, now);

    expect(
      await trangThai('a'),
      'Pending',
      reason: 'Sửa hoá đơn đẩy hạn ra tương lai thì cờ cũ phải rơi ra. Không '
          'có chiều này thì cột đồng bộ lên server sai vĩnh viễn, và app '
          'không có đường nào chữa.',
    );
  });

  test('gỡ cờ Overdue cũng đánh dấu pending để đẩy lên server', () async {
    await themHoaDon(id: 'a', dueDate: DateTime(2026, 10, 4), payStatus: 'Overdue');

    await db.billDao.markOverdue(10, now);

    expect((await db.billDao.getById('a'))!.syncStatus, 'pending',
        reason: 'Sửa dữ liệu mà không đẩy đi thì server vẫn giữ giá trị sai.');
  });

  test('hoá đơn ĐÃ TRẢ không bị lôi về Pending', () async {
    await themHoaDon(
        id: 'a',
        dueDate: DateTime(2026, 10, 4),
        payStatus: 'Payed',
        isPaid: true);

    await db.billDao.markOverdue(10, now);

    expect(await trangThai('a'), 'Payed',
        reason: 'Nhánh gỡ cờ chỉ được đụng đúng những hàng mang "Overdue".');
  });

  test('chạy hai lần liên tiếp: lần hai không đổi gì nữa', () async {
    await themHoaDon(id: 'a', dueDate: DateTime(2026, 9, 4));
    await themHoaDon(id: 'b', dueDate: DateTime(2026, 10, 4), payStatus: 'Overdue');

    await db.billDao.markOverdue(10, now);
    final lanHai = await db.billDao.markOverdue(10, now);

    expect(
      lanHai,
      0,
      reason: 'Quét chạy sau MỌI lần đồng bộ. Ghi lại vô điều kiện là bản ghi '
          'luôn ở trạng thái pending — đẩy lên rồi lại pending, một vòng lặp '
          'đẩy vô tận không có lỗi nào báo ra. Đã vấp đúng lỗi này ở chiều '
          'Pending → Overdue.',
    );
  });

  test('không đụng hoá đơn của tài khoản khác', () async {
    await themHoaDon(id: 'a', dueDate: DateTime(2026, 9, 4), idaccount: 11);
    await themHoaDon(
        id: 'b', dueDate: DateTime(2026, 10, 4), payStatus: 'Overdue', idaccount: 11);

    await db.billDao.markOverdue(10, now);

    expect(await trangThai('a'), 'Pending');
    expect(await trangThai('b'), 'Overdue');
  });
}
