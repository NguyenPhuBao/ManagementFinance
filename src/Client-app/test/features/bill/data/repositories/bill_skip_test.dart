/// Bỏ qua một kỳ hoá đơn, và hoàn tác việc bỏ qua.
///
/// Vì sao cần: hoá đơn lặp có những kỳ **không phải trả** — đi vắng cả tháng
/// nên không có tiền điện, chủ nhà miễn một tháng, gói dịch vụ tặng kỳ. Trước
/// tính năng này người dùng chỉ có hai lối, đều sai:
///
/// - **Trả giả** với số tiền nhỏ → sổ giao dịch có một khoản chi không có
///   thật, thống kê theo danh mục lệch, ngân sách bị trừ oan. Mà `payBill` từ
///   chối số tiền `<= 0` nên thực ra cũng không làm được.
/// - **Xoá kỳ** → mất mắt xích `generatedFromBillId`, và vì chỉ `payBill` mới
///   sinh kỳ sau nên chuỗi dừng hẳn; người dùng phải tạo lại hoá đơn từ đầu.
///
/// Cái đắt nhất trong tệp này là nhóm cuối: một kỳ `Skipped` **đã sinh kỳ kế
/// tiếp**, nên để `payBill` chạy tiếp trên nó là sinh kỳ thứ hai trùng hạn.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
  const categoryId = 'cat-dien';
  const soDuBanDau = 1000000.0;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );

    await db.walletDao.insert(WalletsCompanion.insert(
      id: walletId,
      idaccount: accountId,
      name: 'Ví tiền mặt',
      balance: const Value(soDuBanDau),
      updatedAt: DateTime(2026, 9, 1),
    ));
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

  Future<double> soDu() async =>
      (await db.walletDao.getById(walletId))!.balance;

  Future<List<Transaction>> khoanChi() async =>
      (await db.transactionDao.getAll(accountId))
          .where((t) => !t.isDeleted)
          .toList();

  group('skipBill', () {
    test('KHÔNG trừ ví và KHÔNG ghi giao dịch nào', () async {
      final bill = await seedBill(amount: 200000);

      await repository.skipBill(billId: bill.id);

      expect(await soDu(), soDuBanDau,
          reason: 'Bỏ qua kỳ nghĩa là không trả. Trừ ví ở đây là lấy tiền của '
              'người dùng cho một khoản họ vừa nói là không phải trả.');
      expect(await khoanChi(), isEmpty,
          reason: 'Một khoản chi không có thật sẽ làm lệch thống kê theo danh '
              'mục và trừ oan ngân sách — chính là lý do tính năng này tồn '
              'tại, thay cho mẹo "trả giả với số tiền nhỏ".');
    });

    test('đặt Skipped, giữ isPaid false, và vào hàng đợi đẩy', () async {
      final bill = await seedBill();

      await repository.skipBill(billId: bill.id);

      final sau = (await db.billDao.getById(bill.id))!;
      expect(sau.payStatus, 'Skipped',
          reason: 'Đây là cột ĐI ĐỒNG BỘ — nó là thứ mang quyết định sang máy '
              'khác và sang Admin-web.');
      expect(sau.isPaid, isFalse,
          reason: 'Không có khoản chi nào, nên isPaid phải false. Đặt true là '
              'mọi chỗ hỏi "đã trả chưa" trả lời sai, và nhánh pull cũng suy '
              'ngược lại từ pay_status.');
      expect(sau.syncStatus, 'pending',
          reason: 'Không đặt pending thì quyết định nằm lại máy này mãi.');
    });

    test('sinh kỳ kế tiếp để chuỗi không đứt', () async {
      final bill = await seedBill(isRecurrence: true);

      await repository.skipBill(billId: bill.id);

      final kySau = await db.billDao.getGeneratedFrom(bill.id);
      expect(kySau, isNotNull,
          reason: 'Chỉ payBill mới sinh kỳ sau. Bỏ qua mà không sinh thì chuỗi '
              'dừng hẳn và người dùng phải tạo lại hoá đơn từ đầu — đúng cái '
              'bất tiện mà tính năng này ra đời để tránh.');
      expect(kySau!.dueDate, DateTime(2026, 10, 20),
          reason: 'Kỳ sau tính bằng chính _nextPeriodOf của payBill, không có '
              'bản thứ hai của luật ngày.');
      expect(kySau.payStatus, 'Pending',
          reason: 'Kỳ mới là kỳ phải trả, không kế thừa trạng thái bỏ qua.');
      expect(kySau.amount, 200000,
          reason: 'Không có lần trả nào nên số tiền kế thừa số ghi trên hoá '
              'đơn, không phải một con số bịa ra.');
    });

    test('hoá đơn KHÔNG lặp thì không sinh kỳ nào', () async {
      final bill = await seedBill(isRecurrence: false);

      await repository.skipBill(billId: bill.id);

      expect(await db.billDao.getGeneratedFrom(bill.id), isNull,
          reason: 'Hoá đơn một lần được miễn thì hết, không đẻ ra kỳ sau.');
    });

    test('từ chối kỳ đã trả', () async {
      final bill = await seedBill(isPaid: true);

      expect(() => repository.skipBill(billId: bill.id),
          throwsA(isA<BillAlreadyPaidException>()),
          reason: 'Tiền đã ra khỏi ví rồi; đánh dấu bỏ qua là nói dối sổ sách.');
    });

    test('từ chối kỳ đã bỏ qua — không sinh kỳ trùng', () async {
      final bill = await seedBill();
      await repository.skipBill(billId: bill.id);

      expect(() => repository.skipBill(billId: bill.id),
          throwsA(isA<BillAlreadySkippedException>()),
          reason: 'Bấm hai lần mà chạy hai lần là hai kỳ kế tiếp cùng hạn, và '
              'người dùng không hiểu hoá đơn thứ hai ở đâu ra.');
    });
  });

  group('chốt chặn của payBill', () {
    test('từ chối trả một kỳ đã bỏ qua, TRƯỚC khi trừ ví', () async {
      final bill = await seedBill();
      await repository.skipBill(billId: bill.id);
      final sau = (await db.billDao.getById(bill.id))!;

      expect(
          () => repository.payBill(
                bill: sau,
                walletId: walletId,
                idaccount: accountId,
              ),
          throwsA(isA<BillSkippedCannotPayException>()),
          reason: 'Kỳ bỏ qua ĐÃ sinh kỳ kế tiếp. Trả tiếp trên nó là sinh kỳ '
              'thứ hai trùng hạn — người dùng có hai hoá đơn giống hệt nhau mà '
              'không biết vì sao.');
      expect(await soDu(), soDuBanDau,
          reason: 'Lời từ chối phải xảy ra TRƯỚC khi ví bị trừ.');
      expect(await khoanChi(), isEmpty);
    });
  });

  group('undoSkip', () {
    test('đưa về Pending và gỡ kỳ kế tiếp đã sinh', () async {
      final bill = await seedBill();
      await repository.skipBill(billId: bill.id);
      final kySau = (await db.billDao.getGeneratedFrom(bill.id))!;

      await repository.undoSkip(billId: bill.id);

      expect((await db.billDao.getById(bill.id))!.payStatus, 'Pending',
          reason: 'Hoàn tác là trả kỳ này về đúng chỗ nó đứng trước đó. Không '
              'đoán sang Overdue — markOverdue chạy sau mỗi lần đồng bộ và tự '
              'gắn lại cờ nếu kỳ đã trễ.');
      expect((await db.billDao.getById(kySau.id))!.isDeleted, isTrue,
          reason: 'Để lại thì người dùng có hai kỳ cùng mở, và bỏ qua lần nữa '
              'sẽ đẻ thêm một kỳ trùng — cùng lý do với undoPayment.');
    });

    test('KHÔNG cộng tiền vào ví', () async {
      final bill = await seedBill();
      await repository.skipBill(billId: bill.id);

      await repository.undoSkip(billId: bill.id);

      expect(await soDu(), soDuBanDau,
          reason: 'Chưa từng trừ tiền thì không có gì để hoàn. Chép nguyên '
              'bước hoàn tiền của undoPayment sang đây là TẶNG tiền cho ví.');
    });

    test('từ chối kỳ chưa bỏ qua', () async {
      final bill = await seedBill();

      expect(() => repository.undoSkip(billId: bill.id),
          throwsA(isA<BillNotSkippedException>()));
    });

    test('từ chối kỳ đã trả', () async {
      final bill = await seedBill(isPaid: true);

      expect(() => repository.undoSkip(billId: bill.id),
          throwsA(isA<BillNotSkippedException>()),
          reason: 'Hoàn tác một lần TRẢ phải đi qua undoPayment, thứ có bước '
              'hoàn tiền. Đi nhầm đường này là hoá đơn về Pending mà tiền vẫn '
              'nằm ngoài ví và khoản chi vẫn còn trong sổ.');
    });
  });
}
