/// Con số lớn ở đầu màn Thêm giao dịch không được xuống dòng.
///
/// Canh chừng điều gì: số tiền ở đây là `Text` cỡ **48**, và ở 411dp thì
/// `9.999.999.999.999đ` — **đúng trần** mà `themPhimSoTien` cho gõ — **xuống
/// hai dòng**, chữ "đ" rơi xuống dòng dưới và cả khối đẩy phần còn lại của màn
/// xuống theo. Đo trên máy ảo 2026-09-18.
///
/// ⚠️ Đây **không** phải tràn bố cục: không có sọc vàng, không có
/// `FlutterError`, `takeException()` trả `null`. `Text` chỉ lặng lẽ ngắt dòng.
/// Nên phép đo phải là **số dòng thật sự vẽ ra**, không phải sự vắng mặt của
/// một exception — cùng bài học G43.
///
/// Cùng họ với lỗi đã vá ở ô số dư ví cùng ngày (G45): một trần số chữ số biến
/// giá trị lớn nhất thành **hợp lệ đạt tới được**, và bố cục chưa từng được thử
/// với giá trị ấy.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/transaction/presentation/widgets/so_tien_lon.dart';

void main() {
  Widget dung(String chu, {double rong = 411}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: rong,
              child: SoTienLon(chu: chu, mau: Colors.black),
            ),
          ),
        ),
      );

  /// Chiều cao khối số. Một dòng cỡ 48 cao khoảng 56px; ngắt thành hai dòng là
  /// gấp đôi. Đo chiều cao thay vì đếm dòng vì `RenderParagraph` của bản Flutter
  /// này không có `computeLineMetrics`.
  double cao(WidgetTester t) => t.getSize(find.byType(SoTienLon)).height;

  testWidgets('số dài nhất mà bàn phím cho gõ vẫn nằm trên MỘT dòng',
      (t) async {
    await t.pumpWidget(dung('9.999.999.999.999đ'));
    await t.pumpAndSettle();

    expect(cao(t), lessThan(80),
        reason: 'Đo máy ảo 2026-09-18: ở cỡ 48 con số này xuống hai dòng, chữ '
            '"đ" rơi xuống dòng dưới và cả khối đẩy phần còn lại của màn xuống '
            'theo. Không có sọc vàng nào vì `Text` chỉ NGẮT DÒNG chứ không '
            'tràn — `takeException()` trả null. Ngưỡng 80 nằm giữa một dòng '
            '(~56) và hai dòng (~112).');
  });

  testWidgets('số ngắn vẫn giữ cỡ chữ lớn, không bị co vô cớ', (t) async {
    await t.pumpWidget(dung('50.000đ'));
    await t.pumpAndSettle();

    final para = t.renderObject<RenderParagraph>(
      find.descendant(
          of: find.byType(SoTienLon), matching: find.byType(RichText)),
    );
    expect(para.text.style!.fontSize, 48,
        reason: 'Co chữ là việc của FittedBox khi CẦN. Một con số ngắn phải '
            'giữ nguyên cỡ thiết kế.');
    expect(cao(t), lessThan(80));
  });

  testWidgets('"0đ" không làm nổ gì', (t) async {
    await t.pumpWidget(dung('0đ'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(cao(t), lessThan(80));
  });
}
