/// `NhanCoDeu` — một nhóm nhãn đứng trong các ô bằng nhau (năm nút nhanh Trang chủ, hai tab Ngân sách) co **cùng một hệ
/// số**: hệ số của nhãn rộng nhất. `FittedBox` riêng từng nhãn (G68 / G76) co nhãn dài mà giữ nhãn ngắn — cỡ chữ 1,6 trên
/// Realme (2026-10-26, buổi 4 `KHOA_APP_FEATURE.md`): *"Quét"*, *"Nói"* to hơn hẳn ba nhãn bên cạnh.
library;

import 'dart:io';

import 'package:flowmoney/shared/widgets/nhan_co_deu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nhom = ['Thêm thu', 'Quét', 'Nói'];

  Widget hang(double rongO, {double coChu = 1}) => MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(coChu)),
          child: child!,
        ),
        home: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in nhom)
                SizedBox(
                  width: rongO,
                  child: Center(child: NhanCoDeu(n, nhom: nhom, kieu: const TextStyle(fontSize: 13))),
                ),
            ],
          ),
        ),
      );

  RenderParagraph doan(WidgetTester t, String n) => t.renderObject<RenderParagraph>(find.text(n));

  testWidgets('ô hẹp: mọi nhãn cùng MỘT cỡ (cỡ của nhãn rộng nhất), không nhãn nào vượt ô', (t) async {
    await t.pumpWidget(hang(60));
    final co = {for (final n in nhom) doan(t, n).text.style!.fontSize!};
    expect(co.length, 1, reason: 'mỗi nhãn tự co riêng là "Quét" / "Nói" to hơn "Thêm thu" — cỡ phải chung: $co');
    expect(co.single, lessThan(13), reason: 'font test rộng 1 em/ký tự: "Thêm thu" 104 dp không vừa ô 60 dp');
    for (final n in nhom) {
      expect(t.getSize(find.text(n)).width, lessThanOrEqualTo(60.5), reason: '"$n" vượt ô');
      expect(doan(t, n).didExceedMaxLines, isFalse, reason: '"$n" bị cắt');
    }
  });

  testWidgets('ô đủ rộng: giữ nguyên cỡ thiết kế, không phóng', (t) async {
    await t.pumpWidget(hang(200));
    for (final n in nhom) {
      expect(doan(t, n).text.style!.fontSize, 13);
    }
  });

  testWidgets('cỡ chữ hệ thống 1,5, ô đủ rộng: cỡ vẽ = 13 × 1,5, áp MỘT lần (không nhân đôi qua textScaler)', (t) async {
    await t.pumpWidget(hang(250, coChu: 1.5));
    for (final n in nhom) {
      final p = doan(t, n);
      expect(p.text.style!.fontSize! * p.textScaler.scale(1), closeTo(19.5, 0.01));
    }
  });

  testWidgets('cỡ chữ hệ thống 1,5, ô hẹp: hệ số tính trên chữ ĐÃ phóng — vẫn vừa ô', (t) async {
    await t.pumpWidget(hang(80, coChu: 1.5));
    for (final n in nhom) {
      expect(t.getSize(find.text(n)).width, lessThanOrEqualTo(80.5), reason: '"$n" vượt ô ở cỡ chữ 1,5');
    }
  });
  // Font của app (Inter, tải bằng `google_fonts`) nạp SAU khung đầu. Nhãn dựng lúc ấy đo theo font dự phòng và phải đo
  // lại khi font nạp xong — máy ảo 320 dp × cỡ chữ 1,6 (2026-10-26) vẽ nút "Googl" cụt chữ ở màn Đăng nhập mở lạnh vì
  // đo theo font dự phòng hẹp hơn Inter. Ở đây ngược chiều (font test rộng hơn Roboto) nhưng cùng phép kiểm: sau khi font
  // nạp, cỡ vẽ phải bằng cỡ của một nhãn dựng mới.
  testWidgets('font nạp SAU khung đầu: nhãn đo lại theo font thật', (t) async {
    const ho = 'FontNapMuonNhanCoDeu';
    Widget dung(Key k) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60,
                child: NhanCoDeu('Google', key: k, nhom: const ['Google'], kieu: const TextStyle(fontFamily: ho, fontSize: 14)),
              ),
            ),
          ),
        );
    await t.pumpWidget(dung(const ValueKey(1)));
    final truoc = doan(t, 'Google').text.style!.fontSize!;
    expect(truoc, lessThan(14), reason: 'font test 1 em/ký tự: "Google" 84 dp không vừa ô 60 dp');
    await t.runAsync(() async {
      final l = FontLoader(ho)
        ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync())));
      await l.load();
    });
    await t.pump();
    final sau = doan(t, 'Google').text.style!.fontSize!;
    await t.pumpWidget(dung(const ValueKey(2)));
    final moi = doan(t, 'Google').text.style!.fontSize!;
    expect(moi, greaterThan(truoc), reason: 'Roboto hẹp hơn font test — nhãn dựng mới phải to hơn');
    expect(sau, closeTo(moi, 0.01), reason: 'nhãn dựng TRƯỚC khi font nạp vẫn giữ cỡ đo theo font dự phòng');
  });
}
