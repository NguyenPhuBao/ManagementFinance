/// Hai thẻ lối vào *"việc chờ bạn duyệt"* ở Sổ giao dịch (`TheViecChoDuyet`: D1 *"Có N mục chờ ghi"*, C1 *"Có N giao dịch
/// chưa có danh mục"*) ở khổ hẹp và cỡ chữ lớn.
///
/// Đo bằng font thật 2026-10-26: nút bên phải (*"Gắn nhanh"*, *"Xem"*) giữ bề rộng tự nhiên nên cột chữ còn 63 dp ở 320 dp
/// và 103 dp ở 360 dp ngay ở cỡ chữ thường — tiêu đề C1 cụt ở dòng thứ hai, dòng phụ D1 cụt *"Tin ngân hàng, biên lai và
/// lần …"* (Realme 320 dp × cỡ chữ 1,6); ở 320 dp × 1,76 cột chữ C1 còn 0 dp. ×1,76 ≈ Inter ở 1,6 (Roboto hẹp hơn).
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/transaction/presentation/widgets/the_chua_gan_danh_muc.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

const _tieuDeD1 = 'Có 10 mục chờ ghi';
const _tieuDeC1 = 'Có 12 giao dịch chưa có danh mục';
const _phuD1 = 'Tin ngân hàng, biên lai và lần dùng app ngân hàng — bạn duyệt trước khi lưu';
const _phuC1 = 'Gợi ý từ ghi chú của bạn, bạn duyệt trước khi lưu';

void main() {
  setUp(napFontThat);

  Future<void> dung(WidgetTester t, double rong, double co) async {
    t.view.physicalSize = Size(rong, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Column(children: [
          TheBienDongChuaGhi(soBienDong: 10, onXem: () {}),
          TheChuaGanDanhMuc(soGiaoDich: 12, onGanNhanh: () {}),
        ]),
      ),
    ));
    await t.pump();
  }

  void veTron(WidgetTester t, String chu, String vi) {
    final o = find.text(chu);
    expect(o, findsOneWidget, reason: 'chữ trên thẻ không đổi: "$chu"');
    final p = t.renderObject<RenderParagraph>(o);
    expect(p.didExceedMaxLines, isFalse, reason: '$vi: "$chu" bị cắt');
    expect(p.size.width, greaterThan(40), reason: '$vi: cột chữ bị ép còn ${p.size.width.toStringAsFixed(0)} dp');
  }

  for (final (rong, co) in [(320.0, 1.76), (320.0, 1.0), (360.0, 1.0), (360.0, 1.1)]) {
    testWidgets('$rong dp × $co: tiêu đề + dòng phụ hai thẻ vẽ trọn, nút trong thẻ', (t) async {
      await dung(t, rong, co);
      expect(t.takeException(), isNull);
      final vi = '$rong dp × $co';
      for (final chu in [_tieuDeD1, _phuD1, _tieuDeC1, _phuC1]) {
        veTron(t, chu, vi);
      }
      for (final k in ['the-bien-dong-xem', 'the-chua-gan-gan-nhanh']) {
        final nut = t.getRect(find.byKey(Key(k)));
        // Mép thẻ = màn trừ margin ngang 16, trừ đệm 12.
        expect(nut.right, lessThanOrEqualTo(rong - 16 - 12 + 0.5), reason: '$vi: nút $k tràn khỏi thẻ');
        expect(nut.left, greaterThanOrEqualTo(16 + 12 - 0.5));
      }
    });
  }

  // Đối chứng: đủ chỗ thì bố cục Stitch giữ nguyên — nút bên phải, ngang hàng khối chữ.
  testWidgets('411 dp × 1,0: nút đứng bên phải khối chữ, cùng hàng', (t) async {
    await dung(t, 411, 1.0);
    expect(t.takeException(), isNull);
    for (final (tieuDe, phu, k) in [
      (_tieuDeD1, _phuD1, 'the-bien-dong-xem'),
      (_tieuDeC1, _phuC1, 'the-chua-gan-gan-nhanh'),
    ]) {
      final nut = t.getRect(find.byKey(Key(k)));
      final dau = t.getRect(find.text(tieuDe));
      final cuoi = t.getRect(find.text(phu));
      expect(nut.left, greaterThanOrEqualTo(cuoi.right - 0.5), reason: '$k phải đứng bên phải khối chữ');
      expect(nut.center.dy, inInclusiveRange(dau.top, cuoi.bottom), reason: '$k phải ngang hàng khối chữ, không xuống dưới');
    }
  });
}
