/// Bảng lịch sử tích luỹ đầy đủ, mở từ nút "Xem tất cả".
///
/// Phần lọc thuần đã có test riêng ở `goal_history_filter_test.dart`. Tệp này
/// chỉ canh những gì **chỉ widget mới sai được**: chip có thật sự đổi danh
/// sách không, dòng tổng có đi theo bộ lọc không, và khổ 411dp.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/domain/goal_history_filter.dart';
import 'package:flowmoney/features/goal/presentation/widgets/goal_history_sheet.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  final khoan = [
    KhoanTichLuy(ngay: DateTime(2026, 9, 7), soTien: 100000, laKhoanRut: false),
    KhoanTichLuy(ngay: DateTime(2026, 9, 1), soTien: 500000, laKhoanRut: true),
    KhoanTichLuy(ngay: DateTime(2026, 7, 1), soTien: 200000, laKhoanRut: false),
  ];

  Widget dung(List<KhoanTichLuy> ds) => MaterialApp(
        home: Scaffold(
          body: GoalHistorySheet(tenMucTieu: 'MuaXe', khoan: ds, now: now),
        ),
      );

  testWidgets('mở ra là thấy tất cả, kèm dòng tổng hai chiều', (tester) async {
    await tester.pumpWidget(dung(khoan));

    expect(find.text('Gửi vào mục tiêu'), findsNWidgets(2));
    expect(find.text('Rút khỏi mục tiêu'), findsOneWidget);
    expect(find.textContaining('3 khoản'), findsOneWidget);
    expect(find.textContaining('đã rút'), findsOneWidget);
  });

  testWidgets('chọn "Đã rút" thì danh sách và dòng tổng đổi theo',
      (tester) async {
    await tester.pumpWidget(dung(khoan));

    await tester.tap(find.text('Đã rút'));
    await tester.pumpAndSettle();

    expect(find.text('Gửi vào mục tiêu'), findsNothing);
    expect(find.text('Rút khỏi mục tiêu'), findsOneWidget);
    expect(find.textContaining('1 khoản'), findsOneWidget,
        reason: 'Dòng tổng nằm ngay trên dải chip nên nó phải nói về đúng thứ '
            'đang hiện. Giữ tổng của cả danh sách là hai con số cãi nhau trên '
            'cùng một màn hình.');
  });

  testWidgets('hai bộ lọc cắt nhau, không phải cộng dồn', (tester) async {
    await tester.pumpWidget(dung(khoan));

    await tester.tap(find.text('Đã gửi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 ngày'));
    await tester.pumpAndSettle();

    expect(find.text('Gửi vào mục tiêu'), findsOneWidget,
        reason: 'Chỉ khoản 07/09 vừa là khoản gửi vừa nằm trong 30 ngày. '
            'Khoản 01/07 là gửi nhưng quá cũ, khoản 01/09 trong hạn nhưng là '
            'khoản rút.');
  });

  testWidgets('lọc ra rỗng thì nói rõ, không để trang trắng', (tester) async {
    await tester.pumpWidget(dung([
      KhoanTichLuy(
        ngay: DateTime(2026, 9, 7),
        soTien: 100000,
        laKhoanRut: false,
      ),
    ]));

    await tester.tap(find.text('Đã rút'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không có khoản nào khớp'), findsOneWidget,
        reason: 'Vùng trắng trông y hệt một lỗi tải dữ liệu, và người dùng vừa '
            'tự tay bấm ra nó nên càng dễ tưởng app hỏng.');
    expect(find.textContaining('đã gửi'), findsNothing,
        reason: 'Đọc trên máy thật thì dòng tổng "0 khoản · đã gửi 0 đ" cãi '
            'nhau với thân bảng đang nói không có gì. Rỗng thì nói rỗng, đừng '
            'cộng hai số 0 ra cho có.');
  });

  testWidgets('mục tiêu chưa có khoản nào thì không ném', (tester) async {
    await tester.pumpWidget(dung(const []));

    expect(tester.takeException(), isNull);
    expect(find.text('Không có khoản nào'), findsOneWidget,
        reason: 'Mục tiêu chưa nạp lần nào cũng đi qua đúng nhánh rỗng như khi '
            'lọc không ra gì — một câu cho cả hai ca, không phải "0 khoản · đã '
            'gửi 0 đ".');
  });

  testWidgets('không tràn bố cục ở khổ 411dp', (tester) async {
    tester.view.physicalSize = const Size(411 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(dung([
      KhoanTichLuy(
        ngay: DateTime(2026, 9, 7),
        soTien: 123456789,
        laKhoanRut: true,
      ),
    ]));

    expect(tester.takeException(), isNull,
        reason: 'Bảy chip trên hai dải cần nhiều hơn 411dp. Dùng `Wrap` thì '
            'chúng xuống hàng và ăn mất một dòng lịch sử; dải cuộn ngang thì '
            'không bao giờ tràn — cùng bài học ở trung tâm thông báo.');
  });
}
