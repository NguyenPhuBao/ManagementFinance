/// Thẻ kế hoạch tái phân bổ trên trang Ngân sách (Edge-SLM P2, Task 15) — màn
/// Stitch `f02861d9…` khối 1 (đủ nguồn bù) và khối 3 (thiếu nguồn bù).
library;

import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/ai_edge/presentation/widgets/the_ke_hoach.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetView _v(String id, String ten, {required double amount, double spent = 0}) =>
    BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: amount,
        spent: spent,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: ten,
    );

final _thieu = _v('an', 'Ăn uống', amount: 3000000, spent: 2800000);
final _d1 = _v('giaiTri', 'Giải trí', amount: 2000000, spent: 300000);
final _d2 = _v('muaSam', 'Mua sắm', amount: 1500000, spent: 400000);

KeHoachTaiPhanBo _du() => KeHoachTaiPhanBo(
      thieu: _thieu,
      duPhong: 3600000,
      thamHut: 600000,
      dong: [
        DongTaiPhanBo(nguon: _d1, duDia: 1700000, soTien: 400000),
        DongTaiPhanBo(nguon: _d2, duDia: 1100000, soTien: 200000),
      ],
      trangThai: TrangThaiKeHoach.duNguonBu,
      soThieu: 0,
    );

KeHoachTaiPhanBo _thieuMotPhan() => KeHoachTaiPhanBo(
      thieu: _thieu,
      duPhong: 3900000,
      thamHut: 900000,
      dong: [DongTaiPhanBo(nguon: _d1, duDia: 1700000, soTien: 600000)],
      trangThai: TrangThaiKeHoach.thieuNguonBu,
      soThieu: 300000,
    );

Future<void> _dung(
  WidgetTester tester,
  KeHoachTaiPhanBo kh, {
  VoidCallback? onXem,
  VoidCallback? onXemPhanTich,
}) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: TheKeHoach(
            keHoach: kh, onXem: onXem, onXemPhanTich: onXemPhanTich),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('đủ nguồn bù: nhãn, chip "Dự kiến vượt", câu tóm tắt, nguồn bù, '
      'nút Xem kế hoạch gọi onXem', (tester) async {
    var goi = 0;
    await _dung(tester, _du(), onXem: () => goi++);

    expect(find.text('ĐỀ XUẤT CÂN ĐỐI'), findsOneWidget);
    expect(find.text('Dự kiến vượt'), findsOneWidget);
    expect(find.text(_du().cauTomTat), findsOneWidget,
        reason: 'Thẻ và câu nhận xét dùng đúng MỘT câu tóm tắt — không thể '
            'nói hai chuyện.');
    expect(find.text('Nguồn bù: Giải trí, Mua sắm'), findsOneWidget);
    await tester.tap(find.text('Xem kế hoạch'));
    expect(goi, 1);
    expect(tester.takeException(), isNull, reason: 'Không tràn ở 411dp.');
  });

  testWidgets('thiếu nguồn bù một phần: nhãn đỏ, chip số thiếu, dòng gợi ý, '
      'link phân tích, vẫn có Xem kế hoạch', (tester) async {
    var xem = 0, phanTich = 0;
    await _dung(tester, _thieuMotPhan(),
        onXem: () => xem++, onXemPhanTich: () => phanTich++);

    expect(find.text('ĐỀ XUẤT CÂN ĐỐI · KHÔNG ĐỦ DƯ ĐỊA'), findsOneWidget);
    expect(find.text('-300.000 đ'), findsOneWidget);
    expect(find.textContaining('tối đa gom được 600.000 đ'), findsOneWidget);
    expect(find.text('Tăng hạn mức ngân sách'), findsNothing,
        reason: 'Stitch vẽ nút này; bản thi công cố ý không dựng (ngoài phạm '
            'vi P2) — một nút không đi đâu là nút chết.');
    await tester.tap(find.text('Xem phân tích chi tiêu'));
    expect(phanTich, 1);
    await tester.tap(find.text('Xem kế hoạch'));
    expect(xem, 1,
        reason: 'Còn một nguồn bù thì vẫn có gì để duyệt.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('không có nguồn bù nào: KHÔNG có nút Xem kế hoạch',
      (tester) async {
    final kh = KeHoachTaiPhanBo(
      thieu: _thieu,
      duPhong: 3900000,
      thamHut: 900000,
      dong: const [],
      trangThai: TrangThaiKeHoach.thieuNguonBu,
      soThieu: 900000,
    );
    await _dung(tester, kh, onXem: () {});
    expect(find.text('Xem kế hoạch'), findsNothing,
        reason: 'Sheet rỗng không có dòng nào để tick — mở ra là ngõ cụt.');
    expect(find.text('-900.000 đ'), findsOneWidget);
  });

  testWidgets('không có onXemPhanTich thì link không hiện', (tester) async {
    await _dung(tester, _thieuMotPhan(), onXem: () {});
    expect(find.text('Xem phân tích chi tiêu'), findsNothing,
        reason: 'Cùng lối `onOpenAnalytics` của BudgetTabsView: thà thiếu còn '
            'hơn một link không đi đâu.');
  });
}
