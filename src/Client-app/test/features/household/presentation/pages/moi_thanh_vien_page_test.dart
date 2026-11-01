import 'dart:async';

import 'package:flowmoney/features/household/data/datasources/chia_se_chu.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/presentation/pages/moi_thanh_vien_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

class _ChiaSeGia implements ChiaSeChu {
  final da = <String>[];
  Object? loi;
  @override
  Future<void> chiaSe(String chu) async {
    final l = loi;
    if (l != null) throw l;
    da.add(chu);
  }
}

void main() {
  setUpAll(napFontThat);

  late NhaRepository repoCuoi;

  Future<(HouseholdApiGia, _ChiaSeGia, BatThongBao)> mo(WidgetTester t,
      {Map<String, Object?>? nha, bool banPhim = false, List<Map<String, Object?>> ds = const []}) async {
    dat360(t, banPhim: banPhim);
    final bat = batThongBao();
    final api = HouseholdApiGia()
      ..cuaToiJson = nha ?? nhaJson()
      ..dsMaMoiJson = ds;
    final chiaSe = _ChiaSeGia();
    final repo = await repoNhaThu(api);
    repoCuoi = repo;
    await t.pumpWidget(bocTrangNha(MoiThanhVienPage(repo: repo, chiaSe: chiaSe)));
    await t.pumpAndSettle();
    return (api, chiaSe, bat);
  }

  testWidgets('hai khối, một nhãn Vai; không chữ Stitch tự thêm', (t) async {
    await mo(t);
    expect(find.text('Mời qua email'), findsOneWidget);
    expect(find.text('Mã mời'), findsOneWidget);
    expect(find.text('Vai'), findsNWidgets(2));
    expect(find.text('Vai trò trong nhà'), findsNothing);
    expect(find.text('Cấp quyền khi nhập mã'), findsNothing);
  });

  testWidgets('email sai dạng: nút khoá; gửi xong dòng đã gửi, chung một câu', (t) async {
    final (api, _, _) = await mo(t);
    FilledButton nut() => t.widget(find.ancestor(of: find.text('Gửi lời mời'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    await t.enterText(find.byType(TextField).first, 'an@');
    await t.pump();
    expect(nut().onPressed, isNull);
    await t.enterText(find.byType(TextField).first, 'an@gmail.com');
    await t.pump();
    expect(nut().onPressed, isNotNull, reason: 'email đúng dạng và nhà còn chỗ thì nút phải mở');
    await t.tap(find.text('Gửi lời mời'));
    await t.pumpAndSettle();
    expect(api.goi, contains('moiQuaEmail:an@gmail.com:Member'));
    expect(find.text('Đã gửi lời mời tới an@gmail.com'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('da-gui-loi-moi')), matching: find.byIcon(Icons.check_circle_outline)),
        findsOneWidget,
        reason: 'Stitch `moi`: ô xanh có dấu ✓');
    expect(find.byIcon(Icons.mail_outline), findsWidgets, reason: 'tiêu đề khối Mời qua email có icon thư');
    expect(find.byIcon(Icons.vpn_key_outlined), findsOneWidget, reason: 'tiêu đề khối Mã mời có icon chìa');
  });

  testWidgets('nút Gửi khoá suốt lúc chờ mạng (không gửi hai lần)', (t) async {
    final (api, _, _) = await mo(t);
    await t.enterText(find.byType(TextField).first, 'an@gmail.com');
    await t.pump();
    api.treo = Completer<void>();
    await t.tap(find.text('Gửi lời mời'));
    await t.pump();
    final nut = t.widget<FilledButton>(find.ancestor(of: find.text('Gửi lời mời'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(nut.onPressed, isNull, reason: 'trang phải nghe dangGuiEmail, không đọc state một lần');
    api.treo!.complete();
    await t.pumpAndSettle();
  });

  testWidgets('tạo mã vai Chỉ xem: hiện mã; Chia sẻ soạn sẵn câu có mã', (t) async {
    final (api, chiaSe, _) = await mo(t);
    await t.ensureVisible(find.text('Tạo mã'));
    await t.tap(find.descendant(of: find.byKey(const Key('vai-ma')), matching: find.text('Chỉ xem')));
    await t.pump();
    await t.tap(find.text('Tạo mã'));
    await t.pumpAndSettle();
    expect(api.goi, contains('taoMaMoi:Viewer'));
    expect(find.text('ABCD2345'), findsWidgets);
    await t.ensureVisible(find.text('Chia sẻ'));
    await t.tap(find.text('Chia sẻ'));
    await t.pump();
    expect(chiaSe.da.single, contains('ABCD2345'));
    expect(chiaSe.da.single, contains('Nhà An – Bình'));
    expect(find.descendant(of: find.byKey(const Key('khoi-ma-vua-tao')), matching: find.text('ABCD2345')), findsOneWidget,
        reason: 'Stitch `moi`: mã + hạn + hai nút nằm trong ô xám');
    expect(find.descendant(of: find.byKey(const Key('khoi-ma-vua-tao')), matching: find.text('Chép mã')), findsOneWidget);
  });

  testWidgets('M6: mã vừa tạo đã quá hạn thì khối mã và nút Chia sẻ không còn hiện', (t) async {
    final (api, _, _) = await mo(t);
    api.maMoiJson = const {'code': 'ABCD2345', 'role': 'Member', 'expiresAt': '2020-01-01T00:00:00.000Z'};
    await t.ensureVisible(find.text('Tạo mã'));
    await t.tap(find.text('Tạo mã'));
    await t.pumpAndSettle();
    expect(api.goi, contains('taoMaMoi:Member'));
    expect(find.text('ABCD2345'), findsNothing, reason: 'mã chết mà còn nút Chia sẻ là gửi người ta một mã không dùng được');
    expect(find.text('Chia sẻ'), findsNothing);
  });

  testWidgets('lỗi tạo mã: kênh báo đúng câu', (t) async {
    final (api, _, bat) = await mo(t);
    api.loi = loiServer(500, 'HOUSEHOLD_ERROR');
    await t.ensureVisible(find.text('Tạo mã'));
    await t.tap(find.text('Tạo mã'));
    await t.pumpAndSettle();
    expect(bat.cuoi!.cau, cauLoiNha(LoaiLoiNha.mayChu));
  });

  testWidgets('nhà đủ (gồm cả lời mời còn hiệu lực): hai nút khoá kèm câu lý do', (t) async {
    await mo(t,
        nha: nhaJson(maxMembers: 3),
        ds: [
          {'code': 'AAAA2222', 'role': 'Member', 'email': null, 'expiresAt': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(), 'status': 'Pending'},
        ]);
    expect(find.text('Nhà đã đủ người, kể cả lời mời còn hiệu lực.'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'an@gmail.com');
    await t.pump();
    expect(t.widget<FilledButton>(find.ancestor(of: find.text('Gửi lời mời'), matching: find.byWidgetPredicate((w) => w is FilledButton))).onPressed, isNull);
    expect(t.widget<OutlinedButton>(find.ancestor(of: find.text('Tạo mã'), matching: find.byWidgetPredicate((w) => w is OutlinedButton))).onPressed, isNull);
  });

  testWidgets('vai Thành viên lọt vào màn Mời: nút khoá, nói "chỉ chủ nhà", không nói "chỉ xem"', (t) async {
    await mo(t, nha: nhaJson(myRole: 'Member'));
    expect(find.text('Chỉ chủ nhà làm được việc này.'), findsOneWidget);
    expect(find.textContaining('chế độ chỉ xem'), findsNothing);
    expect(t.widget<OutlinedButton>(find.ancestor(of: find.text('Tạo mã'), matching: find.byWidgetPredicate((w) => w is OutlinedButton))).onPressed, isNull);
  });

  testWidgets('Chủ nhà, nhà chỉ xem: câu chỉ xem, nút khoá', (t) async {
    await mo(t, nha: nhaJson(status: 'ReadOnly'));
    expect(find.text('Nhà đang ở chế độ chỉ xem — chủ nhà cần gia hạn Premium.'), findsOneWidget);
    expect(find.text('Chỉ chủ nhà làm được việc này.'), findsNothing);
    expect(t.widget<OutlinedButton>(find.ancestor(of: find.text('Tạo mã'), matching: find.byWidgetPredicate((w) => w is OutlinedButton))).onPressed, isNull);
  });

  testWidgets('danh sách: dòng còn hiệu lực có Huỷ, dòng đã từ chối có nhãn, không nút', (t) async {
    final han = DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
    final (api, _, _) = await mo(t, ds: [
      {'code': 'AAAA2222', 'role': 'Member', 'email': 'an@x.vn', 'expiresAt': han, 'status': 'Pending'},
      {'code': 'BBBB3333', 'role': 'Viewer', 'email': 'binh@x.vn', 'expiresAt': han, 'status': 'Declined'},
    ]);
    await t.ensureVisible(find.text('binh@x.vn'));
    expect(find.text('Huỷ'), findsOneWidget);
    expect(find.text('Đã từ chối'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('chip-trang-thai-BBBB3333')), matching: find.text('Đã từ chối')), findsOneWidget,
        reason: 'trạng thái đã kết thúc là chip xám (Stitch `moi`), không phải chữ trơn');
    expect(find.byKey(const Key('chip-trang-thai-AAAA2222')), findsNothing, reason: 'dòng còn hiệu lực có nút Huỷ, không chip');
    expect(find.text('Email · Chỉ xem · Đã từ chối'), findsOneWidget, reason: 'Stitch: dòng phụ luôn kèm trạng thái, chip giữ như mockup');
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
    expect(api.goi, contains('huyMaMoi:AAAA2222'));
  });

  testWidgets('360 dp, bàn phím mở: không tràn', (t) async {
    await mo(t, banPhim: true);
    expect(t.takeException(), isNull);
  });

  testWidgets('lời mời email còn hiệu lực có nhãn Đang chờ ở dòng phụ', (t) async {
    final han = DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
    await mo(t, ds: [
      {'code': 'AAAA2222', 'role': 'Member', 'email': 'an@x.vn', 'expiresAt': han, 'status': 'Pending'},
    ]);
    await t.ensureVisible(find.text('an@x.vn'));
    expect(find.text('Email · Thành viên · Đang chờ'), findsOneWidget);
  });

  testWidgets('nhà đổi từ máy khác: người được mời nhận mã thì danh sách nạp lại, hết câu "đã đủ người"', (t) async {
    final han = DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
    final (api, _, _) = await mo(t, nha: nhaJson(maxMembers: 3), ds: [
      {'code': 'AAAA2222', 'role': 'Member', 'email': null, 'expiresAt': han, 'status': 'Pending'},
    ]);
    expect(find.text('Nhà đã đủ người, kể cả lời mời còn hiệu lực.'), findsOneWidget);
    api
      ..dsMaMoiJson = const []
      ..cuaToiJson = nhaJson(maxMembers: 3);
    await repoCuoi.lamMoi();
    await t.pumpAndSettle();
    expect(find.text('Nhà đã đủ người, kể cả lời mời còn hiệu lực.'), findsNothing);
  });

  testWidgets('đã không còn là Chủ: nhà đổi không kéo thêm danh sách lời mời', (t) async {
    final (api, _, _) = await mo(t, nha: nhaJson(myRole: 'Member'));
    final truoc = api.goi.where((g) => g == 'dsMaMoi').length;
    api.cuaToiJson = nhaJson(myRole: 'Member', maxMembers: 5);
    await repoCuoi.lamMoi();
    await t.pumpAndSettle();
    expect(api.goi.where((g) => g == 'dsMaMoi').length, truoc, reason: '403 → lamMoi → nạp lại là vòng lặp');
  });

  testWidgets('Chia sẻ lỗi: có toast lỗi', (t) async {
    final (_, chiaSe, bat) = await mo(t);
    await t.ensureVisible(find.text('Tạo mã'));
    await t.tap(find.text('Tạo mã'));
    await t.pumpAndSettle();
    chiaSe.loi = StateError('x');
    await t.ensureVisible(find.text('Chia sẻ'));
    await t.tap(find.text('Chia sẻ'));
    await t.pumpAndSettle();
    expect(bat.cuoi!.cau, cauLoiNha(LoaiLoiNha.khac));
  });

  testWidgets('Chép mã: ghi được thì báo đã chép; clipboard hỏng thì báo lỗi, không nói đã chép', (t) async {
    final (_, _, bat) = await mo(t);
    var hong = false;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData' && hong) throw PlatformException(code: 'x');
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await t.ensureVisible(find.text('Tạo mã'));
    await t.tap(find.text('Tạo mã'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Chép mã'));
    await t.tap(find.text('Chép mã'));
    await t.pumpAndSettle();
    expect(bat.cuoi!.cau, 'Đã chép mã mời');
    hong = true;
    await t.tap(find.text('Chép mã'));
    await t.pumpAndSettle();
    expect(bat.cuoi!.cau, cauLoiNha(LoaiLoiNha.khac));
  });

  testWidgets('Huỷ: nút của đúng dòng khoá tới hết lượt nạp lại, chỉ một DELETE', (t) async {
    final han = DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
    final (api, _, _) = await mo(t, ds: [
      {'code': 'AAAA2222', 'role': 'Member', 'email': 'an@x.vn', 'expiresAt': han, 'status': 'Pending'},
    ]);
    api.treoDsMaMoi = Completer<void>();
    await t.ensureVisible(find.text('Huỷ'));
    await t.tap(find.text('Huỷ'));
    await t.pump();
    await t.pump();
    final nut = t.widget<TextButton>(find.ancestor(of: find.text('Huỷ'), matching: find.byType(TextButton)));
    expect(nut.onPressed, isNull, reason: 'nút còn mở suốt vòng GET là chạm hai gửi DELETE thứ hai');
    api.treoDsMaMoi!.complete();
    await t.pumpAndSettle();
    expect(api.goi.where((g) => g == 'huyMaMoi:AAAA2222'), hasLength(1));
  });
}
