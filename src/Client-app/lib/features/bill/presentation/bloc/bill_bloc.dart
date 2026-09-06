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
    on<UndoPaymentEvent>(_onUndoPayment);
  }

  Future<void> _onLoadBills(
    LoadBillsEvent event,
    Emitter<BillState> emit,
  ) async {
    emit(BillLoading());

    // Mỗi lần danh sách đổi thì đọc lại bản đồ khoản chi CÙNG LÚC: trả xong
    // trên chính trang này thì ngày trả phải hiện ngay. Đọc một lần chứ
    // không giữ thêm một stream Drift — thứ để lại `Timer` khi huỷ và làm mọi
    // widget test của trang treo.
    //
    // KHÔNG viết thành `watchBills().asyncMap(...)`: `asyncMap` tạm dừng
    // nguồn trong lúc chờ, và với stream một lần (`Stream.value` của stub
    // trong widget test) chạy dưới FakeAsync thì sự kiện `done` bị nuốt —
    // `emit.forEach` không bao giờ kết thúc, `bloc.close()` treo vĩnh viễn và
    // cả ba file widget test của trang đứng đủ 10 phút mỗi test. Đo được
    // 2026-09-06 bằng thăm dò FakeAsync: `await for` và `listen` thường thì
    // nhận `done`, `asyncMap` (kể cả map đồng bộ) thì không.
    var luot = 0;
    var dangDoc = Future<void>.value();
    await emit.onEach<List<Bill>>(
      repository.watchBills(event.idaccount),
      onData: (bills) {
        final luotNay = ++luot;
        dangDoc = repository.paymentsOf(event.idaccount).then(
          (payments) {
            // Danh sách đã đổi tiếp trong lúc chờ, hoặc bloc đã đóng: bỏ,
            // kẻo bản đồ cũ đè lên trạng thái mới.
            if (luotNay != luot || emit.isDone) return;
            emit(BillLoaded(
              bills: bills,
              // Trước đây cộng dồn `isPaid != true` trên TOÀN BỘ danh sách:
              // bỏ sót cột `payStatus` (hàng cũ mang 'Payed' với `isPaid`
              // false vẫn bị tính là nợ) và gộp cả kỳ của những tháng sau
              // vào "tiền cần thanh toán".
              summary: summarizeBills(bills, now()),
              payments: payments,
            ));
          },
          onError: (Object error) {
            if (!emit.isDone) emit(BillError('Không thể tải hóa đơn: $error'));
          },
        );
      },
      onError: (error, stackTrace) =>
          emit(BillError('Không thể tải hóa đơn: $error')),
    );
    // Nguồn đóng (stub trong test) trước khi lần đọc cuối xong thì chờ nốt:
    // `emit` sau khi handler đã trả về là lỗi.
    await dangDoc;
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
        amount: event.amount,
      );
      emit(BillOperationSuccess('Thanh toán hóa đơn thành công'));
    } on BillAlreadyPaidException {
      // Không phải sự cố kỹ thuật — chỉ là người dùng bấm nút hai lần, hoặc
      // hoá đơn đã được trả trên máy khác rồi đồng bộ về.
      emit(BillError('Hóa đơn này đã được thanh toán rồi.'));
    } on BillInvalidAmountException {
      emit(BillError('Số tiền thanh toán phải lớn hơn 0.'));
    } catch (e) {
      emit(BillError('Thanh toán thất bại: $e'));
    }
  }

  Future<void> _onUndoPayment(
    UndoPaymentEvent event,
    Emitter<BillState> emit,
  ) async {
    try {
      await repository.undoPayment(billId: event.billId);
      emit(BillOperationSuccess('Đã hoàn tác thanh toán'));
    } on BillNotPaidException {
      emit(BillError('Hóa đơn này chưa được thanh toán.'));
    } on BillUndoUnavailableException {
      // Lý do cụ thể, không phải lỗi chung chung: khoản chi được ghi bằng bản
      // app cũ nên không có sợi dây `billId` để lần về.
      emit(BillError(
          'Không hoàn tác được: khoản chi của lần thanh toán này được ghi '
          'bằng bản ứng dụng cũ. Hãy xoá nó thủ công ở sổ giao dịch.'));
    } catch (e) {
      emit(BillError('Hoàn tác thất bại: $e'));
    }
  }
}
