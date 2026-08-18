import '../../../../core/database/app_database.dart';

abstract class BillState {}

class BillInitial extends BillState {}

class BillLoading extends BillState {}

class BillLoaded extends BillState {
  final List<Bill> bills;
  final double totalUnpaidAmount;
  final int unpaidCount;

  BillLoaded({
    required this.bills,
    required this.totalUnpaidAmount,
    required this.unpaidCount,
  });
}

class BillOperationSuccess extends BillState {
  final String message;
  BillOperationSuccess(this.message);
}

class BillError extends BillState {
  final String message;
  BillError(this.message);
}
