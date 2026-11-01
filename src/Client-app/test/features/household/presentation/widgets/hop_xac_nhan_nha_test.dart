import 'dart:async';

import 'package:flowmoney/features/household/presentation/widgets/hop_xac_nhan_nha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  setUpAll(napFontThat);

  Future<Future<bool>> mo(WidgetTester t, Future<bool> Function(BuildContext) hoi) async {
    dat360(t);
    late BuildContext ctx;
    await t.pumpWidget(bocTrangNha(Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    final f = hoi(ctx);
    await t.pumpAndSettle();
    return f;
  }

  /// Kết quả hộp, KHÔNG `await` mù: hộp chưa đóng thì [f] không bao giờ xong và `await f` treo ~10 phút thay vì đỏ.
  /// Trả `null` khi hộp còn mở (assertion đỏ).
  Future<bool?> ketQua(WidgetTester t, Future<bool> f) async {
    bool? v;
    unawaited(f.then((x) => v = x));
    await t.pump();
    await t.pump();
    return v;
  }

  testWidgets('rời nhà: chữ theo Stitch; Ở lại → false, Rời nhà → true', (t) async {
    final f = await mo(t, hoiRoiNha);
    expect(find.text('Dữ liệu của nhà sẽ được gỡ khỏi máy này. Khoản bạn đã ghi vẫn ở lại nhà.'), findsOneWidget);
    await t.tap(find.text('Ở lại'));
    await t.pumpAndSettle();
    expect(await ketQua(t, f), isFalse, reason: "hộp phải đã đóng với false");
    final f2 = await mo(t, hoiRoiNha);
    await t.tap(find.widgetWithText(FilledButton, 'Rời nhà'));
    await t.pumpAndSettle();
    expect(await ketQua(t, f2), isTrue, reason: "hộp phải đã đóng với true");
  });

  testWidgets('bấm ra ngoài hộp là không làm (false, không phải null ném)', (t) async {
    final f = await mo(t, (c) => hoiMoiRa(c, 'Nguyễn Linh'));
    expect(find.text('Mời Nguyễn Linh ra khỏi nhà?'), findsOneWidget);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.text('Mời Nguyễn Linh ra khỏi nhà?'), findsNothing, reason: 'chạm ra ngoài phải ĐÓNG hộp (barrier), không để mở');
    expect(await ketQua(t, f), isFalse, reason: "hộp phải đã đóng với false");
  });

  testWidgets('giải tán hai bước: nút khoá tới khi gõ đúng tên, không bộ đếm ký tự', (t) async {
    final f = await mo(t, (c) => hoiGiaiTan(c, 'Nhà Đạt – Linh'));
    expect(find.text('Quỹ chung, sổ chung và danh mục của nhà sẽ biến mất với mọi người.'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await t.pumpAndSettle();
    expect(find.text('Gõ tên nhà để xác nhận'), findsOneWidget);
    FilledButton nut() => t.widget(find.widgetWithText(FilledButton, 'Giải tán nhà'));
    expect(nut().onPressed, isNull);
    expect(find.textContaining(RegExp(r'\d+\s*/\s*\d+')), findsNothing, reason: 'spec 12.2: không bộ đếm "n/m" nào');
    await t.enterText(find.byType(TextField), 'nha dat');
    await t.pump();
    expect(nut().onPressed, isNull, reason: 'thiếu dấu là chưa khớp');
    await t.enterText(find.byType(TextField), ' nhà đạt – linh ');
    await t.pump();
    expect(nut().onPressed, isNotNull);
    await t.tap(find.widgetWithText(FilledButton, 'Giải tán nhà'));
    await t.pumpAndSettle();
    expect(await ketQua(t, f), isTrue, reason: "hộp phải đã đóng với true");
  });

  testWidgets('giải tán bước một Huỷ: không mở bước hai', (t) async {
    final f = await mo(t, (c) => hoiGiaiTan(c, 'Nhà An'));
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
    expect(await ketQua(t, f), isFalse, reason: "hộp phải đã đóng với false");
    expect(find.text('Gõ tên nhà để xác nhận'), findsNothing);
  });

  testWidgets('tên dài + bàn phím mở ở 360 dp: hộp không tràn', (t) async {
    dat360(t, banPhim: true);
    late BuildContext ctx;
    await t.pumpWidget(bocTrangNha(Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    final ten = 'Nhà ${'rất dài ' * 12}';
    hoiChuyenChu(ctx, ten);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('hộp gõ tên: tên 100 ký tự + bàn phím mở ở 360 dp không tràn, ô nhập còn thấy', (t) async {
    dat360(t, banPhim: true);
    late BuildContext ctx;
    await t.pumpWidget(bocTrangNha(Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    hoiGiaiTan(ctx, 'Nhà ${'a' * 96}');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('bố cục theo Stitch: biểu tượng trong ô tròn bên TRÁI tiêu đề, tiêu đề đậm canh trái', (t) async {
    await mo(t, hoiRoiNha);
    final tieuDe = find.text('Rời nhà?');
    final o = find.ancestor(
        of: find.byIcon(Icons.logout),
        matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).shape == BoxShape.circle));
    expect(o, findsOneWidget, reason: 'biểu tượng nằm trong ô tròn nhạt');
    expect(t.getRect(o).right, lessThan(t.getRect(tieuDe).left), reason: 'ô tròn bên trái tiêu đề');
    expect(t.widget<Text>(tieuDe).style?.fontWeight, FontWeight.w700);
    expect(t.widget<Text>(tieuDe).textAlign, isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(t.widget<AlertDialog>(find.byType(AlertDialog)).icon, isNull, reason: 'biểu tượng không còn ở giữa đỉnh hộp');
    expect(find.byKey(const Key('vach-do-hop')), findsNothing, reason: 'hộp Rời nhà không có vạch đỏ');
  });

  testWidgets('hộp giải tán: vạch đỏ trên đỉnh ở cả hai bước, tên nhà trong ô, nhãn TÊN XÁC NHẬN', (t) async {
    await mo(t, (c) => hoiGiaiTan(c, 'Nhà Đạt – Linh'));
    expect(find.byKey(const Key('vach-do-hop')), findsOneWidget, reason: 'bước 1');
    await t.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('vach-do-hop')), findsOneWidget, reason: 'bước 2');
    expect(find.text('TÊN XÁC NHẬN'), findsOneWidget);
    final oTen = find.byKey(const Key('o-ten-nha-giai-tan'));
    expect(find.descendant(of: oTen, matching: find.text('Nhà Đạt – Linh')), findsOneWidget);
    expect(t.getRect(find.byKey(const Key('vach-do-hop'))).top, lessThan(t.getRect(find.text('Gõ tên nhà để xác nhận')).top));
  });

  testWidgets('hộp cuộn được ở 360 dp + bàn phím + cỡ chữ lớn: không tràn', (t) async {
    dat360(t, banPhim: true);
    late BuildContext ctx;
    await t.pumpWidget(bocTrangNha(Builder(builder: (c) {
      ctx = c;
      return MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2)), child: const Scaffold());
    })));
    hoiChuyenChu(ctx, 'Nguyễn Linh');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
