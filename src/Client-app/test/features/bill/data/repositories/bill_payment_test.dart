/// Trả hoá đơn với số tiền thật, và hoàn tác được lần trả.
///
/// Vì sao cần hai việc này:
///
/// **Số tiền.** Hoá đơn điện nước tháng nào cũng khác, nhưng luồng trả chỉ
/// biết đúng con số đã lưu lúc tạo. Muốn đổi thì phải vào form Sửa — mà sửa
/// là đổi luôn cho mọi kỳ sau, chứ không phải cho riêng kỳ này.
///
/// **Hoàn tác.** Trả nhầm là kẹt hẳn: khoản chi sinh ra bị chặn xoá ở sổ giao
/// dịch (`transactionOwnerOf`), hoá đơn không có đường về `Pending`, và kỳ kế
/// tiếp đã được sinh ra rồi. Đây cũng là tiền đề để cho phép xoá khoản trả hoá
/// đơn ở sổ.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;

  const accountId = 7;
  const walletId = 'wallet-1';
  const walletKhac = 'wallet-2';
  const categoryId = 'cat-dien';
  const soDuBanDau = 1000000.0;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );

    for (final w in [walletId, walletKhac]) {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: w,
        idaccount: accountId,
        name: 'Ví $w',
        balance: const Value(soDuBanDau),
        updatedAt: DateTime(2026, 9, 1),
      ));
    }
  });

  tearDown(() => db.close());

  Future<Bill> seedBill({
    String id = 'bill-1',
    double amount = 200000,
    bool isRecurrence = true,
    bool isPaid = false,
  }) async {
    await db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: accountId,
      walletId: const Value(walletId),
      categoryId: const Value(categoryId),
      name: 'Tiền điện',
      amount: amount,
      startDate: Value(DateTime(2026, 8, 20)),
      dueDate: DateTime(2026, 9, 20),
      payStatus: Value(isPaid ? 'Payed' : 'Pending'),
      isPaid: Value(isPaid),
      isRecurrence: Value(isRecurrence),
      timeRecurrence: const Value(kBillCycleMonth),
      recurrence: const Value('monthly'),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2026, 9, 1),
    ));
    return (await db.billDao.getById(id))!;
  }

  Future<double> soDu(String id) async =>
      (await db.walletDao.getById(id))!.balance;

  Future<List<Transaction>> khoanChi() async =>
      (await db.transactionDao.getAll(accountId))
          .where((t) => !t.isDeleted)
          .toList();

  group('trả với số tiền của kỳ này', () {
    test('số tiền truyền vào thắng số đã lưu trên hoá đơn', () async {
      final bill = await seedBill(amount: 200000);

      await repository.payBill(
        bill: bill,
        walletId: walletId,
        idaccount: accountId,
        amount: 350000,
      );

      final chi = await khoanChi();
      expect(chi.single.amount, 350000,
          reason: 'Tiền điện tháng này thật sự là 350.000, không phải con số '
              'ước lượng lúc tạo hoá đơn.');
      expect(await soDu(walletId), soDuBanDau - 350000,
          reason: 'Ví phải trừ đúng số đã trả, không phải số đã lưu.');
    });

    test('hoá đơn ghi lại số tiền THẬT đã trả', () async {
      final bill = await seedBill(amount: 200000);

      await repository.payBill(
        bill: bill,
        walletId: walletId,
        idaccount: accountId,
        amount: 350000,
      );

      expect((await db.billDao.getById('bill-1'))!.amount, 350000,
          reason: 'Tab "Đã thanh toán" là lịch sử; nó phải nói số đã trả thật '
              'chứ không phải con số dự kiến.');
    });

    test('kỳ kế tiếp kế thừa số tiền vừa trả', () async {
      final bill = await seedBill(amount: 200000);

      await repository.payBill(
        bill: bill,
        walletId: walletId,
        idaccount: accountId,
        amount: 350000,
      );

      final ky2 = (await db.billDao.getAll(accountId))
          .firstWhere((b) => b.id != 'bill-1');
      expect(
        ky2.amount,
        350000,
        reason: 'Một quy tắc duy nhất, không có "số mẫu" ẩn: kỳ sau bắt đầu từ '
            'số vừa trả, vốn là ước lượng sát hơn con số cũ.',
      );
    });

    test('không truyền số tiền thì giữ nguyên hành vi cũ', () async {
      final bill = await seedBill(amount: 200000);

      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      expect((await khoanChi()).single.amount, 200000);
      expect(await soDu(walletId), soDuBanDau - 200000);
    });

    test('số tiền không dương bị từ chối, không ghi gì cả', () async {
      final bill = await seedBill();

      await expectLater(
        repository.payBill(
            bill: bill, walletId: walletId, idaccount: accountId, amount: 0),
        throwsA(isA<BillInvalidAmountException>()),
      );
      expect(await khoanChi(), isEmpty);
      expect(await soDu(walletId), soDuBanDau,
          reason: 'Chặn ở tầng repository chứ không chỉ ở ô nhập: ô nhập nằm '
              'NGOÀI khối nguyên tử, cùng bài học với `depositToGoal`.');
      expect((await db.billDao.getById('bill-1'))!.isPaid, isFalse);
    });
  });

  group('hoàn tác thanh toán', () {
    test('hoá đơn quay về chưa thanh toán', () async {
      final bill = await seedBill();
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      await repository.undoPayment(billId: 'bill-1');

      final sau = (await db.billDao.getById('bill-1'))!;
      expect(sau.isPaid, isFalse);
      expect(sau.payStatus, 'Pending',
          reason: 'Phải đặt CẢ HAI cột, cùng lý do với `markPaid`: nhánh đẩy '
              'gửi `pay_status` chứ không gửi `isPaid`.');
      expect(sau.syncStatus, 'pending');
    });

    test('tiền được hoàn vào đúng ví đã trừ, đúng số đã trừ', () async {
      final bill = await seedBill(amount: 200000);
      // Trả bằng ví KHÁC ví mặc định của hoá đơn, và với số tiền khác.
      await repository.payBill(
        bill: bill,
        walletId: walletKhac,
        idaccount: accountId,
        amount: 350000,
      );

      await repository.undoPayment(billId: 'bill-1');

      expect(await soDu(walletKhac), soDuBanDau,
          reason: 'Hoàn theo ví và số tiền của GIAO DỊCH, không phải theo ví '
              'và số tiền ghi trên hoá đơn — hai thứ đó có thể khác nhau.');
      expect(await soDu(walletId), soDuBanDau,
          reason: 'Ví mặc định của hoá đơn không hề bị đụng tới.');
    });

    test('khoản chi đã sinh bị xoá mềm', () async {
      final bill = await seedBill();
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      await repository.undoPayment(billId: 'bill-1');

      expect(await khoanChi(), isEmpty);
      // Đọc thẳng bảng: `getAll` đã lọc bỏ hàng xoá mềm, nên nó không phân
      // biệt được "đã xoá mềm" với "xoá cứng mất luôn".
      final tatCa = await db.select(db.transactions).get();
      expect(tatCa.single.isDeleted, isTrue,
          reason: 'Xoá MỀM, không xoá cứng — quy tắc 5 trong CLAUDE.md.');
      expect(tatCa.single.syncStatus, 'pending');
    });

    test('kỳ kế tiếp đã sinh cũng bị xoá mềm', () async {
      final bill = await seedBill(isRecurrence: true);
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);
      expect((await db.billDao.getAll(accountId)).length, 2);

      await repository.undoPayment(billId: 'bill-1');

      final conLai = await db.billDao.getAll(accountId);
      expect(
        conLai.map((b) => b.id),
        ['bill-1'],
        reason: 'Để lại kỳ kế tiếp thì người dùng có hai kỳ cùng mở, và trả '
            'lại lần nữa sẽ đẻ thêm một kỳ trùng.',
      );
    });

    test('hoá đơn không lặp thì không có kỳ nào để gỡ', () async {
      final bill = await seedBill(isRecurrence: false);
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);

      await repository.undoPayment(billId: 'bill-1');

      expect((await db.billDao.getAll(accountId)).map((b) => b.id), ['bill-1']);
    });

    test('hoàn tác hoá đơn CHƯA trả bị từ chối', () async {
      await seedBill();

      await expectLater(
        repository.undoPayment(billId: 'bill-1'),
        throwsA(isA<BillNotPaidException>()),
      );
    });

    test('khoản trả cũ không có billId thì từ chối, KHÔNG đoán', () async {
      // Hàng do bản app trước 2026-09-06 ghi, hoặc kéo về từ server: đã trả
      // nhưng không có sợi dây nào nối tới khoản chi.
      await seedBill(isPaid: true);

      await expectLater(
        repository.undoPayment(billId: 'bill-1'),
        throwsA(isA<BillUndoUnavailableException>()),
        // Đoán bằng tiền tố ghi chú + số tiền + ngày là quay lại đúng phép so
        // bằng tên mà cột `billId` sinh ra để thay thế; đoán trượt ở đây nghĩa
        // là hoàn tiền vào ví bằng một khoản chi KHÁC của người dùng.
      );
      expect(await soDu(walletId), soDuBanDau);
    });

    test('hoàn tác rồi trả lại được, và chỉ sinh đúng một kỳ mới', () async {
      final bill = await seedBill();
      await repository.payBill(
          bill: bill, walletId: walletId, idaccount: accountId);
      await repository.undoPayment(billId: 'bill-1');

      final lai = (await db.billDao.getById('bill-1'))!;
      await repository.payBill(
          bill: lai, walletId: walletId, idaccount: accountId);

      expect((await db.billDao.getAll(accountId)).length, 2);
      expect(await soDu(walletId), soDuBanDau - 200000);
    });
  });
}
