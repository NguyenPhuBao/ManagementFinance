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

  // `vuaSoDong`: chữ có vẽ trọn trong [soDong] dòng ở bề rộng cho trước không — cùng họ chữ + cỡ chữ hệ thống như `Text`.
  testWidgets('vuaSoDong: "aaaa bbbb" (font test 1 em/ký tự, cỡ 10) ở 50 dp cần đúng hai dòng', (t) async {
    late bool mot, hai, ba;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          const kieu = TextStyle(fontSize: 10, letterSpacing: 0);
          mot = vuaSoDong(context, 'aaaa bbbb', kieu, 50, 1);
          hai = vuaSoDong(context, 'aaaa bbbb', kieu, 50, 2);
          ba = vuaSoDong(context, 'aaaa bbbb', kieu, 200, 1);
          return const SizedBox();
        }),
      ),
    ));
    expect(mot, isFalse, reason: '90 dp chữ không vừa một dòng 50 dp');
    expect(hai, isTrue, reason: 'xuống dòng ở dấu cách: "aaaa" / "bbbb"');
    expect(ba, isTrue);
  });

  testWidgets('vuaSoDong tính cỡ chữ hệ thống: ×2 thì "aaaa bbbb" ở 100 dp không còn vừa hai dòng', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    late bool hai;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          hai = vuaSoDong(context, 'aaaa bbbb', const TextStyle(fontSize: 10, letterSpacing: 0), 70, 2);
          return const SizedBox();
        }),
      ),
    ));
    expect(hai, isFalse, reason: 'cỡ 20: mỗi từ 80 dp > 70 dp — bẻ giữa từ, quá hai dòng');
  });

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
