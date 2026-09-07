/// Form ngân sách: ngưỡng phần trăm bằng 0 đến từ backend không được khoá form.
///
/// Vì sao cần: backend đặt `@default(0)` cho `Threshold_Warning_Percent`, nên
/// mọi ngân sách tạo với ô phần trăm để trống đều quay về máy với giá trị 0.
/// Form trước đây điền "0" vào ô rồi tự từ chối lưu vì đòi 1–100 — người dùng
/// không sửa được gì ở ngân sách ấy nữa, kể cả hạn mức. Thấy trên máy ảo
/// 2026-09-06 với một ngân sách vừa tạo sáng hôm đó.
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

  BudgetEntity dangSua({double? thresholdWarningPercent}) => BudgetEntity(
        id: 'b1',
        idaccount: 7,
        categoryId: 'c-an-uong',
        amount: 2000000,
        thresholdWarningPercent: thresholdWarningPercent,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      );

  Future<BudgetDraft?> dungVaLuu(WidgetTester tester,
      {required BudgetEntity editing}) async {
    BudgetDraft? ketQua;
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: editing,
        onSubmit: (d) => ketQua = d,
      ),
    ));
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    return ketQua;
  }

  testWidgets('ngân sách mang ngưỡng phần trăm 0 vẫn lưu lại được',
      (tester) async {
    final draft =
        await dungVaLuu(tester, editing: dangSua(thresholdWarningPercent: 0));

    expect(
      find.text('Phải trong khoảng 1–100'),
      findsNothing,
      reason: 'Số 0 là default của backend chứ không phải người dùng gõ; '
          'báo lỗi ở đây là khoá người dùng khỏi chính ngân sách của họ.',
    );
    expect(draft, isNotNull,
        reason: 'Form phải đóng được với dữ liệu vừa kéo về từ server.');
    expect(
      draft!.thresholdWarningPercent,
      isNull,
      reason: '`BudgetEntity.warningRatio` đã coi ≤ 0 là "không đặt"; form '
          'phải cùng một cách hiểu, đừng gửi lại số 0 để nó lặp vòng nữa.',
    );
  });

  testWidgets('ngưỡng phần trăm thật (80) vẫn được điền sẵn và giữ nguyên',
      (tester) async {
    final draft =
        await dungVaLuu(tester, editing: dangSua(thresholdWarningPercent: 80));

    expect(draft?.thresholdWarningPercent, 80,
        reason: 'Chỉ 0 mới bị coi là trống; giá trị hợp lệ không được mất.');
  });

  testWidgets('lựa chọn "Chặn" nói rõ là hỏi trước khi ghi, không từ chối ghi',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: dangSua(),
        onSubmit: (_) {},
      ),
    ));

    expect(
      find.text('Hỏi trước khi ghi khoản làm vượt', skipOffstage: false),
      findsOneWidget,
      reason: 'Từ 2026-09-06 "Chặn" = hỏi xác nhận rồi vẫn ghi (tiền đã tiêu '
          'thật). Nhãn cũ "không cho tiêu thêm" hứa một điều app không làm.',
    );
    expect(find.textContaining('không cho tiêu thêm', skipOffstage: false),
        findsNothing);
  });
}
