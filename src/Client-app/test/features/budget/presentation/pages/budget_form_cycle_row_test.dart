/// Form ngân sách: năm lựa chọn chu kỳ nằm trên MỘT hàng ngang ở 411dp.
///
/// Vì sao cần: trước 2026-09-06 chúng là `Wrap` xếp hai ô mỗi hàng, còn form
/// hoá đơn vừa đổi sang thanh chọn phân đoạn ngang. Bản dựng hình Stitch
/// "Cấu hình Ngân sách" cũng vẽ các chu kỳ trên một hàng chia đều (`flex-1`).
/// Hai form cùng một khái niệm mà hai hình dạng thì người dùng phải học hai
/// lần.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
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

  Future<void> dung(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(categories: danhMuc, editing: null, onSubmit: (_) {}),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('năm chu kỳ nằm trên MỘT hàng ngang, chia đều, không tràn',
      (tester) async {
    await dung(tester);

    final keys = [...BudgetRecurrence.all, null]
        .map((v) => ValueKey('budget-cycle-$v'))
        .toList();
    final o = keys.map((k) => tester.getRect(find.byKey(k))).toList();

    expect(o.map((r) => r.top).toSet(), hasLength(1),
        reason: 'Trước đây là `Wrap` hai ô mỗi hàng. Stitch vẽ các chu kỳ '
            'trên một hàng chia đều, và form hoá đơn đã đổi sang thanh chọn '
            'phân đoạn ngang — ngân sách phải cùng hình dạng.');
    expect(o.map((r) => r.width.round()).toSet(), hasLength(1),
        reason: 'Chia đều bề ngang (`flex-1` trong Stitch).');
    expect(o.last.right, lessThanOrEqualTo(411),
        reason: 'Năm nhãn tiếng Việt ở 411dp là chật; không được tràn mép.');
    expect(tester.takeException(), isNull,
        reason: 'Tràn bố cục được báo qua reportError, không ném ra chỗ gọi.');
  });

  testWidgets('chạm "Ngày cụ thể" theo chữ vẫn chọn được', (tester) async {
    await dung(tester);

    await tester.tap(find.text('Ngày cụ thể'));
    await tester.pumpAndSettle();

    // Ở chế độ "Ngày cụ thể" công tắc lặp lại biến mất — dấu hiệu lựa chọn
    // đã ăn vào state chứ không chỉ đổi màu.
    expect(find.byKey(const ValueKey('budget-recurrence-switch')), findsNothing,
        reason: 'Bộ test cũ của form chạm theo `find.text(...)`; đổi bộ chọn '
            'không được làm gãy đường chạm ấy.');
  });
}
