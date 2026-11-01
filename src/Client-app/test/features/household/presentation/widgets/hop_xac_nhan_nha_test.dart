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
}
