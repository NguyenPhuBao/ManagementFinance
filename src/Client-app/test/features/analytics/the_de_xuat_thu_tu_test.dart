/// Thẻ "đưa lên đầu trang" và dòng "Về mặc định" — dự án C việc ba, màn Stitch
/// `e081fc951e474cb1bc1b4ed655f5a026` *"Thống kê - Đề xuất thứ tự khối"*.
library;

import 'package:flowmoney/features/analytics/domain/thu_tu_khoi.dart';
import 'package:flowmoney/features/analytics/presentation/widgets/the_de_xuat_thu_tu.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget w) => MaterialApp(
      // ⚠️ Theme THẬT: theme app ép ElevatedButton rộng vô hạn (bẫy 4.11).
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: SizedBox(width: 328, child: w))),
    );

void main() {
  testWidgets('chữ đúng + hai nút gọi đúng hàm', (tester) async {
    var dua = 0, bo = 0;
    await tester.pumpWidget(_app(TheDeXuatThuTu(
        cum: CumKhoi.coCau, onDuaLen: () => dua++, onBoQua: () => bo++)));
    expect(find.text('THỨ TỰ KHỐI'), findsOneWidget);
    expect(find.textContaining('Bạn hay xem', findRichText: true), findsOneWidget);
    expect(find.textContaining('Cơ cấu danh mục', findRichText: true), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('thu-tu-dua-len')));
    await tester.tap(find.byKey(const ValueKey('thu-tu-bo-qua')));
    expect((dua, bo), (1, 1));
  });

  testWidgets('nút × ở góc (theo Stitch) cũng là Bỏ qua', (tester) async {
    var bo = 0;
    await tester.pumpWidget(_app(TheDeXuatThuTu(
        cum: CumKhoi.coCau, onDuaLen: () {}, onBoQua: () => bo++)));
    await tester.tap(find.byKey(const ValueKey('thu-tu-dong')));
    expect(bo, 1,
        reason: 'Stitch vẽ thêm × cạnh nút Bỏ qua — hai lối, một nghĩa; '
            'không có lối "đóng tạm" thứ ba mà luật học không biết');
  });

  for (final cum in CumKhoi.values) {
    testWidgets('360 dp (lề 16): không tràn với cụm "${cum.ten}"', (tester) async {
      await tester.pumpWidget(_app(TheDeXuatThuTu(cum: cum, onDuaLen: () {}, onBoQua: () {})));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dòng Về mặc định: bấm gọi hàm, không tràn ở 328', (tester) async {
    var n = 0;
    await tester.pumpWidget(_app(DongVeMacDinh(onVeMacDinh: () => n++)));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Thứ tự khối đang theo thói quen xem của bạn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('thu-tu-ve-mac-dinh')));
    expect(n, 1);
  });
}
