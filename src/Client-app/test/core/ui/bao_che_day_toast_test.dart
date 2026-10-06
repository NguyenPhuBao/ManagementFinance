/// `BaoCheDayToast` (2026-10-06, Stitch fb68baba…): bọc một vùng đáy do app TỰ VẼ (16 phím số ở Thêm giao dịch) —
/// hệ điều hành không báo `viewInsets` cho nó, nên toast không biết mà né. Widget đo khoảng đáy màn bị che rồi báo
/// cho `AppToast`; rời cây thì trả về 0.
library;

import 'package:flowmoney/core/ui/bao_che_day_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> dung(WidgetTester tester, ValueNotifier<double> kenh, {bool coPhim = true, double cao = 250}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const Expanded(child: SizedBox.expand()),
          if (coPhim) BaoCheDayToast(kenh: kenh, child: SizedBox(height: cao)),
        ]),
      ),
    ));
    await tester.pump();
  }

  testWidgets('⭐ báo đúng khoảng đáy bị che = chiều cao vùng nằm sát đáy', (tester) async {
    final kenh = ValueNotifier<double>(0);
    await dung(tester, kenh);
    expect(kenh.value, closeTo(250, 0.5));
  });

  testWidgets('vùng đổi chiều cao thì báo lại', (tester) async {
    final kenh = ValueNotifier<double>(0);
    await dung(tester, kenh);
    await dung(tester, kenh, cao: 300);
    expect(kenh.value, closeTo(300, 0.5));
  });

  testWidgets('⭐ rời cây (bàn phím số ẩn / rời màn) thì trả về 0 — không để toast lơ lửng mãi', (tester) async {
    final kenh = ValueNotifier<double>(0);
    await dung(tester, kenh);
    await dung(tester, kenh, coPhim: false);
    expect(kenh.value, 0);
  });
}
