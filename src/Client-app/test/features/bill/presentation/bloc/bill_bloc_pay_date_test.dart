import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_state.dart';

/// Ghi lại tham số mà bloc đưa xuống `payBill`.
class _GhiLaiRepository implements BillRepository {
  double? amount;
  DateTime? occurredAt;
  bool daGoi = false;

  @override
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
    double? amount,
    DateTime? occurredAt,
  }) async {
    daGoi = true;
    this.amount = amount;
    this.occurredAt = occurredAt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Bill _bill() => Bill(
      id: 'a',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: 100000,
      startDate: DateTime(2026, 8, 6),
      dueDate: DateTime(2026, 9, 6),
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  test('PayBillEvent.occurredAt đi thẳng xuống payBill', () async {
    final repo = _GhiLaiRepository();
    final bloc = BillBloc(repository: repo);
    addTearDown(bloc.close);

    bloc.add(PayBillEvent(
      bill: _bill(),
      walletId: 'w1',
      idaccount: 10,
      amount: 150000,
      occurredAt: DateTime(2026, 9, 4),
    ));
    await expectLater(bloc.stream, emits(isA<BillOperationSuccess>()));

    expect(repo.daGoi, isTrue);
    expect(repo.amount, 150000);
    expect(repo.occurredAt, DateTime(2026, 9, 4),
        reason: 'Ngày người dùng chọn trên bảng thanh toán phải thành ngày của '
            'khoản chi, không phải ngày bấm nút.');
  });

  test('không truyền occurredAt thì để repository lấy "bây giờ"', () async {
    final repo = _GhiLaiRepository();
    final bloc = BillBloc(repository: repo);
    addTearDown(bloc.close);

    bloc.add(PayBillEvent(bill: _bill(), walletId: 'w1', idaccount: 10));
    await expectLater(bloc.stream, emits(isA<BillOperationSuccess>()));

    expect(repo.occurredAt, isNull);
  });
}
