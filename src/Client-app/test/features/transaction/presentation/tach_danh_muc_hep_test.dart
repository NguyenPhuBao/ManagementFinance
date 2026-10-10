/// A5 mục 11.6 — bố cục khối tách và sheet *Thêm phần* ở 320 dp / 360 dp với FONT THẬT (họ lỗi G74–G84: chữ bị cắt
/// mất thông tin mà `flutter test` với font Ahem không thấy). Số tiền 13 chữ số trong một dòng phần phải đọc được trọn.
library;

import 'package:flowmoney/features/transaction/domain/doc_mon_hang.dart';
import 'package:flowmoney/features/transaction/domain/tach_giao_dich.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/khoi_tach.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/sheet_them_phan.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/font_that.dart';
import '../../category/presentation/category_test_fakes.dart';

void main() {
  final anUong = makeCategory(id: 'an', name: 'Ăn uống', isDefault: true);
  final giaDinh = makeCategory(id: 'gd', name: 'Gia đình', isDefault: true);
  final dai = makeCategory(id: 'dai', name: 'Đồ dùng cá nhân và gia đình', isDefault: true);

  setUp(napFontThat);

  void khoKhung(WidgetTester tester, double rong, {double cao = 800}) {
    tester.view.physicalSize = Size(rong, cao);
    tester.view.devicePixelRatio = 1.0;
    // Roboto (font test) hẹp hơn Inter thật — phóng ×1,1 để chừa biên (như G80 / G83).
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  void khongCatChu(WidgetTester tester) {
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(p.didExceedMaxLines, isFalse, reason: 'chữ bị cắt: "${p.text.toPlainText()}"');
    }
  }

  for (final rong in [320.0, 360.0]) {
    testWidgets('khối tách ở $rong dp: số 13 chữ số, tên dài — không tràn, không cắt', (tester) async {
      khoKhung(tester, rong);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: KhoiTach(
              chinh: anUong,
              tong: 9999999999999,
              phan: const [
                PhanTach(categoryId: 'dai', soTien: 9999999999990, monIds: {1, 2, 3}),
                PhanTach(categoryId: 'gd', soTien: 1),
              ],
              danhMuc: {'dai': dai, 'gd': giaDinh},
              onSua: (_) {},
              onBo: (_) {},
              onThem: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      khongCatChu(tester);
      expect(find.text('9.999.999.999.990 đ'), findsOneWidget);
      expect(find.text('còn lại, tự tính'), findsOneWidget);
    });

    testWidgets('sheet chọn món ở $rong dp × 640 + bàn phím hệ thống: không tràn', (tester) async {
      khoKhung(tester, rong, cao: 640);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => moSheetThemPhan(
                ctx,
                chonDuoc: [anUong, giaDinh, dai],
                daDung: const {'an'},
                mon: const [
                  MonHang(id: 0, ten: 'NUOC GIAT OMO MATIC CUA TREN 3KG', soTien: 1234567),
                  MonHang(id: 1, ten: 'GIAY VS PULPPY 10C', soTien: 45000),
                  MonHang(id: 2, ten: 'GIAM GIA KM', soTien: -10000),
                ],
                monCuaPhanKhac: const {1: 'Mua sắm'},
              ),
              child: const Text('mo'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      khongCatChu(tester);
      // Chuyển sang nhập số khi bàn phím hệ thống mở.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.tap(find.byKey(const Key('phan-nhap-so')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('phan-so-tien')), findsOneWidget);
    });
  }
}
