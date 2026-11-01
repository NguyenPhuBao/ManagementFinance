import 'package:flowmoney/features/household/presentation/widgets/khung_the_nha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KhungTheNha: dựng con, viền theo tham số', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: KhungTheNha(vien: Colors.red, child: Text('NOI DUNG')))));
    expect(find.text('NOI DUNG'), findsOneWidget);
    final c = t.widget<Container>(find.descendant(of: find.byType(KhungTheNha), matching: find.byType(Container)).first);
    expect(((c.decoration! as BoxDecoration).border! as Border).top.color, Colors.red);
  });
}
