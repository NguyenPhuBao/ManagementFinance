import 'dart:async';

import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/domain/hang_chua_day.dart';
import 'package:flowmoney/features/household/presentation/pages/quan_ly_thanh_vien_page.dart';
import 'package:flowmoney/features/household/presentation/widgets/avatar_chu_cai.dart';
import 'package:flowmoney/features/household/presentation/widgets/khung_the_nha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

/// Treo / ném RIÊNG `chuyenChu` (api giả chung treo cả `cuaToi`, nên không dựng được "máy khác báo mất vai trong lúc POST bay").
class _ApiChuyenChuTreo extends HouseholdApiGia {
  Completer<void>? treoChuyen;
  Completer<void>? treoMe;
  Object? loiChuyen;

  /// Số lượt `await` thêm trước khi ném lỗi của `chuyenChu` (dịch độ lệch microtask so với `/me`).
  int hopLoi = 0;

  @override
  Future<Map<String, Object?>> chuyenChu(int idaccount) async {
    goi.add('chuyenChu:$idaccount');
    await treoChuyen?.future;
    for (var i = 0; i < hopLoi; i++) {
      await Future<void>.value();
    }
    final l = loiChuyen;
    if (l != null) throw l;
    return traVe ?? cuaToiJson;
  }

  @override
  Future<Map<String, Object?>> cuaToi() async {
    goi.add('cuaToi');
    await treoMe?.future;
    return cuaToiJson;
  }
}

