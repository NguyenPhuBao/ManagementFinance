import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/bill/presentation/widgets/bill_grace_selector.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

/// Thanh chọn ân hạn của form hoá đơn: 0 · 7 · 15 · 30 · Khác (ô số).
///
/// Dùng chung cho form Thêm và form Sửa (bài học của thanh chu kỳ 06/09: cùng
/// một khái niệm mà hai form hai kiểu). Widget không giữ giá trị — form giữ
/// trong `BillSchedule.anHanNgay` và truyền xuống.
void main() {
  Future<void> dung(WidgetTester tester,
      {int giaTri = 0, String? loi, double rong = 411}) async {
    int? nhan;
    tester.view.physicalSize = Size(rong, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return BoChonAnHan(
            giaTri: nhan ?? giaTri,
            loi: loi,
            onChanged: (v) => setState(() => nhan = v),
          );
        }),
      ),
    ));
    await tester.pump();
  }

  testWidgets('năm ô trên MỘT hàng ở 411dp, không tràn', (tester) async {
    await dung(tester);
    final tops = [0, 7, 15, 30]
        .map((v) => tester.getRect(find.byKey(ValueKey('bill-grace-$v'))).top)
        .toSet()
      ..add(tester.getRect(find.byKey(const ValueKey('bill-grace-null'))).top);
    expect(tops, hasLength(1),
        reason: 'Năm ô phải nằm trên một hàng ngang — cùng luật với thanh chu '
            'kỳ, nơi bốn ô từng xếp dọc vì dùng Wrap.');
    expect(tester.takeException(), isNull,
        reason: 'Tràn bố cục ở bề rộng điện thoại thật chỉ lộ trong test khi '
            'dựng đúng 411dp và bắt bằng takeException.');
  });

  testWidgets('chạm 15 → onChanged(15), ô số không hiện', (tester) async {
    await dung(tester);
    await tester.tap(find.byKey(const ValueKey('bill-grace-15')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bill-grace-custom')), findsNothing);
  });

  testWidgets('chạm Khác → hiện ô số, gõ 20 giữ được 20', (tester) async {
    await dung(tester);
    await tester.tap(find.byKey(const ValueKey('bill-grace-null')));
    await tester.pump();
    final o = find.byKey(const ValueKey('bill-grace-custom'));
    expect(o, findsOneWidget);
    await tester.enterText(o, '20');
    await tester.pump();
    expect(tester.widget<TextField>(o).controller!.text, '20');
  });

  testWidgets('ô số chỉ nhận tối đa 3 chữ số', (tester) async {
    await dung(tester);
    await tester.tap(find.byKey(const ValueKey('bill-grace-null')));
    await tester.pump();
    final o = find.byKey(const ValueKey('bill-grace-custom'));
    await tester.enterText(o, '12345');
    await tester.pump();
    expect(tester.widget<TextField>(o).controller!.text, '123',
        reason: 'Trần ân hạn là 365; ô nhập chặn từ 4 chữ số để không ai gõ '
            'nhầm 1500 rồi mới bị từ chối.');
  });

  testWidgets('giá trị 20 lúc mở → ô Khác đang chọn và ô số điền sẵn 20',
      (tester) async {
    await dung(tester, giaTri: 20);
    final o = find.byKey(const ValueKey('bill-grace-custom'));
    expect(o, findsOneWidget,
        reason: 'Form Sửa mở hoá đơn có ân hạn 20 phải hiện đúng con số, '
            'không được nhảy về 0.');
    expect(tester.widget<TextField>(o).controller!.text, '20');
  });

  testWidgets('có lỗi thì hiện câu đỏ dưới thanh', (tester) async {
    await dung(tester,
        loi: 'Hạn trả phải trước ngày kết thúc kỳ kế tiếp (01/11)');
    expect(find.byKey(const ValueKey('bill-grace-error')), findsOneWidget);
    expect(find.textContaining('kỳ kế tiếp'), findsOneWidget);
  });
}
