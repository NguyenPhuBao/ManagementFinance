import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/presentation/widgets/tro_ly_ai/hang_chip.dart';

void main() {
  Widget boc(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets('bật → chạm chip gọi onChon với đúng nhãn', (t) async {
    final chon = <String>[];
    await t.pumpWidget(boc(HangChip(nhan: const ['A', 'B'], bat: true, onChon: chon.add)));
    await t.tap(find.text('B'));
    expect(chon, ['B']);
  });

  testWidgets('tắt → chip không hỏi được', (t) async {
    final chon = <String>[];
    await t.pumpWidget(boc(HangChip(nhan: const ['A'], bat: false, onChon: chon.add)));
    await t.tap(find.text('A'));
    expect(chon, isEmpty, reason: 'chưa có mô hình thì chip không là đường vòng quanh khoá');
  });
}
