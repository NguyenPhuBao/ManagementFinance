import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/domain/hang_chua_day.dart';
import 'package:flowmoney/shared/theme/app_colors.dart';
import 'package:flowmoney/features/household/presentation/pages/nha_minh_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/goi_gia.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

Map<String, Object?> _loiMoiJson() => {
      'code': 'WXYZ6789',
      'householdName': 'Nhà Minh Anh',
      'inviterName': 'Minh Anh',
      'role': 'Member',
      'expiresAt': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
    };

/// Chỉ `hangChuaDay` được dùng; ghi lại (idNha, idaccount).
class _DuLieuGia implements DuLieuNhaRepository {
  _DuLieuGia(this.tra);

  final HangChuaDayNha tra;
  final goi = <(int, int?)>[];

  @override
  Future<HangChuaDayNha> hangChuaDay(int idNha, {required int? idaccount}) async {
    goi.add((idNha, idaccount));
    return tra;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(napFontThat);
  late BatThongBao bat;

  Future<HouseholdApiGia> mo(WidgetTester t,
      {Map<String, Object?>? nha, List<Map<String, Object?>> loiMoi = const [], bool basic = true, bool banPhim = false}) async {
    dat360(t, banPhim: banPhim);
    bat = batThongBao();
    final api = HouseholdApiGia()
      ..cuaToiJson = nha ?? const {'household': null, 'myRole': null, 'members': [], 'formerMembers': []}
      ..dsLoiMoiToiJson = loiMoi;
    final repo = await repoNhaThu(api);
    await t.pumpWidget(bocTrangNha(NhaMinhPage(repo: repo), goi: basic ? goiBasic(const {}) : goiPremium(const {})));
    await t.pumpAndSettle();
    return api;
  }

  testWidgets('chưa có nhà, Basic: hai nút, nhãn PREMIUM trên Tạo nhà, không tràn', (t) async {
    await mo(t);
    expect(find.text('Bạn chưa ở nhà nào'), findsOneWidget);
    expect(find.text('Tạo nhà'), findsOneWidget);
    expect(find.text('Tham gia bằng mã'), findsOneWidget);
    expect(find.text('PREMIUM'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('chưa có nhà, Premium còn hạn: không nhãn PREMIUM', (t) async {
    await mo(t, basic: false);
    expect(find.text('Tạo nhà'), findsOneWidget);
    expect(find.text('PREMIUM'), findsNothing);
  });

  testWidgets('Premium tạm ngừng: không mời mua (không nhãn PREMIUM)', (t) async {
    dat360(t);
    bat = batThongBao();
    final repo = await repoNhaThu(HouseholdApiGia());
    await t.pumpWidget(bocTrangNha(NhaMinhPage(repo: repo), goi: goiPremium(const {'household': false})));
    await t.pumpAndSettle();
    expect(find.text('Tạo nhà'), findsOneWidget);
    expect(find.text('PREMIUM'), findsNothing);
  });

  testWidgets('vai Chủ: Mời + Quản lý, không Rời nhà; tên nhà, "Bạn là Chủ nhà · 2/6 thành viên"', (t) async {
    await mo(t, nha: nhaJson());
    expect(find.text('Nhà An – Bình'), findsOneWidget);
    expect(find.text('Bạn là Chủ nhà · 2/6 thành viên'), findsOneWidget);
    expect(find.text('Mời thành viên'), findsOneWidget);
    expect(find.text('Quản lý thành viên'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mời thành viên')).onPressed, isNotNull);
    expect(find.text('Rời nhà'), findsNothing);
  });

  testWidgets('vai Thành viên: Rời nhà, không Mời / Quản lý; rời xong về trạng thái chưa có nhà', (t) async {
    final api = await mo(t, nha: nhaJson(myRole: 'Member'));
    expect(find.text('Mời thành viên'), findsNothing);
    expect(find.text('Quản lý thành viên'), findsNothing);
    await t.ensureVisible(find.text('Rời nhà'));
    await t.tap(find.text('Rời nhà'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Rời nhà'));
    await t.pumpAndSettle();
    expect(api.goi, contains('roiNha'));
    expect(find.text('Bạn chưa ở nhà nào'), findsOneWidget);
  });

  Future<(HouseholdApiGia, _DuLieuGia)> moCoHang(WidgetTester t, {int? phien = 18, int con = 3}) async {
    dat360(t);
    bat = batThongBao();
    final api = HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Member');
    final repo = NhaRepositoryImpl(api: api, kho: InMemoryNhaStore(), demHangChuaDay: (_) async => con);
    addTearDown(repo.dispose);
    await repo.datTaiKhoan(18);
    await repo.lamMoi();
    final duLieu = _DuLieuGia(const HangChuaDayNha(khoan: 1, gop: 1, rut: 0));
    await t.pumpWidget(bocTrangNha(NhaMinhPage(repo: repo, duLieu: duLieu), goi: goiBasic(const {}), idaccount: phien));
    await t.pumpAndSettle();
    return (api, duLieu);
  }

  testWidgets('Rời nhà còn hàng chưa đẩy: hộp nêu hàng, Ở lại thì ở nhà; idaccount từ phiên', (t) async {
    final (api, duLieu) = await moCoHang(t);
    await t.ensureVisible(find.text('Rời nhà'));
    await t.tap(find.text('Rời nhà'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Rời nhà'));
    await t.pumpAndSettle();
    expect(find.text('Còn thay đổi chưa đồng bộ'), findsOneWidget);
    expect(find.text('1 khoản của nhà'), findsOneWidget);
    expect(find.text('1 khoản góp'), findsOneWidget);
    expect(duLieu.goi, [(12, 18)]);
    expect(bat.ds, isEmpty, reason: 'không được toast câu chung trước khi hỏi');
    await t.tap(find.text('Ở lại'));
    await t.pumpAndSettle();
    expect(api.goi, isNot(contains('roiNha')));
    expect(find.text('Nhà An – Bình'), findsOneWidget, reason: 'vẫn ở nhà');
  });

  testWidgets('Vẫn rời nhà: gọi API một lần rồi về trạng thái chưa có nhà', (t) async {
    final (api, _) = await moCoHang(t);
    await t.ensureVisible(find.text('Rời nhà'));
    await t.tap(find.text('Rời nhà'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Rời nhà'));
    await t.pumpAndSettle();
    api.cuaToiJson = const {'household': null, 'myRole': null, 'members': [], 'formerMembers': []};
    await t.tap(find.widgetWithText(FilledButton, 'Vẫn rời nhà'));
    await t.pumpAndSettle();
    expect(api.goi.where((g) => g == 'roiNha'), hasLength(1));
    expect(find.text('Bạn chưa ở nhà nào'), findsOneWidget);
  });

  testWidgets('không có phiên: idaccount gửi xuống là null, không phải giá trị mặc định', (t) async {
    final (_, duLieu) = await moCoHang(t, phien: null);
    await t.ensureVisible(find.text('Rời nhà'));
    await t.tap(find.text('Rời nhà'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Rời nhà'));
    await t.pumpAndSettle();
    expect(duLieu.goi, [(12, null)], reason: 'quy tắc 2: idaccount chỉ từ phiên, không `?? 1`');
  });

  testWidgets('nhà chỉ xem: dải vàng; Chủ thấy Mời khoá, Quản lý vẫn mở', (t) async {
    await mo(t, nha: nhaJson(status: 'ReadOnly'));
    expect(find.text('Nhà đang ở chế độ chỉ xem — chủ nhà cần gia hạn Premium'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mời thành viên')).onPressed, isNull);
    expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Quản lý thành viên')).onPressed, isNotNull);
    expect(find.text('Chỉ xem'), findsNothing, reason: 'spec 12.2: dải đã nói, không nhãn thứ hai');
  });

  testWidgets('chấm trạng thái bên phải thẻ nhà: xanh khi Active', (t) async {
    Color mau() =>
        ((t.widget<Container>(find.byKey(const Key('cham-trang-thai-nha')))).decoration! as BoxDecoration).color!;
    await mo(t, nha: nhaJson());
    expect(find.byKey(const Key('cham-trang-thai-nha')), findsOneWidget);
    expect(mau(), AppColors.income);
    expect(t.getRect(find.byKey(const Key('cham-trang-thai-nha'))).center.dx, greaterThan(300),
        reason: 'chấm nằm bên PHẢI thẻ');
  });

  testWidgets('chấm trạng thái: vàng khi nhà chỉ xem', (t) async {
    await mo(t, nha: nhaJson(status: 'ReadOnly'));
    final d = t.widget<Container>(find.byKey(const Key('cham-trang-thai-nha'))).decoration! as BoxDecoration;
    expect(d.color, AppColors.warning);
  });

  testWidgets('danh sách thành viên: Chủ nhà đứng đầu, còn lại giữ thứ tự server', (t) async {
    await mo(t, nha: nhaJson(members: [
      {'idaccount': 25, 'displayName': 'Nguyễn Bình', 'role': 'Member', 'joinedAt': '2026-10-23T09:12:00.000Z'},
      {'idaccount': 31, 'displayName': 'Lê Chi', 'role': 'Viewer', 'joinedAt': '2026-10-23T09:30:00.000Z'},
      {'idaccount': 18, 'displayName': 'Trần An', 'role': 'Owner', 'joinedAt': '2026-10-23T08:00:00.000Z'},
    ]));
    double y(String s) => t.getTopLeft(find.text(s)).dy;
    expect(y('Trần An'), lessThan(y('Nguyễn Bình')), reason: 'Chủ nhà đứng đầu dù server trả ở cuối');
    expect(y('Nguyễn Bình'), lessThan(y('Lê Chi')), reason: 'hai người còn lại giữ thứ tự server');
  });

  testWidgets('tên thành viên dài: nhãn "Bạn" không bị cắt, chỉ tên cắt, không tràn', (t) async {
    await mo(t, nha: nhaJson(members: [
      {'idaccount': 18, 'displayName': 'Trần Quang Đạt ${'rất dài ' * 10}', 'role': 'Owner', 'joinedAt': '2026-10-23T08:00:00.000Z'},
    ]));
    expect(find.text('Bạn'), findsOneWidget);
    expect(t.takeException(), isNull);
    final nhan = t.getRect(find.text('Bạn'));
    expect(nhan.right, lessThanOrEqualTo(360), reason: 'chữ quan trọng nhất của dòng không được rơi khỏi màn');
  });

  testWidgets('thẻ lời mời khi chưa có nhà: Chấp nhận mở; chấp nhận xong gọi API', (t) async {
    final api = await mo(t, loiMoi: [_loiMoiJson()]);
    expect(find.text('LỜI MỜI ĐANG CHỜ'), findsOneWidget);
    expect(find.text('Nhà Minh Anh'), findsOneWidget);
    expect(find.text('Minh Anh mời bạn với vai Thành viên'), findsOneWidget);
    // Stitch `nha_thanh_vien`: chấm cam, đồng hồ cạnh hạn; chưa khoá thì KHÔNG ổ khoá và KHÔNG câu lý do.
    expect(find.byKey(const Key('cham-loi-moi')), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byKey(const Key('ly-do-khoa-chap-nhan')), findsNothing);
    api.traVe = nhaJson();
    api.dsLoiMoiToiJson = const []; // server: lời mời vừa nhận không còn trong danh sách (01 mục 2.8)
    await t.tap(find.widgetWithText(FilledButton, 'Chấp nhận'));
    await t.pumpAndSettle();
    expect(api.goi, contains('chapNhanLoiMoi:WXYZ6789'));
    expect(find.text('Nhà An – Bình'), findsOneWidget, reason: 'chấp nhận xong màn phải SANG trạng thái có nhà');
    expect(find.text('LỜI MỜI ĐANG CHỜ'), findsNothing, reason: 'và thẻ lời mời vừa nhận biến mất');
  });

  // Realme 360 dp bắt 2026-11-01: ổ khoá + đệm nút làm chữ thành "Chấp nh…"; `takeException` mù vì ellipsis không sọc vàng.
  for (final co in [1.0, 1.3, 1.5]) {
    testWidgets('360 dp, cỡ chữ $co: chữ Chấp nhận trên nút khoá không bị cụt', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = co;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await mo(t, nha: nhaJson(myRole: 'Member'), loiMoi: [_loiMoiJson()]);
      final chu = find.descendant(of: find.byType(FilledButton), matching: find.text('Chấp nhận'));
      expect(chu, findsOneWidget);
      final rp = t.renderObject<RenderParagraph>(chu);
      expect(rp.didExceedMaxLines, isFalse, reason: 'chữ bị cắt thành dấu ba chấm');
      expect(rp.size.width, greaterThanOrEqualTo(rp.getMaxIntrinsicWidth(double.infinity) - 0.5),
          reason: 'hộp chữ hẹp hơn chữ thật');
      final nut = t.getRect(find.widgetWithText(FilledButton, 'Chấp nhận'));
      final hop = t.getRect(chu);
      expect(hop.right, lessThanOrEqualTo(nut.right), reason: 'chữ lọt khỏi nút');
    });
  }

  testWidgets('đang ở nhà: Chấp nhận khoá kèm câu, Từ chối vẫn bấm được', (t) async {
    final api = await mo(t, nha: nhaJson(myRole: 'Member'), loiMoi: [_loiMoiJson()]);
    await t.ensureVisible(find.text('Rời nhà hiện tại trước'));
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chấp nhận')).onPressed, isNull);
    expect(find.descendant(of: find.widgetWithText(FilledButton, 'Chấp nhận'), matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
        reason: 'Stitch `nha_thanh_vien`: Chấp nhận khoá mang ổ khoá');
    final nut = t.getRect(find.widgetWithText(FilledButton, 'Chấp nhận'));
    final lyDo = t.getRect(find.byKey(const Key('ly-do-khoa-chap-nhan')));
    expect(lyDo.top, greaterThanOrEqualTo(nut.bottom), reason: 'câu lý do nằm DƯỚI nút');
    expect(lyDo.left, greaterThanOrEqualTo(nut.left - 1), reason: 'và căn theo nút Chấp nhận (nửa phải), không lệch trái');
    await t.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
    await t.pumpAndSettle();
    expect(api.goi, contains('tuChoiLoiMoi:WXYZ6789'));
  });

  testWidgets('Chủ nhà đang ở nhà: thẻ lời mời chỉ đường chuyển chủ / giải tán, không bảo "rời"', (t) async {
    await mo(t, nha: nhaJson(myRole: 'Owner'), loiMoi: [_loiMoiJson()]);
    await t.ensureVisible(find.text('Chuyển quyền chủ nhà hoặc giải tán trước.'));
    expect(find.text('Rời nhà hiện tại trước'), findsNothing, reason: 'Chủ không rời được; câu chung chỉ sai đường');
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chấp nhận')).onPressed, isNull);
  });

  testWidgets('admin tắt quyền tham gia: Chấp nhận khoá, câu trung tính, không chữ Premium', (t) async {
    dat360(t);
    bat = batThongBao();
    final api = HouseholdApiGia()..dsLoiMoiToiJson = [_loiMoiJson()];
    final repo = await repoNhaThu(api);
    await t.pumpWidget(bocTrangNha(NhaMinhPage(repo: repo), goi: goiBasic(const {'household_join': false})));
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chấp nhận')).onPressed, isNull);
    expect(find.text('Tính năng gia đình hiện không dùng được với tài khoản này.'), findsOneWidget);
  });

  testWidgets('admin tắt quyền tham gia khi đang ở nhà: câu trung tính, không bảo rời nhà', (t) async {
    dat360(t);
    bat = batThongBao();
    final api = HouseholdApiGia()
      ..cuaToiJson = nhaJson(myRole: 'Member')
      ..dsLoiMoiToiJson = [_loiMoiJson()];
    final repo = await repoNhaThu(api);
    await t.pumpWidget(bocTrangNha(NhaMinhPage(repo: repo), goi: goiBasic(const {'household_join': false})));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text(cauLoiNha(LoaiLoiNha.tinhNangKhongMo)));
    expect(find.text('Tính năng gia đình hiện không dùng được với tài khoản này.'), findsOneWidget);
    expect(find.text('Rời nhà hiện tại trước'), findsNothing, reason: 'rời nhà không mở được khoá, chỉ mất dữ liệu nhà');
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chấp nhận')).onPressed, isNull);
  });

  testWidgets('Từ chối lỗi: câu lỗi của cauLoiNha đi qua kênh báo nhanh', (t) async {
    final api = await mo(t, loiMoi: [_loiMoiJson()]);
    api.loi = const LoiNha(LoaiLoiNha.maHetHan);
    await t.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
    await t.pumpAndSettle();
    expect(bat.cuoi?.cau, cauLoiNha(LoaiLoiNha.maHetHan));
  });

  // Spec 12.8: mỗi trạng thái ở 360 dp CÓ bàn phím hệ thống — ba ca riêng (trước đây tên nói ba, thân chỉ dựng một).
  testWidgets('chưa có nhà (kèm lời mời) ở 360 dp có bàn phím mở: không tràn', (t) async {
    await mo(t, loiMoi: [_loiMoiJson()], banPhim: true);
    expect(find.text('LỜI MỜI ĐANG CHỜ'), findsOneWidget, reason: 'ca phải dựng đúng trạng thái đang nói');
    expect(t.takeException(), isNull);
  });

  testWidgets('Chủ nhà (kèm lời mời) ở 360 dp có bàn phím mở: không tràn', (t) async {
    await mo(t, nha: nhaJson(myRole: 'Owner'), loiMoi: [_loiMoiJson()], banPhim: true);
    expect(find.text('Mời thành viên'), findsOneWidget, reason: 'ca phải dựng đúng vai Chủ');
    expect(t.takeException(), isNull);
  });

  testWidgets('nhà chỉ xem + Thành viên (kèm lời mời) ở 360 dp có bàn phím mở: không tràn', (t) async {
    await mo(t, nha: nhaJson(status: 'ReadOnly', myRole: 'Member'), loiMoi: [_loiMoiJson()], banPhim: true);
    expect(find.textContaining('chế độ chỉ xem'), findsOneWidget, reason: 'ca phải dựng đúng trạng thái chỉ xem');
    expect(t.takeException(), isNull);
  });
}
