/// Màn **Xem trước báo cáo** với dữ liệu dựng sẵn.
///
/// Canh chừng điều gì: tầng thuần đã kiểm phép cộng, tệp này kiểm những gì chỉ
/// widget mới sai được — số nào lên thẻ nào, khoảng thời gian hiện ra có đúng
/// là khoảng người dùng chọn không (biên `to` MỞ, hiện thẳng nó là lệch một
/// ngày), nhãn bộ lọc, và khổ 411dp của điện thoại thật với tên danh mục dài.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flowmoney/features/analytics/presentation/pages/report_preview_page.dart';

void main() {
  // `DateFormatter` dùng locale `vi_VN`, và `intl` **ném lỗi** chứ không lùi về
  // mặc định khi locale chưa nạp. Ngoài đời `main.dart` gọi hàm này lúc khởi
  // động; trong test thì phải tự gọi, nếu không cả trang chết ngay ở dòng ngày
  // đầu tiên — trắng màn hình chứ không phải sai một chữ.
  setUpAll(() => initializeDateFormatting('vi_VN', null));

  DongGiaoDich g({
    required DateTime ngay,
    double soTien = 100000,
    String loai = 'chi',
    String? danhMuc = 'c_an',
    String tenDanhMuc = 'Ăn uống',
    String tenVi = 'Tiền mặt',
    String tieuDe = 'Ăn trưa',
  }) =>
      DongGiaoDich(
        id: '$ngay$tieuDe',
        ngay: ngay,
        soTien: soTien,
        loai: loai,
        categoryId: danhMuc,
        tenDanhMuc: tenDanhMuc,
        mauHex: '#F25F5C',
        icon: 'restaurant',
        walletId: 'w1',
        tenVi: tenVi,
        tieuDe: tieuDe,
      );

  BaoCao baoCao(List<DongGiaoDich> ds) => dungBaoCao(
        ds,
        loc: LocBaoCao(
            from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
      );

  // THEME THẬT của app, không phải `MaterialApp` trần: theme đặt
  // `minimumSize: Size(double.infinity, 52)` cho mọi `ElevatedButton`, nên một
  // nút đặt trong `Row` mà không có `Expanded` sẽ đòi chiều rộng vô hạn và làm
  // **hỏng cả khung hình**. Test dựng bằng MaterialApp trần không thấy gì cả —
  // đã vấp thật ngày 2026-09-09: bộ test xanh, máy ảo trắng trang.
  Widget duoi(BaoCao bc, {String nhanVi = 'Tất cả ví'}) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: ReportPreviewPage(
          baoCao: bc,
          nhanVi: nhanVi,
          nhanDanhMuc: 'Tất cả danh mục',
          dinhDang: 'PDF',
          lapNgay: DateTime(2026, 9, 9),
        ),
      );

  /// Khổ điện thoại thật. **Không** dùng `MediaQuery` để giả khổ hẹp: nó chỉ
  /// đổi `MediaQuery.of(context).size`, còn ràng buộc bố cục vẫn là 800×600
  /// của khung test — tức là test "411dp" kiểu ấy chưa bao giờ chạy ở 411dp.
  void khoDienThoai(WidgetTester t) {
    t.view.physicalSize = const Size(411 * 3, 900 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
  }

  testWidgets('ba thẻ tổng lấy số từ báo cáo', (t) async {
    khoDienThoai(t);
    // Chia khoản chi làm hai danh mục để con số trên thẻ "TỔNG CHI" không
    // trùng với bất kỳ dòng nào bên dưới — nếu trùng thì test vẫn xanh khi
    // widget lấy nhầm số của một dòng làm số của thẻ.
    await t.pumpWidget(duoi(baoCao([
      g(ngay: DateTime(2026, 9, 5), loai: 'thu', soTien: 14625000),
      g(ngay: DateTime(2026, 9, 6), loai: 'chi', soTien: 600000),
      g(
        ngay: DateTime(2026, 9, 7),
        loai: 'chi',
        danhMuc: 'c_xe',
        tenDanhMuc: 'Di chuyển',
        soTien: 445000,
      ),
    ])));

    expect(find.text('14.625.000 ₫'), findsOneWidget);
    expect(find.text('1.045.000 ₫'), findsOneWidget);
    expect(find.text('13.580.000 ₫'), findsOneWidget,
        reason: 'Còn lại = thu − chi. Đây là con số người dùng nhìn đầu tiên '
            'trên tờ báo cáo mang đi nộp.');
  });

  testWidgets('khoảng thời gian hiện NGÀY CUỐI THẬT, không hiện biên mở',
      (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([g(ngay: DateTime(2026, 9, 5))])));

    expect(find.text('01/09/2026 – 30/09/2026'), findsOneWidget,
        reason: 'Biên `to` là 01/10 và MỞ. Hiện thẳng nó ra là tờ báo cáo tự '
            'nhận có dữ liệu của một ngày mà nó không hề đếm.');
  });

  testWidgets('chip hiện đúng nhãn bộ lọc đang áp', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(
        duoi(baoCao([g(ngay: DateTime(2026, 9, 5))]), nhanVi: 'Ngân hàng'));

    expect(find.text('Ngân hàng'), findsOneWidget,
        reason: 'Tờ báo cáo phải tự nói nó lọc theo gì — nếu không, hai tờ in '
            'ra từ hai bộ lọc khác nhau trông y hệt nhau.');
    expect(find.text('Tất cả danh mục'), findsOneWidget);
  });

  testWidgets('bảng chi theo danh mục hiện tên, tiền và phần trăm', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([
      g(ngay: DateTime(2026, 9, 5), soTien: 750000),
      g(
        ngay: DateTime(2026, 9, 6),
        danhMuc: 'c_xe',
        tenDanhMuc: 'Di chuyển',
        soTien: 250000,
      ),
    ])));

    expect(find.text('750.000 ₫'), findsOneWidget);
    expect(find.text('(75,0%)'), findsOneWidget);
    expect(find.text('(25,0%)'), findsOneWidget);
  });

  testWidgets('giao dịch gom dưới tiêu đề ngày, kèm tên ví', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([
      g(ngay: DateTime(2026, 9, 8, 9), tieuDe: 'Ăn trưa'),
      g(ngay: DateTime(2026, 9, 8, 20), tieuDe: 'Cà phê'),
    ])));

    expect(find.text('08/09/2026'), findsOneWidget,
        reason: 'Một tiêu đề cho cả ngày, không phải mỗi dòng một tiêu đề.');
    expect(find.text('Ăn trưa'), findsOneWidget);
    expect(find.text('Cà phê'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsNWidgets(2));
  });

  testWidgets('khoản thu mang dấu +, khoản chi mang dấu −', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([
      g(ngay: DateTime(2026, 9, 5), loai: 'thu', soTien: 500000, tieuDe: 'Lương'),
      g(ngay: DateTime(2026, 9, 6), loai: 'chi', soTien: 80000),
    ])));

    expect(find.text('+500.000 ₫'), findsOneWidget);
    expect(find.text('-80.000 ₫'), findsOneWidget);
  });

  testWidgets('báo cáo rỗng nói rõ là rỗng, không vẽ bảng trống', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([])));

    expect(find.textContaining('Không có giao dịch'), findsOneWidget);
    expect(find.text('CHI THEO DANH MỤC'), findsNothing,
        reason: 'Bảng rỗng với tiêu đề đầy đủ trông như lỗi tải dữ liệu.');
  });

  testWidgets('nút Tải xuống chưa làm gì thì phải TẮT, không giả vờ', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([g(ngay: DateTime(2026, 9, 5))])));

    final nut = t.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Tải xuống'),
    );
    expect(nut.onPressed, isNull,
        reason: 'Sinh tệp là lát 2c-2. Nút bấm được mà không ra tệp chính là '
            'kiểu "nút xuất chỉ hiện snackbar" mà lát này đang đi dọn.');
  });

  testWidgets('411dp: tên danh mục dài và số hàng trăm triệu không tràn',
      (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([
      g(
        ngay: DateTime(2026, 9, 5),
        tenDanhMuc: 'Ăn uống ngoài hàng và giao tận nơi',
        tieuDe: 'Đặt cơm văn phòng cho cả nhóm dự án tốt nghiệp',
        soTien: 123456789,
      ),
      g(ngay: DateTime(2026, 9, 6), loai: 'thu', soTien: 987654321),
    ])));

    expect(t.takeException(), isNull,
        reason: 'Bộ test chạy 1280px còn điện thoại thật 411dp. Flutter báo '
            'tràn qua FlutterError.reportError chứ không ném ra chỗ gọi, nên '
            'không có dòng này thì test vẫn xanh khi màn hình đầy sọc vàng.');
  });
}
