import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/household/presentation/widgets/nhan_vai.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NhanVai: Chủ nền đen, vai khác nền xám nhạt; chữ đúng tên vai', (t) async {
    Color nen() => ((t.widget<Container>(find.descendant(of: find.byType(NhanVai), matching: find.byType(Container))))
            .decoration! as BoxDecoration)
        .color!;
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: NhanVai(vai: VaiNha.chu))));
    expect(find.text(tenVai(VaiNha.chu)), findsOneWidget);
    expect(nen(), AppColors.primary);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: NhanVai(vai: VaiNha.chiXem))));
    expect(find.text(tenVai(VaiNha.chiXem)), findsOneWidget);
    expect(nen(), AppColors.surfaceContainerLow);
  });
}
