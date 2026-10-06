// C1 — màn Gắn danh mục nhanh (spec `2026-09-28-c1-gan-danh-muc-hang-loat-design.md` §4–§5, Stitch `5023f081…`).
// Bất biến ④ nhóm C: mô hình chỉ ĐIỀN SẴN; không có gì được ghi trước khi người dùng bấm Áp dụng.
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/features/category/data/gan_danh_muc_nguon.dart';
import 'package:flowmoney/features/category/domain/gan_hang_loat.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/category/presentation/pages/gan_danh_muc_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'category_test_fakes.dart';

Transaction _gd(String id, String note, {String type = 'chi', double amount = 45000}) => Transaction(
      id: id,
      walletId: 'v1',
      idaccount: 7,
      amount: amount,
      type: type,
      status: 'completed',
      provider: 'Manual',
      note: note,
      date: DateTime(2026, 9, 12),
      images: '',
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 12),
      isDeleted: false,
    );

DoanDanhMuc _doan(String cat, String cum) =>
    DoanDanhMuc(categoryId: cat, xacSuat: 0.9, cumBoDau: cum, soLanCung: 6, soLanTong: 7);

final _chonDuoc = [
  makeCategory(id: 'c-dc', name: 'Di chuyển'),
  makeCategory(id: 'c-an', name: 'Ăn uống'),
  makeCategory(id: 'c-luong', name: 'Lương', classify: 'thu'),
  makeCategory(id: 'c-vay', name: 'Cho vay', classify: 'vay_no'),
];

const _lyDo1 = 'Bạn thường ghi “Grab” cho Di chuyển (6/7 lần).';
const _lyDo2 = 'Bạn thường ghi “Com trua” cho Ăn uống (5/5 lần).';

DuLieuGanDanhMuc _du({List<DongGanDanhMuc>? dong}) => DuLieuGanDanhMuc(
      dong: dong ??
          [
            DongGanDanhMuc(giaoDich: _gd('g1', 'Grab ve nha'), doan: _doan('c-dc', 'grab'), lyDo: _lyDo1),
            DongGanDanhMuc(giaoDich: _gd('g2', 'Com trua'), doan: _doan('c-an', 'com trua'), lyDo: _lyDo2),
            DongGanDanhMuc(giaoDich: _gd('g3', 'xyz', amount: 120000)),
          ],
      chonDuoc: _chonDuoc,
      tenVi: const {'v1': 'Tiền mặt'},
    );

