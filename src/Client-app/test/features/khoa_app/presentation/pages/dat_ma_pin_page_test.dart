import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flowmoney/features/khoa_app/presentation/pages/dat_ma_pin_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/khoa_app_gia.dart';

void main() {
  late InMemoryKhoaAppStore kho;
  late KhoaAppService sv;
  bool? ketQua;
  late DateTime now;

  setUp(() {
    kho = InMemoryKhoaAppStore();
    now = DateTime(2026, 10, 25, 9);
    sv = KhoaAppService(store: kho, kenh: KenhGia(), bam: bamNhanh, clock: () => now);
    ketQua = null;
  });

  Widget app(CheDatPin che) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => ketQua = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => DatMaPinPage(che: che, service: sv, idaccount: 10, dongHo: () => now))),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );

  Future<void> mo(WidgetTester t, CheDatPin che) async {
    await t.pumpWidget(app(che));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
  }

  Future<void> go(WidgetTester t, String pin) async {
    for (final c in pin.split('')) {
      await t.tap(find.byKey(Key('phim-$c')));
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  testWidgets('dat: mới → nhập lại khớp → cất cấu hình, pop(true)', (t) async {
    await mo(t, CheDatPin.dat);
    expect(find.text('Nhập mã PIN mới'), findsOneWidget);
    await go(t, '246810');
    expect(find.text('Nhập lại mã PIN'), findsOneWidget);
    await go(t, '246810');
    expect(ketQua, isTrue);
    expect(await kho.doc(10), isNotNull);
  });

  testWidgets('dat: nhập lại lệch → câu lỗi, ở lại bước nhập lại', (t) async {
    await mo(t, CheDatPin.dat);
    await go(t, '246810');
    await go(t, '111111');
    expect(find.text('Hai mã PIN không khớp — nhập lại'), findsOneWidget);
    expect(ketQua, isNull);
    await go(t, '246810');
    expect(ketQua, isTrue);
  });

  testWidgets('doi: PIN hiện tại sai → câu sai; đúng → sang bước mới', (t) async {
    await sv.datPin(10, '246810');
    await mo(t, CheDatPin.doi);
    expect(find.text('Nhập mã PIN hiện tại'), findsOneWidget);
    await go(t, '000000');
    expect(find.text('Mã PIN không đúng'), findsOneWidget);
    await go(t, '246810');
    expect(find.text('Nhập mã PIN mới'), findsOneWidget);
    await go(t, '135790');
    await go(t, '135790');
    expect(ketQua, isTrue);
    expect((await sv.kiemPin(10, '135790')).dung, isTrue);
  });

  testWidgets('tat: PIN hiện tại đúng → xoá cấu hình', (t) async {
    await sv.datPin(10, '246810');
    await mo(t, CheDatPin.tat);
    expect(find.text('Để tắt khoá ứng dụng'), findsOneWidget);
    await go(t, '246810');
    expect(ketQua, isTrue);
    expect(await kho.doc(10), isNull);
  });

  testWidgets('doi: sai nhiều lần → câu Thử lại sau mm:ss', (t) async {
    await sv.datPin(10, '246810');
    await mo(t, CheDatPin.doi);
    for (var i = 0; i < 5; i++) {
      await go(t, '000000');
    }
    expect(find.textContaining('Thử lại sau'), findsOneWidget);
  });


  testWidgets('doi: kho hỏng khi kiểm PIN → câu không kiểm được, không ngoại lệ', (t) async {
    await sv.datPin(10, '246810');
    kho.hongKhiGhi = true;
    await mo(t, CheDatPin.doi);
    await go(t, '000000');
    expect(find.text(kCauKhongKiemDuoc), findsOneWidget);
    expect(find.text('Mã PIN không đúng'), findsNothing);
    expect(t.takeException(), isNull);
    expect(ketQua, isNull);
  });

  testWidgets('dat: kho hỏng khi lưu → câu không lưu được, chưa pop', (t) async {
    await mo(t, CheDatPin.dat);
    await go(t, '246810');
    kho.hongKhiGhi = true;
    await go(t, '246810');
    expect(find.text('Không lưu được mã PIN — thử lại'), findsOneWidget);
    expect(ketQua, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('doi: mở giữa lúc chờ → đếm ngược, phím khoá; hết hạn → PIN đúng qua', (t) async {
    await sv.datPin(10, '246810');
    final c = (await kho.doc(10))!;
    await kho.ghi(10, c.voiLanSai(5, now.add(const Duration(seconds: 30))));
    await mo(t, CheDatPin.doi);
    expect(find.text('Thử lại sau 00:30'), findsOneWidget);
    await t.tap(find.byKey(const Key('phim-1')));
    await t.pump();
    expect(chamPin('day'), findsNothing);
    now = now.add(const Duration(seconds: 31));
    await t.pump(const Duration(seconds: 31));
    expect(find.textContaining('Thử lại sau'), findsNothing);
    await go(t, '246810');
    expect(find.text('Nhập mã PIN mới'), findsOneWidget);
  });
  for (final kich in [const Size(360, 800), const Size(360, 640)]) {
    testWidgets('bố cục ${kich.width.toInt()}x${kich.height.toInt()}: căn giữa, không tràn', (t) async {
      t.view.physicalSize = kich;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await mo(t, CheDatPin.dat);
      expect(t.takeException(), isNull);
      expect(t.getCenter(find.text('Nhập mã PIN mới')).dx, closeTo(180, 0.5));
      expect(t.getCenter(find.byKey(const Key('phim-5'))).dx, closeTo(180, 0.5));
      expect(chamPin('rong'), findsNWidgets(6));
      await t.tap(find.byKey(const Key('phim-1')));
      await t.pump();
      expect(chamPin('day'), findsOneWidget);
      expect(chamPin('rong'), findsNWidgets(5));
    });
  }

  test('CheDatPin.tuTen: lạ → dat', () {
    expect(CheDatPin.tuTen('doi'), CheDatPin.doi);
    expect(CheDatPin.tuTen('x'), CheDatPin.dat);
  });
}
