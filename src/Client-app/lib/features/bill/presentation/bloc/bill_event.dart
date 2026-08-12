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

  PayBillEvent({
    required this.bill,
    required this.walletId,
    required this.idaccount,
  });
}
