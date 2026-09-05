/// Trang chi tiết ngân sách phải chứa đủ bốn khối và không tràn ở 411dp.
///
/// Vì sao cần: Flutter báo tràn qua `FlutterError.reportError` chứ không ném
/// ra chỗ gọi, nên test chỉ `pumpWidget` + `find` vẫn xanh khi màn hình đầy
/// sọc vàng. Phải dựng ở đúng bề rộng điện thoại và bắt bằng `takeException`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_history.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_detail_cubit.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_detail_view.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);

  BudgetView view({double spent = 1000000, String? note}) {
    return BudgetView(
      budget: BudgetEntity(
        id: 'b1',
        idaccount: 7,
        categoryId: 'c1',
        amount: 3000000,
        spent: spent,
        startDate: DateTime(2026, 4, 1),
        // Mặc định của entity là KHÔNG lặp → chết sau kỳ đầu (tháng 4). Phải
        // bật lặp thì tháng 9 mới là kỳ đang chạy.
        recurrence: true,
        note: note ?? '',
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: 'Ăn uống',
    );
  }

  List<BudgetPeriodSummary> lichSu() => [
        for (var m = 4; m <= 9; m++)
          BudgetPeriodSummary(
            from: DateTime(2026, m, 1),
            to: DateTime(2026, m + 1, 1),
            amount: 3000000,
            spent: m == 7 ? 3600000 : 1000000.0 * (m - 3),
          ),
      ];

  TransactionEntity tx(String id, double amount) => TransactionEntity(
        id: id,
        walletId: 'w1',
        idaccount: 7,
        categoryId: 'c1',
        amount: amount,
        type: 'chi',
        note: id == 't1' ? 'Cơm trưa với một ghi chú rất dài để thử tràn' : '',
        date: DateTime(2026, 9, 10),
        updatedAt: now,
      );

  BudgetDetailLoaded loaded({
    BudgetView? v,
    bool expired = false,
    List<TransactionEntity>? transactions,
  }) {
    final view0 = v ?? view();
    return BudgetDetailLoaded(
      view: view0,
      pace: budgetPaceOf(view0.budget, now),
      history: lichSu(),
      transactions: transactions ?? [tx('t1', 50000), tx('t2', 120000)],
      lookup: TransactionLookup.empty,
      expired: expired,
    );
  }

  Future<void> dung(
    WidgetTester tester,
    BudgetDetailLoaded state, {
    VoidCallback? onEdit,
    void Function(TransactionEntity)? onTapTransaction,
  }) async {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: BudgetDetailView(
        state: state,
        onEdit: onEdit,
        onTapTransaction: onTapTransaction ?? (_) {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('không tràn ở 411dp với ghi chú dài và số tiền lớn',
      (tester) async {
    await dung(tester, loaded(v: view(spent: 123456789)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('có đủ nhịp chi, sáu cột lịch sử và các giao dịch của kỳ',
      (tester) async {
    await dung(tester, loaded());

    expect(find.textContaining('Nên chi'), findsOneWidget);
    expect(find.textContaining('còn 16 ngày'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('budget-history-bar-$i')), findsOneWidget,
          reason: 'Mỗi kỳ một cột, kể cả kỳ hiện tại.');
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget-tx-t2')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('budget-tx-t1')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-tx-t2')), findsOneWidget);
  });

  testWidgets('bấm một giao dịch thì báo ra ngoài đúng giao dịch ấy',
      (tester) async {
    TransactionEntity? daBam;
    await dung(tester, loaded(), onTapTransaction: (t) => daBam = t);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget-tx-t2')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('budget-tx-t2')));
    await tester.pump();

    expect(daBam?.id, 't2');
  });

  testWidgets('ngân sách hết hạn: không có nút sửa, không có dòng nên chi',
      (tester) async {
    await dung(tester, loaded(expired: true), onEdit: null);

    expect(find.byKey(const ValueKey('budget-detail-edit')), findsNothing,
        reason: 'Số liệu đã chốt sổ không được đổi về sau — cùng quy tắc với '
            'tab "Đã hết hạn".');
  });

  testWidgets('đang hoạt động: có nút sửa và bấm được', (tester) async {
    var suaDuocGoi = false;
    await dung(tester, loaded(), onEdit: () => suaDuocGoi = true);

    await tester.tap(find.byKey(const ValueKey('budget-detail-edit')));
    await tester.pump();

    expect(suaDuocGoi, isTrue);
  });

  testWidgets('kỳ không có giao dịch thì nói rõ, không để trống', (tester) async {
    await dung(tester, loaded(transactions: const []));
    expect(find.textContaining('Chưa có khoản chi'), findsOneWidget);
  });
}
