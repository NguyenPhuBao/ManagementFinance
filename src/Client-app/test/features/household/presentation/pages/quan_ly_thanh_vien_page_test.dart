import 'dart:async';

import 'package:flowmoney/features/household/presentation/pages/quan_ly_thanh_vien_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  setUpAll(napFontThat);

  Future<(HouseholdApiGia, BatThongBao)> mo(WidgetTester t, {Map<String, Object?>? nha, bool banPhim = false}) async {
    dat360(t, banPhim: banPhim);
    final bat = batThongBao();
    final api = HouseholdApiGia()..cuaToiJson = nha ?? nhaJson();
    final repo = await repoNhaThu(api);
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
    expect(find.text('Vào nhà 23/10/2026'), findsWidgets, reason: 'dòng phụ = ngày vào nhà');
    expect(find.textContaining('@'), findsNothing, reason: 'server không trả email thành viên');
    expect(find.textContaining('HẠN MỨC'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
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
    expect(t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Thành viên')).onSelected, isNull);
    api.treo!.complete();
    await t.pumpAndSettle();
    expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Chuyển chủ nhà')).onPressed, isNotNull);
  });

  testWidgets('nhà chỉ xem: vẫn đổi vai / chuyển chủ / giải tán được (spec 12.3)', (t) async {
    final (api, _) = await mo(t, nha: nhaJson(status: 'ReadOnly'));
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
}
