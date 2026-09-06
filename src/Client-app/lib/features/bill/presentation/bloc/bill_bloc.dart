import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/bill_repository.dart';
import '../../domain/bill_status.dart';
import 'bill_event.dart';
import 'bill_state.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  final BillRepository repository;

  /// Đồng hồ cho phép tiêm — thẻ tổng chỉ tính hoá đơn tới hết tháng này, nên
  /// test không được phụ thuộc ngày chạy.
  final DateTime Function() now;

  BillBloc({required this.repository, DateTime Function()? now})
      : now = now ?? DateTime.now,
        super(BillInitial()) {
    on<LoadBillsEvent>(_onLoadBills);
    on<AddBillEvent>(_onAddBill);
    on<EditBillEvent>(_onEditBill);
    on<DeleteBillEvent>(_onDeleteBill);
    on<PayBillEvent>(_onPayBill);
  }

  Future<void> _onLoadBills(
    LoadBillsEvent event,
    Emitter<BillState> emit,
  ) async {
    emit(BillLoading());
    await emit.forEach<List<Bill>>(
      repository.watchBills(event.idaccount),
      onData: (bills) => BillLoaded(
        bills: bills,
        // Trước đây cộng dồn `isPaid != true` trên TOÀN BỘ danh sách: bỏ sót
        // cột `payStatus` (hàng cũ mang 'Payed' với `isPaid` false vẫn bị tính
        // là nợ) và gộp cả kỳ của những tháng sau vào "tiền cần thanh toán".
        summary: summarizeBills(bills, now()),
      ),
      onError: (error, stackTrace) => BillError('Không thể tải hóa đơn: $error'),
    );
  }

  Future<void> _onAddBill(
    AddBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.addBill(event.bill);
      emit(BillOperationSuccess('Tạo hóa đơn thành công'));
    } catch (e) {
      emit(BillError('Không thể tạo hóa đơn: $e'));
    }
  }

  Future<void> _onEditBill(
    EditBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.editBill(event.bill);
      emit(BillOperationSuccess('Cập nhật hóa đơn thành công'));
    } catch (e) {
      emit(BillError('Không thể cập nhật hóa đơn: $e'));
    }
  }

  Future<void> _onDeleteBill(
    DeleteBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.deleteBill(event.id);
      emit(BillOperationSuccess('Xóa hóa đơn thành công'));
    } catch (e) {
      emit(BillError('Không thể xóa hóa đơn: $e'));
    }
  }

  Future<void> _onPayBill(
    PayBillEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.payBill(
        bill: event.bill,
        walletId: event.walletId,
        idaccount: event.idaccount,
      );
      emit(BillOperationSuccess('Thanh toán hóa đơn thành công'));
    } on BillAlreadyPaidException {
      // Không phải sự cố kỹ thuật — chỉ là người dùng bấm nút hai lần, hoặc
      // hoá đơn đã được trả trên máy khác rồi đồng bộ về.
      emit(BillError('Hóa đơn này đã được thanh toán rồi.'));
    } catch (e) {
      emit(BillError('Thanh toán thất bại: $e'));
    }
  }

}
