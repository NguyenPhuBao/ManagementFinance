import '../../../../core/database/app_database.dart';

class BillLocalDataSource {
  final AppDatabase db;

  BillLocalDataSource(this.db);

  Stream<List<Bill>> watchBills(int idaccount) {
    return db.billDao.watchAll(idaccount);
  }

  Future<List<Bill>> getBills(int idaccount) {
    return db.billDao.getAll(idaccount);
  }

  Future<Bill?> getBillById(String id) async {
    final list = await db.billDao.getPending();
    try {
      return list.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertBill(BillsCompanion bill) {
    return db.billDao.insert(bill);
  }

  Future<void> markPaid(String id) {
    return db.billDao.markPaid(id);
  }

  Future<void> softDeleteBill(String id) {
    return db.billDao.softDelete(id);
  }
}
