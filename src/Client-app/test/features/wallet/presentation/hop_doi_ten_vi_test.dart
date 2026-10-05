/// Hộp Đổi tên ví (G63, spec mục 5.4; màn Stitch `5fea1834ebe344e3a4f53ce64feee2bb`) — ô tên có bộ lọc độ dài như
/// mọi ô tên khác (bẫy 10).
library;

import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/hop_doi_ten_vi.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? ketQua;
  var daDong = false;

  Future<void> moHop(WidgetTester tester, {String? Function(String)? kiemTen}) async {
    ketQua = null;
    daDong = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                ketQua = await hoiTenMoiChoVi(ctx, goiY: 'Ví MB Bank (2)', kiemTen: kiemTen ?? (_) => null);
                daDong = true;
              },
              child: const Text('MO'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('MO'));
    await tester.pumpAndSettle();
  }

  testWidgets('⭐ điền sẵn tên gợi ý; Lưu trả tên đã cắt khoảng trắng', (tester) async {
    await moHop(tester);
    expect(find.text('Đổi tên ví'), findsOneWidget);
    expect(find.text('Ví MB Bank (2)'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('o-ten-vi-moi')), '  Ví MB phụ  ');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nut-luu-ten-vi')));
    await tester.pumpAndSettle();
    expect(daDong, isTrue);
    expect(ketQua, 'Ví MB phụ');
  });

  testWidgets('tên lỗi → hiện câu lỗi, nút Lưu tắt', (tester) async {
    await moHop(tester, kiemTen: (t) => t.trim().isEmpty ? 'Hãy nhập tên ví.' : null);
    await tester.enterText(find.byKey(const ValueKey('o-ten-vi-moi')), '');
    await tester.pump();
    expect(find.text('Hãy nhập tên ví.'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('nut-luu-ten-vi'))).onPressed, isNull);
  });

  testWidgets('Hủy → null', (tester) async {
    await moHop(tester);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(daDong, isTrue);
    expect(ketQua, isNull);
  });

  testWidgets('⭐ ô tên cắt ở độ rộng cột (bẫy 10)', (tester) async {
    await moHop(tester);
    await tester.enterText(find.byKey(const ValueKey('o-ten-vi-moi')), 'A' * 150);
    await tester.pump();
    final o = tester.widget<TextField>(find.byKey(const ValueKey('o-ten-vi-moi')));
    expect(o.controller!.text.runes.length, DoRongCot.tenVi);
  });
}
