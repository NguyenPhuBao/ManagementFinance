/// G76 (phần ngân sách) — hàng tab trang Ngân sách ở màn HẸP (Realme để cỡ
/// hiển thị lớn: mật độ 540 → 320 dp).
///
/// Quét 2026-10-07: *"Đang hoạt động (4"* — mất dấu đóng ngoặc, tức mất một
/// phần con số. `TabBar` cố định chia đôi bề ngang, mỗi ô còn ~128 dp chữ.
/// Sửa: nhãn co nhẹ bằng `FittedBox.scaleDown` (cùng cách G68 cho thanh điều
/// hướng) — màn đủ chỗ giữ nguyên cỡ.
///
/// ⚠️ `Tab` dựng chữ với `overflow: fade`, nên hộp chữ luôn bị ép gọn trong ô —
/// ca test phải so bề rộng CẦN của chữ, so mép hộp thì xanh cả với mã cũ.
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

import '../../../../helpers/font_that.dart';

void main() {
  BudgetView view(String id) => BudgetView(
        budget: BudgetEntity(
          id: id,
          idaccount: 7,
          categoryId: 'c-$id',
          amount: 1000000,
          spent: 0,
          startDate: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
        categoryName: 'Ăn uống $id',
      );

  setUp(napFontThat);

  Future<void> dung(WidgetTester tester, double rong,
      {double chu = 1.0}) async {
    tester.view.physicalSize = Size(rong, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final active = [for (var i = 0; i < 14; i++) view('a$i')];
    final expired = [for (var i = 0; i < 12; i++) view('e$i')];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(chu)),
        child: child!,
      ),
      home: BudgetTabsView(
        now: DateTime(2026, 9, 15, 12),
        state: BudgetLoaded(
          active: active,
          expired: expired,
          totalAmount: 14000000,
          totalSpent: 0,
        ),
        onCreate: () {},
        onEdit: (_) {},
        onDelete: (_) async => false,
        onShowDetail: (_) {},
      ),
    ));
    await tester.pump();
  }

  /// Nhãn tab vẽ TRỌN. `Tab` dựng chữ với `overflow: fade` nên hộp chữ luôn bị
  /// ép gọn trong ô — so mép hộp không bắt được gì; phải so bề rộng CẦN của
  /// chữ với bề rộng được cấp, rồi hộp nhìn thấy (sau khi co) với ô tab.
  void nhanTron(WidgetTester tester, String chu, double rong) {
    final o = find.text(chu);
    expect(o, findsOneWidget, reason: 'phải tìm thấy nhãn "$chu"');
    final rp = tester.renderObject<RenderParagraph>(o);
    expect(rp.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(rp.size.width + 0.5),
        reason: '$rong dp: "$chu" bị cắt — mất dấu đóng ngoặc / con số');
    final hopTab =
        tester.getRect(find.ancestor(of: o, matching: find.byType(Tab)));
    final hopChu = tester.getRect(o);
    expect(hopChu.right, lessThanOrEqualTo(hopTab.right + 0.5),
        reason: '$rong dp: "$chu" tràn khỏi ô tab');
  }

  for (final rong in [320.0, 300.0]) {
    testWidgets('G76 · $rong dp: nhãn tab ngân sách vẽ trọn, không cắt "(14)"',
        (tester) async {
      await dung(tester, rong);
      expect(tester.takeException(), isNull);
      nhanTron(tester, 'Đang hoạt động (14)', rong);
      nhanTron(tester, 'Đã hết hạn (12)', rong);
    });
  }

  testWidgets('G76 · 411 dp: nhãn tab giữ nguyên cỡ chữ (không co khi đủ chỗ)',
      (tester) async {
    await dung(tester, 411, chu: 1.0);
    final hop = tester.getRect(find.text('Đang hoạt động (14)'));
    // Cỡ 14 của font thật: một dòng cao ~16–20 dp; co lại thì thấp hơn hẳn.
    expect(hop.height, greaterThan(15));
  });
}
