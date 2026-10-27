import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/presentation/widgets/tro_ly_ai/dong_khoa.dart';

void main() {
  Widget boc(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets('⭐ B1: tạm ngừng → câu, KHÔNG nút Nâng cấp lẫn Cài đặt AI', (t) async {
    await t.pumpWidget(boc(DongKhoa(cau: 'Trợ lý AI hiện đang tạm ngừng.', goiBasic: false, tamNgung: true, onCaiDatAi: () {})));
    expect(find.text('Trợ lý AI hiện đang tạm ngừng.'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget, reason: 'Stitch khối 6 dùng smart_toy');
    expect(find.text('Cài đặt AI'), findsNothing, reason: 'Cài đặt AI không mở được quyền admin đã tắt');
    expect(find.byKey(const Key('nut-nang-cap')), findsNothing, reason: 'chốt 3 — mua không mở');
  });

  testWidgets('không phải Basic → câu + nút Cài đặt AI', (t) async {
    var n = 0;
    await t.pumpWidget(boc(DongKhoa(cau: 'Câu khoá', goiBasic: false, onCaiDatAi: () => n++)));
    expect(find.text('Câu khoá'), findsOneWidget);
    await t.tap(find.text('Cài đặt AI'));
    expect(n, 1);
  });
}
