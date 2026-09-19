/// Trang Phân tích với repository giả.
///
/// Canh chừng điều gì: trang này từng là **số cứng** — kể cả tháng đang hiện
/// ("T6 2026" khi đang là tháng 9). Tệp này canh những gì chỉ widget mới sai
/// được: số trên thẻ có đúng là số từ stream không, nhãn "% ngân sách" / "%
/// tổng chi" có đổi theo dữ liệu không, tháng có lấy từ đồng hồ không, chọn
/// tháng có hỏi lại đúng tháng không, và khổ 411dp với tên danh mục dài.
library;

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/du_bao_dong_tien.dart';
import 'package:flowmoney/features/analytics/domain/lich_chi_tieu.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flowmoney/features/analytics/domain/phan_loai_dong_tien.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/tong_tai_san.dart';
import 'package:flowmoney/features/analytics/presentation/bloc/analytics_cubit.dart';
import 'package:flowmoney/features/analytics/presentation/pages/analytics_page.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc() : super(authRepository: _StubAuthRepository()) {
    emit(AuthSuccess(
      user: UserModel(
        id: '10',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
  }
}

class _RepoGia implements AnalyticsRepository {
  final goi = <Ky>[];
  StreamController<ThongKeKy>? _c;

  @override
  Stream<ThongKeKy> watchKy(
    int idaccount, {
    required Ky ky,
    DateTime? now,
  }) {
    goi.add(ky);
    _c?.close();
    _c = StreamController<ThongKeKy>();
    return _c!.stream;
  }

  void phat(ThongKeKy tk) => _c!.add(tk);

  Future<void> dong() async => _c?.close();
}

DongDanhMuc _dm(
  String id,
  String ten,
  double soTien,
  double tiLe, {
  double? hanMuc,
  double? daChi,
}) =>
    DongDanhMuc(
      categoryId: id,
      ten: ten,
      icon: 'restaurant',
      mauHex: '#F25F5C',
      soTien: soTien,
      tiLeTongChi: tiLe,
      nganSachHanMuc: hanMuc,
      nganSachDaChi: daChi,
    );

ThongKeKy _tk({
  int nam = 2026,
  int thang = 9,
  Ky? ky,
  double thu = 5000000,
  double chi = 1250000,
  double thuTruoc = 0,
  double chiTruoc = 1000000,
  double thuNamTruoc = 0,
  double chiNamTruoc = 0,
  List<DongDanhMuc> danhMuc = const [],
  List<DiemThoiGian>? chuoi,
  List<LatPhanLoai> lat = const [],
  Map<String, List<DongDanhMuc>> theoLat = const {},
  Map<String?, List<DiemThoiGian>> chuoiDm = const {},
  SoLieuNhanh? soLieu,
  List<DiemVayNo>? chuoiVayNo,
  List<DongVi> theoVi = const [],
  List<DongGiaoDich> topChi = const [],
  DongTien? dongTien,
  DuBaoDongTien? duBao,
  Map<DateTime, NgayChiTieu> lich = const {},
  List<DiemTaiSan>? taiSan,
  DateTime? giaoDichDauTien,
}) =>
    ThongKeKy(
      ky: ky ?? Ky.thang(nam, thang),
      tong: TongThuChi(thu: thu, chi: chi),
      tongTruoc: TongThuChi(thu: thuTruoc, chi: chiTruoc),
      tongNamTruoc: TongThuChi(thu: thuNamTruoc, chi: chiNamTruoc),
      chiTheoDanhMuc: [
        for (final d in danhMuc)
          ChiTheoDanhMuc(
            categoryId: d.categoryId,
            soTien: d.soTien,
            tiLe: d.tiLeTongChi,
          ),
      ],
      danhMuc: danhMuc,
      // Mặc định là sáu điểm toàn số 0 — đúng cấu trúc chuỗi thật, để test
      // nào không nói gì về biểu đồ vẫn đi qua nhánh thường thay vì nhánh
      // "chưa có chuỗi".
      chuoi: chuoi ?? chuoiTheoKy(const [], ky: ky ?? Ky.thang(nam, thang)),
      latPhanLoai: lat,
      danhMucTheoLat: theoLat,
      chuoiDanhMuc: chuoiDm,
      soLieu: soLieu ??
          const SoLieuNhanh(
            chiMoiNgay: 0,
            ngayChiNhieuNhat: null,
            chiNgayNhieuNhat: 0,
            khoanChiLonNhat: null,
          ),
      theoVi: theoVi,
      topChi: topChi,
      lichChiTieu: lich,
      dongTien: dongTien,
      duBao: duBao,
      // Mặc định là sáu điểm phẳng — đúng cấu trúc thật, để MỌI ca của trang
      // đi qua nhánh có khối tài sản thay vì nhánh "chưa có chuỗi"; đó là cách
      // các ca cũ bắt được tràn bố cục do khối mới gây ra.
      taiSan: taiSan ??
          tongTaiSanCua(
            const [],
            const [],
            ky: ky ?? Ky.thang(nam, thang),
            now: DateTime(nam, thang, 8, 12),
          ),
      giaoDichDauTien: giaoDichDauTien,
      // ⚠️ Mặc định phải **cùng số kỳ** với `chuoi`, không phải rỗng: hai chuỗi
      // luôn được repository dựng từ cùng một `ky` và cùng `kSoKyXuHuong`, nên
      // một `ThongKeKy` có sáu điểm thu/chi mà không điểm vay/nợ nào là trạng
      // thái **không tồn tại trong đời thực**. Khối "Dòng tiền tự do" ghép hai
      // chuỗi theo chỉ số và nổ khi chúng lệch — chốt ấy chỉ có nghĩa khi test
      // dựng dữ liệu hợp lệ.
      chuoiVayNo: chuoiVayNo ??
          [
            for (final d in chuoi ?? chuoiTheoKy(const [], ky: ky ?? Ky.thang(nam, thang)))
              DiemVayNo(ky: d.ky),
          ],
    );

CamKet _camKet(
  String ten,
  DateTime ngay,
  double soTien, {
  LoaiCamKet loai = LoaiCamKet.hoaDon,
  bool quaHan = false,
  bool laKyChieu = false,
}) =>
    CamKet(
      ngay: ngay,
      ten: ten,
      loai: loai,
      walletId: 'w1',
      tenVi: 'Tiền mặt',
      soTien: soTien,
      categoryId: null,
      quaHan: quaHan,
      laKyChieu: laKyChieu,
      tacDongTong: -soTien,
    );

/// Dựng một [DuBaoDongTien] đúng cấu trúc thật — chuỗi 31 điểm lấy từ chính
/// `chuoiDuBao` của tầng thuần, không bịa tay.
DuBaoDongTien _duBao({
  double soDu = 10000000,
  List<CamKet> camKet = const [],
  double nganSachConLai = 0,
  List<ViThieu> viThieu = const [],
}) {
  final homNay = DateTime(2026, 9, 8);
  final tong = camKet.fold<double>(0, (s, c) => s - c.tacDongTong);
  return DuBaoDongTien(
    tu: homNay,
    soDuHienTai: soDu,
    camKet: camKet,
    tongCamKet: tong,
    nganSachConLai: nganSachConLai,
    viThieu: viThieu,
    chuoi: chuoiDuBao(
      homNay: homNay,
      soDu: soDu,
      camKet: camKet,
      nganSachConLai: nganSachConLai,
    ),
  );
}

/// Ba phân loại mẫu, dùng chung cho nhóm test "Cơ cấu theo danh mục" — đủ cả
/// ba thì trang hiện đủ ba chip.
const _baLat = [
  LatPhanLoai(phanLoai: 'thu', soTien: 600000, tiLe: 0.6),
  LatPhanLoai(phanLoai: 'chi', soTien: 300000, tiLe: 0.3),
  LatPhanLoai(phanLoai: 'vay_no', soTien: 100000, tiLe: 0.1),
];

void main() {
  // Khối "Top 5 khoản chi" in ngày qua `DateFormatter`, thứ cần dữ liệu locale.
  // App gọi `initializeDateFormatting` ở `main.dart:30`; test thì phải tự gọi,
  // nếu không widget ném `LocaleDataException` và **cả cây dừng dựng** — mọi ca
  // trong tệp trông như "khối không hiện".
  setUpAll(() => initializeDateFormatting('vi_VN', null));

  late _RepoGia repo;
  final now = DateTime(2026, 9, 8, 12);

  setUp(() async {
    repo = _RepoGia();
    if (sl.isRegistered<AnalyticsCubit>()) {
      await sl.unregister<AnalyticsCubit>();
    }
    sl.registerFactory<AnalyticsCubit>(
      () => AnalyticsCubit(repository: repo, clock: () => now),
    );
  });

  tearDown(() async {
    if (sl.isRegistered<AnalyticsCubit>()) {
      await sl.unregister<AnalyticsCubit>();
    }
    await repo.dong();
  });

  Future<void> moTrang(WidgetTester tester) async {
    final auth = _FixedAuthBloc();
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: const MaterialApp(home: AnalyticsPage()),
      ),
    );
    await tester.pump();
  }

  Future<void> phat(WidgetTester tester, ThongKeKy tk) async {
    repo.phat(tk);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('header không vẽ icon menu chết', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk());

    expect(find.byIcon(Icons.menu), findsNothing,
        reason: 'Icon menu ở header từng là `Icon` trần, không bọc nút — vẽ '
            'giống hamburger mở drawer của Trang chủ nhưng bấm không làm gì. '
            'Trang này không có drawer, nên không vẽ icon ấy (UX 2026-09-19, A2).');
  });

  testWidgets('tháng lấy từ ĐỒNG HỒ, không phải hằng số', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk());

    expect(find.text('Tháng này (T9 2026)'), findsOneWidget,
        reason: 'Trang cũ hiện "T6 2026" cứng suốt nhiều tuần trong khi đang '
            'là tháng 9 — sai ngay trên màn hình.');
    expect(find.textContaining('T6 2026'), findsNothing);
  });

  testWidgets('ba thẻ tổng hiện số từ stream', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk());

    expect(find.text('+5.000.000đ'), findsOneWidget);
    expect(find.text('-1.250.000đ'), findsOneWidget);
    expect(find.text('3.750.000đ'), findsOneWidget,
        reason: 'Số dư còn lại = thu − chi của tháng đang xem.');
  });

  testWidgets('so với tháng trước: có số thì nói tăng/giảm, không có thì nói không có',
      (tester) async {
    await moTrang(tester);
    await phat(tester, _tk());

    expect(find.text('Tăng 25% so với T8'), findsOneWidget);
    expect(find.text('Không có dữ liệu T8'), findsOneWidget,
        reason: 'Thu tháng trước bằng 0. "Tăng ∞%" hay "tăng 100%" đều là số '
            'bịa; không có gì để so thì nói không có.');
  });

  testWidgets('chi vượt thu thì số dư còn lại ÂM, không kẹp về 0', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk(thu: 1000000, chi: 1500000));

    expect(find.text('-500.000đ'), findsOneWidget,
        reason: 'Kẹp về 0 là giấu đi việc tháng này đã âm. Người dùng mở trang '
            'này chính là để biết điều đó.');
  });

  testWidgets('dòng danh mục: "% ngân sách" khi có, "% tổng chi" khi không',
      (tester) async {
    final chiTiet = [
      _dm('a', 'Ăn uống', 800000, 0.64, hanMuc: 2500000, daChi: 800000),
      _dm('b', 'Di chuyển', 450000, 0.36),
    ];
    await moTrang(tester);
    await phat(
      tester,
      // Danh sách cuối trang đọc theo NHÓM đang chọn, không phải `danhMuc`.
      _tk(
        danhMuc: chiTiet,
        lat: const [LatPhanLoai(phanLoai: 'chi', soTien: 1250000, tiLe: 1.0)],
        theoLat: {'chi': chiTiet},
      ),
    );

    expect(find.text('Ăn uống'), findsWidgets);
    expect(find.text('32% ngân sách'), findsOneWidget);
    expect(find.text('36% tổng chi'), findsOneWidget,
        reason: 'Không bịa ngân sách cho danh mục chưa đặt: nhãn phải đổi, '
            'không được hiện "0% ngân sách".');
    expect(find.text('800.000đ'), findsOneWidget);
  });

  testWidgets('mức danh mục: 4 lát đầu + "Khác", tâm hiện tổng của lát',
      (tester) async {
    // Phép "top 4 + Khác" chạy BÊN TRONG nhóm đang chọn. Nhóm Chi mở sẵn
    // nên không cần chạm gì — mức gốc ba lát theo phân loại đã bỏ (A8 #2).
    final chiTietChi = [
      _dm('a', 'Ăn uống', 2100000, 0.323),
      _dm('b', 'Mua sắm', 1500000, 0.231),
      _dm('c', 'Di chuyển', 900000, 0.138),
      _dm('d', 'Giải trí', 600000, 0.092),
      _dm('e', 'Y tế', 800000, 0.123),
      _dm('f', 'Khác nữa', 600000, 0.092),
    ];
    await moTrang(tester);
    await phat(
      tester,
      _tk(
        chi: 6500000,
        danhMuc: chiTietChi,
        lat: const [LatPhanLoai(phanLoai: 'chi', soTien: 6500000, tiLe: 1.0)],
        theoLat: {'chi': chiTietChi},
      ),
    );

    expect(find.text('6.5M'), findsOneWidget);
    expect(find.text('Khác'), findsOneWidget,
        reason: 'Chú giải có đúng bốn ô. Lát thứ năm trở đi gom thành "Khác", '
            'thiếu nó là vòng donut hở một khoảng trông như lỗi vẽ.');
    expect(find.text('Y tế'), findsOneWidget,
        reason: 'Danh mục thứ 5 vẫn có mặt ở BẢNG chi tiết dù không có trong '
            'chú giải donut.');
  });

  testWidgets('tháng rỗng thì nói rỗng, không vẽ toàn số 0', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk(thu: 0, chi: 0, chiTruoc: 0));

    expect(find.textContaining('Chưa có giao dịch nào trong T9 2026'),
        findsOneWidget);
    expect(find.text('+0đ'), findsNothing);
    expect(find.text('Chi tiêu theo hạng mục'), findsNothing,
        reason: 'Donut của một tháng rỗng là một vòng tròn xám với chữ "0" ở '
            'giữa — trông như lỗi tải dữ liệu.');
  });

  // ── Phạm vi thời gian — P1, 2026-09-15 ─────────────────────────────────
  testWidgets('tiêu đề khối xu hướng đổi theo đơn vị đang xem', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk(ky: Ky.tuan(DateTime(2026, 9, 17))));

    expect(find.text('Xu hướng 6 tuần'), findsOneWidget,
        reason: 'xem một tuần mà tiêu đề vẫn nói "6 tháng" thì hai khối trên '
            'cùng trang đang nói về hai kỳ khác nhau');
    expect(find.text('Xu hướng 6 tháng'), findsNothing);
  });

  testWidgets('nhãn trục biểu đồ đổi theo đơn vị', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk(ky: Ky.quy(2026, 3)));

    // ⚠️ **Ba** widget mỗi nhãn, không phải một: trang có ba biểu đồ đường
    // cùng sáu kỳ — "Xu hướng" (2026-09-14), "Dòng tiền tự do" (A8 #8,
    // 2026-09-15) và "Tổng tài sản" (#5, 2026-09-17) — và cả ba đọc trục từ
    // cùng `Ky.nhanTruc`. Con số này cố ý chặt: thêm hay bớt một biểu đồ
    // trục-sáu-kỳ thì ca này đỏ, và người sửa phải nhìn lại trục thay vì để nó
    // trôi. Nó đã làm đúng việc ấy khi đường thứ ba vào.
    expect(find.text('Q3/26'), findsNWidgets(3),
        reason: 'nhãn trục đọc thẳng từ Ky.nhanTruc — trang không tự suy từ '
            'số tháng nữa');
    expect(find.text('Q3/25'), findsNWidgets(3),
        reason: 'sáu quý trải qua một năm rưỡi nên nhãn phải mang năm, nếu '
            'không hai cột khác nhau cùng ghi "Q3"');
  });

  testWidgets('ô header hiện tên kỳ của đơn vị đang xem', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk(ky: Ky.nam(2025)));

    expect(find.text('2025'), findsWidgets);
    expect(find.textContaining('Năm nay'), findsNothing,
        reason: 'năm 2025 không chứa mốc đồng hồ của test (T9 2026)');
  });

  testWidgets('mở bộ chọn phạm vi thấy đủ năm chip đơn vị', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk());

    await tester.tap(find.text('Tháng này (T9 2026)'));
    await tester.pumpAndSettle();

    for (final ten in ['Tuần', 'Tháng', 'Quý', 'Năm', 'Tuỳ chọn']) {
      expect(find.text(ten), findsOneWidget, reason: 'thiếu chip $ten');
    }
  });

  testWidgets('chọn tháng khác thì hỏi lại đúng tháng ấy', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk());

    await tester.tap(find.text('Tháng này (T9 2026)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T8 2026').last);
    // KHÔNG pumpAndSettle: sau khi chọn, state Loading vẽ vòng quay quay mãi
    // nên không bao giờ "lắng" — bản test đầu treo tới timeout ở đây.
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.goi.last, Ky.thang(2026, 8));

    await phat(tester, _tk(thang: 8, chiTruoc: 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tháng này (T9 2026)'), findsNothing,
        reason: 'Ô chọn phải đổi nhãn theo tháng vừa chọn; giữ "Tháng này" '
            'cho một tháng đã qua là nói dối về thứ đang hiện.');
    expect(find.text('T8 2026'), findsWidgets);
  });

  testWidgets('"Xem tất cả" mở bảng đủ mọi danh mục khi hơn 5 dòng',
      (tester) async {
    final bay = [
      for (var i = 0; i < 7; i++) _dm('c$i', 'Danh mục $i', 100000, 1 / 7),
    ];
    await moTrang(tester);
    await phat(
      tester,
      _tk(
        danhMuc: bay,
        lat: const [LatPhanLoai(phanLoai: 'chi', soTien: 700000, tiLe: 1.0)],
        theoLat: {'chi': bay},
      ),
    );

    expect(find.text('Danh mục 6'), findsNothing,
        reason: 'Trang chỉ dựng 5 dòng đầu, cùng lối với lịch sử mục tiêu — '
            'danh sách ở đây không ảo hoá.');

    // Nút nằm dưới khung nhìn 600px của test; chạm vào chỗ ngoài màn hình
    // thì trượt mà không báo lỗi.
    await tester.ensureVisible(find.text('Xem tất cả'));
    await tester.tap(find.text('Xem tất cả'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết danh mục'), findsOneWidget,
        reason: 'Tiêu đề của bảng — bằng chứng sheet đã mở.');
    // ListView trong sheet KHÔNG dựng hàng ngoài khung nhìn, nên phải cuộn tới
    // chứ không tìm thẳng — tìm thẳng là xanh oan khi hàng ấy không tồn tại.
    await tester.scrollUntilVisible(
      find.text('Danh mục 6'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Danh mục 6'), findsOneWidget);
  });

  testWidgets('không tràn bố cục ở khổ 411dp với tên danh mục dài',
      (tester) async {
    tester.view.physicalSize = const Size(411 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final chiTiet = [
      _dm('a', 'Ăn uống ngoài hàng quán cuối tuần với gia đình', 98765432, 1.0,
          hanMuc: 100000000, daChi: 98765432),
    ];
    await moTrang(tester);
    await phat(
      tester,
      // `theoLat` là thứ dựng ra dòng danh mục. Thiếu nó thì danh sách rỗng và
      // ca này XANH OAN — nó không còn canh tên dài nào cả.
      _tk(
        thu: 123456789,
        chi: 98765432,
        danhMuc: chiTiet,
        lat: const [LatPhanLoai(phanLoai: 'chi', soTien: 98765432, tiLe: 1.0)],
        theoLat: {'chi': chiTiet},
      ),
    );

    expect(tester.takeException(), isNull,
        reason: 'Dòng danh mục cũ đặt tên trong một Row không giới hạn bề '
            'rộng, nên tên dài tràn qua cột số tiền. Flutter báo tràn qua '
            'FlutterError.reportError chứ không ném ra chỗ gọi — test chỉ '
            'pumpWidget sẽ xanh dù màn hình đầy sọc vàng.');
  });

  // ── Mốc so sánh: chip "kỳ trước" / "cùng kỳ năm trước" (2026-09-16) ──────
  group('chip mốc so sánh', () {
    testWidgets('mặc định là kỳ trước — người dùng cũ không thấy gì đổi',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(chiTruoc: 1000000, chiNamTruoc: 500000));

      expect(find.text('So với kỳ trước'), findsOneWidget);
      expect(find.text('Cùng kỳ năm trước'), findsOneWidget);
      expect(find.textContaining('so với T8'), findsWidgets);
      expect(find.textContaining('so với T9 2025'), findsNothing);
    });

    testWidgets('chạm chip thứ hai thì thẻ đổi CẢ số lẫn nhãn', (tester) async {
      await moTrang(tester);
      // Chi 1.250.000: so kỳ trước (1.000.000) là +25%, so năm trước
      // (500.000) là +150% — hai con số khác hẳn nhau nên không thể nhầm.
      await phat(tester, _tk(chiTruoc: 1000000, chiNamTruoc: 500000));
      expect(find.textContaining('Tăng 25% so với T8'), findsOneWidget);

      await tester.tap(find.text('Cùng kỳ năm trước'));
      await tester.pump();

      expect(
        find.textContaining('Tăng 150% so với T9 2025'),
        findsOneWidget,
        reason: 'lấy số của năm trước mà in nhãn kỳ trước — hoặc ngược lại — '
            'cho ra một câu hoàn toàn hợp lý và hoàn toàn sai',
      );
      expect(find.textContaining('so với T8'), findsNothing);
    });

    testWidgets('chưa có dữ liệu năm trước thì NÓI THẲNG, không bịa phần trăm',
        (tester) async {
      await moTrang(tester);
      // Ca THƯỜNG của mọi tài khoản chưa đủ một năm tuổi.
      await phat(tester, _tk(chiTruoc: 1000000, thuNamTruoc: 0, chiNamTruoc: 0));

      await tester.tap(find.text('Cùng kỳ năm trước'));
      await tester.pump();

      expect(find.textContaining('Không có dữ liệu T9 2025'), findsWidgets);
      expect(
        find.textContaining('Tăng 100%'),
        findsNothing,
        reason: 'nền bằng 0 thì mọi phần trăm đều là số bịa',
      );
    });

    testWidgets('nhãn kỳ đổi theo ĐƠN VỊ đang xem, không cứng là tháng',
        (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(ky: Ky.quy(2026, 3), chiTruoc: 1000000, chiNamTruoc: 500000),
      );

      await tester.tap(find.text('Cùng kỳ năm trước'));
      await tester.pump();

      expect(find.textContaining('so với Q3 2025'), findsOneWidget);
    });

    testWidgets('hàng chip và hai thẻ KHÔNG tràn ở khổ 411dp', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await moTrang(tester);
      // Nhãn dài nhất: kỳ tuỳ chọn ở mốc năm trước — "05/09 – 17/09 2025".
      await phat(
        tester,
        _tk(
          ky: Ky.tuyChon(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 18)),
          thu: 123456789,
          chi: 98765432,
          chiTruoc: 1000000,
          thuNamTruoc: 1,
          chiNamTruoc: 1,
        ),
      );
      await tester.tap(find.text('Cùng kỳ năm trước'));
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'hai thẻ chỉ rộng chừng 180dp; Flutter báo tràn qua '
            'FlutterError.reportError chứ không ném ra chỗ gọi, nên test chỉ '
            'pumpWidget sẽ xanh dù màn hình đầy sọc vàng (bẫy 1 của mục test)',
      );
    });
  });

  // ── Lịch chi tiêu — heatmap theo ngày (#6 khảo sát, 2026-09-16) ──────────
  group('khối Lịch chi tiêu', () {
    NgayChiTieu ngay(double tien, {int soKhoan = 1, String ten = 'Ăn uống'}) =>
        NgayChiTieu(
          tongChi: tien,
          soKhoan: soKhoan,
          lonNhat: DongGiaoDich(
            id: 'x',
            ngay: DateTime(2026, 9, 11),
            soTien: tien,
            loai: 'chi',
            categoryId: 'c1',
            tenDanhMuc: ten,
            mauHex: null,
            icon: null,
            walletId: 'w1',
            tenVi: 'Tiền mặt',
            tieuDe: ten,
          ),
        );

    final lichMau = {
      DateTime(2026, 9, 3): ngay(120000),
      DateTime(2026, 9, 11): ngay(350000, soKhoan: 3, ten: 'Mua sắm'),
      DateTime(2026, 9, 20): ngay(50000),
    };

    testWidgets('hiện lưới có tiêu đề thứ và đủ số ô ngày của tháng',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(lich: lichMau));

      expect(find.text('Lịch chi tiêu'), findsOneWidget);
      for (final t in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
        expect(find.text(t), findsWidgets, reason: 'thiếu cột $t');
      }
      // Tháng 9/2026 có 30 ngày; mỗi ô mang số ngày.
      expect(find.text('30'), findsWidgets);
      expect(
        find.text('31'),
        findsNothing,
        reason: 'tháng 9 không có ngày 31 — lưới phải theo số ngày THẬT',
      );
    });

    testWidgets('⚠️ kỳ KHÁC tháng thì ẩn hẳn khối — chốt ở hai lớp',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(ky: Ky.quy(2026, 3), lich: lichMau));

      expect(
        find.text('Lịch chi tiêu'),
        findsNothing,
        reason: 'một lưới 91 ô ở 411dp không đọc được, và PocketSmith/Money '
            'Lover đều chỉ vẽ lịch THÁNG',
      );
    });

    testWidgets('chưa chạm ô nào thì chưa có thẻ tóm tắt', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(lich: lichMau));
      // ⚠️ Chỉ tìm chữ "khoản" là KHÔNG ĐỦ: một bản sai hiện sẵn thẻ cho ngày
      // đầu tháng — ngày ấy không có chi nên thẻ nói "Không chi", và ca test
      // vẫn xanh. Phải cấm CẢ HAI mặt của thẻ.
      expect(find.textContaining('khoản'), findsNothing);
      expect(find.textContaining('Không chi'), findsNothing);
      expect(
        find.textContaining('Thứ '),
        findsNothing,
        reason: 'nhãn ngày của thẻ tóm tắt luôn bắt đầu bằng tên thứ',
      );
    });

    testWidgets('chạm một ô có chi thì hiện tóm tắt của ĐÚNG ngày ấy',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(lich: lichMau));

      await tester.ensureVisible(find.text('Lịch chi tiêu'));
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(find.textContaining('11/09'), findsWidgets);
      expect(find.textContaining('3 khoản'), findsOneWidget);
      expect(find.textContaining('350.000'), findsWidgets);
      expect(
        find.textContaining('Mua sắm'),
        findsWidgets,
        reason: 'khoản lớn nhất phải là của NGÀY ấy, không phải của cả tháng',
      );
    });

    testWidgets('chạm một ô KHÔNG chi vẫn nói rõ là không chi', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(lich: lichMau));

      await tester.ensureVisible(find.text('Lịch chi tiêu'));
      await tester.tap(find.text('5'));
      await tester.pump();

      expect(
        find.textContaining('Không chi'),
        findsOneWidget,
        reason: 'im lặng ở đây làm người dùng tưởng cú chạm không ăn',
      );
    });

    testWidgets('không tràn ở 411dp với số tiền lớn', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await moTrang(tester);
      await phat(tester, _tk(lich: {
        for (var i = 1; i <= 30; i++)
          DateTime(2026, 9, i): ngay(123456789, soKhoan: 12),
      }));
      await tester.ensureVisible(find.text('Lịch chi tiêu'));
      await tester.tap(find.text('11'));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'bảy cột trên 411dp chỉ được ~50dp mỗi ô');
    });
  });

  group('biểu đồ xu hướng', () {
    List<DiemThoiGian> chuoiMau() => [
          for (var i = 0; i < 6; i++)
            DiemThoiGian(
              ky: Ky.thang(2026, 4 + i),
              tong: TongThuChi(
                thu: 1000000.0 * (i + 1),
                chi: 500000.0 * (i + 1),
              ),
            ),
        ];

    testWidgets('hiện tiêu đề và đủ sáu nhãn tháng của chuỗi', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(chuoi: chuoiMau()));

      expect(find.text('Xu hướng 6 tháng'), findsOneWidget);
      for (final nhan in ['T4', 'T5', 'T6', 'T7', 'T8', 'T9']) {
        expect(find.text(nhan), findsWidgets,
            reason: 'Nhãn trục là Text thật do fl_chart dựng, nên thiếu một '
                'tháng là test thấy được. Đây là chỗ duy nhất chứng minh '
                'chuỗi đi tới được biểu đồ chứ không dừng ở repository.');
      }
    });

    testWidgets('có chú giải phân biệt đường thu và đường chi',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(chuoi: chuoiMau()));

      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Chi'), findsOneWidget,
          reason: 'Hai đường cùng khung mà không chú giải thì người dùng phải '
              'đoán màu nào là gì. Xanh/đỏ là quy ước, không phải hiển nhiên '
              'với người mù màu.');
    });

    testWidgets('chuỗi rỗng thì bỏ qua khối chứ không nổ', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(chuoi: const []));

      expect(find.text('Xu hướng 6 tháng'), findsNothing);
      expect(tester.takeException(), isNull,
          reason: 'Biểu đồ không có điểm nào là chia cho 0 khi tính thang '
              'đo. Trang phải bỏ qua khối, không được kéo cả màn hình chết '
              'theo.');
    });

    testWidgets('biểu đồ không tràn ở khổ 411dp với số tiền lớn',
        (tester) async {
      tester.view.physicalSize = const Size(411 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await moTrang(tester);
      await phat(
        tester,
        _tk(chuoi: [
          for (var i = 0; i < 6; i++)
            DiemThoiGian(
              ky: Ky.thang(2026, 4 + i),
              tong: const TongThuChi(thu: 987654321.0, chi: 123456789.0),
            ),
        ]),
      );

      expect(tester.takeException(), isNull,
          reason: 'Nhãn trục trái mang số tiền rút gọn; số hàng trăm triệu là '
              'chuỗi dài nhất có thể, và font của bộ test rộng gấp đôi ngoài '
              'đời nên đây là ca chật nhất.');
    });
    testWidgets('nhãn trục tung không in HAI chuỗi khác nhau ở cùng một mốc',
        (tester) async {
      // G39. Đỉnh 43.000 là một trong tám giá trị (quét bằng máy 2026-09-14,
      // dải 1.000–300.000) khiến `maxY` và `3 * (maxY / 3)` rơi về HAI PHÍA
      // ranh giới làm tròn của `rutGon`: 49449.99999999999 cho "49.4K", còn
      // ba lần `buoc` cho "49.5K". fl_chart vẽ nhãn cho CẢ mốc theo
      // `interval` LẪN biên trên — mà hai thứ đó ở cùng một vị trí — nên hai
      // chuỗi ấy in đè khít lên nhau và đọc ra một vệt.
      await moTrang(tester);
      await phat(
        tester,
        _tk(chuoi: [
          for (var i = 0; i < 6; i++)
            DiemThoiGian(
              ky: Ky.thang(2026, 4 + i),
              tong: TongThuChi(thu: i == 5 ? 43000 : 0, chi: 0),
            ),
        ]),
      );

      final coThap = find.text('49.4K').evaluate().isNotEmpty;
      final coCao = find.text('49.5K').evaluate().isNotEmpty;

      expect(coThap && coCao, isFalse,
          reason: 'Biên trên và mốc cuối của `interval` là CÙNG một vị trí. '
              'In hai chuỗi khác nhau ở đó là hai nhãn chồng khít, không ai '
              'đọc được — thấy thật trên máy ảo ngày 2026-09-14 (G39).');
      expect(coThap || coCao, isTrue,
          reason: 'Vẫn phải còn ĐÚNG MỘT nhãn ở biên trên. Chữa bằng cách bỏ '
              'luôn nhãn ấy là mất mốc cao nhất của thang đo — người đọc hết '
              'biết đường cao tới đâu.');
    });

  });

  group('Cơ cấu theo danh mục', () {
    ChoiceChip chipNhom(WidgetTester tester, String pl) =>
        tester.widget<ChoiceChip>(find.byKey(Key('chip-nhom-$pl')));

    testWidgets('mở sẵn nhóm Chi, không bắt chạm thêm bước nào', (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(lat: _baLat, theoLat: {
          'chi': [_dm('c_an', 'Ăn uống', 300000, 1.0)],
          'thu': [_dm('c_luong', 'Lương', 600000, 1.0)],
          'vay_no': [_dm('c_no', 'Trả nợ', 100000, 1.0)],
        }),
      );

      expect(find.text('Cơ cấu theo danh mục'), findsOneWidget);
      expect(chipNhom(tester, 'chi').selected, isTrue,
          reason: 'Bản đầu (A8 #2) bắt chạm một lát mới thấy danh mục bên '
              'trong. Mức gốc ấy đã bỏ ngày 2026-09-14 — vào trang là thấy '
              'ngay nhóm Chi, không tốn một cú chạm.');
      expect(chipNhom(tester, 'thu').selected, isFalse);
      expect(chipNhom(tester, 'vay_no').selected, isFalse);
      expect(find.text('Ăn uống'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nhóm KHÔNG có phát sinh thì không có chip', (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(
          lat: const [LatPhanLoai(phanLoai: 'chi', soTien: 300000, tiLe: 1.0)],
          theoLat: {
            'chi': [_dm('c_an', 'Ăn uống', 300000, 1.0)],
          },
        ),
      );

      expect(find.byKey(const Key('chip-nhom-chi')), findsOneWidget);
      expect(find.byKey(const Key('chip-nhom-thu')), findsNothing,
          reason: 'Chip cho nhóm rỗng dẫn tới một vòng tròn trống — không lỗi '
              'nào, chỉ là một ngõ cụt người dùng phải tự bấm mới biết.');
      expect(find.byKey(const Key('chip-nhom-vay_no')), findsNothing);
    });

    testWidgets('chạm chip Thu thì cả donut lẫn danh sách đổi theo',
        (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(
          lat: _baLat,
          danhMuc: [_dm('c_an', 'Ăn uống', 300000, 1.0)],
          theoLat: {
            'chi': [_dm('c_an', 'Ăn uống', 300000, 1.0)],
            'thu': [_dm('c_luong', 'Lương', 600000, 1.0)],
          },
        ),
      );

      expect(find.text('Ăn uống'), findsWidgets,
          reason: 'Nhóm mặc định là Chi.');

      await tester.ensureVisible(find.byKey(const Key('chip-nhom-thu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip-nhom-thu')));
      await tester.pumpAndSettle();

      expect(find.text('Lương'), findsNWidgets(2),
          reason: 'Chú giải donut và dòng danh sách cuối trang — hai khối phải '
              'đi theo cùng một chip, lệch nhau là donut nói một số còn danh '
              'sách cộng ra số khác (§3.2 spec)');
      expect(find.text('Ăn uống'), findsNothing,
          reason: 'Danh mục của nhóm khác không được lẫn vào.');
    });

    testWidgets('nhãn mẫu số của dòng đổi theo nhóm', (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(lat: _baLat, theoLat: {
          'thu': [_dm('c_luong', 'Lương', 600000, 1.0)],
        }),
      );

      await tester.ensureVisible(find.byKey(const Key('chip-nhom-thu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip-nhom-thu')));
      await tester.pumpAndSettle();

      expect(find.text('100% tổng thu'), findsOneWidget,
          reason: '"% tổng chi" ở nhóm Thu là nói sai mẫu số');
    });

    testWidgets('tâm donut là tổng của NHÓM, không phải tổng chi toàn tháng',
        (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(
          chi: 6500000,
          lat: const [
            LatPhanLoai(phanLoai: 'chi', soTien: 5000000, tiLe: 0.77),
            LatPhanLoai(phanLoai: 'vay_no', soTien: 1500000, tiLe: 0.23),
          ],
          theoLat: {
            'chi': [_dm('c_an', 'Ăn uống', 5000000, 1.0)],
            'vay_no': [_dm('c_no', 'Trả nợ', 1500000, 1.0)],
          },
        ),
      );

      expect(find.text('5M'), findsOneWidget,
          reason: 'Nhóm Chi KHÔNG bằng "Tổng chi" của thẻ đầu trang: phần chi '
              'gắn danh mục vay/nợ đã sang nhóm Vay/nợ. Lấy tổng chi toàn '
              'tháng làm mẫu số là các lát cộng lại không ra 100% mà không '
              'một dòng log nào báo (§2.1 spec).');
      expect(find.text('6.5M'), findsNothing);
      expect(find.text('-6.500.000đ'), findsOneWidget,
          reason: 'Thẻ đầu trang thì vẫn là tổng chi thật của tháng — hai con '
              'số khác nhau là đúng, và đó chính là chỗ dễ "sửa" nhầm.');
    });

    testWidgets('tên danh mục dài không tràn ở 411dp', (tester) async {
      tester.view.physicalSize = const Size(411 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await moTrang(tester);
      await phat(
        tester,
        _tk(lat: _baLat, theoLat: {
          'chi': [
            _dm('c_an', 'Ăn uống nhà hàng và cà phê cuối tuần', 300000, 1.0),
          ],
        }),
      );

      expect(tester.takeException(), isNull,
          reason: 'Flutter báo tràn qua FlutterError.reportError chứ không ném '
              'ra chỗ gọi — test chỉ pumpWidget + find sẽ xanh ngay cả khi màn '
              'hình đầy sọc vàng');
    });
  });

  group('chip danh mục của khối Xu hướng', () {
    List<DiemThoiGian> chuoiMau() =>
        chuoiTheoKy(const [], ky: Ky.thang(2026, 9));

    FilterChip chipXh(WidgetTester tester, String id) =>
        tester.widget<FilterChip>(find.byKey(Key('chip-xu-huong-$id')));

    testWidgets('mặc định không chip nào bật — hai đường Thu/Chi',
        (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(
          danhMuc: [_dm('c_an', 'Ăn uống', 300000, 1.0)],
          chuoiDm: {'c_an': chuoiMau()},
        ),
      );

      expect(chipXh(tester, 'c_an').selected, isFalse);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Chi'), findsOneWidget,
          reason: 'Tập rỗng là hai đường Thu/Chi — trang mở ra vẫn phải có gì '
              'đó để nhìn, không phải một khung trống chờ người dùng chọn.');
      expect(
        find.text('Chọn tối đa $kToiDaDuongXuHuong danh mục · '
            'Bỏ chọn hết để xem Thu/Chi'),
        findsOneWidget,
        reason: 'Bản đầu là dropdown chọn MỘT, có sẵn mục "Tất cả danh mục" '
            'nói lên trạng thái rỗng. Hàng chip không tự nói được điều đó — '
            'dòng chữ này là chỗ duy nhất nói, bỏ nó là người dùng không biết '
            'làm sao quay về Thu/Chi.',
      );
    });

    testWidgets('bật một chip thì chú giải đổi thành tên danh mục',
        (tester) async {
      await moTrang(tester);
      await phat(
        tester,
        _tk(
          danhMuc: [_dm('c_an', 'Ăn uống', 300000, 1.0)],
          chuoiDm: {'c_an': chuoiMau()},
        ),
      );

      await tester.tap(find.byKey(const Key('chip-xu-huong-c_an')));
      await tester.pumpAndSettle();

      expect(chipXh(tester, 'c_an').selected, isTrue);
      expect(find.text('Thu'), findsNothing,
          reason: 'Đã chọn danh mục thì hai đường Thu/Chi nhường chỗ — để cả '
              'hai là ba đường mà chú giải chỉ giải thích được một.');
      expect(find.text('Chi'), findsNothing);
      expect(find.text('Ăn uống'), findsNWidgets(2),
          reason: 'Nhãn chip và chú giải đường.');
      expect(tester.takeException(), isNull);
    });

    testWidgets('chỉ có chip cho danh mục CÓ chuỗi 6 tháng', (tester) async {
      final dm = [
        _dm('c_an', 'Ăn uống', 300000, 0.75),
        _dm('c_di', 'Đi lại', 100000, 0.25),
      ];
      await moTrang(tester);
      await phat(
        tester,
        _tk(
          danhMuc: dm,
          lat: const [LatPhanLoai(phanLoai: 'chi', soTien: 400000, tiLe: 1.0)],
          theoLat: {'chi': dm},
          // Chỉ 'c_an' có chuỗi — 'c_di' phát sinh ngoài 6 tháng.
          chuoiDm: {'c_an': chuoiMau()},
        ),
      );

      expect(find.byKey(const Key('chip-xu-huong-c_an')), findsOneWidget);
      expect(find.byKey(const Key('chip-xu-huong-c_di')), findsNothing,
          reason: 'Liệt kê mọi danh mục là bắt người dùng lướt qua hàng chục '
              'chip để tìm ra một đường phẳng bằng 0.');
      expect(find.text('Đi lại'), findsWidgets,
          reason: 'Nó vẫn có mặt ở donut và bảng chi tiết — chỉ hàng chip xu '
              'hướng mới bỏ nó.');
    });

    testWidgets('ĐỦ TRẦN: chip thứ sáu bị KHOÁ, chip đang bật vẫn tắt được',
        (tester) async {
      final dm = [
        for (var i = 1; i <= 6; i++) _dm('c$i', 'Danh mục $i', 100000, 1 / 6),
      ];
      await moTrang(tester);
      await phat(
        tester,
        _tk(
          danhMuc: dm,
          chuoiDm: {for (var i = 1; i <= 6; i++) 'c$i': chuoiMau()},
        ),
      );

      // Gọi thẳng callback thay vì tap: sáu chip cuộn ngang thì chip cuối nằm
      // ngoài khung nhìn, và điều đang canh là chính giá trị `onSelected`.
      for (var i = 1; i <= kToiDaDuongXuHuong; i++) {
        chipXh(tester, 'c$i').onSelected!(true);
        await tester.pump();
      }

      expect(chipXh(tester, 'c6').onSelected, isNull,
          reason: 'Đủ trần thì chip chưa bật phải KHOÁ, nhìn thấy được. Để bấm '
              'được mà cubit lặng lẽ bỏ qua là người dùng bấm mãi và tưởng app '
              'hỏng — không toast, không log.');
      expect(chipXh(tester, 'c1').onSelected, isNotNull,
          reason: 'Chip đang bật luôn tắt được. Khoá cả nó là người dùng kẹt ở '
              'đúng năm đường ấy, không đổi được nữa.');
    });

    testWidgets('tên danh mục dài không tràn hàng chip ở 411dp',
        (tester) async {
      tester.view.physicalSize = const Size(411 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await moTrang(tester);
      await phat(
        tester,
        _tk(
          danhMuc: [
            _dm('c_an', 'Ăn uống nhà hàng và cà phê cuối tuần dài', 300000, 0.7),
            _dm('c_di', 'Đi lại bằng xe công nghệ và xăng xe máy', 100000, 0.3),
          ],
          chuoiDm: {'c_an': chuoiMau(), 'c_di': chuoiMau()},
        ),
      );

      expect(tester.takeException(), isNull,
          reason: 'Hàng chip cuộn ngang che được tràn NGANG, nhưng nhãn bên '
              'trong chip vẫn phải tự cắt — font của bộ test rộng gấp đôi '
              'ngoài đời nên đây là ca chật nhất.');
    });
  });

  // ── Bốn khối mượn từ trang Báo cáo (P2, 2026-09-15) ──────────────────────
  group('bốn khối mượn từ trang Báo cáo', () {
    // Trang là một ListView dựng lười: bốn khối này nằm cuối trang nên ở khổ
    // mặc định 800x600 chúng chưa được dựng, và `find.text` trả rỗng — trông
    // hệt như "khối không hiện". Cho cả nhóm một khung cao để ca test nói về
    // NỘI DUNG chứ không về việc cuộn tới đâu; ca canh tràn tự đặt khổ 411dp.
    ThongKeKy tkDayDu() => _tk(
          soLieu: const SoLieuNhanh(
            chiMoiNgay: 41666.67,
            ngayChiNhieuNhat: null,
            chiNgayNhieuNhat: 0,
            khoanChiLonNhat: null,
          ),
          theoVi: const [
            DongVi(
                walletId: 'w1',
                ten: 'Tiền mặt',
                thu: 0,
                chi: 900000,
                soGiaoDich: 3),
            DongVi(
                walletId: 'w2',
                ten: 'Ngân hàng',
                thu: 5000000,
                chi: 120000,
                soGiaoDich: 2),
          ],
          topChi: [
            DongGiaoDich(
              id: 't1',
              ngay: DateTime(2026, 9, 10),
              soTien: 500000,
              loai: 'chi',
              categoryId: 'c_an',
              tenDanhMuc: 'Ăn uống',
              mauHex: null,
              icon: null,
              walletId: 'w1',
              tenVi: 'Tiền mặt',
              tieuDe: 'Sửa xe',
            ),
            DongGiaoDich(
              id: 't2',
              ngay: DateTime(2026, 9, 4),
              soTien: 60000,
              loai: 'chi',
              categoryId: 'c_mua',
              tenDanhMuc: 'Mua sắm',
              mauHex: null,
              icon: null,
              walletId: 'w1',
              tenVi: 'Tiền mặt',
              tieuDe: 'Mua sắm',
            ),
          ],
          dongTien: const DongTien(dauKy: 10500000, cuoiKy: 10200000),
        );

    /// Dựng trang trong một khung cao để mọi khối cùng được dựng.
    Future<void> moCao(WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await moTrang(tester);
    }

    testWidgets('bốn khối hiện đủ, đúng tiêu đề', (tester) async {
      await moCao(tester);
      await phat(tester, tkDayDu());

      expect(find.text('Dòng tiền trong kỳ'), findsOneWidget);
      expect(find.text('Số liệu nhanh'), findsOneWidget);
      expect(find.text('Phân bổ theo ví'), findsOneWidget);
      expect(find.text('Top 5 khoản chi'), findsOneWidget);
    });

    testWidgets('⚠️ khối dòng tiền LUÔN kèm câu nói rõ nó là số suy ngược',
        (tester) async {
      await moCao(tester);
      await phat(tester, tkDayDu());

      expect(
        find.text('Suy ngược từ số dư hiện tại của các ví'),
        findsOneWidget,
        reason: 'app không lưu lịch sử số dư — bê mỗi con số là để người đọc '
            'tưởng đây là số đo. Mục 3.16.',
      );
    });

    testWidgets('phân bổ theo ví hiện tên ví và số giao dịch', (tester) async {
      await moCao(tester);
      await phat(tester, tkDayDu());

      expect(find.text('Tiền mặt'), findsOneWidget);
      expect(find.text('3 giao dịch'), findsOneWidget);
      expect(find.text('Ngân hàng'), findsOneWidget);
    });

    testWidgets('top khoản chi hiện tiêu đề, danh mục và số thứ tự',
        (tester) async {
      await moCao(tester);
      await phat(tester, tkDayDu());

      expect(find.text('Sửa xe'), findsOneWidget);
      expect(find.textContaining('Ăn uống'), findsWidgets);

      // Số thứ tự phải nằm TRONG hàng của khoản ấy. Tìm chuỗi '1' trần thì
      // trúng cả nhãn trục biểu đồ và ngày tháng — ba chỗ, và ca test khi ấy
      // xanh hay đỏ đều không nói lên điều gì.
      final hang = find.ancestor(
        of: find.text('Sửa xe'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: hang.first, matching: find.text('1')),
        findsOneWidget,
        reason: 'số thứ tự của khoản đứng đầu top',
      );
    });

    testWidgets('khối rỗng thì KHÔNG hiện, không vẽ thẻ trống', (tester) async {
      await moCao(tester);
      await phat(tester, _tk());

      expect(find.text('Phân bổ theo ví'), findsNothing);
      expect(find.text('Top 5 khoản chi'), findsNothing);
    });

    testWidgets('⚠️ cột số tiền thẳng mép PHẢI ở mọi hàng', (tester) async {
      // Người dùng bắt được trên máy ảo 2026-09-15: các con số "bị lệch". Gốc
      // rễ là `Flexible` mang `flex: 1` mặc định nên được chia MỘT NỬA chỗ
      // trống, nội dung lại hẹp hơn, và `MainAxisAlignment.start` đẩy phần thừa
      // về cuối hàng — mỗi hàng thừa một kiểu nên mép phải răng cưa.
      //
      // Cột tiền phải thẳng mép phải: đó là cách người ta đọc một cột tiền, và
      // lệch thì mắt bắt ngay dù không một dòng log nào.
      await moCao(tester);
      await phat(tester, tkDayDu());

      double mepPhai(String chu) => tester.getRect(find.text(chu)).right;

      expect(
        mepPhai('-900.000 đ'),
        moreOrLessEquals(mepPhai('-120.000 đ'), epsilon: 0.5),
        reason: 'hai ví khác nhau, cùng một mép phải',
      );
      expect(
        mepPhai('+5.000.000 đ'),
        moreOrLessEquals(mepPhai('-120.000 đ'), epsilon: 0.5),
        reason: 'thu và chi của cùng một ví cũng phải thẳng cột',
      );
      expect(
        mepPhai('-500.000 đ'),
        moreOrLessEquals(mepPhai('-60.000 đ'), epsilon: 0.5),
        reason: 'hai dòng của Top 5, cùng một mép phải',
      );
    });

    testWidgets('không tràn ở 411dp với tên ví dài', (tester) async {
      tester.view.physicalSize = const Size(411, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await moTrang(tester);
      await phat(
        tester,
        _tk(theoVi: const [
          DongVi(
              walletId: 'w1',
              ten: 'Ví tiền mặt để dành cho chuyến đi Đà Lạt tháng sau',
              thu: 123456789,
              chi: 987654321,
              soGiaoDich: 42),
        ]),
      );

      expect(tester.takeException(), isNull,
          reason: 'Flutter báo tràn qua reportError chứ không ném ra chỗ gọi');
    });
  });

  // ── Hai biểu đồ vay/nợ — A8 #4 và #5 (2026-09-15) ────────────────────────
  group('hai biểu đồ vay/nợ', () {
    List<DiemVayNo> chuoi({
      double choVay = 0,
      double thuNo = 0,
      double diVay = 0,
      double traNo = 0,
      double khacRa = 0,
      double khacVao = 0,
    }) =>
        [
          for (var i = 5; i >= 0; i--)
            DiemVayNo(
              ky: Ky.thang(2026, 9 - i),
              choVay: i == 0 ? choVay : 0,
              thuNo: i == 0 ? thuNo : 0,
              diVay: i == 0 ? diVay : 0,
              traNo: i == 0 ? traNo : 0,
              khacRa: i == 0 ? khacRa : 0,
              khacVao: i == 0 ? khacVao : 0,
            ),
        ];

    Future<void> moCao(WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await moTrang(tester);
    }

    testWidgets('có phát sinh thì hiện đủ hai khối', (tester) async {
      await moCao(tester);
      await phat(
        tester,
        _tk(chuoiVayNo: chuoi(choVay: 500000, thuNo: 200000, diVay: 900000, traNo: 300000)),
      );

      expect(find.text('Cho vay & Thu nợ'), findsOneWidget);
      expect(find.text('Đi vay & Trả nợ'), findsOneWidget);
      expect(find.text('Cho vay'), findsOneWidget, reason: 'chú giải');
      expect(find.text('Thu nợ'), findsOneWidget);
      expect(find.text('Đi vay'), findsOneWidget);
      expect(find.text('Trả nợ'), findsOneWidget);
    });

    testWidgets('khối nào không có phát sinh thì KHÔNG hiện', (tester) async {
      await moCao(tester);
      await phat(tester, _tk(chuoiVayNo: chuoi(choVay: 500000)));

      expect(find.text('Cho vay & Thu nợ'), findsOneWidget);
      expect(find.text('Đi vay & Trả nợ'), findsNothing,
          reason: 'vẽ một biểu đồ toàn số 0 trông như lỗi tải dữ liệu');
    });

    testWidgets('không có vay/nợ nào thì cả hai khối biến mất', (tester) async {
      await moCao(tester);
      await phat(tester, _tk());

      expect(find.text('Cho vay & Thu nợ'), findsNothing);
      expect(find.text('Đi vay & Trả nợ'), findsNothing);
    });

    testWidgets('khối "chưa xếp được vai" chỉ hiện khi CÓ', (tester) async {
      await moCao(tester);
      await phat(tester, _tk(chuoiVayNo: chuoi(choVay: 500000)));
      expect(find.text('Vay/nợ chưa xếp được vai'), findsNothing);

      await phat(tester, _tk(chuoiVayNo: chuoi(choVay: 500000, khacRa: 111000)));
      expect(find.text('Vay/nợ chưa xếp được vai'), findsOneWidget,
          reason: 'khoản không đoán được vai vẫn phải nhìn thấy được — giấu đi '
              'là im lặng đánh rơi tiền của người dùng');
    });

    testWidgets('không tràn ở 411dp với số hàng trăm triệu', (tester) async {
      await moCao(tester);
      await phat(
        tester,
        _tk(chuoiVayNo: chuoi(choVay: 987654321, thuNo: 123456789, diVay: 555555555, traNo: 999999999)),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // ── Thác nước "Tiền đi đâu" — A8 #10 (2026-09-15) ────────────────────────
  //
  // Phép tính đã test ở `thac_nuoc_test.dart`; ở đây chỉ canh những gì widget
  // mới sai được: khối có hiện không, và có nói rõ mức trung bình không.
  group('khối thác nước', () {
    /// Số thật đọc trên máy ảo: 10.000 + 14.625.000 − 1.045.000 = 13.590.000.
    /// Sáu danh mục chi để `topVaKhac(top: 5)` còn sinh ra cột "Khác".
    ThongKeKy tkThacNuoc({DongTien? dongTien = const DongTien(
      dauKy: 10000,
      cuoiKy: 13590000,
    )}) =>
        _tk(
          thu: 14625000,
          chi: 1045000,
          dongTien: dongTien,
          danhMuc: [
            _dm('c1', 'Chưa phân loại', 500000, 0.48),
            _dm('c2', 'Di chuyển', 305000, 0.29),
            _dm('c3', 'Mua sắm', 60000, 0.06),
            _dm('c4', 'Danh mục đã xoá', 55000, 0.05),
            _dm('c5', 'Ăn uống', 50000, 0.05),
            _dm('c6', 'Giáo dục', 75000, 0.07),
          ],
        );

    Future<void> moCaoVaPhat(WidgetTester tester, ThongKeKy tk) async {
      tester.view.physicalSize = const Size(411, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await moTrang(tester);
      await phat(tester, tk);
    }

    testWidgets('khối hiện với tiêu đề và dải chú giải ba màu', (tester) async {
      await moCaoVaPhat(tester, tkThacNuoc());

      expect(find.text('Tiền đi đâu'), findsOneWidget);
      expect(find.text('Số dư'), findsOneWidget);
      expect(find.text('Thu'), findsWidgets);
      expect(find.text('Chi'), findsWidgets);
    });

    testWidgets('⚠️ nói rõ mức trung bình mỗi nhóm, không để người đọc tự đoán',
        (tester) async {
      await moCaoVaPhat(tester, tkThacNuoc());

      // 1.045.000 / 6 nhóm = 174.166,67 → làm tròn về đồng chẵn.
      expect(find.textContaining('174.167 đ'), findsOneWidget,
          reason: 'Phần đậm trên cột là "chỗ vượt mức trung bình". Không nói '
              'mức ấy là bao nhiêu thì hai sắc độ chỉ còn là trang trí — '
              'người đọc không suy ra được ngưỡng từ hình vẽ.');
    });

    testWidgets('⚠️ lọc theo một ví thì khối BIẾN MẤT, không vẽ hình cụt',
        (tester) async {
      // `dongTien` null nghĩa là số dư hai đầu không suy ngược được (mục
      // 3.16). Thiếu hai cột mốc thì thác nước mất cả điểm đầu lẫn điểm cuối —
      // còn lại một dãy khối lơ lửng không kể được gì.
      await moCaoVaPhat(tester, tkThacNuoc(dongTien: null));

      expect(find.text('Tiền đi đâu'), findsNothing);
    });

    testWidgets('không tràn ở 411dp với sáu nhóm chi', (tester) async {
      await moCaoVaPhat(tester, tkThacNuoc());

      expect(tester.takeException(), isNull,
          reason: 'Chín cột trên 411dp là chỗ chật nhất của trang; Flutter báo '
              'tràn qua reportError chứ không ném ra chỗ gọi.');
    });
  });

  group('Tỉ lệ tiết kiệm', () {
    /// Sáu kỳ vay/nợ, chỉ kỳ cuối (kỳ đang xem) mang số.
    List<DiemVayNo> vayNoKyCuoi({double diVay = 0, double thuNo = 0}) {
      final cs = chuoiTheoKy(const [], ky: Ky.thang(2026, 9));
      return [
        for (var i = 0; i < cs.length; i++)
          DiemVayNo(
            ky: cs[i].ky,
            diVay: i == cs.length - 1 ? diVay : 0,
            thuNo: i == cs.length - 1 ? thuNo : 0,
          ),
      ];
    }

    testWidgets('hiện phần trăm thu nhập chưa tiêu', (tester) async {
      await moTrang(tester);
      // Mặc định: thu 5.000.000, chi 1.250.000 → để dành 75%.
      await phat(tester, _tk());

      expect(find.text('Để dành 75% thu nhập'), findsOneWidget);
    });

    testWidgets('⚠️ tiền ĐI VAY không làm tỉ lệ đẹp lên', (tester) async {
      await moTrang(tester);
      // 20tr tiền vào, trong đó 5tr là vay mượn; tiêu 10tr.
      await phat(
        tester,
        _tk(thu: 20000000, chi: 10000000, chuoiVayNo: vayNoKyCuoi(diVay: 5000000)),
      );

      expect(find.text('Để dành 33% thu nhập'), findsOneWidget,
          reason: '(20tr − 5tr vay − 10tr chi) / 15tr. Dùng nguyên tong.thu sẽ '
              'ra 50% — tháng đi vay lại trông tiết kiệm hơn thật.');
      expect(find.text('Để dành 50% thu nhập'), findsNothing);
    });

    testWidgets('chi vượt thu nhập thì tỉ lệ ÂM, không kẹp về 0',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(thu: 10000000, chi: 13000000));

      expect(find.text('Để dành -30% thu nhập'), findsOneWidget);
    });

    testWidgets('⚠️ không có thu nhập thì ẨN dòng, không in 0%',
        (tester) async {
      await moTrang(tester);
      // Kỳ chỉ có tiền đi vay: tổng thu 5tr nhưng thu nhập bằng 0.
      await phat(
        tester,
        _tk(thu: 5000000, chi: 1000000, chuoiVayNo: vayNoKyCuoi(diVay: 5000000)),
      );

      expect(find.textContaining('Để dành'), findsNothing,
          reason: '"tiết kiệm bao nhiêu phần trăm của số không" là câu không có '
              'nghĩa — in 0% là bịa một con số');
    });
  });

  group('Dòng tiền tự do (A8 #8)', () {
    /// Sáu kỳ; chỉ kỳ **cuối** (kỳ đang xem) mang số, để con số lớn của khối
    /// đọc ra được bằng `find.text`.
    ({List<DiemThoiGian> chuoi, List<DiemVayNo> vayNo}) boSoLieu({
      double thu = 0,
      double diVay = 0,
      double thuNo = 0,
      double khacVao = 0,
      double traNo = 0,
    }) {
      final ky = Ky.thang(2026, 9);
      final cs = chuoiTheoKy(const [], ky: ky);
      return (
        chuoi: [
          for (var i = 0; i < cs.length; i++)
            DiemThoiGian(
              ky: cs[i].ky,
              tong: TongThuChi(thu: i == cs.length - 1 ? thu : 0, chi: 0),
            ),
        ],
        vayNo: [
          for (var i = 0; i < cs.length; i++)
            DiemVayNo(
              ky: cs[i].ky,
              diVay: i == cs.length - 1 ? diVay : 0,
              thuNo: i == cs.length - 1 ? thuNo : 0,
              khacVao: i == cs.length - 1 ? khacVao : 0,
              traNo: i == cs.length - 1 ? traNo : 0,
            ),
        ],
      );
    }

    Future<void> moCaoVaPhat(WidgetTester tester, ThongKeKy tk) async {
      tester.view.physicalSize = const Size(411, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await moTrang(tester);
      await phat(tester, tk);
    }

    testWidgets('hiện cả khi không ai nợ ai — người dùng chốt "luôn hiện"',
        (tester) async {
      await moCaoVaPhat(tester, _tk());

      expect(find.text('Dòng tiền tự do 6 tháng'), findsOneWidget);
      expect(
        find.text('Thu nhập sau khi trả nợ; không tính tiền đi vay và thu hồi nợ'),
        findsOneWidget,
        reason: 'con số này không tự giải thích — bê trần nó ra là để người đọc '
            'hiểu nhầm, cùng lý do khối Dòng tiền luôn kèm câu "Suy ngược từ…"',
      );
    });

    testWidgets('⚠️ tiền ĐI VAY không được tính là thu nhập', (tester) async {
      // 20tr tiền vào, trong đó 5tr là vay mượn; trả nợ 3tr.
      final b = boSoLieu(thu: 20000000, diVay: 5000000, traNo: 3000000);
      await moCaoVaPhat(tester, _tk(chuoi: b.chuoi, chuoiVayNo: b.vayNo));

      expect(find.text('12.000.000đ'), findsOneWidget,
          reason: '(20tr − 5tr vay) − 3tr trả nợ. Đây là ca lật thiết kế: lấy '
              'nguyên tong.thu thì tháng đi vay lại trông đẹp lên.');
      expect(find.text('17.000.000đ'), findsNothing,
          reason: '17tr là con số của công thức sai — tong.thu − traNo.');
    });

    testWidgets('⚠️ tiền THU NỢ và khoản vay/nợ vào KHÔNG rõ vai cũng bị trừ',
        (tester) async {
      final b = boSoLieu(thu: 20000000, thuNo: 6000000, khacVao: 2000000);
      await moCaoVaPhat(tester, _tk(chuoi: b.chuoi, chuoiVayNo: b.vayNo));

      expect(find.text('12.000.000đ'), findsOneWidget,
          reason: 'thu hồi vốn là tiền cũ quay về; khoản vay/nợ tiền vào không '
              'rõ vai chỉ có thể là đi vay hoặc thu nợ — không lối nào là thu nhập');
    });

    testWidgets('trả nợ vượt thu nhập thì con số ÂM, không kẹp về 0',
        (tester) async {
      final b = boSoLieu(thu: 4000000, traNo: 6500000);
      await moCaoVaPhat(tester, _tk(chuoi: b.chuoi, chuoiVayNo: b.vayNo));

      expect(find.text('-2.500.000đ'), findsOneWidget,
          reason: 'kẹp về 0 là giấu đúng kỳ người dùng cần thấy nhất');
    });

    testWidgets('không tràn ở 411dp', (tester) async {
      final b = boSoLieu(thu: 20000000, diVay: 5000000, traNo: 3000000);
      await moCaoVaPhat(tester, _tk(chuoi: b.chuoi, chuoiVayNo: b.vayNo));

      expect(tester.takeException(), isNull,
          reason: 'Flutter báo tràn qua reportError chứ không ném ra chỗ gọi.');
    });
  });

  // ── Dự báo 30 ngày tới (2026-09-16) ──────────────────────────────────────
  //
  // Phép tính đã test ở `du_bao_dong_tien_test.dart`; ở đây chỉ canh những gì
  // widget mới sai được: hiện/ẩn, ba con số, dòng ví thiếu, "Xem thêm", câu
  // rỗng, và không tràn ở 411dp.
  group('khối dự báo 30 ngày', () {
    Future<void> moCaoVaPhat(WidgetTester tester, ThongKeKy tk) async {
      tester.view.physicalSize = const Size(411, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await moTrang(tester);
      await phat(tester, tk);
    }

    final sauCamKet = [
      _camKet('Tiền điện', DateTime(2026, 9, 8), 800000, quaHan: true),
      _camKet('Internet', DateTime(2026, 9, 12), 250000),
      _camKet('Mua xe', DateTime(2026, 9, 15), 500000,
          loai: LoaiCamKet.trichTuDong, laKyChieu: true),
      _camKet('Tiền nước', DateTime(2026, 9, 20), 120000),
      _camKet('Gym', DateTime(2026, 10, 1), 400000),
      _camKet('Tiền điện', DateTime(2026, 10, 8), 800000, laKyChieu: true),
    ];

    testWidgets('khối hiện tiêu đề, ba con số và có LineChart', (tester) async {
      await moCaoVaPhat(
          tester, _tk(duBao: _duBao(camKet: sauCamKet, nganSachConLai: 1200000)));

      expect(find.text('Dự báo 30 ngày tới'), findsOneWidget);
      expect(find.text('Còn tiêu được'), findsOneWidget);
      // 10.000.000 − (800 + 250 + 500 + 120 + 400 + 800)k = 7.130.000
      expect(find.text('7.130.000đ'), findsOneWidget);
      expect(find.text('Số dư hiện tại'), findsOneWidget);
      expect(find.text('10.000.000đ'), findsOneWidget);
      expect(find.text('Nếu tiêu đúng ngân sách'), findsOneWidget);
      expect(find.text('5.930.000đ'), findsOneWidget);
      expect(find.byType(LineChart), findsWidgets);
    });

    testWidgets('không có ngân sách thì KHÔNG hiện dòng "Nếu tiêu đúng ngân sách"',
        (tester) async {
      await moCaoVaPhat(tester, _tk(duBao: _duBao(camKet: sauCamKet)));
      expect(find.text('Nếu tiêu đúng ngân sách'), findsNothing);
    });

    testWidgets('⚠️ duBao null thì ẩn CẢ KHỐI — chốt ở hai lớp', (tester) async {
      await moCaoVaPhat(tester, _tk(duBao: null));
      expect(find.text('Dự báo 30 ngày tới'), findsNothing,
          reason: 'Không có ví thì không có thang đo. Bản sai phải phá cả `if` '
              'ở trang lẫn guard trong widget mới làm ca này đỏ.');
    });

    testWidgets('dòng ví thiếu nói rõ ví nào, thiếu bao nhiêu, tới ngày nào',
        (tester) async {
      await moCaoVaPhat(
          tester,
          _tk(
              duBao: _duBao(camKet: sauCamKet, viThieu: [
            ViThieu(
                walletId: 'w1',
                ten: 'Tiền mặt',
                thieu: 1500000,
                ngay: DateTime(2026, 9, 25))
          ])));
      expect(
          find.text('Ví Tiền mặt thiếu 1.500.000đ để trả cam kết ngày 25/09'),
          findsOneWidget);
    });

    testWidgets(
        'danh sách thu gọn 5 dòng, "Xem thêm (1)" mở hết; huy hiệu Quá hạn / Dự kiến',
        (tester) async {
      await moCaoVaPhat(tester, _tk(duBao: _duBao(camKet: sauCamKet)));

      expect(find.text('Gym'), findsOneWidget, reason: 'dòng thứ 5 theo ngày');
      expect(find.text('Quá hạn'), findsOneWidget);
      expect(find.text('Dự kiến'), findsOneWidget,
          reason: 'Mua xe; "Tiền điện 08/10" là dòng thứ 6, đang bị thu gọn');
      expect(find.text('Xem thêm (1)'), findsOneWidget);

      await tester.tap(find.text('Xem thêm (1)'));
      await tester.pump();

      expect(find.text('Xem thêm (1)'), findsNothing);
      expect(find.text('Dự kiến'), findsNWidgets(2));
    });

    testWidgets(
        'không cam kết: ba con số vẫn hiện, thân thay bằng một câu',
        (tester) async {
      await moCaoVaPhat(tester, _tk(duBao: _duBao()));
      expect(find.text('Dự báo 30 ngày tới'), findsOneWidget);
      expect(
          find.text('Không có hoá đơn hay trích tự động nào trong 30 ngày tới'),
          findsOneWidget);
      expect(find.text('10.000.000đ'), findsWidgets);
    });

    testWidgets('kỳ đang xem RỖNG vẫn hiện dự báo — nó không nói về kỳ',
        (tester) async {
      await moCaoVaPhat(
          tester, _tk(thu: 0, chi: 0, duBao: _duBao(camKet: sauCamKet)));
      expect(find.text('Dự báo 30 ngày tới'), findsOneWidget);
    });

    testWidgets('không tràn ở 411dp với tên dài và số lớn', (tester) async {
      await moCaoVaPhat(
          tester,
          _tk(
              duBao: _duBao(
            soDu: 1234567890,
            camKet: [
              _camKet('Một hoá đơn có tên rất dài để thử tràn bố cục ngang',
                  DateTime(2026, 9, 9), 987654321)
            ],
            viThieu: [
              ViThieu(
                  walletId: 'w1',
                  ten: 'Ví có tên cũng rất dài',
                  thieu: 987654321,
                  ngay: DateTime(2026, 9, 9))
            ],
          )));
      expect(tester.takeException(), isNull,
          reason: 'Flutter báo tràn qua reportError chứ không ném ra chỗ gọi.');
    });
  });

  group('Tổng tài sản theo thời gian (#5)', () {
    /// Sáu điểm tăng dần, điểm cuối 13.590.000 — con số đo được trên tài khoản
    /// thật ngày 2026-09-17.
    List<DiemTaiSan> chuoiTaiSan() {
      final ky = Ky.thang(2026, 9);
      const moc = [11240000.0, 11600000.0, 12100000.0, 11900000.0, 12750000.0, 13590000.0];
      return [
        for (var i = 0; i < kSoKyXuHuong; i++)
          (
            ky: lui(ky, kSoKyXuHuong - 1 - i),
            moc: lui(ky, kSoKyXuHuong - 1 - i).to,
            tong: moc[i],
          ),
      ];
    }

    testWidgets('hiện tiêu đề và số tổng tài sản hiện tại', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(taiSan: chuoiTaiSan()));

      expect(find.text('Tổng tài sản 6 tháng gần đây'), findsOneWidget);
      expect(find.text('13.590.000 đ'), findsOneWidget,
          reason: 'Số lớn là ĐIỂM CUỐI của đường, và nó phải bằng con số '
              'Trang chủ — mốc để người dùng tin cả biểu đồ.');
    });

    testWidgets('tiêu đề đổi theo đơn vị đang xem', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(ky: Ky.quy(2026, 3), taiSan: chuoiTaiSan()));

      expect(find.text('Tổng tài sản 6 quý gần đây'), findsOneWidget);
    });

    testWidgets('dòng thay đổi hiện khi cả chuỗi đứng vững', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(
        taiSan: chuoiTaiSan(),
        giaoDichDauTien: DateTime(2024, 1, 1),
      ));

      expect(find.text('+2.350.000 đ trong 6 tháng'), findsOneWidget);
    });

    testWidgets('⚠️ dòng thay đổi ẨN khi chuỗi chạm vùng chưa có dữ liệu',
        (tester) async {
      // Điểm đầu khi ấy là số 0 "chưa biết". In hiệu với nó là nói người dùng
      // vừa kiếm được nguyên cả tài sản trong sáu tháng — hợp lý và sai hẳn.
      await moTrang(tester);
      await phat(tester, _tk(
        taiSan: chuoiTaiSan(),
        giaoDichDauTien: DateTime(2026, 9, 2),
      ));

      expect(find.textContaining('trong 6 tháng'), findsNothing);
    });

    testWidgets('câu cảnh báo hiện đúng ngày khi đoạn đầu đường chưa có dữ liệu',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(
        taiSan: chuoiTaiSan(),
        giaoDichDauTien: DateTime(2026, 9, 2),
      ));

      expect(
          find.text('Trước 02/09/2026 chưa có giao dịch nào để suy ra số dư.'),
          findsOneWidget);
    });

    testWidgets('không cảnh báo khi cả chuỗi nằm sau giao dịch đầu tiên',
        (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(
        taiSan: chuoiTaiSan(),
        giaoDichDauTien: DateTime(2024, 1, 1),
      ));

      expect(find.textContaining('chưa có giao dịch nào'), findsNothing);
    });

    testWidgets('chuỗi rỗng thì ẩn hẳn khối', (tester) async {
      await moTrang(tester);
      await phat(tester, _tk(taiSan: const []));

      expect(find.textContaining('Tổng tài sản'), findsNothing,
          reason: 'Không điểm nào thì không có thang đo — bỏ khối, đừng vẽ '
              'một khung rỗng.');
    });
  });
}
