/// `BoCucTheoFont` — bố cục chọn theo bề rộng chữ (`doRongChu`) phải chọn lại khi font nạp xong.
///
/// Font của app (Inter, `google_fonts`) không đóng gói sẵn — nạp từ bộ nhớ đệm hoặc mạng **sau** khung đầu. `Text` tự đo
/// lại khi ấy (`RenderParagraph` nghe `PaintingBinding.systemFonts`), còn phép đo trong `builder` của `LayoutBuilder` thì
/// không: ràng buộc không đổi nên `builder` không chạy lại. Máy ảo 320 dp × cỡ chữ 1,6 (2026-10-26): màn Đăng nhập mở
/// lạnh vẽ nút *"Googl"* cụt chữ, ép dựng lại (đổi cỡ chữ rồi trả) thì trọn chữ.
library;

import 'dart:io';

import 'package:flowmoney/core/ui/do_chu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ho = 'FontNapMuonDoChu';
  const kieu = TextStyle(fontFamily: ho, fontSize: 14);

  Widget dung(Key k) => MaterialApp(
        home: Scaffold(
          body: BoCucTheoFont(
            key: k,
            builder: (context, rang) => Text('rộng ${doRongChu(context, 'Google', kieu).toStringAsFixed(1)}'),
          ),
        ),
      );

  String chu(WidgetTester t) => t.widget<Text>(find.textContaining('rộng ')).data!;

  testWidgets('font nạp SAU khung đầu: builder chạy lại, phép đo theo font thật', (t) async {
    await t.pumpWidget(dung(const ValueKey(1)));
    final truoc = chu(t);
    expect(double.parse(truoc.substring(5)), greaterThan(84), reason: 'font test 1 em/ký tự: 6 × 14 (+ giãn chữ của theme)');
    await t.runAsync(() async {
      final l = FontLoader(ho)
        ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync())));
      await l.load();
    });
    await t.pump();
    final sau = chu(t);
    await t.pumpWidget(dung(const ValueKey(2)));
    final moi = chu(t);
    expect(moi, isNot(truoc), reason: 'Roboto hẹp hơn font test');
    expect(sau, moi, reason: 'bố cục dựng TRƯỚC khi font nạp vẫn giữ phép đo theo font dự phòng');
  });
}
