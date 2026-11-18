/// Dòng phụ có viên tên nhà (spec 2026-11-16): ở 320 dp, tên nhà dài VÀ dòng phụ dài đều co về dấu ba chấm, không tràn,
/// và không cao thêm một dòng (dòng giao dịch có chiều cao cố định theo bố cục Stitch).
library;

import 'package:flowmoney/features/transaction/presentation/widgets/nhan_nha_nho.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> dung(WidgetTester t, {required String chu, String? tenNha}) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            const SizedBox(width: 60),
            Expanded(child: DongPhuGiaoDich(chu: chu, tenNha: tenNha, style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 90),
          ],
        ),
      ),
    ));
  }

  testWidgets('320 dp: tên nhà 60 ký tự + dòng phụ dài → không tràn, một dòng', (t) async {
    await dung(t, chu: 'Ăn uống • Tiền chợ của cả nhà tháng này', tenNha: 'Nhà ' * 15);
    expect(t.takeException(), isNull);
    expect(find.byType(NhanNhaNho), findsOneWidget);
    expect(t.getSize(find.byType(DongPhuGiaoDich)).height, lessThan(24), reason: 'dòng phụ không được xuống dòng');
  });

  testWidgets('khoản riêng: không có viên nhà', (t) async {
    await dung(t, chu: 'Ăn uống • Tiền mặt');
    expect(find.byType(NhanNhaNho), findsNothing);
    expect(find.text('Ăn uống • Tiền mặt'), findsOneWidget);
  });
}
