import '../../../../core/database/app_database.dart';

abstract class BillEvent {}

class LoadBillsEvent extends BillEvent {
  final int idaccount;
  LoadBillsEvent({required this.idaccount});
}

class AddBillEvent extends BillEvent {
  final BillsCompanion bill;
  AddBillEvent({required this.bill});
}

class EditBillEvent extends BillEvent {
  final BillsCompanion bill;
  EditBillEvent({required this.bill});
}

class DeleteBillEvent extends BillEvent {
  final String id;
  DeleteBillEvent({required this.id});
}

class PayBillEvent extends BillEvent {
  final Bill bill;
  final String walletId;
  final int idaccount;

  /// Số tiền thật của kỳ này; `null` = dùng số đã lưu trên hoá đơn.
  final double? amount;

  /// Ngày trả người dùng chọn trên bảng thanh toán; `null` = lúc bấm nút.
  /// Thành `date` của khoản chi — xem `BillRepository.payBill`.
  final DateTime? occurredAt;

  /// Ghi chú riêng của lần trả này; `null`/rỗng = không có.
  final String? note;

  PayBillEvent({
    required this.bill,
    required this.walletId,
    required this.idaccount,
    this.amount,
    this.occurredAt,
    this.note,
  });
}

class UndoPaymentEvent extends BillEvent {
  final String billId;
  UndoPaymentEvent({required this.billId});
}