void main() {
  late List<String> toast;

  setUp(() {
    final tb = ThongBaoNhanh();
    sl.registerSingleton<ThongBaoNhanh>(tb);
    toast = [];
    tb.stream.listen((t) => toast.add(t.cau));
  });
  tearDown(() => sl.reset());

  Future<void> mo(
    WidgetTester tester, {
    int? idaccount = 7,
    DuLieuGanDanhMuc? du,
    List<(String, String)>? apDung,
    List<(String, String, String)>? phanHoi,
    Set<String> hong = const {},
    List<int>? soLanTai,
    Size kho = const Size(411, 900),
  }) async {
    tester.view.physicalSize = kho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/so/gan',
      routes: [
        GoRoute(
          path: '/so',
          builder: (_, __) => const Scaffold(body: Text('SỔ GIAO DỊCH')),
          routes: [
            GoRoute(
              path: 'gan',
              builder: (_, __) => GanDanhMucPage(
                idaccount: idaccount,
                taiDuLieu: (_) async {
                  soLanTai?.add(1);
                  return du ?? _du();
                },
                apDung: (d, c) async {
                  if (hong.contains(d.giaoDich.id)) throw StateError('hỏng');
                  apDung?.add((d.giaoDich.id, c));
                },
                ghiPhanHoi: (d, k, c) async => phanHoi?.add((d.giaoDich.id, k, c)),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
  }

  bool? tick(WidgetTester tester, String id) => tester.widget<Checkbox>(find.byKey(Key('gan-tick-$id'))).value;
  VoidCallback? nutApDung(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byKey(const Key('gan-ap-dung'))).onPressed;

  Future<void> chonTrongBang(WidgetTester tester, String dong, String cat) async {
    await tester.ensureVisible(find.byKey(Key('gan-chip-$dong')));
    await tester.tap(find.byKey(Key('gan-chip-$dong')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('gan-chon-$cat')));
    await tester.pumpAndSettle();
  }

  testWidgets('dòng có dự đoán TICK SẴN kèm câu lý do; dòng chưa đoán trống, không tick được', (tester) async {
    await mo(tester);

    expect(tick(tester, 'g1'), isTrue);
    expect(tick(tester, 'g2'), isTrue);
    expect(tick(tester, 'g3'), isFalse);
    expect(tester.widget<Checkbox>(find.byKey(const Key('gan-tick-g3'))).onChanged, isNull,
        reason: 'dòng chưa có danh mục thì không có gì để gắn — tick nó là hứa một lần ghi không làm được');
    expect(find.text(_lyDo1), findsOneWidget);
    expect(find.text(_lyDo2), findsOneWidget);
    expect(find.text('Chọn danh mục'), findsOneWidget);
    expect(find.text('CHƯA ĐOÁN ĐƯỢC'), findsOneWidget);
    expect(find.text('Áp dụng 2'), findsOneWidget);
    expect(find.text('12/09 · Tiền mặt'), findsNWidgets(3));
  });

  testWidgets('chạm ô trống → bảng chọn CHỈ danh mục khớp chiều; chọn xong tự tick', (tester) async {
    await mo(tester);

    await tester.tap(find.byKey(const Key('gan-chip-g3')));
    await tester.pumpAndSettle();
    expect(find.text('KHOẢN CHI'), findsOneWidget);
    expect(find.text('VAY / NỢ'), findsOneWidget);
    expect(find.byKey(const Key('gan-chon-c-an')), findsOneWidget);
    expect(find.byKey(const Key('gan-chon-c-vay')), findsOneWidget);
    expect(find.byKey(const Key('gan-chon-c-luong')), findsNothing,
        reason: 'khoản chi không được chọn danh mục thu — cùng luật hopLeTheoChieu với dự đoán');

    await tester.tap(find.byKey(const Key('gan-chon-c-an')));
    await tester.pumpAndSettle();
    expect(tick(tester, 'g3'), isTrue, reason: 'chọn danh mục là ý định gắn dòng ấy');
    expect(find.text('Áp dụng 3'), findsOneWidget);
  });

  testWidgets('dòng THU: bảng chọn chỉ có danh mục thu và vay/nợ', (tester) async {
    await mo(tester, du: _du(dong: [DongGanDanhMuc(giaoDich: _gd('g4', 'ban do cu', type: 'thu'))]));

    await tester.tap(find.byKey(const Key('gan-chip-g4')));
    await tester.pumpAndSettle();
    expect(find.text('KHOẢN THU'), findsOneWidget);
    expect(find.byKey(const Key('gan-chon-c-luong')), findsOneWidget);
    expect(find.byKey(const Key('gan-chon-c-vay')), findsOneWidget);
    expect(find.byKey(const Key('gan-chon-c-dc')), findsNothing);
  });

  testWidgets('bỏ tick thì đếm lại; bỏ hết thì nút Áp dụng tắt', (tester) async {
    await mo(tester);

    await tester.tap(find.byKey(const Key('gan-tick-g1')));
    await tester.pump();
    expect(find.text('Áp dụng 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gan-tick-g2')));
    await tester.pump();
    expect(find.text('Áp dụng 0'), findsOneWidget);
    expect(nutApDung(tester), isNull, reason: 'không dòng nào tick thì không có gì để ghi');
  });

  testWidgets('⭐ chưa bấm Áp dụng thì KHÔNG ghi gì — mở màn, đổi, bỏ tick đều không chạm sổ', (tester) async {
    final apDung = <(String, String)>[];
    final phanHoi = <(String, String, String)>[];
    await mo(tester, apDung: apDung, phanHoi: phanHoi);

    await chonTrongBang(tester, 'g3', 'c-an');
    await tester.tap(find.byKey(const Key('gan-tick-g1')));
    await tester.pump();

    expect(apDung, isEmpty, reason: 'bất biến ④ nhóm C: AI điền sẵn, người dùng bấm mới ghi');
    expect(phanHoi, isEmpty);
  });

  testWidgets('Áp dụng: đúng các cặp (dòng, danh mục); phản hồi chon/khac CHỈ cho dòng có dự đoán; toast; quay về',
      (tester) async {
    final apDung = <(String, String)>[];
    final phanHoi = <(String, String, String)>[];
    await mo(tester, apDung: apDung, phanHoi: phanHoi);

    await chonTrongBang(tester, 'g2', 'c-dc'); // đổi dự đoán Ăn uống → Di chuyển
    await chonTrongBang(tester, 'g3', 'c-vay');
    expect(find.text('Áp dụng 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gan-ap-dung')));
    await tester.pumpAndSettle();

    expect(apDung, [('g1', 'c-dc'), ('g2', 'c-dc'), ('g3', 'c-vay')]);
    expect(phanHoi, [('g1', kKetQuaGoiYChon, 'c-dc'), ('g2', kKetQuaGoiYKhac, 'c-dc')],
        reason: 'g3 không có dự đoán → không có gì để phán xét, không ghi');
    expect(toast, ['Đã gắn danh mục']);
    expect(find.text('SỔ GIAO DỊCH'), findsOneWidget, reason: 'áp dụng xong quay về Sổ giao dịch');
  });

  testWidgets('dòng bỏ tick không được ghi và không có phản hồi', (tester) async {
    final apDung = <(String, String)>[];
    final phanHoi = <(String, String, String)>[];
    await mo(tester, apDung: apDung, phanHoi: phanHoi);

    await tester.tap(find.byKey(const Key('gan-tick-g1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gan-ap-dung')));
    await tester.pumpAndSettle();

    expect(apDung, [('g2', 'c-an')]);
    expect(phanHoi, [('g2', kKetQuaGoiYChon, 'c-an')],
        reason: 'bỏ tick là "chưa muốn sửa dòng này", không phải "dự đoán sai" — ghi bo_qua/khac là dạy sai mô hình');
  });

  testWidgets('một dòng hỏng không chặn dòng sau; toast nói còn kẹt; dòng hỏng không có phản hồi', (tester) async {
    final apDung = <(String, String)>[];
    final phanHoi = <(String, String, String)>[];
    await mo(tester, apDung: apDung, phanHoi: phanHoi, hong: {'g1'});

    await tester.tap(find.byKey(const Key('gan-ap-dung')));
    await tester.pumpAndSettle();

    expect(apDung, [('g2', 'c-an')]);
    expect(phanHoi.map((p) => p.$1), ['g2']);
    expect(toast, ['Đã gắn danh mục — có giao dịch chưa lưu được']);
  });

  testWidgets('mọi dòng chưa đoán: câu giải thích khác, không tiêu đề nhóm, nút tắt', (tester) async {
    await mo(tester, du: _du(dong: [DongGanDanhMuc(giaoDich: _gd('g3', 'xyz'))]));

    expect(find.textContaining('Chưa đoán được danh mục nào'), findsOneWidget);
    expect(find.text('CHƯA ĐOÁN ĐƯỢC'), findsNothing);
    expect(nutApDung(tester), isNull);
  });

  testWidgets('idaccount null → không đọc sổ, không dựng dòng nào', (tester) async {
    final soLanTai = <int>[];
    await mo(tester, idaccount: null, soLanTai: soLanTai);

    expect(soLanTai, isEmpty, reason: 'quy tắc 2: không có phiên thì không đọc — không rơi về tài khoản admin');
    expect(find.text('Chưa xác định được tài khoản đăng nhập'), findsOneWidget);
  });

  for (final kho in const [Size(411, 900), Size(360, 640)]) {
    testWidgets('khổ ${kho.width.toInt()} × ${kho.height.toInt()}, ghi chú 120 ký tự: không tràn', (tester) async {
      final dai = 'Grab ${'di lam ve muon qua ' * 7}'.substring(0, 120);
      await mo(
        tester,
        kho: kho,
        du: _du(dong: [
          DongGanDanhMuc(giaoDich: _gd('g1', dai, amount: 1234567890), doan: _doan('c-dc', 'grab'), lyDo: _lyDo1),
          DongGanDanhMuc(giaoDich: _gd('g3', '')),
        ]),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('(Không có ghi chú)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gan-chip-g3')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'bảng chọn ở khổ thấp phải cuộn được (bẫy G60)');
    });
  }
}
