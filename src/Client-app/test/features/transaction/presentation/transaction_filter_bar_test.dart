import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/transaction/domain/transaction_filter.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/transaction_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Thanh lọc của sổ giao dịch: ô tìm ghi chú + chip loại + chip ví + chip
/// danh mục + nút xoá lọc. Widget chỉ phát `TransactionFilter` mới qua
/// `onChanged`; việc lọc thật nằm ở `applyTransactionFilter` (đã test riêng).
void main() {
  final wallets = [
    makeWallet(id: 'w-cash', name: 'Tiền mặt'),
    makeWallet(id: 'w-save', name: 'Tiết kiệm'),
  ];
  final anUong = makeCategory(id: 'c-food', name: 'Ăn uống');
  final lookup = TransactionLookup(wallets: wallets, categories: [anUong]);

  Future<List<TransactionFilter>> pump(
    WidgetTester tester, {
    TransactionFilter filter = const TransactionFilter(),
    Future<Category?> Function()? pickCategory,
  }) async {
    final emitted = <TransactionFilter>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionFilterBar(
          filter: filter,
          lookup: lookup,
          wallets: wallets,
          onChanged: emitted.add,
          pickCategory: pickCategory ?? () async => null,
        ),
      ),
    ));
    return emitted;
  }

  testWidgets('chip loại phát bộ lọc theo loại', (tester) async {
    final emitted = await pump(tester);

    await tester.tap(find.text('Thu'));
    await tester.pump();

    expect(emitted.single.type, TransactionTypeFilter.thu);
  });

  testWidgets('gõ vào ô tìm kiếm phát query', (tester) async {
    final emitted = await pump(tester);

    await tester.enterText(find.byType(TextField), 'cà phê');
    await tester.pump();

    expect(emitted.last.query, 'cà phê');
  });

  testWidgets('chip ví mở danh sách ví; chọn một ví phát walletId',
      (tester) async {
    final emitted = await pump(tester);

    await tester.tap(find.byKey(const Key('filter-wallet')));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả ví'), findsOneWidget);
    await tester.tap(find.text('Tiết kiệm'));
    await tester.pumpAndSettle();

    expect(emitted.single.walletId, 'w-save');
  });

  testWidgets('đang lọc theo ví thì chip hiện tên ví ấy', (tester) async {
    await pump(tester, filter: const TransactionFilter(walletId: 'w-save'));
    expect(find.text('Tiết kiệm'), findsOneWidget);
  });

  testWidgets('chip danh mục gọi pickCategory và phát categoryId',
      (tester) async {
    final emitted = await pump(tester, pickCategory: () async => anUong);

    await tester.tap(find.byKey(const Key('filter-category')));
    await tester.pumpAndSettle();

    expect(emitted.single.categoryId, 'c-food');
  });

  testWidgets('"Xoá lọc" chỉ hiện khi đang lọc, và trả về bộ lọc rỗng',
      (tester) async {
    expect(
      (await pump(tester)).isEmpty && find.text('Xoá lọc').evaluate().isEmpty,
      isTrue,
      reason: 'Chưa lọc gì thì không có gì để xoá.',
    );

    final emitted = await pump(tester,
        filter: const TransactionFilter(
            type: TransactionTypeFilter.chi, query: 'xăng'));
    await tester.tap(find.text('Xoá lọc'));
    await tester.pump();

    expect(emitted.single.isActive, isFalse);
  });
}
