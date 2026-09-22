/// Sheet kế hoạch tái phân bổ (Edge-SLM P2, Task 15) — màn Stitch `f02861d9…`
/// khối 2: tick từng dòng, sửa số, "Áp dụng kế hoạch" đi qua `updateBudget`
/// và ghi phản hồi; "Bỏ qua" chỉ ghi phản hồi; vuốt/chạm nền tắt thì **không
/// ghi gì**.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/ai_edge/presentation/pages/ke_hoach_tai_phan_bo_sheet.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements BudgetRepository {
  final daCapNhat = <BudgetEntity>[];
  @override
  Future<void> updateBudget(BudgetEntity budget) async => daCapNhat.add(budget);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

final _now = DateTime(2026, 9, 21, 10);

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

KeHoachTaiPhanBo _keHoach() => KeHoachTaiPhanBo(
      thieu: _thieu,
      duPhong: 3600000,
      thamHut: 600000,
      dong: [
        DongTaiPhanBo(nguon: _d1, duDia: 1700000, soTien: 500000),
        DongTaiPhanBo(nguon: _d2, duDia: 1100000, soTien: 100000),
      ],
      trangThai: TrangThaiKeHoach.duNguonBu,
      soThieu: 0,
    );

void main() {
  late _Repo repo;
  late List<AiRebalancingFeedbacksCompanion> daGhi;

  setUp(() {
    repo = _Repo();
    daGhi = [];
  });

  /// Dựng một trang có nút mở sheet — sheet thật đi qua `showModalBottomSheet`
  /// nên tắt bằng chạm nền cũng kiểm được.
  Future<void> mo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => moKeHoachTaiPhanBoSheet(
                ctx,
                keHoach: _keHoach(),
                idaccount: 7,
                budgets: repo,
                ghiPhanHoi: (c) async => daGhi.add(c),
                clock: () => _now,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  Finder tick(String id) => find.byKey(Key('ke-hoach-tick-$id'));
  Finder oTien(String id) => find.byKey(Key('ke-hoach-so-tien-$id'));
  Finder apDung() => find.byKey(const Key('ke-hoach-ap-dung'));

  testWidgets('mở ra: tiêu đề, thâm hụt, hai dòng với dư địa và số đề xuất, '
      'tổng bù 100 %', (tester) async {
    await mo(tester);

    expect(find.text('Kế hoạch cân đối ngân sách'), findsOneWidget);
    expect(find.textContaining('Ăn uống · thâm hụt dự kiến'), findsOneWidget);
    expect(find.textContaining('600.000 đ'), findsWidgets);
    expect(find.text('Giải trí'), findsOneWidget);
    expect(find.text('Mua sắm'), findsOneWidget);
    expect(find.textContaining('dư địa 1.700.000 đ'), findsOneWidget);
    expect(tester.widget<TextField>(oTien('giaiTri')).controller!.text,
        '500.000',
        reason: 'Số đề xuất điền sẵn, định dạng `formatSoThoi` (không ký hiệu).');
    expect(find.text('Tổng bù: 600.000 đ / 600.000 đ'), findsOneWidget);
    expect(find.text('100% CÂN ĐỐI'), findsOneWidget);
    expect(find.text('Tăng hạn mức ngân sách'), findsNothing,
        reason: 'Stitch vẽ nút này ở thẻ thiếu nguồn bù; bản thi công cố ý '
            'không dựng (ngoài phạm vi P2).');
    expect(tester.takeException(), isNull, reason: 'Không tràn ở 411dp.');
  });

  testWidgets('sheet cao CỐ ĐỊNH 70 % màn — không co theo số dòng',
      (tester) async {
    await mo(tester);
    final cao = tester.getSize(find.byKey(const Key('ke-hoach-sheet'))).height;
    expect(cao, closeTo(914 * 0.7, 1),
        reason: 'Bài học sheet chọn phạm vi (2026-09-15): sheet neo đáy mà co '
            'theo nội dung thì hàng nút trượt dưới ngón tay khi số dòng đổi.');
  });

  testWidgets('bỏ tick một dòng → tổng bù đổi; sửa số một dòng → tổng bù đổi',
      (tester) async {
    await mo(tester);

    await tester.tap(tick('muaSam'));
    await tester.pump();
    expect(find.text('Tổng bù: 500.000 đ / 600.000 đ'), findsOneWidget);
    expect(find.text('83% CÂN ĐỐI'), findsOneWidget);

    await tester.enterText(oTien('giaiTri'), '300000');
    await tester.pump();
    expect(find.text('Tổng bù: 300.000 đ / 600.000 đ'), findsOneWidget);
    expect(find.text('50% CÂN ĐỐI'), findsOneWidget);
  });

  testWidgets('ô tiền có trần số chữ số', (tester) async {
    await mo(tester);
    final o = tester.widget<TextField>(oTien('giaiTri'));
    expect(o.inputFormatters!.whereType<GioiHanSoChuSo>(), isNotEmpty,
        reason: 'budget."TotalAmount" là numeric(15,2) — G46.');
  });

  testWidgets('Áp dụng: hai lượt updateBudget đúng hạn mức, hai hàng phản hồi '
      '(modified, rejected), sheet đóng', (tester) async {
    await mo(tester);
    await tester.tap(tick('muaSam'));
    await tester.enterText(oTien('giaiTri'), '300000');
    await tester.pump();

    await tester.tap(apDung());
    await tester.pumpAndSettle();

    final theoId = {for (final b in repo.daCapNhat) b.id: b.amount};
    expect(theoId, {'giaiTri': 1700000.0, 'an': 3300000.0},
        reason: 'Nguồn bù trừ 300.000, thâm hụt cộng 300.000; dòng bỏ tick '
            'không sinh lượt cập nhật nào.');
    final theoDonor = {for (final c in daGhi) c.donorBudgetId.value: c};
    expect(theoDonor['giaiTri']!.action.value, 'modified');
    expect(theoDonor['giaiTri']!.actualAmount.value, 300000);
    expect(theoDonor['muaSam']!.action.value, 'rejected');
    expect(theoDonor['muaSam']!.periodFrom.value, DateTime(2026, 9, 1));
    expect(find.text('Kế hoạch cân đối ngân sách'), findsNothing,
        reason: 'Áp dụng xong thì sheet đóng.');
  });

  testWidgets('Bỏ qua: 0 lượt updateBudget, mọi hàng rejected, sheet đóng',
      (tester) async {
    await mo(tester);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();

    expect(repo.daCapNhat, isEmpty);
    expect(daGhi, hasLength(2));
    expect(daGhi.every((c) => c.action.value == 'rejected'), isTrue);
    expect(find.text('Kế hoạch cân đối ngân sách'), findsNothing);
  });

  testWidgets('chạm nền để tắt → KHÔNG ghi gì (chưa quyết không phải từ chối)',
      (tester) async {
    await mo(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Kế hoạch cân đối ngân sách'), findsNothing);
    expect(repo.daCapNhat, isEmpty);
    expect(daGhi, isEmpty,
        reason: 'Ghi `rejected` khi người dùng chỉ tắt sheet là dạy luật C3 '
            'một điều họ không nói; kế hoạch sẽ hiện lại ở lượt sau.');
  });

  testWidgets('không dòng nào tick → nút Áp dụng tắt', (tester) async {
    await mo(tester);
    await tester.tap(tick('giaiTri'));
    await tester.tap(tick('muaSam'));
    await tester.pump();

    expect(tester.widget<ElevatedButton>(apDung()).onPressed, isNull);
    expect(find.text('Tổng bù: 0 đ / 600.000 đ'), findsOneWidget);
  });

  testWidgets('số vượt dư địa → báo lỗi ngay dưới ô và nút Áp dụng tắt',
      (tester) async {
    await mo(tester);
    await tester.enterText(oTien('giaiTri'), '1700001');
    await tester.pump();

    expect(find.textContaining('Vượt dư địa'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(apDung()).onPressed, isNull,
        reason: 'Cắt quá dư địa là đẩy nguồn bù vào thâm hụt; `hanMucMoi` cũng '
            'ném, nhưng người dùng phải thấy lý do TRƯỚC khi bấm.');
    expect(tester.takeException(), isNull);
  });
}
