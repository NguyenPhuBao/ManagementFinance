/// Form ngân sách gợi ý hạn mức từ chi tiêu ba tháng trước của danh mục.
///
/// Vì sao cần: người mới đặt hạn mức thường đoán một con số tròn, rồi thấy
/// ngân sách vượt ngay tháng đầu. Spendee và Money Lover đều nhắc "tháng
/// trước bạn chi X". Gợi ý đi qua callback tiêm vào form — form vẫn không đọc
/// cubit, giữ được widget test thuần như mọi phép kiểm khác của nó.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_form.dart';

void main() {
  final danhMuc = [
    Category(
      id: 'c-an-uong',
      idaccount: 7,
      name: 'Ăn uống',
      classify: 'chi',
      icon: 'restaurant',
      colour: '#F25F5C',
      isDefault: false,
      isGroup: false,
      isLocalOnly: false,
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    ),
  ];

  Future<void> dung(
    WidgetTester tester, {
    Future<double?> Function(String categoryId)? suggestFor,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: null,
        onSubmit: (_) {},
        suggestFor: suggestFor,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> chonAnUong(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('budget-category')));
    await tester.pumpAndSettle();
    // Mục trong menu vừa mở, không phải nhãn trên nút.
    await tester.tap(find.text('Ăn uống').last);
    await tester.pumpAndSettle();
  }

  testWidgets('chọn danh mục thì hiện gợi ý theo chi tiêu ba tháng trước',
      (tester) async {
    final hoi = <String>[];
    await dung(tester, suggestFor: (id) async {
      hoi.add(id);
      return 1200000;
    });
    await chonAnUong(tester);

    expect(hoi, ['c-an-uong']);
    expect(find.textContaining('1.200.000'), findsOneWidget,
        reason: 'Gợi ý phải nêu con số, đây không phải banner tạm thời.');
    expect(find.text('Dùng số này'), findsOneWidget);
  });

  testWidgets('bấm "Dùng số này" thì ô hạn mức nhận đúng con số', (tester) async {
    await dung(tester, suggestFor: (_) async => 1200000);
    await chonAnUong(tester);

    await tester.tap(find.text('Dùng số này'));
    await tester.pumpAndSettle();

    final o = tester.widget<TextFormField>(
        find.byKey(const ValueKey('budget-amount')));
    expect(o.controller?.text, '1200000',
        reason: 'Ô nhận số thô (không dấu chấm) như khi người dùng tự gõ, để '
            '`CurrencyFormatter.parse` đọc được lúc lưu.');
  });

  testWidgets('không có dữ liệu ba tháng trước thì không hiện gì', (tester) async {
    await dung(tester, suggestFor: (_) async => null);
    await chonAnUong(tester);

    expect(find.text('Dùng số này'), findsNothing);
    expect(find.textContaining('3 tháng gần nhất'), findsNothing,
        reason: 'Một dòng "trung bình 0 đ" là gợi ý sai, tệ hơn không gợi ý.');
  });

  testWidgets('không tiêm callback thì form vẫn như cũ', (tester) async {
    await dung(tester);
    await chonAnUong(tester);

    expect(find.text('Dùng số này'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
