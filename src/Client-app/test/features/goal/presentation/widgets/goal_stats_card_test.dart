/// Thẻ ba con số tổng hợp của mục tiêu — thêm 2026-09-09.
///
/// Phép tính nằm ở `goal_stats.dart` và được test ở đó. Test này canh ba thứ
/// còn lại, đều hỏng **im lặng** được: thẻ có biến mất đúng lúc không, ô chuỗi
/// có im khi thiếu căn cứ không, và ba ô có tràn ở 411dp không.
///
/// Khổ máy đặt bằng `tester.view.physicalSize` chứ không bằng `MediaQuery`:
/// bọc `MediaQuery` chỉ đổi con số widget đọc được, ràng buộc bố cục vẫn là
/// 800×600 của bộ test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_history_filter.dart';
import 'package:flowmoney/features/goal/presentation/widgets/goal_stats_card.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 9, 9);

  GoalEntity mt({DateTime? batDau, String? chuKy = 'Month'}) => GoalEntity(
        id: 'g1',
        idaccount: 7,
        name: 'Mua MacBook Pro',
        targetAmount: 40000000,
        currentAmount: 20000000,
        startDate: batDau,
        targetDate: DateTime(2026, 12, 1),
        walletId: 'w1',
        cycleTakeMoney: chuKy,
        updatedAt: DateTime(2026, 9, 1),
      );

  KhoanTichLuy k(DateTime ngay, {double soTien = 100000, bool rut = false}) =>
      KhoanTichLuy(
        ngay: ngay,
        soTien: soTien,
        laKhoanRut: rut,
        laTuDong: false,
      );

  Future<void> dung(
    WidgetTester t, {
    required GoalEntity goal,
    required List<KhoanTichLuy> khoan,
  }) async {
    t.view.physicalSize = const Size(411 * 3, 900 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MaterialApp(
        // Theme thật: nó ép mọi `ElevatedButton` rộng vô hạn (bẫy 4.11).
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GoalStatsCard(goal: goal, khoan: khoan, now: now),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('chưa có khoản nạp nào thì thẻ biến mất hẳn', (t) async {
    await dung(
      t,
      goal: mt(batDau: DateTime(2026, 6, 15)),
      khoan: [k(DateTime(2026, 8, 1), rut: true)],
    );

    expect(
      find.text('lần nạp'),
      findsNothing,
      reason: 'Chỉ có khoản rút thì cả ba con số đều vô nghĩa. Một thẻ "0 lần '
          '· 0 đ" vẫn chiếm chỗ và vẫn nói một điều sai.',
    );
  });

  testWidgets('ba ô không tràn bố cục ở 411dp', (t) async {
    // Số tiền dài nhất có thể: trung bình bảy chữ số.
    await dung(
      t,
      goal: mt(batDau: DateTime(2026, 6, 15)),
      khoan: [
        k(DateTime(2026, 7, 20), soTien: 9876543),
        k(DateTime(2026, 8, 20), soTien: 1234567),
      ],
    );

    expect(
      t.takeException(),
      isNull,
      reason: 'Flutter báo tràn qua FlutterError.reportError chứ KHÔNG ném ra '
          'chỗ gọi, nên test chỉ pumpWidget + find vẫn xanh trong khi màn hình '
          'đầy sọc vàng. Ba ô chia đều một hàng là đúng chỗ dễ tràn nhất.',
    );
  });

  testWidgets('nhãn chuỗi đọc theo chu kỳ của mục tiêu', (t) async {
    await dung(
      t,
      goal: mt(batDau: DateTime(2026, 6, 15), chuKy: 'Week'),
      khoan: [k(DateTime(2026, 9, 5)), k(DateTime(2026, 9, 1))],
    );

    expect(
      find.text('tuần liên tiếp'),
      findsOneWidget,
      reason: 'Nhãn phải nói đúng đơn vị mà phép đếm đã cắt. "tháng liên tiếp" '
          'cho một mục tiêu hàng tuần là một con số không ai kiểm lại được.',
    );
  });

  testWidgets('không có mốc gốc thì giấu ô chuỗi, hai ô kia vẫn hiện',
      (t) async {
    await dung(
      t,
      goal: mt(batDau: null),
      khoan: [k(DateTime(2026, 8, 20), soTien: 500000)],
    );

    expect(find.text('lần nạp'), findsOneWidget);
    expect(find.text('trung bình mỗi lần'), findsOneWidget);
    expect(
      find.textContaining('liên tiếp'),
      findsNothing,
      reason: 'Không có mốc gốc thì không cắt được kỳ. Một ô trống mang nhãn '
          '"liên tiếp" vẫn hứa một con số mà app không có.',
    );
  });
}
