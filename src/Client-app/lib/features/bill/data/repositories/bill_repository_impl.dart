import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../datasources/bill_local_datasource.dart';
import 'bill_repository.dart';

class BillRepositoryImpl implements BillRepository {
  final BillLocalDataSource dataSource;
  final AppDatabase db;

  BillRepositoryImpl({required this.dataSource, required this.db});

  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    return dataSource.watchBills(idaccount);
  }

  @override
  Future<List<Bill>> getBills(int idaccount) {
    return dataSource.getBills(idaccount);
  }

  @override
  Future<void> addBill(BillsCompanion bill) {
    return dataSource.insertBill(bill);
  }

  @override
  Future<void> editBill(BillsCompanion bill) {
    return dataSource.insertBill(bill);
  }

  @override
  Future<void> deleteBill(String id) {
    return dataSource.softDeleteBill(id);
  }

  @override
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
  }) async {
    final now = DateTime.now();

    // 1. Mark bill as paid
    await dataSource.markPaid(bill.id);

    // 2. Create expense transaction
    final transactionId = const Uuid().v4();
    await db.transactionDao.insert(
      TransactionsCompanion.insert(
        id: transactionId,
        idaccount: idaccount,
        walletId: walletId,
        amount: bill.amount,
        type: 'chi',
        note: Value('Thanh toán hóa đơn: ${bill.name}'),
        date: now,
        syncStatus: const Value('pending'),
        updatedAt: now,
      ),
    );

    // 3. Deduct wallet balance
    final wallet = await db.walletDao.getById(walletId);
    if (wallet != null) {
      final newBalance = wallet.balance - bill.amount;
      await db.walletDao.updateBalance(walletId, newBalance);
    }

    // 4. Generate next period bill if recurring
    final recurrence = bill.recurrence;
    if (recurrence != 'once') {
      DateTime nextDueDate = bill.dueDate;
      if (recurrence == 'weekly') {
        nextDueDate = bill.dueDate.add(const Duration(days: 7));
      } else if (recurrence == 'monthly') {
        nextDueDate = DateTime(
          bill.dueDate.year,
          bill.dueDate.month + 1,
          bill.dueDate.day,
          bill.dueDate.hour,
          bill.dueDate.minute,
        );
      } else if (recurrence == 'yearly') {
        nextDueDate = DateTime(
          bill.dueDate.year + 1,
          bill.dueDate.month,
          bill.dueDate.day,
          bill.dueDate.hour,
          bill.dueDate.minute,
        );
      }

      final nextBillId = const Uuid().v4();
      await dataSource.insertBill(
        BillsCompanion.insert(
          id: nextBillId,
          idaccount: idaccount,
          name: bill.name,
          amount: bill.amount,
          dueDate: nextDueDate,
          isPaid: const Value(false),
          recurrence: Value(recurrence),
          icon: Value(bill.icon),
          colour: Value(bill.colour),
          note: Value(bill.note),
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );
    }
  }
}
