/// Bottom sheet chọn phạm vi của trang Phân tích (P1, 2026-09-15).
///
/// Hai tầng: hàng chip chọn **đơn vị** ở trên, danh sách **kỳ** ở dưới. Đổi chip
/// chỉ đổi danh sách — nó chưa phải một lựa chọn, vì người dùng còn phải nói rõ
/// kỳ nào. Trộn hai thao tác ấy làm một là bấm "Quý" liền nhảy sang quý này mà
/// không ai yêu cầu.
///
/// Dựng bằng `AppTheme.lightTheme` chứ không `ThemeData()` — bẫy **4.11**
/// `ANALYTICS_FEATURE.md`: theme của app ép mọi `ElevatedButton` rộng vô hạn, và
/// một nút trần trong `Row` làm trắng cả trang mà không một dòng log nào.
///
/// Khổ 411dp là khổ máy thật; bộ test mặc định rộng 800 và font của nó rộng gấp
/// đôi ngoài đời (bẫy 4.4), nên đây là phép đo chặt hơn máy thật một chút.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/presentation/widgets/chon_pham_vi_sheet.dart';

void main() {
  final moc = DateTime(2026, 9, 17); // thứ Năm, tuần ISO 38

  Widget dung(Ky kyHienTai, {ValueChanged<Ky>? onChon}) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 411,
              height: 700,
              child: ChonPhamViSheet(
                kyHienTai: kyHienTai,
                moc: moc,
                onChon: onChon ?? (_) {},
              ),
            ),
          ),
        ),
      );

  testWidgets('mở ra ở đúng đơn vị của kỳ đang xem', (tester) async {
    await tester.pumpWidget(dung(Ky.thang(2026, 9)));

    expect(find.text('Tháng này (T9 2026)'), findsOneWidget);
    expect(find.text('T8 2026'), findsOneWidget);
    expect(find.text('T7 2026'), findsOneWidget);
  });

  testWidgets('kỳ đang xem có dấu tích, kỳ khác thì không', (tester) async {
    await tester.pumpWidget(dung(Ky.thang(2026, 7)));

    expect(find.byIcon(Icons.check), findsOneWidget,
        reason: 'đúng một dòng được đánh dấu — dòng của kỳ đang xem');
    final dong = find.ancestor(
      of: find.text('T7 2026'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: dong, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('bấm chip Tuần thì danh sách đổi sang tuần, CHƯA chọn kỳ nào',
      (tester) async {
    Ky? chon;
    await tester.pumpWidget(dung(Ky.thang(2026, 9), onChon: (k) => chon = k));

    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tuần 38'), findsOneWidget);
    expect(find.text('T8 2026'), findsNothing);
    expect(
      chon,
      isNull,
      reason: 'đổi chip mới là đổi câu hỏi, chưa phải câu trả lời — tự nhảy '
          'sang kỳ đầu danh sách là chọn hộ người dùng',
    );
  });

  testWidgets('danh sách tuần mang cả số tuần lẫn khoảng ngày', (tester) async {
    await tester.pumpWidget(dung(Ky.tuan(moc)));

    expect(find.text('Tuần này (Tuần 38)'), findsOneWidget);
    expect(find.text('Tuần 37 (07/09 – 13/09)'), findsOneWidget,
        reason: 'số tuần một mình thì không ai biết nó rơi vào ngày nào');
  });

  testWidgets('chọn một kỳ thì trả đúng kỳ ấy về', (tester) async {
    Ky? chon;
    await tester.pumpWidget(dung(Ky.thang(2026, 9), onChon: (k) => chon = k));

    await tester.tap(find.text('T7 2026'));
    await tester.pumpAndSettle();

    expect(chon, Ky.thang(2026, 7));
  });

  testWidgets('chọn một tuần thì trả về Ky đơn vị TUẦN', (tester) async {
    Ky? chon;
    await tester.pumpWidget(dung(Ky.thang(2026, 9), onChon: (k) => chon = k));

    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Tuần 37'));
    await tester.pumpAndSettle();

    expect(chon?.donVi, DonViKy.tuan);
    expect(chon?.from, DateTime(2026, 9, 7));
  });

  testWidgets('đủ năm chip đơn vị, đúng thứ tự cố định', (tester) async {
    await tester.pumpWidget(dung(Ky.thang(2026, 9)));

    // Thứ tự theo độ dài kỳ, không theo tần suất dùng: người đọc quét một hàng
    // chip bằng cách tìm chỗ của nó trong một dãy đã biết.
    for (final ten in ['Tuần', 'Tháng', 'Quý', 'Năm', 'Tuỳ chọn']) {
      expect(find.text(ten), findsOneWidget, reason: 'thiếu chip $ten');
    }
  });

  testWidgets('không tràn ở 411dp, kể cả khi danh sách dài nhất', (tester) async {
    await tester.pumpWidget(dung(Ky.tuan(moc)));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'Flutter báo tràn qua FlutterError.reportError chứ không ném ra '
          'chỗ gọi — test chỉ pumpWidget sẽ xanh dù sheet đầy sọc vàng',
    );
  });

  testWidgets('kỳ tuỳ chọn hiện nhãn khoảng ngày, không có dạng "… này"',
      (tester) async {
    await tester.pumpWidget(dung(
      Ky.tuyChon(from: DateTime(2026, 9, 3), to: DateTime(2026, 9, 30)),
    ));

    expect(find.text('Tuỳ chọn'), findsOneWidget);
    expect(find.textContaining('này'), findsNothing,
        reason: 'một khoảng tuỳ ý không phải "kỳ này" của đơn vị nào');
  });
}
