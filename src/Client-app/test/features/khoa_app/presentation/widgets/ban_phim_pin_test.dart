import 'package:flowmoney/features/khoa_app/presentation/widgets/ban_phim_pin.dart';
import 'package:flowmoney/features/khoa_app/presentation/widgets/cham_pin.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/khoa_app_gia.dart';

Widget _boc(Widget w, {Size kho = const Size(360, 640)}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(data: MediaQueryData(size: kho), child: Scaffold(body: Center(child: w))),
    );

void main() {
  testWidgets('bàn phím 360×640 + 320×480 không tràn, đủ phím', (t) async {
    for (final kho in const [Size(360, 640), Size(320, 480)]) {
      t.view.physicalSize = kho;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(_boc(SizedBox(height: kho.height * 0.6, child: BanPhimPin(khiGo: (_) {}, khiXoa: () {}, khiVanTay: () {})), kho: kho));
      expect(t.takeException(), isNull, reason: 'tràn ở $kho');
      for (var d = 0; d <= 9; d++) {
        expect(find.byKey(Key('phim-$d')), findsOneWidget);
      }
      expect(find.byKey(const Key('phim-van-tay')), findsOneWidget);
    }
    addTearDown(t.view.reset);
  });

  testWidgets('gõ số / xoá / vân tay gọi đúng; tatSo chặn số nhưng vân tay vẫn chạy', (t) async {
    final go = <String>[];
    var xoa = 0, vanTay = 0;
    await t.pumpWidget(_boc(SizedBox(height: 400, child: BanPhimPin(
      khiGo: go.add, khiXoa: () => xoa++, khiVanTay: () => vanTay++))));
    await t.tap(find.byKey(const Key('phim-7')));
    await t.tap(find.byKey(const Key('phim-xoa')));
    await t.tap(find.byKey(const Key('phim-van-tay')));
    expect([go, xoa, vanTay], [['7'], 1, 1]);

    await t.pumpWidget(_boc(SizedBox(height: 400, child: BanPhimPin(
      khiGo: go.add, khiXoa: () => xoa++, khiVanTay: () => vanTay++, tatSo: true))));
    await t.tap(find.byKey(const Key('phim-3')));
    await t.tap(find.byKey(const Key('phim-van-tay')));
    expect([go, vanTay], [['7'], 2], reason: 'đang chờ: số tắt, vân tay vẫn mở được (spec mục 6)');
  });

  testWidgets('không có khiVanTay → ô trống, không phím vân tay', (t) async {
    await t.pumpWidget(_boc(SizedBox(height: 400, child: BanPhimPin(khiGo: (_) {}, khiXoa: () {}))));
    expect(find.byKey(const Key('phim-van-tay')), findsNothing);
  });

  testWidgets('ChamPin: 6 chấm, số chấm đầy theo soDaNhap', (t) async {
    await t.pumpWidget(_boc(const ChamPin(soDaNhap: 2)));
    expect(chamPin('day'), findsNWidgets(2));
    expect(chamPin('rong'), findsNWidgets(4));
  });
}
