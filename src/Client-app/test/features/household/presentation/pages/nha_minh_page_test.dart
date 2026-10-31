import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/presentation/pages/nha_minh_page.dart';
import 'package:flutter/material.dart';
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

  testWidgets('nhà chỉ xem: dải vàng; Chủ thấy Mời khoá, Quản lý vẫn mở', (t) async {
    await mo(t, nha: nhaJson(status: 'ReadOnly'));
    expect(find.text('Nhà đang ở chế độ chỉ xem — chủ nhà cần gia hạn Premium'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mời thành viên')).onPressed, isNull);
    expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Quản lý thành viên')).onPressed, isNotNull);
    expect(find.text('Chỉ xem'), findsNothing, reason: 'spec 12.2: dải đã nói, không nhãn thứ hai');
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
    api.traVe = nhaJson();
    await t.tap(find.widgetWithText(FilledButton, 'Chấp nhận'));
    await t.pumpAndSettle();
    expect(api.goi, contains('chapNhanLoiMoi:WXYZ6789'));
  });

  testWidgets('đang ở nhà: Chấp nhận khoá kèm câu, Từ chối vẫn bấm được', (t) async {
    final api = await mo(t, nha: nhaJson(myRole: 'Member'), loiMoi: [_loiMoiJson()]);
    await t.ensureVisible(find.text('Rời nhà hiện tại trước'));
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chấp nhận')).onPressed, isNull);
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

  testWidgets('ba trạng thái ở 360 dp có bàn phím mở: không tràn', (t) async {
    await mo(t, nha: nhaJson(status: 'ReadOnly', myRole: 'Member'), loiMoi: [_loiMoiJson()], banPhim: true);
    expect(t.takeException(), isNull);
  });
}
