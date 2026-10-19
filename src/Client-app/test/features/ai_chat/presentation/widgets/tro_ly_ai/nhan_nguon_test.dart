import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/domain/duong_hoi.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';
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
  Color? cham(WidgetTester t) =>
      (t.widget<Container>(find.byKey(const Key('cham-nguon'))).decoration as BoxDecoration).color;
  testWidgets('màu chấm: online êm xanh; có ghi chú đỏ; trên máy xám Stitch', (t) async {
    await t.pumpWidget(boc(const NhanNguon(nguon: NguonTraLoi.online)));
    expect(cham(t), const Color(0xFF006E1C));
    await t.pumpWidget(boc(const NhanNguon(nguon: NguonTraLoi.online, ghiChu: kGhiChuRoiVeMay)));
    expect(cham(t), AppColors.error);
    await t.pumpWidget(boc(const NhanNguon(nguon: NguonTraLoi.trenMay)));
    expect(cham(t), const Color(0xFF454743));
    expect(t.widget<Text>(find.byKey(const Key('nhan-nguon'))).style?.color, const Color(0xFF454743),
        reason: 'Stitch #454743, không phải onSurfaceVariant #767872');
  });
}
