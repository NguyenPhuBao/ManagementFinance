/// B1 (spec 2026-10-27 mục 3) — ba khoá ở Trang chủ: thẻ Tổng tài sản (`net_worth_overview`), hàng nút ghi nhanh
/// (`quick_action_shortcuts`), dòng nhịp chi của thẻ ngân sách (`budget_overspend_alert`). Gác trong chính widget để test
/// được mà không dựng cả trang (khung test Trang chủ nặng — `PREMIUM_FEATURE.md` bẫy 8.5 #6).
library;

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/home/presentation/widgets/hang_nut_nhanh.dart';
import 'package:flowmoney/features/home/presentation/widgets/home_budget_card.dart';
import 'package:flowmoney/features/home/presentation/widgets/the_tong_so_du.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/goi_gia.dart';

void main() {
  Future<void> dung(WidgetTester t, Widget con, {GoiCubit? goi}) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final app = MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: con)),
    );
    await t.pumpWidget(goi == null ? app : BlocProvider<GoiCubit>.value(value: goi, child: app));
    await t.pump();
  }

  final nut = [
    for (final n in ['Thêm thu', 'Thêm chi', 'Chuyển', 'Quét', 'Nói'])
      NutNhanh(bieuTuong: Icons.add, nhan: n, dam: false, onTap: () {}),
  ];

  final nganSach = BudgetView(
    budget: BudgetEntity(
      id: 'a',
      idaccount: 7,
      categoryId: 'c-a',
      amount: 3000000,
      spent: 1000000,
      startDate: DateTime(2026, 9, 1),
      recurrence: true,
      updatedAt: DateTime(2026, 9, 15),
    ),
    categoryName: 'Ăn uống',
  );

  testWidgets('tiền đề: không GoiCubit → ba khối như cũ', (t) async {
    await dung(t, Column(children: [
      const TheTongSoDu(tongSoDu: 13590000),
      HangNutNhanh(nut: nut),
      HomeBudgetCard(budgets: [nganSach], now: DateTime(2026, 9, 15, 12)),
    ]));
    expect(find.text('Tổng số dư ví'), findsOneWidget);
    expect(find.text('Thêm thu'), findsOneWidget);
    expect(find.textContaining('Nên chi'), findsOneWidget);
  });

  testWidgets('⭐ net_worth_overview tắt → thẻ khoá thay thẻ Tổng số dư, không con số', (t) async {
    await dung(t, const TheTongSoDu(tongSoDu: 13590000), goi: goiBasic(const {'net_worth_overview': false}));
    expect(find.byKey(const Key('the-khoa-net_worth_overview')), findsOneWidget);
    expect(find.text('Tổng số dư ví'), findsNothing);
    expect(find.text('13.590.000 đ'), findsNothing);
  });

  testWidgets('⭐ quick_action_shortcuts tắt → MỘT dòng khoá thay cả hàng năm nút', (t) async {
    await dung(t, HangNutNhanh(nut: nut), goi: goiBasic(const {'quick_action_shortcuts': false}));
    expect(find.byKey(const Key('dong-khoa-quick_action_shortcuts')), findsOneWidget);
    expect(find.text('Nút ghi nhanh — dành cho Premium'), findsOneWidget);
    expect(find.text('Thêm thu'), findsNothing);
    expect(find.text('Nói'), findsNothing);
  });

  testWidgets('⭐ budget_overspend_alert tắt → dòng "Nên chi …" thành dòng khoá', (t) async {
    await dung(t, HomeBudgetCard(budgets: [nganSach], now: DateTime(2026, 9, 15, 12)),
        goi: goiBasic(const {'budget_overspend_alert': false}));
    expect(find.textContaining('Nên chi'), findsNothing);
    expect(find.byKey(const Key('dong-khoa-budget_overspend_alert')), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget, reason: 'chỉ dòng nhịp chi bị khoá, thẻ ngân sách vẫn hiện');
  });
}
