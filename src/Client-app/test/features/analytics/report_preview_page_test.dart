/// Màn **Xem trước báo cáo** với dữ liệu dựng sẵn.
///
/// Canh chừng điều gì: tầng thuần đã kiểm phép cộng, tệp này kiểm những gì chỉ
/// widget mới sai được — số nào lên thẻ nào, khoảng thời gian hiện ra có đúng
/// là khoảng người dùng chọn không (biên `to` MỞ, hiện thẳng nó là lệch một
/// ngày), nhãn bộ lọc, và khổ 411dp của điện thoại thật với tên danh mục dài.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/analytics/data/xuat_tep_service.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flowmoney/features/analytics/presentation/pages/report_preview_page.dart';

class _DichVuGia implements XuatTepService {
  final goi = <String>[];
  Object? loi;
  String? noiLuu = 'Tải về/BaoCao_01-09-2026_30-09-2026.pdf';

  @override
  Future<String?> xuat(
    BaoCao bc, {
    required String dinhDang,
    required String nhanVi,
    required String nhanDanhMuc,
    required DateTime lapNgay,
  }) async {
    goi.add(dinhDang);
    if (loi != null) throw loi!;
    return noiLuu;
  }
}

void main() {
  late _DichVuGia dichVu;

  setUp(() async {
    dichVu = _DichVuGia();
    if (sl.isRegistered<XuatTepService>()) {
      await sl.unregister<XuatTepService>();
    }
    sl.registerFactory<XuatTepService>(() => dichVu);
  });

  tearDown(() async {
    if (sl.isRegistered<XuatTepService>()) {
      await sl.unregister<XuatTepService>();
    }
  });

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
    String vi = 'w1',
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
        walletId: vi,
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

  /// Cuộn tới khối cần kiểm. Trang báo cáo nay dài hơn một màn hình, và
  /// `ListView` **không dựng** hàng ngoài khung nhìn — `find.text` cho khối ở
  /// dưới sẽ trả rỗng dù widget hoàn toàn đúng (cùng bẫy 4.6 của bottom sheet).
  Future<void> cuonToi(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 300,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
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

    expect(find.text('14.625.000 đ'), findsOneWidget);
    expect(find.text('1.045.000 đ'), findsOneWidget);
    expect(find.text('13.580.000 đ'), findsOneWidget,
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

    await cuonToi(t, find.text('CHI THEO DANH MỤC'));
    // Không khẳng định trên số tiền: cùng con số ấy còn xuất hiện ở khối
    // "TOP 5 KHOẢN CHI" và ở danh sách giao dịch. Phần trăm thì chỉ bảng này
    // có.
    expect(find.text('(75,0%)'), findsOneWidget);
    expect(find.text('(25,0%)'), findsOneWidget);
  });

  testWidgets('giao dịch gom dưới tiêu đề ngày, kèm tên ví', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([
      g(ngay: DateTime(2026, 9, 8, 9), tieuDe: 'Ăn trưa'),
      g(ngay: DateTime(2026, 9, 8, 20), tieuDe: 'Cà phê'),
    ])));

    await cuonToi(t, find.text('DANH SÁCH GIAO DỊCH'));
    final khoi = find.byKey(const Key('khoiGiaoDich'));
    expect(find.descendant(of: khoi, matching: find.text('08/09/2026')),
        findsOneWidget,
        reason: 'Một tiêu đề cho cả ngày, không phải mỗi dòng một tiêu đề. '
            'Phải tìm TRONG khối giao dịch: ngày ấy nay còn hiện ở "Số liệu '
            'nhanh" và "Top 5 khoản chi".');
    expect(find.descendant(of: khoi, matching: find.text('Cà phê')),
        findsOneWidget);
    expect(find.descendant(of: khoi, matching: find.text('Tiền mặt')),
        findsNWidgets(2));
  });

  testWidgets('khoản thu mang dấu +, khoản chi mang dấu −', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([
      g(ngay: DateTime(2026, 9, 5), loai: 'thu', soTien: 500000, tieuDe: 'Lương'),
      g(ngay: DateTime(2026, 9, 6), loai: 'chi', soTien: 80000),
    ])));

    await cuonToi(t, find.text('DANH SÁCH GIAO DỊCH'));
    final khoi = find.byKey(const Key('khoiGiaoDich'));
    expect(find.descendant(of: khoi, matching: find.text('+500.000 đ')),
        findsOneWidget);
    expect(find.descendant(of: khoi, matching: find.text('-80.000 đ')),
        findsOneWidget);
  });

  testWidgets('báo cáo rỗng nói rõ là rỗng, không vẽ bảng trống', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([])));

    expect(find.textContaining('Không có giao dịch'), findsOneWidget);
    expect(find.text('CHI THEO DANH MỤC'), findsNothing,
        reason: 'Bảng rỗng với tiêu đề đầy đủ trông như lỗi tải dữ liệu.');
  });

  testWidgets('nút Tải xuống gọi dịch vụ xuất, kèm ĐÚNG định dạng đã chọn',
      (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([g(ngay: DateTime(2026, 9, 5))])));

    await t.tap(find.widgetWithText(ElevatedButton, 'Tải xuống'));
    await t.pumpAndSettle();

    expect(dichVu.goi, ['PDF'],
        reason: 'Định dạng người dùng chọn ở trang trước phải đi tới tận nơi '
            'sinh tệp. Bỏ qua nó là bấm CSV mà nhận PDF — không lỗi nào báo.');
  });

  testWidgets('lưu xong thì nói RÕ tệp nằm ở đâu', (t) async {
    khoDienThoai(t);
    await t.pumpWidget(duoi(baoCao([g(ngay: DateTime(2026, 9, 5))])));

    await t.tap(find.widgetWithText(ElevatedButton, 'Tải xuống'));
    await t.pumpAndSettle();

    expect(find.textContaining('Tải về/BaoCao_01-09-2026_30-09-2026.pdf'),
        findsOneWidget,
        reason: 'Tệp lưu vào bộ nhớ chung thì người dùng phải biết đường mà '
            'tìm. "Đã lưu" trống không thì họ vẫn phải đi lục cả máy.');
  });

  testWidgets('máy không lưu thẳng được thì KHÔNG nói dối là đã lưu', (t) async {
    khoDienThoai(t);
    dichVu.noiLuu = null; // Android 9 trở xuống: chỉ mở được sheet chia sẻ.
    await t.pumpWidget(duoi(baoCao([g(ngay: DateTime(2026, 9, 5))])));

    await t.tap(find.widgetWithText(ElevatedButton, 'Tải xuống'));
    await t.pumpAndSettle();

    expect(find.textContaining('Đã lưu'), findsNothing);
  });

  testWidgets('xuất tệp hỏng thì NÓI RA, không nuốt lỗi', (t) async {
    khoDienThoai(t);
    dichVu.loi = Exception('hết chỗ trống');
    await t.pumpWidget(duoi(baoCao([g(ngay: DateTime(2026, 9, 5))])));

    await t.tap(find.widgetWithText(ElevatedButton, 'Tải xuống'));
    await t.pumpAndSettle();

    expect(find.textContaining('Không xuất được'), findsOneWidget,
        reason: 'Bấm "Tải xuống" mà không thấy gì thì người dùng sẽ bấm tiếp '
            'mãi; im lặng là kiểu hỏng tệ nhất ở đây.');
  });

  group('các khối chi tiết thêm ở lát 2c-1b', () {
    BaoCao voiDongTien(List<DongGiaoDich> ds, {double soDu = 5000000}) =>
        dungBaoCao(ds,
            loc: LocBaoCao(
                from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
            soDuHienTai: soDu);

    testWidgets('khối dòng tiền hiện số dư đầu kỳ và cuối kỳ', (t) async {
      khoDienThoai(t);
      await t.pumpWidget(duoi(voiDongTien([
        g(ngay: DateTime(2026, 9, 5), loai: 'chi', soTien: 1000000),
      ])));

      expect(find.text('SỐ DƯ ĐẦU KỲ'), findsOneWidget);
      expect(find.text('6.000.000 đ'), findsOneWidget);
      expect(find.text('SỐ DƯ CUỐI KỲ'), findsOneWidget);
      expect(find.textContaining('Suy ngược từ số dư hiện tại'), findsOneWidget,
          reason: 'App không lưu lịch sử số dư nên hai con số này là suy ra. '
              'Ví tạo GIỮA kỳ mang theo số dư ban đầu không phải giao dịch, '
              'nên nó bị tính vào số dư đầu kỳ — người đọc có quyền biết con '
              'số từ đâu ra.');
      expect(find.text('5.000.000 đ'), findsOneWidget,
          reason: 'Đầu kỳ 6 triệu, chi 1 triệu, cuối kỳ 5 triệu — phép cân của '
              'cả tờ báo cáo phải đọc được bằng mắt.');
    });

    testWidgets('lọc theo ví thì khối dòng tiền biến mất, không hiện số 0',
        (t) async {
      khoDienThoai(t);
      final bc = dungBaoCao(
        [g(ngay: DateTime(2026, 9, 5))],
        loc: LocBaoCao(
            from: DateTime(2026, 9, 1),
            to: DateTime(2026, 10, 1),
            walletId: 'w1'),
        soDuHienTai: 5000000,
      );
      await t.pumpWidget(duoi(bc));
      expect(find.text('SỐ DƯ ĐẦU KỲ'), findsNothing);
    });

    testWidgets('thẻ tổng mang phần trăm so với kỳ trước', (t) async {
      khoDienThoai(t);
      await t.pumpWidget(duoi(dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), soTien: 200000),
        g(ngay: DateTime(2026, 8, 5), soTien: 100000),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)))));

      // Tìm đúng chuỗi có mũi tên: `textContaining('100,0%')` khớp nhầm ô
      // "(100,0%)" của bảng chi theo danh mục — khoản chi duy nhất thì tỉ lệ
      // của nó cũng là 100%. Test ấy xanh cả khi widget không hề vẽ phần so
      // sánh kỳ trước.
      expect(find.text('▲ 100,0%'), findsOneWidget,
          reason: 'Chi 200k so với 100k của tháng trước là tăng 100%. Không có '
              'con số này thì người đọc không biết tháng này bất thường hay '
              'bình thường.');
    });

    testWidgets('bảng thu theo danh mục hiện bên cạnh bảng chi', (t) async {
      khoDienThoai(t);
      await t.pumpWidget(duoi(dungBaoCao([
        g(
            ngay: DateTime(2026, 9, 5),
            loai: 'thu',
            danhMuc: 'c_luong',
            tenDanhMuc: 'Lương',
            soTien: 9000000),
        g(ngay: DateTime(2026, 9, 6), loai: 'chi', soTien: 100000),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)))));

      await cuonToi(t, find.text('THU THEO DANH MỤC'));
      expect(find.text('THU THEO DANH MỤC'), findsOneWidget);
      expect(find.text('Lương'), findsWidgets);
    });

    testWidgets('bảng ngân sách hiện hạn mức và đánh dấu khoản vượt', (t) async {
      khoDienThoai(t);
      await t.pumpWidget(duoi(dungBaoCao(
        [g(ngay: DateTime(2026, 9, 5), soTien: 1200000)],
        loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
        nganSach: const [
          DongNganSach(
              categoryId: 'c_an',
              ten: 'Ăn uống',
              hanMuc: 1000000,
              daChi: 1200000),
        ],
      )));

      await cuonToi(t, find.text('NGÂN SÁCH KỲ NÀY'));
      expect(find.text('NGÂN SÁCH KỲ NÀY'), findsOneWidget);
      expect(find.textContaining('Vượt'), findsOneWidget,
          reason: 'Vượt ngân sách là thứ người dùng cần thấy ngay, không phải '
              'tự so hai con số.');
    });

    testWidgets('bảng phân bổ theo ví và top khoản chi', (t) async {
      khoDienThoai(t);
      await t.pumpWidget(duoi(dungBaoCao([
        g(
            ngay: DateTime(2026, 9, 5),
            vi: 'v2',
            tenVi: 'Ngân hàng ACB',
            soTien: 700000,
            tieuDe: 'Thuê nhà'),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)))));

      await cuonToi(t, find.text('KHOẢN CHI LỚN NHẤT'));
      expect(find.text('KHOẢN CHI LỚN NHẤT'), findsOneWidget);
      expect(find.text('Thuê nhà'), findsWidgets);
      await cuonToi(t, find.text('PHÂN BỔ THEO VÍ'));
      expect(find.text('Ngân hàng ACB'), findsWidgets);
      expect(find.text('0 đ'), findsOneWidget,
          reason: 'Ví ấy không có khoản thu nào. "+0 đ" là số không mang dấu '
              'cộng — thấy trên máy ảo, và nó làm cả bảng trông như lỗi định '
              'dạng.');
      expect(find.text('+0 đ'), findsNothing);
    });

    testWidgets('số liệu nhanh hiện chi trung bình mỗi ngày', (t) async {
      khoDienThoai(t);
      await t.pumpWidget(duoi(dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), soTien: 300000),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)))));

      await cuonToi(t, find.text('CHI MỖI NGÀY'));
      expect(find.text('10.000 đ'), findsOneWidget);
    });

    testWidgets('có biểu đồ thu/chi trong kỳ', (t) async {
      khoDienThoai(t);
      await t.pumpWidget(duoi(dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), soTien: 300000),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)))));

      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  // ── G40: cột số tiền phải thẳng mép phải ──────────────────────────────────
  //
  // Người dùng bắt được lỗi này ở trang Phân tích ngày 2026-09-15 (bẫy 4.19
  // `ANALYTICS_FEATURE.md`), và trang Xem trước báo cáo mang **đúng cùng khuôn**
  // `Flexible(child: FittedBox(alignment: centerRight))` ở sáu chỗ. Đo trên máy
  // ảo cùng ngày: mép phải chữ dao động **856 → 949px** trong khối "Chi theo
  // danh mục" — lệch 93px, gấp ba lần con số 26,5px của trang Phân tích.
  //
  // `Flexible` và `Expanded` đều mang `flex: 1` nên chia đôi chỗ trống như
  // nhau; khác biệt là `Flexible` để con giữ **bề rộng tự nhiên**, rồi
  // `MainAxisAlignment.start` đẩy phần thừa về **cuối hàng**. Hàng có số ngắn
  // thừa nhiều, hàng có số dài thừa ít, nên `alignment: centerRight` đang canh
  // phải bên trong một cái hộp đang trôi.
  //
  // ⚠️ Phép đo bám **hộp**, không bám chuỗi: mép phải của một `Text` số tiền
  // không nói lên điều gì ở khối danh mục (sau nó còn ô phần trăm), và cùng một
  // chuỗi số tiền xuất hiện ở nhiều khối nên `find.text` không khoanh được
  // vùng. Lấy thẳng `RenderBox` của các `FittedBox` canh phải trong một khối là
  // đo đúng thứ quyết định chỗ chữ rơi xuống.
  group('G40 — cột số tiền thẳng mép phải', () {
    /// Báo cáo có đủ **sáu** khối mang khuôn ấy, và số tiền dài ngắn rất khác
    /// nhau — điều kiện cần để lỗi lộ ra. Số bằng nhau thì hai hàng thừa như
    /// nhau và ca test xanh oan dù mã vẫn sai.
    BaoCao duHinh() => dungBaoCao(
          [
            g(
              ngay: DateTime(2026, 9, 5),
              vi: 'v1',
              tenVi: 'Tiền mặt',
              danhMuc: 'c_an',
              tenDanhMuc: 'Ăn uống',
              soTien: 1500000,
              tieuDe: 'Thuê nhà',
            ),
            g(
              ngay: DateTime(2026, 9, 6),
              vi: 'v2',
              tenVi: 'Ngân hàng ACB',
              danhMuc: 'c_xe',
              tenDanhMuc: 'Di chuyển',
              soTien: 60000,
              tieuDe: 'Xe buýt',
            ),
            g(
              ngay: DateTime(2026, 9, 7),
              loai: 'thu',
              vi: 'v1',
              tenVi: 'Tiền mặt',
              danhMuc: 'c_luong',
              tenDanhMuc: 'Lương',
              soTien: 20000000,
              tieuDe: 'Lương tháng 9',
            ),
          ],
          loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
          soDuHienTai: 5000000,
          nganSach: const [
            DongNganSach(
                categoryId: 'c_an',
                ten: 'Ăn uống',
                hanMuc: 2000000,
                daChi: 1500000),
            DongNganSach(
                categoryId: 'c_xe',
                ten: 'Di chuyển',
                hanMuc: 90000,
                daChi: 60000),
          ],
        );

    /// Khổ **gấp đôi** 411dp, và đó là điều kiện để ca test này canh được gì.
    ///
    /// Lỗi chỉ xuất hiện khi chữ **ngắn hơn** suất được chia: khi ấy `Flexible`
    /// co hộp lại bằng bề rộng chữ và phần thừa rơi về cuối hàng. Nhưng font
    /// của `flutter test` là "Ahem" — mỗi ký tự rộng bằng cỡ chữ, tức gấp đôi
    /// ngoài đời (bẫy 4.4) — nên ở 411dp mọi chuỗi đều **tràn** suất, `FittedBox`
    /// thu nhỏ chúng cho vừa, và hộp nào cũng lấp đầy suất của nó. Ba ca đầu
    /// tiên viết ở 411dp **xanh ngay từ đầu** vì đúng lý do ấy, trong khi máy
    /// ảo đo được lệch 93px.
    ///
    /// Cho khung rộng gấp đôi là cách trả lại **đúng tỷ lệ chữ trên suất** của
    /// điện thoại thật. Ca "411dp … không tràn" ở cuối tệp vẫn giữ khổ thật.
    void khoGapDoi(WidgetTester t) {
      t.view.physicalSize = const Size(822 * 3, 900 * 3);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);
    }

    /// Mép phải của **hộp** cột tiền ở từng hàng của khối mang nhãn [nhanKhoi].
    List<double> mepPhaiCotTien(WidgetTester t, String nhanKhoi) {
      final cot = find.descendant(
        of: find
            .ancestor(
                of: find.text(nhanKhoi), matching: find.byType(Column))
            .first,
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.alignment == Alignment.centerRight,
          description: 'hộp cột số tiền',
        ),
      );
      return [
        for (final e in cot.evaluate())
          (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dx +
              (e.renderObject! as RenderBox).size.width,
      ];
    }

    /// Mọi hàng của một khối phải kết thúc ở **cùng một** mép phải.
    Future<void> thangCot(WidgetTester t, String nhanKhoi) async {
      khoGapDoi(t);
      await t.pumpWidget(duoi(duHinh()));
      await cuonToi(t, find.text(nhanKhoi));

      final mep = mepPhaiCotTien(t, nhanKhoi);
      expect(mep.length, greaterThanOrEqualTo(2),
          reason: 'Khối "$nhanKhoi" phải có ít nhất hai hàng thì phép so mép '
              'phải mới nói lên điều gì. Một hàng thì ca test này xanh mà '
              'không canh gì cả.');
      for (final m in mep.skip(1)) {
        expect(m, moreOrLessEquals(mep.first, epsilon: 0.5),
            reason: 'Mọi hàng của "$nhanKhoi" phải kết thúc ở cùng một mép '
                'phải. Đó là cách người ta đọc một cột tiền — lệch thì mắt bắt '
                'ngay, trong khi không một dòng log nào báo.');
      }
    }

    testWidgets('khối CHI THEO DANH MỤC', (t) async {
      await thangCot(t, 'CHI THEO DANH MỤC');
    });

    testWidgets('khối NGÂN SÁCH KỲ NÀY', (t) async {
      await thangCot(t, 'NGÂN SÁCH KỲ NÀY');
    });

    testWidgets('khối PHÂN BỔ THEO VÍ', (t) async {
      await thangCot(t, 'PHÂN BỔ THEO VÍ');
    });

    testWidgets('khối TOP 5 KHOẢN CHI', (t) async {
      await thangCot(t, 'TOP 5 KHOẢN CHI');
    });

    testWidgets('khối DANH SÁCH GIAO DỊCH', (t) async {
      await thangCot(t, 'DANH SÁCH GIAO DỊCH');
    });

    testWidgets('hàng "Thay đổi trong kỳ" canh SÁT mép phải của ô', (t) async {
      // Khối dòng tiền chỉ có **một** hàng, nên phép so giữa các hàng không
      // dùng được — thay vào đó so với chính cái ô chứa nó. Với `Flexible` thì
      // con số dừng ở đâu đó giữa ô; với `Expanded` nó sát mép trong.
      khoGapDoi(t);
      await t.pumpWidget(duoi(duHinh()));
      await cuonToi(t, find.text('DÒNG TIỀN TRONG KỲ'));

      final mep = mepPhaiCotTien(t, 'DÒNG TIỀN TRONG KỲ');
      expect(mep, hasLength(1));

      final o = t.getRect(find
          .ancestor(
              of: find.text('Thay đổi trong kỳ'),
              matching: find.byType(Container))
          .first);
      expect(mep.first, moreOrLessEquals(o.right - 12, epsilon: 0.5),
          reason: 'Ô có đệm ngang 12, nên mép trong của nó là `right - 12`. '
              'Con số phải chạm đúng đó; dừng sớm hơn là dấu hiệu hộp chứa nó '
              'đang hẹp hơn suất được chia.');
    });
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
