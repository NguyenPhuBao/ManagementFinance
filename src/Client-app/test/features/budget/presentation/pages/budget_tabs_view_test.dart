/// Tab "Đã hết hạn" phải khoá sửa và xoá — chỉ xem được chi tiết.
///
/// Vì sao cần: khoá thao tác là **quy tắc nghiệp vụ**, nhưng nó chỉ tồn tại
/// dưới dạng "widget này không được dựng". Không có test thì một lần dọn giao
/// diện vô tình đưa nút sửa trở lại sẽ không làm gì đỏ lên, và người dùng sửa
/// được một ngân sách đã chốt sổ.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';

void main() {
  BudgetView view({
    required String id,
    double amount = 1000000,
    double spent = 0,
    String? loiDongBo,
    String tenDanhMuc = 'Ăn uống',
  }) {
    return BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c1',
        amount: amount,
        spent: spent,
        startDate: DateTime(2026, 9, 1),
        syncError: loiDongBo,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: tenDanhMuc,
    );
  }

  Future<void> dung(
    WidgetTester tester, {
    List<BudgetView> active = const [],
    List<BudgetView> expired = const [],
    void Function(BudgetView)? onEdit,
    DateTime? now,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: BudgetTabsView(
        now: now,
        state: BudgetLoaded(
          active: active,
          expired: expired,
          totalAmount: active.fold(0.0, (s, v) => s + v.budget.amount),
          totalSpent: active.fold(0.0, (s, v) => s + v.budget.spent),
        ),
        onCreate: () {},
        onEdit: onEdit ?? (_) {},
        onDelete: (_) async => false,
        onShowDetail: (_) {},
      ),
    ));
  }

  testWidgets('tab đang hoạt động: vuốt xoá được và có nút chỉnh',
      (tester) async {
    await dung(tester, active: [view(id: 'b1')]);

    expect(find.byType(Dismissible), findsOneWidget,
        reason: 'Ngân sách đang chạy phải vuốt để xoá được như trước.');
    expect(find.byKey(const ValueKey('budget-edit-b1')), findsOneWidget,
        reason: 'Nút chỉnh (biểu tượng tune) có trong bản dựng hình Stitch.');
  });

  testWidgets('thẻ đang hoạt động ghi nên chi mỗi ngày và số ngày còn lại',
      (tester) async {
    await dung(
      tester,
      active: [view(id: 'b1', amount: 3000000, spent: 1000000)],
      now: DateTime(2026, 9, 15, 12),
    );

    expect(
      find.textContaining('125.000'),
      findsOneWidget,
      reason: 'Còn 2.000.000 cho 16 ngày (15/9 trưa → 1/10) = 125.000/ngày. '
          'Đây là con số mọi app cùng loại đều hiện; thiếu nó thì "Còn X" '
          'không nói được phải kéo dài bao lâu.',
    );
    expect(find.textContaining('còn 16 ngày'), findsOneWidget);
  });

  testWidgets('thẻ đã hết hạn không có dòng nên chi', (tester) async {
    await dung(
      tester,
      expired: [view(id: 'b1', amount: 3000000, spent: 1000000)],
      now: DateTime(2026, 11, 15),
    );
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nên chi'), findsNothing,
        reason: 'Ngân sách đã chốt sổ không còn ngày nào để chia.');
  });

  testWidgets('tab đã hết hạn: không vuốt xoá được', (tester) async {
    await dung(tester, expired: [view(id: 'b1')]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(
      find.byType(Dismissible),
      findsNothing,
      reason: 'Còn Dismissible thì người dùng vẫn vuốt xoá được một ngân sách '
          'đã chốt sổ — mất luôn lịch sử mà không có cảnh báo nào.',
    );
  });

  testWidgets('tab đã hết hạn: không có nút chỉnh', (tester) async {
    await dung(tester, expired: [view(id: 'b1')]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget-edit-b1')), findsNothing,
        reason: 'Sửa hạn mức của một kỳ đã đóng làm số liệu lịch sử đổi theo.');
  });

  testWidgets('tab đã hết hạn: bản ghi HỎNG ĐỒNG BỘ thì mở lại sửa và xoá',
      (tester) async {
    await dung(tester, expired: [
      view(id: 'b1', loiDongBo: 'violates check constraint '
          'chk_budget_end_after_start'),
    ]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget-edit-b1')), findsOneWidget,
        reason: 'Canh chừng G15. Bản ghi này không đẩy lên được; khoá luôn cả '
            'sửa lẫn xoá là nhốt nó vĩnh viễn, và lối thoát duy nhất trở thành '
            'xoá dữ liệu site của trình duyệt.');
    expect(find.byType(Dismissible), findsOneWidget,
        reason: 'Xoá cũng phải mở, không chỉ sửa: có lỗi mà người dùng không '
            'muốn sửa thì phải bỏ được bản ghi đi.');
    expect(find.byKey(const ValueKey('budget-sync-error-b1')), findsOneWidget,
        reason: 'Phải có dấu hiệu vì sao thẻ này khác các thẻ hết hạn còn lại '
            '— nếu không, việc nó sửa được trông như một lỗi giao diện.');
  });

  testWidgets('tab đã hết hạn: bản ghi SẠCH vẫn khoá, kể cả khi có thẻ hỏng',
      (tester) async {
    await dung(tester, expired: [
      view(id: 'b1', loiDongBo: 'lỗi gì đó'),
      view(id: 'b2'),
    ]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget-edit-b2')), findsNothing,
        reason: 'Ngoại lệ G15 chỉ áp cho bản ghi hỏng. Mở cả danh sách vì có '
            'MỘT thẻ hỏng là bỏ luôn yêu cầu gốc mà không ai nhận ra.');
    expect(find.byKey(const ValueKey('budget-sync-error-b2')), findsNothing);
  });

  testWidgets('411dp: thẻ hỏng đồng bộ ở tab hết hạn KHÔNG tràn bố cục',
      (tester) async {
    // 411dp là bề rộng điện thoại thật; bộ test và skill `chay-app` chạy Chrome
    // ở 1280px nên không bao giờ thấy tràn. Sáu chỗ tràn của mảng hoá đơn chỉ
    // lộ ra khi dựng hẹp có chủ ý như thế này.
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await dung(tester, expired: [
      view(
        id: 'b1',
        // Tên dài có thật trong dữ liệu người dùng, và dấu hiệu "Chưa đồng bộ
        // được" nằm ngay dưới nó.
        tenDanhMuc: 'Ăn uống ngoài hàng và cà phê cuối tuần',
        loiDongBo: 'violates check constraint chk_budget_end_after_start',
      ),
    ]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'Dấu hiệu mới là một Row gồm icon + chữ — đúng hình dạng đã gây '
          'tràn sáu lần ở mảng hoá đơn. Flutter báo tràn qua '
          'FlutterError.reportError chứ KHÔNG ném ra chỗ gọi, nên chỉ '
          '`takeException` mới thấy; test chỉ pump rồi `expect(find...)` sẽ '
          'xanh ngay cả khi màn hình đầy sọc vàng.',
    );
    expect(find.byKey(const ValueKey('budget-sync-error-b1')), findsOneWidget);
  });

  testWidgets('chạm thẻ đã hết hạn KHÔNG mở trang sửa', (tester) async {
    final daMoSua = <String>[];
    await dung(
      tester,
      expired: [view(id: 'b1')],
      onEdit: (v) => daMoSua.add(v.budget.id),
    );
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();

    expect(daMoSua, isEmpty,
        reason: 'Chạm thẻ ở tab này mở bảng chi tiết chỉ đọc, không phải form.');
  });

  testWidgets('tab đã hết hạn còn dư thì báo "Còn dư", vượt thì báo "Vượt"',
      (tester) async {
    await dung(tester, expired: [
      view(id: 'du', amount: 1000000, spent: 400000),
      view(id: 'vuot', amount: 1000000, spent: 1350000),
    ]);
    await tester.tap(find.textContaining('Đã hết hạn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Còn dư'), findsOneWidget);
    expect(find.textContaining('Vượt'), findsOneWidget,
        reason: 'Anh yêu cầu tab này nói rõ vượt bao nhiêu, không chỉ tô màu.');
  });

  testWidgets('chỉ có ngân sách hết hạn thì không hiện màn hình rỗng toàn trang',
      (tester) async {
    await dung(tester, expired: [view(id: 'b1')]);

    expect(find.textContaining('Đã hết hạn'), findsOneWidget,
        reason: 'Thanh tab phải còn đó để người dùng sang xem được dữ liệu cũ.');
  });
}
