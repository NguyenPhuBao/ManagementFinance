import 'dart:async';

import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/presentation/pages/tham_gia_nha_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/goi_gia.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  setUpAll(napFontThat);

  test('MaMoiFormatter: in hoa, bỏ khoảng trắng / gạch nối, tối đa 8 ký tự', () {
    final f = MaMoiFormatter();
    TextEditingValue go(String s) => f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s));
    expect(go('abcd-2345').text, 'ABCD2345');
    expect(go('ab cd 23 45 67').text, 'ABCD2345');
    expect(go('ab').selection.baseOffset, 2, reason: 'con trỏ phải ở cuối');
  });

  testWidgets('Xem trước khoá tới khi đủ 8 ký tự; xem xong hiện thẻ, không nhãn Khả dụng; Tham gia pop về', (t) async {
    dat360(t);
    batThongBao();
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    final r = routerThu(ThamGiaNhaPage(repo: repo));
    await t.pumpWidget(bocRouterNha(r, goi: goiBasic(const {})));
    r.push('/dich');
    await t.pumpAndSettle();
    expect(find.text('Nhập mã 8 ký tự chủ nhà gửi cho bạn.'), findsOneWidget);
    OutlinedButton xem() =>
        t.widget(find.ancestor(of: find.text('Xem trước'), matching: find.byWidgetPredicate((w) => w is OutlinedButton)));
    FilledButton vao() =>
        t.widget(find.ancestor(of: find.text('Tham gia'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(xem().onPressed, isNull);
    expect(vao().onPressed, isNull);
    await t.enterText(find.byType(TextField), 'abcd2345');
    await t.pump();
    expect(xem().onPressed, isNotNull);
    expect(vao().onPressed, isNull, reason: 'chưa xem trước thì chưa được vào');
    await t.tap(find.text('Xem trước'));
    await t.pumpAndSettle();
    expect(find.text('Nhà An – Bình'), findsOneWidget);
    expect(find.text('Trần An'), findsOneWidget);
    expect(find.text('2/6'), findsOneWidget);
    expect(find.text('Khả dụng'), findsNothing);
    expect(find.text('Vào nhà xong, dữ liệu của nhà sẽ tải về máy này.'), findsOneWidget);
    expect(vao().onPressed, isNotNull);
    api.traVe = nhaJson();
    await t.tap(find.text('Tham gia'));
    await t.pumpAndSettle();
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('lỗi xem trước và lỗi tham gia ra đúng câu qua kênh báo của trang', (t) async {
    dat360(t);
    final bat = batThongBao();
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    await t.pumpWidget(bocTrangNha(ThamGiaNhaPage(repo: repo), goi: goiBasic(const {})));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'abcd2345');
    await t.pump();
    api.loi = loiServer(409, 'HOUSEHOLD_INVITE_EXPIRED');
    await t.tap(find.text('Xem trước'));
    await t.pumpAndSettle();
    expect(bat.cuoi!.cau, cauLoiNha(LoaiLoiNha.maHetHan));
    api.loi = null;
    await t.tap(find.text('Xem trước'));
    await t.pumpAndSettle();
    api.loi = loiServer(409, 'HOUSEHOLD_FULL');
    await t.tap(find.text('Tham gia'));
    await t.pumpAndSettle();
    expect(bat.cuoi!.cau, cauLoiNha(LoaiLoiNha.nhaDu));
  });

  testWidgets('nút Tham gia khoá suốt lúc chờ mạng', (t) async {
    dat360(t);
    batThongBao();
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    final r = routerThu(ThamGiaNhaPage(repo: repo));
    await t.pumpWidget(bocRouterNha(r, goi: goiBasic(const {})));
    r.push('/dich');
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'abcd2345');
    await t.pump();
    await t.tap(find.text('Xem trước'));
    await t.pumpAndSettle();
    final treo = Completer<void>();
    api.treo = treo;
    await t.tap(find.text('Tham gia'));
    await t.pump();
    final vao = t.widget<FilledButton>(find.ancestor(of: find.text('Tham gia'), matching: find.byType(FilledButton)));
    expect(vao.onPressed, isNull);
    treo.complete();
    await t.pumpAndSettle();
  });

  testWidgets('admin tắt household_join: khoá ô và nút, câu trung tính, không mời mua', (t) async {
    dat360(t);
    batThongBao();
    final repo = await repoNhaThu(HouseholdApiGia());
    await t.pumpWidget(bocTrangNha(ThamGiaNhaPage(repo: repo), goi: goiBasic(const {'household_join': false})));
    await t.pumpAndSettle();
    expect(find.text('Tính năng gia đình hiện không dùng được với tài khoản này.'), findsOneWidget);
    expect(find.textContaining('Premium'), findsNothing);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('360 dp, bàn phím mở, có thẻ xem trước: không tràn', (t) async {
    dat360(t, banPhim: true);
    batThongBao();
    final repo = await repoNhaThu(HouseholdApiGia());
    await t.pumpWidget(bocTrangNha(ThamGiaNhaPage(repo: repo), goi: goiBasic(const {})));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'abcd2345');
    await t.pump();
    await t.tap(find.text('Xem trước'));
    await t.pumpAndSettle();
    expect(find.text('Nhà An – Bình'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
