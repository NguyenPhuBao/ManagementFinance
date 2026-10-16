import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flowmoney/core/ui/bieu_do_cham.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vẽ một biểu đồ đường sáu kỳ rồi đếm điểm ảnh đỏ ở NỬA TRÁI chấm đầu tiên.
///
/// Khổ vẽ là khổ thật của trang Phân tích ở 320 dp (Realme mật độ 540): vùng
/// vẽ ~190 dp sau 46 dp nhãn trục tung. Chấm bán kính 5 viền 2 là chấm to nhất
/// của app (chấm cuối khối Tổng tài sản).
Future<int> _demNuaTraiChamDau(
  WidgetTester tester, {
  required double minX,
  required double maxX,
  required FlClipData clip,
}) async {
  const trai = 46.0;
  const rong = 236.0;
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: Colors.white,
          width: rong,
          height: 120,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: 10,
              clipData: clip,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                // Giữ chỗ nhãn trục tung như trang thật nhưng không vẽ chữ:
                // font của bộ test vẽ chữ thành khối màu, lấn vào ô đếm.
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: trai,
                    getTitlesWidget: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < 6; i++) FlSpot(i.toDouble(), 5),
                  ],
                  color: const Color(0xFFFF0000),
                  barWidth: 1,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 5,
                      color: const Color(0xFFFF0000),
                      strokeWidth: 2,
                      strokeColor: const Color(0xFFFF0000),
                    ),
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  final hop = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // Tâm chấm đầu theo đúng phép chiếu của fl_chart: vùng vẽ [trai, rong].
  final cx = trai + (0 - minX) / (maxX - minX) * (rong - trai);
  var dem = 0;
  await tester.runAsync(() async {
    final anh = await hop.toImage();
    final b = (await anh.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    for (var x = (cx - 7).floor(); x < cx.floor(); x++) {
      for (var y = 53; y < 68; y++) {
        if (x < 0) continue;
        final i = (y * anh.width + x) * 4;
        if (b.getUint8(i) > 200 && b.getUint8(i + 1) < 80) dem++;
      }
    }
  });
  return dem;
}

void main() {
  group('trucNgangCoCham', () {
    test('nới hai đầu đúng một phần dải', () {
      final t = trucNgangCoCham(0, 5);
      expect(t.min, closeTo(-5 * kLeTrucCoCham, 1e-9));
      expect(t.max, closeTo(5 + 5 * kLeTrucCoCham, 1e-9));
    });

    test('dải rỗng (một kỳ) vẫn có lề, không chia cho 0', () {
      final t = trucNgangCoCham(3, 3);
      expect(t.min, lessThan(3));
      expect(t.max, greaterThan(3));
    });
  });

  group('laMocChiSo', () {
    test('mốc nguyên là chỉ số kỳ, mốc biên đã nới thì không', () {
      expect(laMocChiSo(0), isTrue);
      expect(laMocChiSo(5), isTrue);
      expect(laMocChiSo(-0.25), isFalse,
          reason: 'fl_chart hỏi nhãn ở cả hai biên đã nới; -0.25 làm tròn ra '
              '0 nên nhãn kỳ đầu sẽ in HAI lần lệch nhau vài dp.');
      expect(laMocChiSo(5.25), isFalse);
    });
  });

  testWidgets(
      '⭐ G79 — FlClipData.vertical() vẫn cắt nửa chấm mép trái; nới trục thì chấm '
      'đầu tròn đủ dù cắt hết', (tester) async {
    final khongCat = await _demNuaTraiChamDau(tester,
        minX: 0, maxX: 5, clip: const FlClipData.none());
    final catTrenDuoi = await _demNuaTraiChamDau(tester,
        minX: 0, maxX: 5, clip: const FlClipData.vertical());
    final t = trucNgangCoCham(0, 5);
    final noiTruc = await _demNuaTraiChamDau(tester,
        minX: t.min, maxX: t.max, clip: const FlClipData.all());

    expect(khongCat, greaterThan(40), reason: 'Tiền đề: chấm có vẽ.');
    expect(catTrenDuoi, lessThan(khongCat ~/ 4),
        reason: 'Tiền đề của G79: `FlClipData.vertical()` (G55) vẫn cắt nửa '
            'trái chấm ở minX trong fl_chart 1.2.0. Ca '
            'này đỏ nghĩa là thư viện đổi hành vi; xem lại cả lối nới trục.');
    // Không đòi bằng khít: tâm chấm rơi vào nửa điểm ảnh khác nên phần khử
    // răng cưa đếm lệch vài điểm (đo: 63 so với 73), còn bị cắt thì còn ~0.
    expect(noiTruc, greaterThanOrEqualTo(khongCat * 0.85),
        reason: 'Nới trục hai đầu thì chấm nằm trọn trong vùng vẽ, nên cắt cả '
            'bốn mép (phòng thủ bẫy 4.17) cũng không mất nửa chấm.');
  });
}
