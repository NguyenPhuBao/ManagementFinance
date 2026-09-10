/// Bộ chạy tự động thanh toán hoá đơn — chỗ thứ hai trong app tự chuyển tiền
/// khi người dùng vắng mặt.
///
/// Mọi test kiểm cả hai vế: tiền có đi đúng chỗ không, và **có dừng lại đúng
/// lúc không**. Vế thứ hai quan trọng hơn: một kỳ chưa trả thì người dùng bấm
/// Thanh toán là xong, còn một vòng lặp trả nhầm sẽ rút cạn ví trước khi ai
/// kịp nhìn thấy.
///
/// Cả bộ nằm trong **quá khứ** so với đồng hồ thật: `payBill` chặn `occurredAt`
/// ở tương lai và ghi `updatedAt` bằng `DateTime.now()`, nên kịch bản ở tương
/// lai là một tiền đề không xảy ra được ngoài đời (cùng bài học với bộ test
/// trích tự động của mục tiêu).
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay_runner.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;
  late BillAutoPayRunner runner;

  const accountId = 7;
  const walletId = 'w1';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    runner = BillAutoPayRunner(db: db, repository: repository);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: walletId,
      idaccount: accountId,
      name: 'Tiền mặt',
      balance: const Value(1000000.0),
      updatedAt: DateTime(2025, 1, 1),
    ));
  });

  tearDown(() => db.close());

  Future<void> seedBill({
    String id = 'b1',
    String name = 'Tiền điện',
    double amount = 200000,
    DateTime? due,
    bool autoPay = true,
    bool recurring = true,
    String? wallet = walletId,
    String? category = 'c1',
  }) async {
    final han = due ?? DateTime(2025, 9, 20);
    await db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: accountId,
      walletId: Value(wallet),
      categoryId: Value(category),
      name: name,
      amount: amount,
      startDate: Value(DateTime(han.year, han.month - 1, han.day)),
      dueDate: han,
      isRecurrence: Value(recurring),
      timeRecurrence: const Value(kBillCycleMonth),
      recurrence: Value(recurring ? 'monthly' : 'once'),
      autoPayEnabled: Value(autoPay),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2025, 1, 1),
    ));
  }

  Future<double> soDu() async => (await db.walletDao.getById(walletId))!.balance;

  Future<List<Bill>> hoaDon() async =>
      (await db.billDao.getAll(accountId)).where((b) => !b.isDeleted).toList();

  Future<List<Transaction>> khoanChi() async =>
      (await db.transactionDao.getAll(accountId))
          .where((t) => !t.isDeleted)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  group('một kỳ tới hạn', () {
    test('trả: đánh dấu đã trả, trừ ví, ghi giao dịch mang NGÀY HẠN, sinh kỳ sau',
        () async {
      await seedBill();

      final ra = await runner.chay(accountId, now: DateTime(2025, 9, 21, 9));

      expect(ra.single.loai, LoaiTuTra.traDu);
      expect(ra.single.soTien, 200000);
      expect(ra.single.tenVi, 'Tiền mặt');
      expect(ra.single.ky, DateTime(2025, 9, 20),
          reason: 'Mốc sự kiện là ngày đến hạn của kỳ, đi vào khoá thông báo.');

      final b1 = (await db.billDao.getById('b1'))!;
      expect(b1.isPaid, isTrue);
      expect(b1.payStatus, 'Payed');
      expect(await soDu(), 800000);

      final chi = await khoanChi();
      expect(chi.single.date, DateTime(2025, 9, 20),
          reason: 'Khoản trả bù mang ngày của kỳ, không phải lúc bù.');
      expect(chi.single.billId, 'b1',
          reason: 'Đi qua `payBill` nên sợi dây hoàn tác vẫn có.');

      final kySau = (await hoaDon()).firstWhere((b) => b.id != 'b1');
      expect(kySau.dueDate, DateTime(2025, 10, 20));
      expect(kySau.isPaid, isFalse);
      expect(kySau.autoPayEnabled, isTrue);
    });

    test('đúng ngày đến hạn, bất kỳ giờ nào, là trả', () async {
      await seedBill(due: DateTime(2025, 9, 20, 23, 30));

      await runner.chay(accountId, now: DateTime(2025, 9, 20, 6, 15));

      expect((await db.billDao.getById('b1'))!.isPaid, isTrue);
    });

    test('CHƯA tới ngày đến hạn thì không đụng gì', () async {
      await seedBill();

      final ra = await runner.chay(accountId, now: DateTime(2025, 9, 19, 23));

      expect(ra, isEmpty);
      expect((await db.billDao.getById('b1'))!.isPaid, isFalse);
      expect(await soDu(), 1000000);
      expect(await khoanChi(), isEmpty);
    });

    test('không bật thì không trả', () async {
      await seedBill(autoPay: false);

      final ra = await runner.chay(accountId, now: DateTime(2025, 10, 1));

      expect(ra, isEmpty);
      expect(await soDu(), 1000000);
    });

    test('hoá đơn KHÔNG lặp: trả xong là hết, không sinh kỳ sau', () async {
      await seedBill(recurring: false);

      await runner.chay(accountId, now: DateTime(2025, 10, 1));

      expect((await hoaDon()).length, 1);
      expect((await db.billDao.getById('b1'))!.isPaid, isTrue);
    });

    test('chạy hai lượt liên tiếp không trả hai lần', () async {
      await seedBill();

      await runner.chay(accountId, now: DateTime(2025, 9, 21));
      final ra = await runner.chay(accountId, now: DateTime(2025, 9, 21));

      expect(ra, isEmpty,
          reason: 'Cờ đã trả là chốt chống trả hai lần; kỳ sau (20/10) chưa '
              'tới hạn nên không có gì để làm.');
      expect(await soDu(), 800000);
      expect((await khoanChi()).length, 1);
    });
  });

  group('trả bù nhiều kỳ', () {
    test('kỳ sau sinh ra cũng đã quá hạn thì trả tiếp, tới trần 3', () async {
      await seedBill(due: DateTime(2025, 3, 20));

      // Sáu tháng không mở app: 20/03, 20/04, ... 20/08 đều đã qua.
      final ra = await runner.chay(accountId, now: DateTime(2025, 9, 1));

      expect(ra.length, 3,
          reason: 'Sáu kỳ trả một lúc là rút cạn ví ngay khi mở app. Trần 3 '
              'mỗi lượt; phần dư ở lại lượt sau.');
      expect(ra.every((e) => e.loai == LoaiTuTra.traDu), isTrue);
      expect(await soDu(), 400000);

      final chi = await khoanChi();
      expect(chi.map((t) => t.date).toList(), [
        DateTime(2025, 3, 20),
        DateTime(2025, 4, 20),
        DateTime(2025, 5, 20),
      ], reason: 'Ba kỳ bù là ba sự việc của ba ngày, không phải một cột.');

      final conMo = (await hoaDon()).where((b) => !b.isPaid).toList();
      expect(conMo.single.dueDate, DateTime(2025, 6, 20),
          reason: 'Kỳ thứ tư được sinh ra nhưng chưa trả — lượt sau xử lý.');
    });

    test('lượt sau trả tiếp phần dư', () async {
      await seedBill(due: DateTime(2025, 3, 20));
      await runner.chay(accountId, now: DateTime(2025, 9, 1));
      // Lượt đầu tiêu 600.000; nạp thêm để lượt hai đủ cho ba kỳ nữa.
      await db.walletDao.updateBalance(walletId, 2000000);

      final ra = await runner.chay(accountId, now: DateTime(2025, 9, 1));

      expect(ra.length, 3);
      expect(ra.every((e) => e.loai == LoaiTuTra.traDu), isTrue);
      expect((await khoanChi()).length, 6);
      expect((await hoaDon()).where((b) => !b.isPaid).single.dueDate,
          DateTime(2025, 9, 20),
          reason: 'Kỳ 20/09 chưa tới hạn (hôm nay 01/09) nên còn mở.');
    });

    test('dừng NGAY khi ví không đủ cho kỳ kế tiếp', () async {
      await seedBill(due: DateTime(2025, 3, 20), amount: 400000);

      final ra = await runner.chay(accountId, now: DateTime(2025, 9, 1));

      expect(ra.map((e) => e.loai).toList(),
          [LoaiTuTra.traDu, LoaiTuTra.traDu, LoaiTuTra.viKhongDu]);
      expect(await soDu(), 200000);
      expect((await khoanChi()).length, 2);
    });
  });

  group('dừng đúng lúc', () {
    test('ví không đủ: không trả, không đổi gì, báo viKhongDu', () async {
      await seedBill(amount: 1500000);

      final ra = await runner.chay(accountId, now: DateTime(2025, 10, 1));

      expect(ra.single.loai, LoaiTuTra.viKhongDu);
      expect(ra.single.soTien, 0);
      expect(ra.single.tenVi, 'Tiền mặt');
      expect(await soDu(), 1000000);
      expect((await db.billDao.getById('b1'))!.isPaid, isFalse);
      expect(await khoanChi(), isEmpty);
      expect((await hoaDon()).length, 1,
          reason: 'Không sinh kỳ sau cho một kỳ chưa trả.');
    });

    test('ví có tiền ở lượt sau thì kỳ ấy tự trả', () async {
      await seedBill(amount: 1500000);
      await runner.chay(accountId, now: DateTime(2025, 10, 1));

      await db.walletDao.updateBalance(walletId, 2000000);
      final ra = await runner.chay(accountId, now: DateTime(2025, 10, 2));

      expect(ra.single.loai, LoaiTuTra.traDu);
      expect((await db.billDao.getById('b1'))!.isPaid, isTrue);
    });

    test('ví không còn tồn tại: khongChayDuoc, không trả', () async {
      await seedBill(wallet: 'w-da-xoa');

      final ra = await runner.chay(accountId, now: DateTime(2025, 10, 1));

      expect(ra.single.loai, LoaiTuTra.khongChayDuoc);
      expect(ra.single.tenVi, isNull);
      expect((await db.billDao.getById('b1'))!.isPaid, isFalse);
    });

    test('ví ĐÃ LƯU TRỮ: khongChayDuoc, không trả', () async {
      await seedBill();
      await db.walletDao.setStatus(walletId, luuTru: true);

      final ra = await runner.chay(accountId, now: DateTime(2025, 10, 1));

      expect(ra.single.loai, LoaiTuTra.khongChayDuoc,
          reason: 'Lưu trữ ví là ĐÓNG BĂNG nó: không sinh kỳ mới, không tự rút '
              'tiền. Trả im lặng khỏi một ví người dùng đã cất đi là cách hỏng '
              'tệ nhất — họ không nhìn ví ấy nữa nên sẽ không thấy gì cả.');
      expect((await db.billDao.getById('b1'))!.isPaid, isFalse);
      expect((await db.walletDao.getById(walletId))!.balance, 1000000.0);
    });

    test('mỗi hoá đơn độc lập: hoá đơn hỏng không chặn hoá đơn khác', () async {
      await seedBill(id: 'hong', name: 'Hỏng', wallet: 'w-da-xoa');
      await seedBill(id: 'tot', name: 'Tốt');

      final ra = await runner.chay(accountId, now: DateTime(2025, 10, 1));

      expect(ra.map((e) => e.billId).toSet(), {'hong', 'tot'});
      expect((await db.billDao.getById('tot'))!.isPaid, isTrue);
    });

    test('không đụng hoá đơn của tài khoản khác', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w-khac',
        idaccount: 99,
        name: 'Ví khác',
        balance: const Value(1000000.0),
        updatedAt: DateTime(2025, 1, 1),
      ));
      await db.billDao.insert(BillsCompanion.insert(
        id: 'b-khac',
        idaccount: 99,
        walletId: const Value('w-khac'),
        categoryId: const Value('c1'),
        name: 'Của người khác',
        amount: 100000,
        dueDate: DateTime(2025, 9, 20),
        autoPayEnabled: const Value(true),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2025, 1, 1),
      ));

      final ra = await runner.chay(accountId, now: DateTime(2025, 10, 1));

      expect(ra, isEmpty);
      expect((await db.billDao.getById('b-khac'))!.isPaid, isFalse);
    });
  });

  test('hoàn tác vẫn được sau khi tự trả', () async {
    await seedBill();
    await runner.chay(accountId, now: DateTime(2025, 9, 21));

    await repository.undoPayment(billId: 'b1');

    expect((await db.billDao.getById('b1'))!.isPaid, isFalse);
    expect(await soDu(), 1000000);
    expect((await hoaDon()).length, 1,
        reason: 'Kỳ sau do lần tự trả sinh ra cũng bị gỡ.');
  });
}
