// test/features/home/presentation/widgets/hang_nut_nhanh_test.dart
/// C4 §2.3 — hàng năm nút nhanh ở Trang chủ (thêm *Nói*). Năm vòng 56 dp cố định `spaceBetween` tràn ở 320 dp, nên mỗi
/// nút là một ô `Expanded`, vòng 52 dp, nhãn co bằng `FittedBox`. ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ
/// chứa ca đo font thật.
library;

import 'package:flowmoney/features/home/presentation/widgets/hang_nut_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

/// P17: chữ phải giữ ít nhất ngần này bề rộng tự nhiên (không co tí hon).
const _nguongCo = 0.85;

void main() {
  setUp(napFontThat);

  final nhan = ['Thêm thu', 'Thêm chi', 'Chuyển', 'Quét', 'Nói'];
  final nut = [
    for (final (i, n) in nhan.indexed)
      NutNhanh(bieuTuong: Icons.mic_none, nhan: n, dam: i < 2, onTap: () {}, khoa: Key('nut-$i')),
  ];

  for (final rong in [320.0, 360.0, 411.0]) {
    testWidgets('$rong dp: năm nút không tràn, nhãn đủ chữ', (tester) async {
      tester.view.physicalSize = Size(rong, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: HangNutNhanh(nut: nut))),
      ));
      expect(tester.takeException(), isNull);
      for (final n in nhan) {
        expect(find.text(n), findsOneWidget);
        // P17: `getSize` = kích thước tự nhiên (không co); `getRect` áp phép biến đổi của FittedBox = bề rộng vẽ thật.
        final tuNhien = tester.getSize(find.text(n)).width;
        final veThat = tester.getRect(find.text(n)).width;
        // ignore: avoid_print
        print('DO|$rong|$n|tu nhien ${tuNhien.toStringAsFixed(1)}|ve ${veThat.toStringAsFixed(1)}|'
            '${(veThat / tuNhien).toStringAsFixed(3)}');
        expect(veThat / tuNhien, greaterThanOrEqualTo(_nguongCo),
            reason: 'Nhãn "$n" ở $rong dp co dưới ${(_nguongCo * 100).round()} % bề rộng tự nhiên — chữ tí hon.');
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
