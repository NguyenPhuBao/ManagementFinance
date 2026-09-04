import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/bill/bill_recurrence.dart';
import '../datasources/bill_local_datasource.dart';
import 'bill_repository.dart';

class BillRepositoryImpl implements BillRepository {
  final BillLocalDataSource dataSource;
  final AppDatabase db;
  final SyncEngine? syncEngine;

  BillRepositoryImpl({
    required this.dataSource,
    required this.db,
    this.syncEngine,
  });

  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    return dataSource.watchBills(idaccount);
  }

  @override
  Future<List<Bill>> getBills(int idaccount) {
    return dataSource.getBills(idaccount);
  }

  @override
  Future<void> addBill(BillsCompanion bill) async {
    await dataSource.insertBill(bill);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> editBill(BillsCompanion bill) async {
    // KHÔNG dùng insertBill: nó chèn theo insertOrReplace nên thay cả hàng và
    // đưa mọi cột vắng mặt về mặc định. Xem `BillDao.updateFields`.
    await dataSource.updateBill(bill);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> deleteBill(String id) async {
    await dataSource.softDeleteBill(id);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
  }) async {
    // UI truyền vào ảnh chụp `Bill` mà nó đang giữ; bấm nút hai lần thì lần
    // thứ hai vẫn mang isPaid = false. Trạng thái thật phải đọc lại từ CSDL.
    final current = await dataSource.getBillById(bill.id);
    if (current == null) {
      throw StateError('Không tìm thấy hoá đơn ${bill.id}');
    }
    if (current.isPaid || current.payStatus == 'Payed') {
      throw BillAlreadyPaidException(bill.id);
    }

    final now = DateTime.now();

    // Cả bốn bước nằm trong một transaction: hỏng giữa chừng mà vẫn giữ lại
    // phần đã ghi thì ví bị trừ nhưng hoá đơn chưa đánh dấu (hoặc ngược lại).
    await db.transaction(() async {
      // 1. Đánh dấu đã thanh toán (đặt cả isPaid lẫn payStatus).
      await dataSource.markPaid(current.id);

      // 2. Sinh giao dịch chi tương ứng.
      await db.transactionDao.insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          idaccount: idaccount,
          walletId: walletId,
          // Không gắn danh mục thì khoản chi này nằm ngoài mọi thống kê theo
          // danh mục và mọi ngân sách.
          categoryId: Value(current.categoryId),
          amount: current.amount,
          type: 'chi',
          note: Value('Thanh toán hóa đơn: ${current.name}'),
          date: now,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );

      // 3. Trừ số dư ví.
      final wallet = await db.walletDao.getById(walletId);
      if (wallet != null) {
        await db.walletDao.updateBalance(walletId, wallet.balance - current.amount);
      }

      // 4. Sinh hoá đơn kỳ kế tiếp.
      //
      // Nguồn sự thật là cặp `isRecurrence` + `timeRecurrence`. Cột
      // `recurrence` dạng chuỗi cũ KHÔNG đáng tin: nhánh pull không ghi nó,
      // nên hàng kéo về từ backend luôn mang mặc định 'monthly' của bảng — đọc
      // theo nó thì hoá đơn không lặp cũng đẻ ra kỳ mới.
      if (current.isRecurrence) {
        await dataSource.insertBill(
          _nextPeriodOf(current, now),
        );
      }
    });

    syncEngine?.scheduleSync();
  }

  /// Hoá đơn của kỳ kế tiếp, kế thừa toàn bộ cấu hình của [current].
  ///
  /// Bỏ sót `walletId`/`categoryId` ở đây là tự tạo lại đúng lỗi chặn đường
  /// đẩy: hai cột đó NOT NULL phía backend. Bỏ sót `isRecurrence` thì chuỗi
  /// hoá đơn định kỳ dừng lại sau đúng một kỳ.
  ///
  /// Kỳ sau bắt đầu **đúng tại ngày đến hạn của kỳ trước**, nên các kỳ nối
  /// đuôi nhau không hở và luôn giữ được `startDate < dueDate`. Vì chuỗi mất
  /// mốc gốc để neo, `nextBillDueDate` áp quy tắc ngày cuối tháng để mốc không
  /// tụt dần — xem `core/bill/bill_recurrence.dart`.
  BillsCompanion _nextPeriodOf(Bill current, DateTime now) {
    return BillsCompanion.insert(
      id: const Uuid().v4(),
      idaccount: current.idaccount,
      walletId: Value(current.walletId),
      categoryId: Value(current.categoryId),
      name: current.name,
      amount: current.amount,
      startDate: Value(current.dueDate),
      dueDate: nextBillDueDate(current.dueDate, current.timeRecurrence),
      payStatus: const Value('Pending'),
      isPaid: const Value(false),
      timeNotification: Value(current.timeNotification),
      isRecurrence: const Value(true),
      timeRecurrence: Value(current.timeRecurrence),
      recurrence: Value(legacyFromTimeRecurrence(current.timeRecurrence)),
      icon: Value(current.icon),
      colour: Value(current.colour),
      note: Value(current.note),
      syncStatus: const Value('pending'),
      updatedAt: now,
    );
  }
}
