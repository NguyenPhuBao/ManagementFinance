import 'package:flowmoney/features/household/presentation/pages/tao_nha_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/goi_gia.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  setUpAll(napFontThat);

  testWidgets('ô rỗng: nút khoá (nợ 8); gõ tên: mở; ba dòng chính, không dòng phụ của Stitch', (t) async {
    dat360(t);
    batThongBao();
    final repo = await repoNhaThu(HouseholdApiGia());
    await t.pumpWidget(bocTrangNha(TaoNhaPage(repo: repo), goi: goiPremium(const {})));
    await t.pumpAndSettle();
    FilledButton nut() => t.widget(find.widgetWithText(FilledButton, 'Tạo nhà'));
    expect(nut().onPressed, isNull);
    await t.enterText(find.byType(TextField), '   ');
    await t.pump();
    expect(nut().onPressed, isNull);
    await t.enterText(find.byType(TextField), 'Nhà An');
    await t.pump();
    expect(nut().onPressed, isNotNull);
    expect(find.text('Bạn sẽ là Chủ nhà'), findsOneWidget);
    expect(find.text('Nhà có tối đa 6 thành viên'), findsOneWidget);
    expect(find.text('Cần có mạng để tạo nhà'), findsOneWidget);
    expect(find.textContaining('tức thời'), findsNothing, reason: 'app không hứa đồng bộ tức thì');
  });

  testWidgets('ô tên chặn ở 100 ký tự', (t) async {
    dat360(t);
    batThongBao();
    final repo = await repoNhaThu(HouseholdApiGia());
    await t.pumpWidget(bocTrangNha(TaoNhaPage(repo: repo), goi: goiPremium(const {})));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'a' * 150);
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text.length, 100);
  });

  testWidgets('tạo thành công: pop về trang trước, không thay stack', (t) async {
    dat360(t);
    batThongBao();
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    final r = routerThu(TaoNhaPage(repo: repo));
    await t.pumpWidget(bocRouterNha(r, goi: goiPremium(const {})));
    r.push('/dich');
    await t.pumpAndSettle();
    api.traVe = nhaJson(ten: 'Nhà An');
    await t.enterText(find.byType(TextField), '  Nhà An ');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Tạo nhà'));
    await t.pumpAndSettle();
    expect(api.goi, contains('taoNha:Nhà An'), reason: 'cắt trắng trước khi gửi');
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('403 FEATURE_DISABLED, Premium tạm ngừng: báo câu tạm ngừng, ở lại màn', (t) async {
    dat360(t);
    final bat = batThongBao();
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    await t.pumpWidget(bocTrangNha(TaoNhaPage(repo: repo), goi: goiPremium(const {'household': false})));
    await t.pumpAndSettle();
    api.loi = loiServer(403, 'FEATURE_DISABLED');
    await t.enterText(find.byType(TextField), 'Nhà An');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Tạo nhà'));
    await t.pumpAndSettle();
    expect(bat.cau, ['Tính năng gia đình đang tạm ngừng.']);
    expect(find.text('Tạo nhà'), findsWidgets);
  });

  testWidgets('360 dp, bàn phím mở: không tràn, nút còn trên màn', (t) async {
    dat360(t, banPhim: true);
    batThongBao();
    final repo = await repoNhaThu(HouseholdApiGia());
    await t.pumpWidget(bocTrangNha(TaoNhaPage(repo: repo), goi: goiPremium(const {})));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(t.getRect(find.widgetWithText(FilledButton, 'Tạo nhà')).bottom, lessThanOrEqualTo(500));
  });
}
