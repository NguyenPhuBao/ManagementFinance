import '../../../../core/database/app_database.dart';

abstract class BillRepository {
  Stream<List<Bill>> watchBills(int idaccount);
  Future<List<Bill>> getBills(int idaccount);
  Future<void> addBill(BillsCompanion bill);
  Future<void> editBill(BillsCompanion bill);
  Future<void> deleteBill(String id);
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
  });
}
