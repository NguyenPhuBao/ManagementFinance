import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/domain/duong_hoi.dart';
import 'package:flowmoney/features/ai_chat/presentation/widgets/tro_ly_ai/nhan_nguon.dart';

void main() {
  Widget boc(Widget w) => MaterialApp(home: Scaffold(body: w));
  testWidgets('online không ghi chú → "Trợ lý online"', (t) async {
    await t.pumpWidget(boc(const NhanNguon(nguon: NguonTraLoi.online)));
    expect(find.text(kNguonOnline), findsOneWidget);
  });
  testWidgets('trên máy + ghi chú rơi → "AI trên máy · máy chủ không phản hồi"', (t) async {
    await t.pumpWidget(boc(const NhanNguon(nguon: NguonTraLoi.trenMay, ghiChu: kGhiChuRoiVeMay)));
    expect(find.text('$kNguonTrenMay · $kGhiChuRoiVeMay'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('nhan-nguon'))).style?.fontSize, 12);
  });
}
