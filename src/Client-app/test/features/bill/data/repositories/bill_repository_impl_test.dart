import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';

void main() {
  late AppDatabase db;
  late BillLocalDataSource dataSource;
  late BillRepositoryImpl repository;

  const accountId = 7;
  const walletId = 'wallet-1';
  const categoryId = 'cat-dien';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = BillLocalDataSource(db);
    repository = BillRepositoryImpl(dataSource: dataSource, db: db);

    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: walletId,
        idaccount: accountId,
        name: 'Ví chính',
        balance: const Value(1000000.0),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Một hoá đơn đầy đủ thuộc tính như hàng kéo về từ backend.
  Future<Bill> seedBill({
    String id = 'bill-1',
    DateTime? dueDate,
    bool isRecurrence = true,
    String timeRecurrence = kBillCycleMonth,
    bool isPaid = false,
  }) async {
    await db.billDao.insert(
      BillsCompanion.insert(
        id: id,
        idaccount: accountId,
        walletId: const Value(walletId),
        categoryId: const Value(categoryId),
        name: 'Tiền điện',
        amount: 200000.0,
        startDate: Value(DateTime(2026, 1, 20)),
        dueDate: dueDate ?? DateTime(2026, 8, 20),
        payStatus: Value(isPaid ? 'Payed' : 'Pending'),
        isPaid: Value(isPaid),
        timeNotification: const Value('3'),
        isRecurrence: Value(isRecurrence),
        timeRecurrence: Value(timeRecurrence),
        recurrence: Value(
          isRecurrence ? legacyFromTimeRecurrence(timeRecurrence) : 'once',
        ),
        icon: const Value('bolt'),
        colour: const Value('#FF0000'),
        note: const Value('Ghi chú cũ'),
        updatedAt: DateTime.now(),
      ),
    );
    return (await db.billDao.getAll(accountId)).firstWhere((b) => b.id == id);
  }

  group('editBill', () {
    test('không đụng tới các cột vắng mặt trong companion', () async {
      await seedBill(isPaid: true);

      // Đúng companion mà bill_edit_page.dart dựng: chỉ những trường trên form.
      await repository.editBill(
        BillsCompanion(
          id: const Value('bill-1'),
          idaccount: const Value(accountId),
          name: const Value('Tiền điện tháng 9'),
          amount: const Value(250000.0),
          dueDate: Value(DateTime(2026, 9, 20)),
          note: const Value('Ghi chú mới'),
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final after = (await db.billDao.getAll(accountId)).single;
      expect(after.name, 'Tiền điện tháng 9');
      expect(after.amount, 250000.0);
      expect(after.note, 'Ghi chú mới');

      expect(after.isPaid, true,
          reason: 'Sửa tên/số tiền không được biến hoá đơn ĐÃ THANH TOÁN '
              'thành chưa thanh toán.');
      expect(after.payStatus, 'Payed',
          reason: 'payStatus phải sống sót y như isPaid.');
      expect(after.walletId, walletId,
          reason: 'Mất walletId là mất luôn khả năng đẩy lên backend — '
              'bill.Idwallet là NOT NULL.');
      expect(after.categoryId, categoryId,
          reason: 'Mất categoryId cũng chặn hẳn đường đẩy — bill.Idcategory '
              'là NOT NULL.');
      expect(after.isRecurrence, true,
          reason: 'Chu kỳ lặp biến mất thì hoá đơn ngừng sinh kỳ mới.');
      expect(after.timeRecurrence, kBillCycleMonth);
      expect(after.timeNotification, '3');
      expect(after.icon, 'bolt', reason: 'Icon người dùng chọn không được '
          'rơi về mặc định.');
      expect(after.colour, '#FF0000');
      expect(after.startDate, DateTime(2026, 1, 20));
    });

    test('sửa hoá đơn không làm nó sống lại sau khi đã xoá mềm', () async {
      await seedBill();
      await repository.deleteBill('bill-1');

      await repository.editBill(
        BillsCompanion(
          id: const Value('bill-1'),
          idaccount: const Value(accountId),
          name: const Value('Tên mới'),
          amount: const Value(1.0),
          dueDate: Value(DateTime(2026, 9, 20)),
          syncStatus: const Value('pending'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final row = await (db.select(db.bills)
            ..where((t) => t.id.equals('bill-1')))
          .getSingle();
      expect(row.isDeleted, true,
          reason: 'insertOrReplace từng đưa cờ xoá về mặc định, làm hàng đã '
              'xoá hiện lại trên danh sách.');
      expect(row.deletedAt != null, true);
    });
  });

  group('payBill', () {
    test('đặt cả isPaid lẫn payStatus', () async {
      final bill = await seedBill();
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      final paid = (await db.billDao.getAll(accountId))
          .firstWhere((b) => b.id == 'bill-1');
      expect(paid.isPaid, true);
      expect(paid.payStatus, 'Payed',
          reason: 'Nhánh đẩy gửi pay_status chứ không gửi isPaid. Chỉ đặt '
              'isPaid thì backend vĩnh viễn thấy hoá đơn là Pending — hỏng '
              'im lặng, không có lỗi nào báo ra.');
    });

    test('tạo giao dịch chi gắn đúng danh mục của hoá đơn', () async {
      final bill = await seedBill();
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      final tx = (await db.transactionDao.getAll(accountId)).single;
      expect(tx.amount, 200000.0);
      expect(tx.type, 'chi');
      expect(tx.walletId, walletId);
      expect(tx.categoryId, categoryId,
          reason: 'Giao dịch không có danh mục thì khoản chi này không vào '
              'được thống kê theo danh mục lẫn ngân sách nào.');
    });

    test('trừ đúng số dư ví một lần', () async {
      final bill = await seedBill();
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      final wallet = await db.walletDao.getById(walletId);
      expect(wallet?.balance, 800000.0);
    });

    test('hoá đơn kỳ sau kế thừa đủ thuộc tính của kỳ hiện tại', () async {
      final bill = await seedBill(dueDate: DateTime(2026, 1, 31));
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      final next = (await db.billDao.getAll(accountId))
          .firstWhere((b) => b.id != 'bill-1');

      expect(next.dueDate, DateTime(2026, 2, 28),
          reason: 'Kỳ sau phải kẹp vào ngày cuối tháng, không tràn sang 03/03.');
      expect(next.isPaid, false);
      expect(next.payStatus, 'Pending');
      expect(next.walletId, walletId,
          reason: 'Kỳ sau không có ví thì lại rơi vào đúng lỗi không đẩy '
              'được lên backend.');
      expect(next.categoryId, categoryId);
      expect(next.isRecurrence, true,
          reason: 'Kỳ sau mất cờ lặp thì chuỗi hoá đơn định kỳ dừng lại sau '
              'đúng một kỳ.');
      expect(next.timeRecurrence, kBillCycleMonth);
      expect(next.timeNotification, '3');
      expect(next.icon, 'bolt');
      expect(next.colour, '#FF0000');
      expect(next.startDate, DateTime(2026, 1, 31),
          reason: 'Kỳ sau bắt đầu ĐÚNG tại ngày đến hạn của kỳ trước, nên các '
              'kỳ nối đuôi nhau không hở. Giữ nguyên startDate của kỳ cũ sẽ '
              'làm mọi kỳ trông như cùng bắt đầu một chỗ.');
      expect(next.startDate!.isBefore(next.dueDate), true,
          reason: 'Bất biến của mọi hoá đơn: ngày bắt đầu phải trước ngày đến '
              'hạn. Chu kỳ nào cũng phải giữ được điều này.');
      expect(next.syncStatus, 'pending');
    });

    test('chu kỳ lấy từ isRecurrence, không lấy từ chuỗi cũ', () async {
      // Hàng kéo về từ backend: nhánh pull chỉ ghi isRecurrence, còn cột
      // `recurrence` giữ nguyên mặc định 'monthly' của bảng.
      await db.billDao.insert(
        BillsCompanion.insert(
          id: 'bill-pulled',
          idaccount: accountId,
          walletId: const Value(walletId),
          categoryId: const Value(categoryId),
          name: 'Phí một lần',
          amount: 50000.0,
          dueDate: DateTime(2026, 8, 20),
          isRecurrence: const Value(false),
          updatedAt: DateTime.now(),
        ),
      );
      final bill = (await db.billDao.getAll(accountId)).single;
      expect(bill.recurrence, 'monthly',
          reason: 'Đây chính là trạng thái mà nhánh pull để lại.');

      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      expect((await db.billDao.getAll(accountId)).length, 1,
          reason: 'isRecurrence = false nghĩa là không lặp. Đọc chuỗi cũ '
              "'monthly' sẽ đẻ ra một kỳ mới mà người dùng không hề đặt.");
    });

    test('hoá đơn không lặp thì không sinh kỳ mới', () async {
      final bill = await seedBill(isRecurrence: false);
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);
      expect((await db.billDao.getAll(accountId)).length, 1);
    });

    test('thanh toán lần hai bị từ chối, không để lại tác dụng phụ nào',
        () async {
      final bill = await seedBill();
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      // `bill` vẫn là ảnh chụp CŨ (isPaid = false), đúng như đối tượng mà UI
      // đang giữ khi người dùng bấm nút lần thứ hai.
      await expectLater(
        repository.payBill(
            bill: bill, walletId: walletId, idaccount: accountId),
        throwsA(isA<BillAlreadyPaidException>()),
      );

      final wallet = await db.walletDao.getById(walletId);
      expect(wallet?.balance, 800000.0,
          reason: 'Trừ ví hai lần là mất tiền thật của người dùng.');
      expect((await db.transactionDao.getAll(accountId)).length, 1,
          reason: 'Giao dịch trùng làm sai toàn bộ báo cáo chi tiêu.');
      expect((await db.billDao.getAll(accountId)).length, 2,
          reason: 'Chỉ được sinh đúng một hoá đơn kỳ sau.');
    });
  });
}
