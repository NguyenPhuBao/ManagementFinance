/// Khối "Nhận xét" trên trang Ngân sách (Edge-SLM P2, Task 14 — đóng A6).
///
/// Canh chừng: khối đọc **đúng** ngân sách căng nhất của state (qua
/// `GoiSoNganSach.tu`), nối câu tóm tắt kế hoạch khi state mang `keHoach`, và
/// **không** dựng khi chưa có ngân sách nào — tab ấy đã có `_InlineEmpty` nói
/// đúng câu đó, hai thẻ cùng nói "chưa có ngân sách" là thừa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/ai_edge/presentation/widgets/khoi_nhan_xet.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

BudgetView _view({
  required String id,
  double amount = 1000000,
  double spent = 0,
  String tenDanhMuc = 'Ăn uống',
}) =>
    BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: amount,
        spent: spent,
        startDate: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: tenDanhMuc,
    );

Future<void> _dung(
  WidgetTester tester, {
  List<BudgetView> active = const [],
  KeHoachTaiPhanBo? keHoach,
}) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: BudgetTabsView(
      now: DateTime(2026, 9, 15, 12),
      state: BudgetLoaded(
        active: active,
        expired: const [],
        totalAmount: active.fold(0.0, (s, v) => s + v.budget.amount),
        totalSpent: active.fold(0.0, (s, v) => s + v.budget.spent),
        keHoach: keHoach,
      ),
      onCreate: () {},
      onEdit: (_) {},
      onDelete: (_) async => false,
      onShowDetail: (_) {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('có ngân sách → một khối Nhận xét, câu đúng số của state',
      (tester) async {
    await _dung(tester, active: [
      _view(id: 'b1', amount: 3000000, spent: 1000000),
    ]);

    expect(find.byType(KhoiNhanXet), findsOneWidget,
        reason: 'A6: trang Ngân sách phải có khối Nhận xét (Stitch b396533b…).');
    // 1.000.000 / 3.000.000 = 33,3 %; 15/9 trưa → 1/10 là 16 ngày;
    // 2.000.000 / 16 = 125.000 mỗi ngày — đúng số `budgetPaceOf` đang in trên
    // thẻ ngân sách ngay dưới.
    expect(
      find.textContaining(
          'Ăn uống: đã dùng 1.000.000 đ / 3.000.000 đ (33,3%), còn 16 ngày'),
      findsOneWidget,
      reason: 'Câu mẫu phải nói về đúng ngân sách và đúng số của state — '
          'không phải một câu chung chung.',
    );
    expect(tester.takeException(), isNull, reason: 'Không tràn ở 411dp.');
  });

  testWidgets('khối nói về ngân sách CĂNG NHẤT, cùng luật với thẻ Trang chủ',
      (tester) async {
    await _dung(tester, active: [
      _view(id: 'b1', amount: 3000000, spent: 300000, tenDanhMuc: 'Ăn uống'),
      _view(id: 'b2', amount: 1000000, spent: 950000, tenDanhMuc: 'Xăng xe'),
    ]);

    expect(find.textContaining('Xăng xe: đã dùng'), findsOneWidget,
        reason: '`pickHomeBudget` chọn ngân sách căng nhất; hai chỗ (Trang chủ '
            'và đây) không được nói về hai ngân sách khác nhau.');
    expect(find.textContaining('Ăn uống: đã dùng'), findsNothing);
  });

  testWidgets('có kế hoạch → câu nối thêm tóm tắt kế hoạch', (tester) async {
    final thieu = _view(id: 'b1', amount: 3000000, spent: 2800000);
    final nguon = _view(id: 'b2', amount: 2000000, spent: 200000,
        tenDanhMuc: 'Mua sắm');
    await _dung(
      tester,
      active: [thieu, nguon],
      keHoach: KeHoachTaiPhanBo(
        thieu: thieu,
        duPhong: 4200000,
        thamHut: 1200000,
        dong: [DongTaiPhanBo(nguon: nguon, duDia: 1800000, soTien: 500000)],
        trangThai: TrangThaiKeHoach.duNguonBu,
        soThieu: 0,
      ),
    );

    expect(
      find.textContaining('Ăn uống dự kiến vượt 1.200.000 đ. Bớt từ 1 ngân '
          'sách khác?'),
      findsOneWidget,
      reason: 'Kế hoạch của state phải đi vào gói số (`keHoach:`), nếu không '
          'câu nhận xét im lặng về thâm hụt trong khi thẻ kế hoạch (Task 15) '
          'lại nói có — hai khối cạnh nhau nói hai chuyện.',
    );
  });

  testWidgets('chưa có ngân sách nào → KHÔNG dựng khối', (tester) async {
    await _dung(tester);

    expect(find.byType(KhoiNhanXet), findsNothing,
        reason: 'Tab rỗng đã có `_InlineEmpty` nói "Chưa có ngân sách nào đang '
            'chạy"; thêm một thẻ Nhận xét nói y hệt là hai thẻ cùng một câu.');
  });
}
