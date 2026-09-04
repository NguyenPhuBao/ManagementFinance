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

  /// Đọc thẳng theo khoá chính.
  ///
  /// Trước đây hàm này lọc trong `getPending()`, tức chỉ nhìn thấy những hàng
  /// đang chờ đồng bộ — hoá đơn đã `synced` thì báo là không tồn tại.
  Future<Bill?> getBillById(String id) {
    return db.billDao.getById(id);
  }

  Future<void> insertBill(BillsCompanion bill) {
    return db.billDao.insert(bill);
  }

  /// Chỉ ghi đè những cột có trong [bill] — xem `BillDao.updateFields`.
  Future<void> updateBill(BillsCompanion bill) {
    return db.billDao.updateFields(bill);
  }

  Future<void> markPaid(String id) {
    return db.billDao.markPaid(id);
  }

  Future<void> softDeleteBill(String id) {
    return db.billDao.softDelete(id);
  }
}
