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
    );

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
    await moTrang(tester);
    await phat(
      tester,
      _tk(danhMuc: [
        _dm('a', 'Ăn uống', 800000, 0.64, hanMuc: 2500000, daChi: 800000),
        _dm('b', 'Di chuyển', 450000, 0.36),
      ]),
    );

    expect(find.text('Ăn uống'), findsWidgets);
    expect(find.text('32% ngân sách'), findsOneWidget);
    expect(find.text('36% tổng chi'), findsOneWidget,
        reason: 'Không bịa ngân sách cho danh mục chưa đặt: nhãn phải đổi, '
            'không được hiện "0% ngân sách".');
    expect(find.text('800.000đ'), findsOneWidget);
  });

  testWidgets('donut: 4 lát đầu + "Khác", tâm hiện tổng chi rút gọn',
      (tester) async {
    await moTrang(tester);
    await phat(
      tester,
      _tk(chi: 6500000, danhMuc: [
        _dm('a', 'Ăn uống', 2100000, 0.323),
        _dm('b', 'Mua sắm', 1500000, 0.231),
        _dm('c', 'Di chuyển', 900000, 0.138),
        _dm('d', 'Giải trí', 600000, 0.092),
        _dm('e', 'Y tế', 800000, 0.123),
        _dm('f', 'Khác nữa', 600000, 0.092),
      ]),
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
    await moTrang(tester);
    await phat(
      tester,
      _tk(danhMuc: [
        for (var i = 0; i < 7; i++)
          _dm('c$i', 'Danh mục $i', 100000, 1 / 7),
      ]),
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

    await moTrang(tester);
    await phat(
      tester,
      _tk(thu: 123456789, chi: 98765432, danhMuc: [
        _dm('a', 'Ăn uống ngoài hàng quán cuối tuần với gia đình', 98765432,
            1.0,
            hanMuc: 100000000, daChi: 98765432),
      ]),
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
}
