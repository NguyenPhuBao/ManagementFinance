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
    KhoanTichLuy(
      ngay: DateTime(2026, 9, 7),
      soTien: 100000,
      laKhoanRut: false,
      laTuDong: false,
    ),
    KhoanTichLuy(
      ngay: DateTime(2026, 9, 1),
      soTien: 500000,
      laKhoanRut: true,
      laTuDong: false,
    ),
    // Khoản duy nhất do bộ trích tự động ghi.
    KhoanTichLuy(
      ngay: DateTime(2026, 7, 1),
      soTien: 200000,
      laKhoanRut: false,
      laTuDong: true,
    ),
  ];

  Widget dung(List<KhoanTichLuy> ds) => MaterialApp(
        home: Scaffold(
          body: GoalHistorySheet(tenMucTieu: 'MuaXe', khoan: ds, now: now),
        ),
      );

  testWidgets('CHỈ dòng do app tự trích mới mang nhãn "Tự động"',
      (tester) async {
    await tester.pumpWidget(dung(khoan));

    expect(find.text('Tự động'), findsOneWidget,
        reason: 'Ba khoản, một cái tự động. Nhãn dán lên cả ba là nói dối về '
            'việc ai đã chuyển tiền — mà khoản trích tự động và khoản nạp tay '
            'cố ý giống hệt nhau trên mọi cột khác, nên không còn gì trên màn '
            'hình cãi lại được.');
  });

  testWidgets('không khoản nào tự động thì không có nhãn nào', (tester) async {
    await tester.pumpWidget(dung([
      KhoanTichLuy(
        ngay: DateTime(2026, 9, 7),
        soTien: 100000,
        laKhoanRut: false,
        laTuDong: false,
      ),
    ]));

    expect(find.text('Tự động'), findsNothing,
        reason: 'Mọi khoản ghi trước đợt này đều đọc là "tay". Nhãn phải VẮNG '
            'MẶT chứ không được đoán ngược cho lịch sử cũ.');
  });

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
        laTuDong: false,
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
        laTuDong: false,
      ),
      // Dòng chật nhất dựng được: chip "Tự động" và số tiền dài cùng tranh bề
      // rộng với tiêu đề trên một hàng.
      KhoanTichLuy(
        ngay: DateTime(2026, 9, 6),
        soTien: 987654321,
        laKhoanRut: false,
        laTuDong: true,
      ),
    ]));

    expect(tester.takeException(), isNull,
        reason: 'Bảy chip trên hai dải cần nhiều hơn 411dp. Dùng `Wrap` thì '
            'chúng xuống hàng và ăn mất một dòng lịch sử; dải cuộn ngang thì '
            'không bao giờ tràn — cùng bài học ở trung tâm thông báo. Chip '
            '"Tự động" là thứ MỚI chen vào hàng tiêu đề, và máy ảo không kiểm '
            'hộ được: nó chỉ hiện từ kỳ trích tự động kế tiếp trở đi.');
    expect(find.text('Tự động'), findsOneWidget);
  });
}
