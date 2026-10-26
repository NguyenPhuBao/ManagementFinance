// test/features/home/presentation/widgets/hang_nut_nhanh_test.dart
/// C4 §2.3 — hàng năm nút nhanh ở Trang chủ (thêm *Nói*). Năm vòng 56 dp cố định `spaceBetween` tràn ở 320 dp, nên mỗi
/// nút là một ô `Expanded`, vòng 52 dp, nhãn co bằng `FittedBox`. ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ
/// chứa ca đo font thật.
library;

import 'package:flowmoney/features/home/presentation/widgets/hang_nut_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

/// P17: chữ phải giữ ít nhất ngần này cỡ tự nhiên (không co tí hon) ở cỡ chữ thường. 0,85 → 0,8 ngày 2026-10-26 (phiên 9):
/// mỗi ô chừa 2 dp hai bên cho hai nhãn không dính (*"Thêm thuThêm chi"* trên Realme 320 dp) — ở 320 dp × 1,1 *"Thêm thu"*
/// 62,5 dp vào ô 50,4 dp = 0,81.
const _nguongCo = 0.8;

/// Cỡ vẽ thật / cỡ tự nhiên của nhãn [n] (13 sp × [co]) — đo bằng CHIỀU CAO hộp vẽ (`getRect`, gồm cả phép co nếu có), nên
/// đúng cho cả cách co bằng `FittedBox` lẫn co bằng cỡ chữ.
double _tiLeCo(WidgetTester t, String n, double co) {
  final p = t.renderObject<RenderParagraph>(find.text(n));
  final tp = TextPainter(
    text: TextSpan(text: n, style: p.text.style!.copyWith(fontSize: 13)),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(co),
  )..layout();
  final r = t.getRect(find.text(n)).height / tp.height;
  tp.dispose();
  return r;
}

void main() {
  setUp(napFontThat);

  final nhan = ['Thêm thu', 'Thêm chi', 'Chuyển', 'Quét', 'Nói'];
  final nut = [
    for (final (i, n) in nhan.indexed)
      NutNhanh(bieuTuong: Icons.mic_none, nhan: n, dam: i < 2, onTap: () {}, khoa: Key('nut-$i')),
  ];

  // Lề NGANG 24 dp = lề thật của Trang chủ (home_page.dart:59); ×1,1 bù Roboto hẹp hơn Inter (nếp G80/G83).
  // ×1,76 ≈ Inter ở cỡ chữ 1,6 (Realme buổi 4, 2026-10-26): cỡ ấy được phép co sâu, nhưng vẫn phải đều + có khe.
  for (final (rong, co) in [(320.0, 1.0), (320.0, 1.1), (360.0, 1.0), (411.0, 1.0), (320.0, 1.76), (360.0, 1.76)]) {
    testWidgets('$rong dp ×$co: năm nút không tràn, nhãn đủ chữ', (tester) async {
      tester.view.physicalSize = Size(rong, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = co;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home:
            Scaffold(body: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: HangNutNhanh(nut: nut))),
      ));
      expect(tester.takeException(), isNull);
      final tiLe = {for (final n in nhan) n: _tiLeCo(tester, n, co)};
      for (final n in nhan) {
        expect(find.text(n), findsOneWidget);
        if (co <= 1.1) {
          expect(tiLe[n], greaterThanOrEqualTo(_nguongCo),
              reason:
                  'Nhãn "$n" ở $rong dp ×$co co còn ${tiLe[n]!.toStringAsFixed(3)}, dưới ${(_nguongCo * 100).round()} % cỡ tự nhiên — chữ tí hon.');
        }
      }
      final cacCo = [for (final v in tiLe.values) v * 13 * co];
      final lech = cacCo.reduce((a, b) => a > b ? a : b) - cacCo.reduce((a, b) => a < b ? a : b);
      expect(lech, lessThan(0.2),
          reason: '$rong dp ×$co: năm nhãn phải CÙNG cỡ vẽ (co đều theo nhãn rộng nhất) — đang là '
              '${cacCo.map((c) => c.toStringAsFixed(2)).join(' · ')}');
      for (var i = 1; i < nhan.length; i++) {
        final khe = tester.getRect(find.text(nhan[i])).left - tester.getRect(find.text(nhan[i - 1])).right;
        expect(khe, greaterThanOrEqualTo(2),
            reason: '$rong dp ×$co: "${nhan[i - 1]}" và "${nhan[i]}" cách ${khe.toStringAsFixed(1)} dp — dính nhau');
      }
      final x = [for (var i = 0; i < 5; i++) tester.getCenter(find.byKey(Key('nut-$i'))).dx];
      for (var i = 1; i < 5; i++) {
        expect(x[i], greaterThan(x[i - 1]), reason: 'năm nút trên một hàng, đúng thứ tự');
      }
    });
  }

  test('duongNutNoi: có quyền → /add?noi=1; Basic → màn Nâng cấp mở bằng tên tính năng', () {
    expect(duongNutNoi(coQuyen: true), '/add?noi=1');
    expect(duongNutNoi(coQuyen: false), '/premium?quyen=ai_quick_input');
  });
}
