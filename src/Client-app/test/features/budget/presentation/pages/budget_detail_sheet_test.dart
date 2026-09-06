/// Bảng chi tiết ngân sách phải cuộn được, không tràn khung.
///
/// Vì sao cần: bảng này là bottom sheet, chiều cao do màn hình quyết định chứ
/// không do nội dung. Ngân sách có ghi chú dài, có ngày kết thúc, hoặc mở trên
/// máy màn hình thấp là số dòng vượt chỗ trống — Flutter ném lỗi layout và
/// phần cuối bị cắt mất, người dùng không đọc được.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_detail_sheet.dart';

void main() {
  BudgetView view({String note = ''}) {
    return BudgetView(
      budget: BudgetEntity(
        id: 'b1',
        idaccount: 7,
        categoryId: 'c1',
        amount: 2000000,
        spent: 1350000,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 10, 1),
        recurrence: true,
        note: note,
        updatedAt: DateTime(2026, 9, 4),
      ),
      categoryName: 'Ăn uống',
    );
  }

  Future<void> dungTrongKhung(
    WidgetTester tester,
    Size khung, {
    String note = '',
  }) async {
    tester.view.physicalSize = khung;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BudgetDetailSheet(view: view(note: note))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('không tràn khung trên màn hình thấp', (tester) async {
    await dungTrongKhung(tester, const Size(500, 320));

    expect(
      tester.takeException(),
      isNull,
      reason: 'Khung 320px là đúng kích thước đã gây "RenderFlex overflowed by '
          '5.9 pixels" ngày 2026-09-04. Column thẳng không cuộn được thì nội '
          'dung dài hơn chỗ trống là mất luôn phần cuối.',
    );
  });

  testWidgets('ghi chú dài cũng không làm tràn', (tester) async {
    await dungTrongKhung(
      tester,
      const Size(500, 320),
      note: 'Ghi chú rất dài để kiểm tra rằng nội dung do người dùng nhập '
          'không thể làm vỡ bố cục: tiền chợ, tiền cà phê, tiền ăn trưa với '
          'đồng nghiệp, và các khoản lặt vặt khác trong tháng.',
    );

    expect(tester.takeException(), isNull,
        reason: 'Độ dài ghi chú do người dùng quyết định — bố cục không được '
            'phụ thuộc vào việc họ viết ngắn hay dài.');
  });

  testWidgets('hiện đủ các mục chính', (tester) async {
    await dungTrongKhung(tester, const Size(500, 800));

    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.textContaining('Hạn mức'), findsOneWidget);
    expect(find.textContaining('Còn dư'), findsOneWidget,
        reason: 'Đã tiêu 1.350.000 trên hạn mức 2.000.000 nên chưa vượt — nhãn '
            'phải là "Còn dư", không phải "Vượt".');
  });
}
