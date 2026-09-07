import '../../../../core/database/app_database.dart';
import '../../domain/bill_status.dart';

abstract class BillState {}

class BillInitial extends BillState {}

class BillLoading extends BillState {}

class BillLoaded extends BillState {
  final List<Bill> bills;

  /// Số liệu của **kỳ này** cho thẻ tổng đầu trang — xem [summarizeBills].
  final BillSummary summary;

  /// Khoản chi của từng hoá đơn đã trả, theo `billId`. Hoá đơn không có mục
  /// ở đây là "không biết ngày trả" (hàng kéo về từ server, hoặc trả bằng bản
  /// app trước v16) — trang không được đoán.
  final Map<String, Transaction> payments;

  BillLoaded({
    required this.bills,
    required this.summary,
    this.payments = const {},
  });

  /// Giữ tên cũ để nơi gọi không phải đổi: nay chỉ là lối tắt vào [summary].
  double get totalUnpaidAmount => summary.unpaidAmount;
  int get unpaidCount => summary.unpaidCount;
}

class BillOperationSuccess extends BillState {
  final String message;
  BillOperationSuccess(this.message);
}

class BillError extends BillState {
  final String message;
  BillError(this.message);
}
