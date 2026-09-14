/// Trang Phân tích với repository giả.
///
/// Canh chừng điều gì: trang này từng là **số cứng** — kể cả tháng đang hiện
/// ("T6 2026" khi đang là tháng 9). Tệp này canh những gì chỉ widget mới sai
/// được: số trên thẻ có đúng là số từ stream không, nhãn "% ngân sách" / "%
/// tổng chi" có đổi theo dữ liệu không, tháng có lấy từ đồng hồ không, chọn
/// tháng có hỏi lại đúng tháng không, và khổ 411dp với tên danh mục dài.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/phan_loai_dong_tien.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
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
  final goi = <({int nam, int thang})>[];
  StreamController<ThongKeThang>? _c;

  @override
  Stream<ThongKeThang> watchThang(
    int idaccount, {
    required int nam,
    required int thang,
    DateTime? now,
  }) {
    goi.add((nam: nam, thang: thang));
    _c?.close();
    _c = StreamController<ThongKeThang>();
    return _c!.stream;
  }

  void phat(ThongKeThang tk) => _c!.add(tk);

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

ThongKeThang _tk({
  int nam = 2026,
  int thang = 9,
  double thu = 5000000,
  double chi = 1250000,
  double thuTruoc = 0,
  double chiTruoc = 1000000,
  List<DongDanhMuc> danhMuc = const [],
  List<DiemThoiGian>? chuoi,
  List<LatPhanLoai> lat = const [],
  Map<String, List<DongDanhMuc>> theoLat = const {},
  Map<String?, List<DiemThoiGian>> chuoiDm = const {},
}) =>
    ThongKeThang(
      nam: nam,
      thang: thang,
      tong: TongThuChi(thu: thu, chi: chi),
      tongTruoc: TongThuChi(thu: thuTruoc, chi: chiTruoc),
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
      chuoi: chuoi ?? chuoiTheoThang(const [], nam: nam, thang: thang),
      latPhanLoai: lat,
      danhMucTheoLat: theoLat,
      chuoiDanhMuc: chuoiDm,
    );

/// Ba phân loại mẫu, dùng chung cho nhóm test "Cơ cấu theo danh mục" — đủ cả
/// ba thì trang hiện đủ ba chip.
const _baLat = [
  LatPhanLoai(phanLoai: 'thu', soTien: 600000, tiLe: 0.6),
  LatPhanLoai(phanLoai: 'chi', soTien: 300000, tiLe: 0.3),
  LatPhanLoai(phanLoai: 'vay_no', soTien: 100000, tiLe: 0.1),
];

void main() {
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

  Future<void> phat(WidgetTester tester, ThongKeThang tk) async {
    repo.phat(tk);
    await tester.pump();
    await tester.pump();
  }

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

  testWidgets('chọn tháng khác thì hỏi lại đúng tháng ấy', (tester) async {
    await moTrang(tester);
    await phat(tester, _tk());

    await tester.tap(find.text('Tháng này (T9 2026)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T8 2026').last);
    // KHÔNG pumpAndSettle: sau khi chọn, state Loading vẽ vòng quay quay mãi
    // nên không bao giờ "lắng" — bản test đầu treo tới timeout ở đây.
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.goi.last, (nam: 2026, thang: 8));

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

  group('biểu đồ xu hướng', () {
    List<DiemThoiGian> chuoiMau() => [
          for (var i = 0; i < 6; i++)
            DiemThoiGian(
              nam: 2026,
              thang: 4 + i,
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
              nam: 2026,
              thang: 4 + i,
              tong: const TongThuChi(thu: 987654321.0, chi: 123456789.0),
            ),
        ]),
      );

      expect(tester.takeException(), isNull,
          reason: 'Nhãn trục trái mang số tiền rút gọn; số hàng trăm triệu là '
              'chuỗi dài nhất có thể, và font của bộ test rộng gấp đôi ngoài '
              'đời nên đây là ca chật nhất.');
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
        chuoiTheoThang(const [], nam: 2026, thang: 9);

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
}
