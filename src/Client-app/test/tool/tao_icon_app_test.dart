/// Sinh ảnh nguồn cho icon app và splash — CHẠY TAY, mặc định bỏ qua.
///
/// ```
/// flutter test test/tool/tao_icon_app_test.dart --run-skipped
/// dart run flutter_launcher_icons
/// dart run flutter_native_splash:create
/// ```
///
/// Vì sao là một test: dự án không có Python hay ImageMagick, còn `dart run`
/// thường không có `dart:ui`; `flutter test` thì có Skia và vẽ được widget ra
/// PNG. Nhãn hiệu lấy từ màn Đăng nhập (glyph ví + chữ "FlowMoney") và design
/// system Kinetic Finance (đen #1A1A19 trên nền ấm #EDEDE9), nên icon không
/// phải một bức vẽ mới mà là cái app đã tự nhận mình.
///
/// ⚠️ Glyph vẽ bằng `CustomPainter`, KHÔNG dùng `Icon(Icons.account_balance_wallet)`:
/// môi trường `flutter test` không nạp font MaterialIcons, nên icon vẽ ra là
/// một ô vuông rỗng (đã vấp 2026-09-19: bản đầu sinh ra icon hình ô vuông).
/// Chữ cũng vậy (font Ahem), nên icon không mang chữ.
///
/// Ba tệp ra ở `assets/icon/`: `app_icon.png` (1024², đen bo góc, ví trắng —
/// icon thường và iOS), `app_icon_foreground.png` (1024², ví trắng trên nền
/// trong suốt, có lề an toàn cho adaptive icon Android), và `splash.png`
/// (1152², ô đen bo góc nhỏ ở giữa nền trong suốt — Android 12 đòi ảnh splash
/// 1152 với lề 1/3).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _ghi(WidgetTester tester, Widget w, double canh, String duong) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: canh, height: canh, child: w),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final anh = await ro.toImage(pixelRatio: 1);
    final bytes = await anh.toByteData(format: ui.ImageByteFormat.png);
    final f = File(duong)..createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _den = Color(0xFF1A1A19);

/// Glyph ví theo dáng `Icons.account_balance_wallet`: thân bo góc, túi bên
/// phải có nút bấm tròn. Toạ độ theo tỉ lệ cạnh, vẽ trong ô vuông `size`.
class _ViPainter extends CustomPainter {
  const _ViPainter({required this.mau, required this.nen});

  final Color mau;

  /// Màu "khoét" cho túi — cùng màu nền phía sau glyph.
  final Color nen;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final than = Paint()..color = mau;
    final khoet = Paint()..color = nen;

    // Thân ví.
    canvas.drawRRect(
      RRect.fromLTRBR(0.12 * s, 0.23 * s, 0.88 * s, 0.77 * s,
          Radius.circular(0.09 * s)),
      than,
    );
    // Túi bên phải, khoét vào thân, hở mép phải.
    canvas.drawRRect(
      RRect.fromLTRBR(0.56 * s, 0.40 * s, 0.80 * s, 0.60 * s,
          Radius.circular(0.05 * s)),
      khoet,
    );
    // Nút bấm.
    canvas.drawCircle(Offset(0.68 * s, 0.50 * s), 0.045 * s, than);
  }

  @override
  bool shouldRepaint(covariant _ViPainter old) =>
      old.mau != mau || old.nen != nen;
}

Widget _oDen({required double canh, required double boGoc, required double glyph}) {
  return Container(
    width: canh,
    height: canh,
    decoration: BoxDecoration(
      color: _den,
      borderRadius: BorderRadius.circular(boGoc),
    ),
    child: Center(
      child: CustomPaint(
        size: Size.square(glyph),
        painter: const _ViPainter(mau: Colors.white, nen: _den),
      ),
    ),
  );
}

void main() {
  testWidgets('sinh app_icon.png, app_icon_foreground.png, splash.png',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _ghi(
      tester,
      _oDen(canh: 1024, boGoc: 224, glyph: 800),
      1024,
      'assets/icon/app_icon.png',
    );
    // Adaptive icon: hệ điều hành cắt mask trong vùng 66% giữa, nên glyph nhỏ
    // hơn và nền để trong suốt (màu nền khai ở pubspec).
    await _ghi(
      tester,
      const Center(
        child: CustomPaint(
          size: Size.square(600),
          painter: _ViPainter(mau: Colors.white, nen: _den),
        ),
      ),
      1024,
      'assets/icon/app_icon_foreground.png',
    );
    await _ghi(
      tester,
      Center(child: _oDen(canh: 384, boGoc: 84, glyph: 300)),
      1152,
      'assets/icon/splash.png',
    );

    expect(File('assets/icon/app_icon.png').lengthSync(), greaterThan(1000));
  }, skip: true); // Chạy tay với --run-skipped; ghi tệp vào assets/icon/.
}