/// Chỉ `hangChuaDay` được dùng; ghi lại (idNha, idaccount) để ca canh nguồn của hai tham số.
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

  late NhaRepository repoDaMo;

  Future<(HouseholdApiGia, BatThongBao)> mo(WidgetTester t,
      {Map<String, Object?>? nha, bool banPhim = false, HouseholdApiGia? apiDung}) async {
    dat360(t, banPhim: banPhim);
    final bat = batThongBao();
    final api = (apiDung ?? HouseholdApiGia())..cuaToiJson = nha ?? nhaJson();
    final repo = await repoNhaThu(api);
    repoDaMo = repo;
    final r = routerThu(QuanLyThanhVienPage(repo: repo));
    await t.pumpWidget(bocRouterNha(r));
    r.push('/dich');
    await t.pumpAndSettle();
    return (api, bat);
  }

  testWidgets('dòng của mình không có nút; người khác có hai vai, Chuyển chủ, Mời ra; không email / hạn mức / ⋮', (t) async {
    await mo(t);
    expect(find.text('2/6 thành viên'), findsOneWidget);
    expect(find.text('Bạn'), findsOneWidget);
    expect(find.text('Chuyển chủ nhà'), findsOneWidget);
    expect(find.text('Mời ra'), findsOneWidget);
    expect(find.text('Vào nhà 23/10/2026'), findsNWidgets(2), reason: 'dòng phụ = ngày vào nhà, cả dòng của mình (spec 12.2)');
    expect(find.textContaining('@'), findsNothing, reason: 'server không trả email thành viên');
    expect(find.textContaining('HẠN MỨC'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('M4 theo Stitch quan_ly_tv: chip vai viên thuốc, nút Giải tán chữ nhật bo góc, avatar pastel theo idaccount', (t) async {
    await mo(t);
    final chip = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chỉ xem'));
    expect(chip.shape, isA<StadiumBorder>());
    await t.ensureVisible(find.text('Giải tán nhà'));
    final nut = t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Giải tán nhà'));
    final shape = nut.style!.shape!.resolve(<WidgetState>{});
    expect(shape, isA<RoundedRectangleBorder>());
    expect(shape, isNot(isA<StadiumBorder>()));
    final nen = [
      for (final a in t.widgetList<AvatarChuCai>(find.byType(AvatarChuCai)))
        ((t.widget<Container>(find.descendant(of: find.byWidget(a), matching: find.byType(Container)))).decoration! as BoxDecoration)
            .color
    ];
    expect(nen, [mauAvatarTheoId(18).nen, mauAvatarTheoId(25).nen]);
  });

  testWidgets('đổi vai: gọi API đúng vai, không hỏi xác nhận', (t) async {
    final (api, _) = await mo(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Chỉ xem'));
    await t.pumpAndSettle();
    expect(api.goi, contains('doiVai:25:Viewer'));
  });

  testWidgets('mời ra: hỏi rồi mới gọi; Huỷ thì không gọi', (t) async {
    final (api, _) = await mo(t);
    await t.tap(find.text('Mời ra'));
    await t.pumpAndSettle();
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
    expect(api.goi.where((g) => g.startsWith('moiRa')), isEmpty);
    await t.tap(find.text('Mời ra'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Mời ra'));
    await t.pumpAndSettle();
    expect(api.goi, contains('moiRa:25'));
  });

  testWidgets('chuyển chủ: xong về trang trước đúng MỘT lần, không báo mất vai', (t) async {
    final (api, bat) = await mo(t);
    await t.tap(find.text('Chuyển chủ nhà'));
    await t.pumpAndSettle();
    api.traVe = nhaJson(myRole: 'Member');
    await t.tap(find.widgetWithText(FilledButton, 'Chuyển chủ nhà'));
    await t.pumpAndSettle();
    expect(api.goi, contains('chuyenChu:25'));
    expect(find.text('GOC'), findsOneWidget, reason: 'pop hai lần là văng khỏi stack');
    expect(bat.cau, isEmpty, reason: 'chính mình chuyển: câu "không còn là chủ nhà" là thừa');
  });

  testWidgets('giải tán hai bước: xong về trang trước; 500 thì ở lại, báo, nhà giữ nguyên', (t) async {
    final (api, bat) = await mo(t);
    Future<void> motLuot() async {
      await t.ensureVisible(find.text('Giải tán nhà'));
      await t.tap(find.text('Giải tán nhà'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Nhà An – Bình');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Giải tán nhà'));
      await t.pumpAndSettle();
    }

    api.loi = loiServer(500, 'HOUSEHOLD_ERROR');
    await motLuot();
    expect(bat.cau, ['Máy chủ chưa phản hồi. Thử lại sau.']);
    expect(find.text('GOC'), findsNothing);

    api.loi = null;
    api.cuaToiJson = const {'household': null};
    await motLuot();
    expect(api.goi, contains('giaiTan'));
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('giải tán còn hàng chưa đẩy: đi hai bước rồi mới tới hộp, nút ghi Vẫn giải tán; Ở lại không giải tán', (t) async {
    dat360(t);
    final bat = batThongBao();
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = NhaRepositoryImpl(api: api, kho: InMemoryNhaStore(), demHangChuaDay: (_) async => 2);
    addTearDown(repo.dispose);
    await repo.datTaiKhoan(18);
    await repo.lamMoi();
    final duLieu = _DuLieuGia(const HangChuaDayNha(khoan: 2));
    final r = routerThu(QuanLyThanhVienPage(repo: repo, duLieu: duLieu));
    await t.pumpWidget(bocRouterNha(r, idaccount: 18));
    r.push('/dich');
    await t.pumpAndSettle();
    Future<void> haiBuoc() async {
      await t.ensureVisible(find.text('Giải tán nhà'));
      await t.tap(find.text('Giải tán nhà'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Nhà An – Bình');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Giải tán nhà'));
      await t.pumpAndSettle();
    }

    await haiBuoc();
    expect(find.text('Còn thay đổi chưa đồng bộ'), findsOneWidget);
    expect(find.text('Những thay đổi này chưa lên máy chủ và sẽ mất nếu bạn giải tán nhà:'), findsOneWidget);
    expect(duLieu.goi, [(12, 18)], reason: 'đếm theo nhà đang ở và theo tài khoản của PHIÊN');
    await t.tap(find.text('Ở lại'));
    await t.pumpAndSettle();
    expect(api.goi, isNot(contains('giaiTan')), reason: 'Ở lại thì không giải tán');
    expect(find.text('GOC'), findsNothing, reason: 'vẫn ở màn Quản lý');
    expect(bat.ds, isEmpty);

    api.cuaToiJson = const {'household': null};
    await haiBuoc();
    await t.tap(find.widgetWithText(FilledButton, 'Vẫn giải tán'));
    await t.pumpAndSettle();
    expect(api.goi, contains('giaiTan'));
    expect(find.text('GOC'), findsOneWidget, reason: 'xong về trang trước đúng một lần');
  });

  testWidgets('đổi vai / mời ra / chuyển chủ lỗi 500: báo đúng câu, chuyển chủ ở lại màn', (t) async {
    final (api, bat) = await mo(t);
    api.loi = loiServer(500, 'HOUSEHOLD_ERROR');
    await t.tap(find.widgetWithText(ChoiceChip, 'Chỉ xem'));
    await t.pumpAndSettle();
    expect(bat.cuoi?.cau, 'Máy chủ chưa phản hồi. Thử lại sau.');
    bat.ds.clear();
    await t.tap(find.text('Mời ra'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Mời ra'));
    await t.pumpAndSettle();
    expect(bat.cuoi?.cau, 'Máy chủ chưa phản hồi. Thử lại sau.');
    bat.ds.clear();
    await t.tap(find.text('Chuyển chủ nhà'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Chuyển chủ nhà'));
    await t.pumpAndSettle();
    expect(bat.cuoi?.cau, 'Máy chủ chưa phản hồi. Thử lại sau.');
    expect(find.text('GOC'), findsNothing, reason: 'thất bại thì ở lại màn');
  });

  testWidgets('đang xử lý: nút khoá; xong: mở lại', (t) async {
    final (api, _) = await mo(t);
    expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Chuyển chủ nhà')).onPressed, isNotNull);
    expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Giải tán nhà')).onPressed, isNotNull);
    api.treo = Completer<void>();
    await t.tap(find.widgetWithText(ChoiceChip, 'Chỉ xem'));
    await t.pump();
    expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Chuyển chủ nhà')).onPressed, isNull);
    expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Giải tán nhà')).onPressed, isNull);
    // Nguyễn Bình đang là Thành viên: chip *Chỉ xem* là chip DUY NHẤT đổi vai được, nên lúc khoá nó phải đóng. Chip vai hiện
    // tại (*Thành viên*) chạm vào không làm gì và không bao giờ vào kiểu "vô hiệu" (xem ca *chạm chip vai hiện tại* dưới).
    expect(t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chỉ xem')).onSelected, isNull);
    api.treo!.complete();
    await t.pumpAndSettle();
    expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Chuyển chủ nhà')).onPressed, isNotNull);
    expect(t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chỉ xem')).onSelected, isNotNull);
  });

  testWidgets('chạm chip vai hiện tại: không gọi API', (t) async {
    final (api, _) = await mo(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Thành viên'));
    await t.pumpAndSettle();
    expect(api.goi.where((g) => g.startsWith('doiVai')), isEmpty);
  });

  testWidgets('chuyển chủ thất bại, sau đó máy khác làm mất vai: màn tự về kèm câu', (t) async {
    final (api, bat) = await mo(t);
    api.loi = loiServer(500, 'HOUSEHOLD_ERROR');
    await t.tap(find.text('Chuyển chủ nhà'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Chuyển chủ nhà'));
    await t.pumpAndSettle();
    expect(find.text('GOC'), findsNothing);
    bat.ds.clear();
    api.loi = null;
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repoDaMo.lamMoi();
    await t.pumpAndSettle();
    expect(find.text('GOC'), findsOneWidget, reason: 'cờ tự thao tác phải hạ sau thất bại, nếu không GacVaiChu im');
    expect(bat.cau, ['Bạn không còn là chủ nhà.']);
  });

  testWidgets('máy khác làm mất vai khi không thao tác gì: màn tự về kèm câu', (t) async {
    final (api, bat) = await mo(t);
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repoDaMo.lamMoi();
    await t.pumpAndSettle();
    expect(find.text('GOC'), findsOneWidget, reason: 'GacVaiChu phải gác ở mức trang');
    expect(bat.cau, ['Bạn không còn là chủ nhà.']);
  });

  testWidgets('mất vai TRONG LÚC chuyển chủ đang bay rồi bị từ chối: màn vẫn tự về, một lần, kèm câu', (t) async {
    final api = _ApiChuyenChuTreo();
    final (_, bat) = await mo(t, apiDung: api);
    api.treoChuyen = Completer<void>();
    await t.tap(find.text('Chuyển chủ nhà'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Chuyển chủ nhà'));
    await t.pump();
    // `household.changed` từ máy khác tới TRƯỚC phản hồi từ chối: `/me` nói mình đã mất vai.
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repoDaMo.lamMoi();
    await t.pump();
    expect(find.text('GOC'), findsNothing, reason: 'đang tự thao tác: GacVaiChu đứng yên');
    bat.ds.clear();
    api.loiChuyen = loiServer(403, 'FORBIDDEN_NOT_OWNER');
    api.treoChuyen!.complete();
    await t.pumpAndSettle();
    expect(find.text('GOC'), findsOneWidget, reason: 'cạnh mất vai bị nuốt lúc tự thao tác: nhánh thất bại phải xét lại');
    expect(find.text('Quản lý thành viên'), findsNothing);
    expect(bat.cau.where((c) => c == 'Bạn không còn là chủ nhà.'), hasLength(1));
  });

  // I1: quét độ lệch microtask giữa phản hồi lỗi của `chuyenChu` và `/me` báo mất vai. Ở một vài độ lệch (bản cũ: hopLoi = 4)
  // cạnh mất vai tới BlocListener TRƯỚC khi nhánh thất bại của `_lamRoiVe` chạy: hạ cờ `_tuThaoTac` trước phép xét là pop đôi.
  // Một con số đơn lẻ không canh được khe này, nên quét cả dải.
  for (var hop = 0; hop <= 8; hop++) {
    testWidgets('mất vai và bị từ chối lệch $hop lượt microtask: về trang trước đúng MỘT lần, một câu (I1)', (t) async {
      final api = _ApiChuyenChuTreo();
      final (_, bat) = await mo(t, apiDung: api);
      api.treoChuyen = Completer<void>();
      await t.tap(find.text('Chuyển chủ nhà'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Chuyển chủ nhà'));
      await t.pump();
      bat.ds.clear();
      api
        ..hopLoi = hop
        ..treoMe = Completer<void>()
        ..cuaToiJson = nhaJson(myRole: 'Member')
        ..loiChuyen = loiServer(403, 'FORBIDDEN_NOT_OWNER');
      final lamMoi = repoDaMo.lamMoi();
      await t.pump();
      api.treoChuyen!.complete();
      api.treoMe!.complete();
      await t.pumpAndSettle();
      await lamMoi;
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('GOC'), findsOneWidget, reason: 'pop hai lần là văng khỏi trang gốc (hoặc go thay cả stack)');
      expect(find.text('Quản lý thành viên'), findsNothing);
      expect(bat.cau.where((c) => c == 'Bạn không còn là chủ nhà.'), hasLength(1), reason: 'hop=$hop');
    });
  }

  testWidgets('bàn phím hệ thống mở, 360 dp: không tràn', (t) async {
    await mo(t, banPhim: true);
    expect(t.takeException(), isNull);
  });

  testWidgets('nhà chỉ xem: vẫn đổi vai / chuyển chủ / giải tán được (spec 12.3)', (t) async {
    final (api, _) = await mo(t, nha: nhaJson(status: 'ReadOnly'));
    expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Chuyển chủ nhà')).onPressed, isNotNull);
    expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Giải tán nhà')).onPressed, isNotNull);
    await t.tap(find.widgetWithText(ChoiceChip, 'Chỉ xem'));
    await t.pumpAndSettle();
    expect(api.goi, contains('doiVai:25:Viewer'));
  });

  testWidgets('đủ sáu người, tên dài, 360 dp: không tràn', (t) async {
    await mo(t,
        nha: nhaJson(members: [
          {'idaccount': 18, 'displayName': 'Tôi ${'rất dài ' * 8}', 'role': 'Owner', 'joinedAt': '2026-10-23T08:00:00.000Z'},
          for (var i = 0; i < 5; i++)
            {'idaccount': 30 + i, 'displayName': 'Người $i ${'rất dài ' * 8}', 'role': i.isEven ? 'Member' : 'Viewer', 'joinedAt': '2026-10-23T08:00:00.000Z'},
        ]));
    expect(t.takeException(), isNull);
  });

  /// Số đo hàng thao tác (Stitch `quan_ly_tv`: vạch → chữ ~15 dp, chữ → đáy thẻ ~26 dp, *Mời ra* sát mép phải vạch).
  Map<String, double> soDoHang(WidgetTester t) {
    final the = find.ancestor(of: find.text('Chuyển chủ nhà'), matching: find.byType(KhungTheNha)).first;
    final vach = t.getRect(find.descendant(of: the, matching: find.byType(Divider)));
    final chuyen = t.getRect(find.text('Chuyển chủ nhà'));
    final moiRa = t.getRect(find.text('Mời ra'));
    return {
      'vach_den_chu': chuyen.top - vach.center.dy,
      'chu_den_day': t.getRect(the).bottom - chuyen.bottom,
      'moi_ra_den_mep': vach.right - moiRa.right,
    };
  }

  testWidgets('hàng thao tác: sát vạch, đáy thẻ không dư, Mời ra sát mép phải vạch (số đo)', (t) async {
    await mo(t);
    final s = soDoHang(t);
    // ignore: avoid_print
    print('SO_DO $s');
    expect(s['vach_den_chu']!, lessThanOrEqualTo(8), reason: 'vạch → chữ (hộp chữ; Stitch ~15 dp tính từ nét chữ, hộp chữ cao hơn nét ~9 dp)');
    expect(s['chu_den_day']!, lessThanOrEqualTo(22), reason: 'chữ → đáy thẻ (Stitch ~26 dp từ nét chữ)');
    expect(s['moi_ra_den_mep']!, lessThanOrEqualTo(2), reason: '*Mời ra* sát mép phải vạch');
  });

  testWidgets('hai nút hàng thao tác dùng tapTargetSize shrinkWrap (vùng chạm 48 dp làm dư khoảng dưới thẻ)', (t) async {
    await mo(t);
    for (final nhan in ['Chuyển chủ nhà', 'Mời ra']) {
      final nut = t.widget<ButtonStyleButton>(find.ancestor(of: find.text(nhan), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).first);
      expect(nut.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap, reason: nhan);
    }
  });

  testWidgets('Chủ nhà đứng đầu (kể cả khi server trả ở cuối); còn lại giữ thứ tự server', (t) async {
    await mo(t, nha: nhaJson(members: [
      {'idaccount': 25, 'displayName': 'Nguyễn Bình', 'role': 'Member', 'joinedAt': '2026-10-23T09:12:00.000Z'},
      {'idaccount': 31, 'displayName': 'Lê Chi', 'role': 'Viewer', 'joinedAt': '2026-10-23T09:30:00.000Z'},
      {'idaccount': 18, 'displayName': 'Trần An', 'role': 'Owner', 'joinedAt': '2026-10-23T08:00:00.000Z'},
    ]));
    double y(String s) => t.getTopLeft(find.text(s)).dy;
    expect(y('Trần An'), lessThan(y('Nguyễn Bình')), reason: 'Chủ nhà đứng đầu dù server trả ở cuối');
    expect(y('Nguyễn Bình'), lessThan(y('Lê Chi')));
  });
}
