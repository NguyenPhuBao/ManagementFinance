import 'package:flowmoney/features/household/presentation/widgets/ten_thanh_vien.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TenThanhVien: tên dài bị cắt, nhãn Bạn luôn còn; không phải mình thì không có nhãn', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 120, child: TenThanhVien(ten: 'Tên rất rất rất dài ${'x' * 40}', laToi: true)))));
    expect(find.text('Bạn'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TenThanhVien(ten: 'An', laToi: false))));
    expect(find.text('Bạn'), findsNothing);
    expect(find.text('An'), findsOneWidget);
  });
}
