import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/bill_repository.dart';
import 'bill_event.dart';
import 'bill_state.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  final BillRepository repository;
  StreamSubscription? _subscription;

  BillBloc({required this.repository}) : super(BillInitial()) {
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
      onData: (bills) {
        final unpaidBills = bills.where((b) => b.isPaid != true);
        final totalUnpaid = unpaidBills.fold(
          0.0,
          (sum, b) => sum + b.amount,
        );
        return BillLoaded(
          bills: bills,
          totalUnpaidAmount: totalUnpaid,
          unpaidCount: unpaidBills.length,
        );
      },
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
    } catch (e) {
      emit(BillError('Thanh toán thất bại: $e'));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
