import '../../../../core/database/app_database.dart';

/// Ném ra khi [BillRepository.payBill] được gọi trên một hoá đơn mà CSDL đã
/// ghi nhận là đã thanh toán.
///
/// Cần một ngoại lệ riêng vì UI truyền vào đối tượng `Bill` nó đang giữ — một
/// ảnh chụp có thể đã cũ. Bấm nút hai lần thì lần thứ hai vẫn mang `isPaid =
/// false`, nên trạng thái thật phải đọc lại từ CSDL chứ không tin tham số.
class BillAlreadyPaidException implements Exception {
  final String billId;
  const BillAlreadyPaidException(this.billId);

  @override
  String toString() => 'Hoá đơn $billId đã được thanh toán trước đó.';
}

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
