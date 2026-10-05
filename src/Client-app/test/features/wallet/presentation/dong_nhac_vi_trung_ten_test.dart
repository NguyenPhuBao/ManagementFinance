/// Dòng nhắc "N ví trùng tên đang chờ bạn xử lý" ở Trang chủ (G63, spec mục 5.5; màn Stitch
/// `5dd90541f4cc4be398a8f2840bcec9d6`).
library;

import 'package:flowmoney/features/wallet/data/vi_trung_ten_nguon.dart';
import 'package:flowmoney/features/wallet/presentation/an_nhac_vi_trung_ten.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/dong_nhac_vi_trung_ten.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NguonGia implements ViTrungTenNguon {
  _NguonGia(this.soCap);
  final int soCap;

  /// `Stream.value` là stream MỘT người nghe — đúng tính chất của stream thật
  /// (`watch` + `asyncMap`): widget nghe lại nó là ném "already been listened to".
  @override
  Stream<List<CapViHienThi>> theoDoi(int idaccount) => Stream.value([
        for (var i = 0; i < soCap; i++)
          CapViHienThi(
              idViMayNay: 'r$i', idViDaDongBo: 'p$i', ten: 'Ví $i', soDuMayNay: 0, soDuDaDongBo: 0, soGiaoDich: 0),
      ]);
  @override
  Future<Set<String>> viCanTha(int idaccount) async => {};
  @override
  Future<Set<String>> viDangBiGiu(int idaccount) async => {};
}

void main() {
  late AnNhacViTrungTen an;
  late int soLanMo;

  Future<void> dung(WidgetTester tester, int soCap, {Size kho = const Size(411, 900)}) async {
    tester.view.physicalSize = kho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    an = AnNhacViTrungTen();
    soLanMo = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Column(children: [
          DongNhacViTrungTen(idaccount: 7, nguon: _NguonGia(soCap), an: an, moQuanLyVi: () => soLanMo++),
          const Text('DUOI'),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('không có cặp → không dựng gì, không chiếm chỗ', (tester) async {
    await dung(tester, 0);
    expect(find.byKey(const ValueKey('dong-nhac-vi-trung-ten')), findsNothing);
    expect(tester.getSize(find.byType(DongNhacViTrungTen)).height, 0);
  });

  testWidgets('⭐ có cặp → câu đếm đúng; chạm → mở Quản lý ví', (tester) async {
    await dung(tester, 2);
    expect(find.text('2 ví trùng tên đang chờ bạn xử lý'), findsOneWidget);
    await tester.tap(find.text('2 ví trùng tên đang chờ bạn xử lý'));
    expect(soLanMo, 1);
  });

  testWidgets('⭐ ✕ ẩn trong lần mở app này; đặt lại cờ thì hiện lại', (tester) async {
    await dung(tester, 1);
    await tester.tap(find.byTooltip('Ẩn lời nhắc'));
    await tester.pump();
    expect(find.byKey(const ValueKey('dong-nhac-vi-trung-ten')), findsNothing);
    expect(soLanMo, 0, reason: 'chạm ✕ không được mở Quản lý ví');
    an.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('dong-nhac-vi-trung-ten')), findsOneWidget);
  });

  testWidgets('360 dp → không tràn', (tester) async {
    await dung(tester, 12, kho: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });
}
