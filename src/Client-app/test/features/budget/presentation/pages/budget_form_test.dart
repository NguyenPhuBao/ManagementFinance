/// Form ngân sách: mốc neo chu kỳ phải đi được từ ô chọn xuống bản ghi.
///
/// Vì sao cần: mốc neo lưu ở cột `Nexttime_recurrence`. Quên tính nó khi lưu
/// thì form vẫn đóng lại bình thường, ngân sách vẫn tạo được, chỉ có chu kỳ âm
/// thầm neo vào ngày bắt đầu thay vì mốc người dùng chọn — không exception,
/// không log, và người dùng chỉ phát hiện ra sau vài kỳ khi số liệu lệch.
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

  Future<BudgetDraft?> dungVaLuu(
    WidgetTester tester, {
    BudgetEntity? editing,
    Future<void> Function(WidgetTester)? truocKhiLuu,
  }) async {
    BudgetDraft? ketQua;
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: editing,
        onSubmit: (d) => ketQua = d,
      ),
    ));
    await truocKhiLuu?.call(tester);
    // Bấm nút "Lưu" trên thanh tiêu đề: nó luôn hiển thị, còn nút ở cuối form
    // nằm ngoài khung màn hình test nên cú chạm không tới nơi.
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    return ketQua;
  }

  BudgetEntity dangSua({
    DateTime? startDate,
    DateTime? endDate,
    bool recurrence = true,
    DateTime? nextTimeRecurrence,
    String timeRecurrence = BudgetRecurrence.month,
  }) {
    return BudgetEntity(
      id: 'b1',
      idaccount: 7,
      categoryId: 'c-an-uong',
      amount: 2000000,
      startDate: startDate ?? DateTime(2026, 9, 15),
      endDate: endDate,
      recurrence: recurrence,
      timeRecurrence: timeRecurrence,
      nextTimeRecurrence: nextTimeRecurrence,
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  testWidgets('tắt công tắc lặp lại thì draft ghi recurrence = false',
      (tester) async {
    final draft = await dungVaLuu(
      tester,
      editing: dangSua(),
      truocKhiLuu: (t) async {
        await t.tap(find.byKey(const ValueKey('budget-recurrence-switch')));
        await t.pumpAndSettle();
      },
    );

    expect(draft?.recurrence, isFalse,
        reason: 'Đây là công tắc quyết định ngân sách có hết hạn hay không.');
  });

  testWidgets('không chọn danh mục thì không lưu được', (tester) async {
    BudgetDraft? ketQua;
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: null,
        onSubmit: (d) => ketQua = d,
      ),
    ));

    // Điền hạn mức hợp lệ nhưng bỏ trống danh mục.
    await tester.enterText(
        find.byKey(const ValueKey('budget-amount')), '500000');
    // Nút "Lưu" trên thanh tiêu đề luôn hiển thị, không cần cuộn.
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(
      ketQua,
      isNull,
      reason: 'Đường ghi ở repository cũng chặn, nhưng để form gửi đi rồi mới '
          'báo lỗi thì người dùng nhận một snackbar đỏ thay vì thấy ô nào còn '
          'thiếu.',
    );
    expect(find.textContaining('Hãy chọn danh mục'), findsOneWidget);
  });

  testWidgets('bật lặp lại thì ngày kết thúc để trống — ngân sách chạy mãi',
      (tester) async {
    final draft = await dungVaLuu(tester, editing: dangSua(recurrence: true));

    expect(
      draft?.endDate,
      isNull,
      reason: 'Tu dien ngay ket thuc khi dang bat lap lai se lam cong tac do '
          'thanh vo nghia: ngan sach nao cung chet sau dung mot ky.',
    );
  });

  testWidgets('tắt lặp lại thì ngày kết thúc tự điền = bắt đầu + một chu kỳ',
      (tester) async {
    final draft = await dungVaLuu(
      tester,
      editing: dangSua(startDate: DateTime(2026, 9, 15)),
      truocKhiLuu: (t) async {
        await t.tap(find.byKey(const ValueKey('budget-recurrence-switch')));
        await t.pumpAndSettle();
      },
    );

    expect(
      draft?.endDate,
      DateTime(2026, 10, 15),
      reason: 'Anh yêu cầu: chọn ngày bắt đầu và loại chu kỳ thì hệ thống tự '
          'tính ra ngày kết thúc. Để null ở đây thì ngân sách một-kỳ không có '
          'điểm dừng nào hiện trên màn hình.',
    );
  });

  testWidgets('đổi loại chu kỳ thì ngày kết thúc tự tính lại', (tester) async {
    final draft = await dungVaLuu(
      tester,
      editing: dangSua(startDate: DateTime(2026, 9, 15)),
      truocKhiLuu: (t) async {
        await t.tap(find.byKey(const ValueKey('budget-recurrence-switch')));
        await t.pumpAndSettle();
        await t.tap(find.text('Hàng quý'));
        await t.pumpAndSettle();
      },
    );

    expect(
      draft?.endDate,
      DateTime(2026, 12, 15),
      reason: 'Đổi chu kỳ mà ngày kết thúc đứng yên thì nó nói dối: người dùng '
          'thấy "hàng quý" nhưng ngân sách vẫn chết sau một tháng.',
    );
  });

  testWidgets('"Ngày cụ thể": không lưu được khi ngày kết thúc TRÙNG ngày bắt đầu',
      (tester) async {
    BudgetDraft? ketQua;
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: BudgetEntity(
          id: 'b1',
          idaccount: 7,
          categoryId: 'c-an-uong',
          amount: 2000000,
          startDate: DateTime(2026, 9, 4),
          endDate: DateTime(2026, 9, 4),
          timeRecurrence: null,
          updatedAt: DateTime(2026, 9, 4),
        ),
        onSubmit: (d) => ketQua = d,
      ),
    ));

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(
      ketQua,
      isNull,
      reason: 'PostgreSQL có ràng buộc chk_budget_end_after_start = '
          '("End" IS NULL OR "End" > "Start") — BẰNG nhau cũng vi phạm. Để lọt '
          'thì backend từ chối, client xếp lỗi vào transient và đẩy lại vĩnh '
          'viễn, kéo chậm toàn bộ hàng đợi đồng bộ.',
    );
    expect(find.textContaining('sau ngày bắt đầu'), findsOneWidget,
        reason: 'Người dùng phải thấy ô nào sai ngay trên form.');
  });

  testWidgets('"Ngày cụ thể": không lưu được khi ngày kết thúc TRƯỚC ngày bắt đầu',
      (tester) async {
    BudgetDraft? ketQua;
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: BudgetEntity(
          id: 'b1',
          idaccount: 7,
          categoryId: 'c-an-uong',
          amount: 2000000,
          startDate: DateTime(2026, 9, 20),
          endDate: DateTime(2026, 9, 4),
          timeRecurrence: null,
          updatedAt: DateTime(2026, 9, 4),
        ),
        onSubmit: (d) => ketQua = d,
      ),
    ));

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(ketQua, isNull,
        reason: 'Đổi ngày bắt đầu vượt qua ngày kết thúc là cách dễ rơi vào '
            'trạng thái này nhất: ô ngày bắt đầu không hề bị chặn trên.');
  });

  testWidgets('"Ngày cụ thể": ngày kết thúc sau ngày bắt đầu thì lưu bình thường',
      (tester) async {
    BudgetDraft? ketQua;
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: BudgetEntity(
          id: 'b1',
          idaccount: 7,
          categoryId: 'c-an-uong',
          amount: 2000000,
          startDate: DateTime(2026, 9, 4),
          endDate: DateTime(2026, 10, 4),
          timeRecurrence: null,
          updatedAt: DateTime(2026, 9, 4),
        ),
        onSubmit: (d) => ketQua = d,
      ),
    ));

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(ketQua?.endDate, DateTime(2026, 10, 4),
        reason: 'Phép kiểm mới không được chặn nhầm trường hợp hợp lệ.');
  });

  group('Lựa chọn "Ngày cụ thể"', () {
    testWidgets('có mặt trong dãy chu kỳ', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BudgetForm(
          categories: danhMuc,
          editing: dangSua(),
          onSubmit: (_) {},
        ),
      ));

      expect(find.text('Ngày cụ thể'), findsOneWidget,
          reason: 'Đây là đường duy nhất để đặt ngày kết thúc không rơi đúng '
              'mốc chu kỳ nào.');
    });

    testWidgets('chọn nó thì draft không mang chu kỳ nào', (tester) async {
      final draft = await dungVaLuu(
        tester,
        editing: dangSua(
          startDate: DateTime(2026, 9, 4),
          endDate: DateTime(2026, 11, 20),
        ),
        truocKhiLuu: (t) async {
          await t.tap(find.text('Ngày cụ thể'));
          await t.pumpAndSettle();
        },
      );

      expect(
        draft?.timeRecurrence,
        isNull,
        reason: 'Backend biểu diễn "không theo chu kỳ" bằng Time_recurrence = '
            'NULL, và ràng buộc chk_budget_time_recurrence đã cho phép. Gửi '
            "'Month' ở đây là bịa ra một chu kỳ người dùng không chọn.",
      );
      expect(draft?.endDate, isNotNull,
          reason: 'Không có chu kỳ thì ngày kết thúc là thứ duy nhất cho biết '
              'ngân sách chạy tới bao giờ.');
    });

    testWidgets('ẩn công tắc lặp lại — không có chu kỳ thì lặp bằng gì',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BudgetForm(
          categories: danhMuc,
          editing: dangSua(
            startDate: DateTime(2026, 9, 4),
            endDate: DateTime(2026, 11, 20),
          ),
          onSubmit: (_) {},
        ),
      ));
      await tester.tap(find.text('Ngày cụ thể'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('budget-recurrence-switch')),
        findsNothing,
        reason: 'Để công tắc lại thì người dùng bật được "lặp lại" cho một '
            'ngân sách không có chu kỳ — không có gì để lặp, và bản ghi lưu '
            'xuống sẽ mâu thuẫn với chính nó.',
      );
    });

    testWidgets('mở lại ngân sách không chu kỳ thì nút đó sáng', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BudgetForm(
          categories: danhMuc,
          editing: BudgetEntity(
            id: 'b1',
            idaccount: 7,
            categoryId: 'c-an-uong',
            amount: 2000000,
            startDate: DateTime(2026, 9, 4),
            endDate: DateTime(2026, 11, 20),
            timeRecurrence: null,
            updatedAt: DateTime(2026, 9, 4),
          ),
          onSubmit: (_) {},
        ),
      ));

      expect(find.byKey(const ValueKey('budget-recurrence-switch')), findsNothing,
          reason: 'Dựng lại đúng trạng thái đã lưu: chu kỳ null nghĩa là "Ngày '
              'cụ thể", nên công tắc lặp lại không được hiện.');
    });

    testWidgets('quay lại một chu kỳ thì ngày kết thúc tự tính lại',
        (tester) async {
      final draft = await dungVaLuu(
        tester,
        editing: dangSua(startDate: DateTime(2026, 9, 4)),
        truocKhiLuu: (t) async {
          await t.tap(find.text('Ngày cụ thể'));
          await t.pumpAndSettle();
          await t.tap(find.text('Hàng tháng'));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('budget-recurrence-switch')));
          await t.pumpAndSettle();
        },
      );

      expect(draft?.timeRecurrence, BudgetRecurrence.month);
      expect(draft?.endDate, DateTime(2026, 10, 4),
          reason: 'Đổi từ "Ngày cụ thể" về một chu kỳ thì ngày kết thúc phải '
              'bám lại theo chu kỳ, không giữ ngày cũ người dùng từng chọn.');
    });
  });

  testWidgets('không còn ô chọn mốc chốt sổ', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BudgetForm(
        categories: danhMuc,
        editing: dangSua(),
        onSubmit: (_) {},
      ),
    ));

    expect(
      find.textContaining('Chốt sổ vào'),
      findsNothing,
      reason: 'Ngày bắt đầu đã đóng vai mốc chu kỳ. Giữ thêm một ô nữa làm '
          'cùng việc đó thì người dùng phải tự đoán hai ô khác nhau chỗ nào.',
    );
  });
}
