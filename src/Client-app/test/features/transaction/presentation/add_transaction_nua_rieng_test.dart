/// FINAL I-1 (gia đình 1B): form THƯỜNG sửa nửa riêng của góp / rút (hàng còn `fundPairId`, đã rời nhà). Canh: không chip
/// Chuyển khoản, không đổi được chi / thu, lưu được khi chưa có danh mục; hàng thường không đổi hành vi.
library;

import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/nha_gia.dart';
import '../../category/presentation/category_test_fakes.dart';

void main() {
  final vi = makeWallet(id: 'cash', name: 'Tiền mặt', balance: 1000000);

  TransactionEntity hang({String? fundPairId}) => TransactionEntity(
        id: 'tx-nua',
        walletId: 'cash',
        idaccount: 10,
        categoryId: null,
        amount: 200000,
        type: 'chi',
        note: 'góp quỹ',
        date: DateTime(2026, 11, 1, 7, 30),
        images: const [],
        syncStatus: 'synced',
        isDeleted: false,
        updatedAt: DateTime(2026, 11, 1),
        fundPairId: fundPairId,
      );

  Widget dung(FakeTransactionRepository repo, TransactionEntity tx) {
    final bloc = TransactionBloc(transactionRepository: repo);
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/start/sua',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, __) => const Scaffold(body: Text('Trang trước')),
          routes: [
            GoRoute(
              path: 'sua',
              builder: (_, __) => AddTransactionPage(
                idaccount: 10,
                laPremium: true,
                wallets: [vi, makeWallet(id: 'v2', name: 'Quỹ')],
                categoryRepository: FakeCategoryRepository(),
                transactionBloc: bloc,
                initial: EditTransactionArgs(transaction: tx, category: null),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    return bocRouterNha(router);
  }

  testWidgets('nửa riêng của cặp: không chip Chuyển khoản', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository(), hang(fundPairId: 'cap-1')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('transaction-type-transfer')), findsNothing,
        reason: 'Transfer kèm idfund_pair bị server từ chối HOUSEHOLD_SCOPE_MISMATCH, hàng kẹt pending');
    expect(find.byKey(const Key('transaction-type-chi')), findsOneWidget, reason: 'phải đòi có, không chỉ đòi vắng');
  });

  testWidgets('nửa riêng của cặp: chạm Thu nhập không đổi chiều, lưu vẫn là chi', (t) async {
    final repo = FakeTransactionRepository();
    await t.pumpWidget(dung(repo, hang(fundPairId: 'cap-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('transaction-type-thu')));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.check));
    await t.pumpAndSettle();
    expect(repo.updated.single.after.type, 'chi', reason: 'đổi chi sang thu đảo góp thành rút');
  });

  testWidgets('nửa riêng của cặp lưu được khi chưa có danh mục', (t) async {
    final repo = FakeTransactionRepository();
    await t.pumpWidget(dung(repo, hang(fundPairId: 'cap-1')));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.check));
    await t.pumpAndSettle();
    expect(repo.updated, hasLength(1), reason: 'không đòi "Vui lòng chọn danh mục" cho nửa của cặp');
    expect(repo.updated.single.after.categoryId, isNull);
    expect(repo.updated.single.after.fundPairId, 'cap-1');
  });

  testWidgets('đối chứng: hàng thường vẫn có chip Chuyển khoản', (t) async {
    await t.pumpWidget(dung(FakeTransactionRepository(), hang()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('transaction-type-transfer')), findsOneWidget,
        reason: 'không có đối chứng này thì ca khoá chiều xanh dù chip vắng vì lý do khác');
  });
}
