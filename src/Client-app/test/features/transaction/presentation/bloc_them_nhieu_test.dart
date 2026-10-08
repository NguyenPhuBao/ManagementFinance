/// A5 mục 11.4 — `AddTransactionsEvent`: N giao dịch của một khoản đã tách → MỘT `actionSuccess` (form hiện một toast,
/// đóng một lần). Hai lượt `actionSuccess` là form pop hai lần.
library;

import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  TransactionEntity chi(String id, double tien) => TransactionEntity(
        id: id,
        walletId: 'w',
        idaccount: 1,
        categoryId: 'c$id',
        amount: tien,
        type: 'chi',
        note: 'BHX',
        date: DateTime(2026, 10, 8),
        images: const [],
        syncStatus: 'pending',
        isDeleted: false,
        updatedAt: DateTime(2026, 10, 8),
      );

  test('⭐ 3 giao dịch → repository một lượt addTransactions, đúng MỘT actionSuccess', () async {
    final repo = FakeTransactionRepository();
    final bloc = TransactionBloc(transactionRepository: repo);
    final thanhCong = <TransactionState>[];
    final sub = bloc.stream.listen((s) {
      if (s is TransactionLoadedState && s.actionSuccess == true) thanhCong.add(s);
    });
    bloc.add(AddTransactionsEvent(transactions: [chi('a', 1000), chi('b', 2000), chi('c', 3000)]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.luotThemNhieu, [3]);
    expect(repo.added.length, 3);
    expect(thanhCong.length, 1);
    await sub.cancel();
    await bloc.close();
  });
}
