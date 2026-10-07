/// Trang chi tiết ngân sách phải chứa đủ bốn khối và không tràn ở 411dp.
///
/// Vì sao cần: Flutter báo tràn qua `FlutterError.reportError` chứ không ném
/// ra chỗ gọi, nên test chỉ `pumpWidget` + `find` vẫn xanh khi màn hình đầy
/// sọc vàng. Phải dựng ở đúng bề rộng điện thoại và bắt bằng `takeException`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_history.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flowmoney/features/budget/domain/nhip_chi.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_detail_cubit.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_detail_view.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';

import '../../domain/nhip_chi_mau.dart';

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
    NhipChi? nhipChi,
  }) {
    final view0 = v ?? view();
    return BudgetDetailLoaded(
      view: view0,
      pace: budgetPaceOf(view0.budget, now, nhipChi: nhipChi),
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
    expect(find.textContaining(RegExp(r'còn\s16\sngày')), findsOneWidget);
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
    // `scrollUntilVisible` dừng khi dòng mới ló mép khung — ô NHỊP CHI cao thêm
    // một hàng (2026-10-04) là tâm dòng rơi ra ngoài và cú chạm trượt, im lặng.
    await tester.ensureVisible(find.byKey(const ValueKey('budget-tx-t2')));
    await tester.pumpAndSettle();
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

  Future<void> dung360(WidgetTester tester, BudgetDetailLoaded state) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: BudgetDetailView(
          state: state, onEdit: null, onTapTransaction: (_) {}),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có nhịp riêng → "Theo thời gian đã trôi", không tràn ở 360dp',
      (tester) async {
    await dung360(tester, loaded());
    expect(find.textContaining('Theo thời gian đã trôi'), findsOneWidget);
    expect(find.textContaining('Theo nhịp thường lệ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('⭐ có nhịp riêng → "Theo nhịp thường lệ", không tràn ở 360dp',
      (tester) async {
    await dung360(tester, loaded(nhipChi: nhipAnUong()));
    expect(find.textContaining('Theo nhịp thường lệ'), findsOneWidget);
    expect(find.textContaining('Theo thời gian đã trôi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Nghiệm thu Realme 360 dp 2026-10-04: chip "Chậm hơn dự kiến" đứng cùng hàng
  // làm dòng "Theo thời gian đã trôi: 53.824 đ" bị cắt thành "…" — mất đúng con
  // số. Người dùng chọn đưa dòng xuống hàng riêng dưới chip, đọc trọn.
  testWidgets('dòng "Theo …: X" nằm DƯỚI chip và không bị cắt ở 360dp',
      (tester) async {
    await dung360(tester, loaded(v: view(spent: 0)));
    final chip = find.text('Chậm hơn dự kiến');
    final dong = find.textContaining('Theo thời gian đã trôi');
    expect(chip, findsOneWidget);
    expect(tester.getRect(dong).top,
        greaterThanOrEqualTo(tester.getRect(chip).bottom),
        reason: 'cùng hàng với chip thì dòng chỉ còn phần bề rộng thừa');
    expect(tester.renderObject<RenderParagraph>(dong).didExceedMaxLines,
        isFalse,
        reason: 'bị cắt "…" là mất con số — `find.text` so `data` nên không '
            'thấy, phải hỏi chính RenderParagraph');
    expect(tester.takeException(), isNull);
  });
}
