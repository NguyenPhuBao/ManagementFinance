// test/features/transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh_stitch_c4_test.dart
/// Ô Nhập nhanh theo màn Stitch `d696e81e…` *"Thêm giao dịch - Nhập nhanh bằng giọng nói (4 trạng thái)"* — người dùng
/// chốt 2026-10-16 cho app theo Stitch, trừ hai dòng "đang chép lời" / "đang kiểm" vẫn hiện lần lượt (lệch ghi ở mục 8
/// `GIONG_NOI_FEATURE.md`). Đỏ của trạng thái nghe là `#BA1A1A` (error) — tia sét giữ `#F25F5C` theo màn C2
/// `8afdfe11…`, nơi nó ra đời.
library;

import 'package:flowmoney/features/transaction/presentation/bloc/nghe_giong_noi_state.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/them_giao_dich/o_nhap_nhanh.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _doLoi = Color(0xFFBA1A1A);

void main() {
  Future<void> dung(
    WidgetTester tester, {
    TrangThaiNghe tt = TrangThaiNghe.cho,
    bool laPremium = true,
    Widget? khoiChonSoTien,
  }) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = TextEditingController();
    final f = FocusNode();
    addTearDown(c.dispose);
    addTearDown(f.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ONhapNhanh(
            controller: c,
            focusNode: f,
            laPremium: laPremium,
            dangDocAi: false,
            ketQua: null,
            onDien: () {},
            onHuy: () {},
            coMicro: true,
            trangThaiNghe: tt,
            giayGhi: 3,
            onMicro: () {},
            onHuyNghe: () {},
            khoiChonSoTien: khoiChonSoTien,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('đang nghe: nhãn "Đang nghe…" ở đầu thẻ, ô không mượn chữ gợi ý để nói việc ấy', (tester) async {
    await dung(tester, tt: TrangThaiNghe.dangNghe);
    expect(find.byKey(const Key('nhap-nhanh-dang-nghe')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('nhap-nhanh-dang-nghe')), matching: find.text('Đang nghe…')),
        findsOneWidget);
    final o = tester.widget<TextField>(find.byKey(const Key('nhap-nhanh-o')));
    expect(o.decoration?.hintText, isNot('Đang nghe…'),
        reason: 'Stitch đặt trạng thái ở nhãn đầu thẻ; chữ gợi ý biến mất ngay khi chữ chép lời đầu tiên về.');
  });

  testWidgets('đang nghe: viền ô và nút dừng ■ màu đỏ lỗi #BA1A1A', (tester) async {
    await dung(tester, tt: TrangThaiNghe.dangNghe);
    final khung = tester.widget<Container>(find
        .ancestor(of: find.byKey(const Key('nhap-nhanh-o')), matching: find.byType(Container))
        .first);
    expect(((khung.decoration! as BoxDecoration).border! as Border).top.color, _doLoi,
        reason: 'Stitch: border-2 border-[#BA1A1A]; bản cũ dùng AppColors.expense #F25F5C.');
    final o = tester.widget<Container>(find.byKey(const Key('nhap-nhanh-dung')));
    expect((o.decoration! as BoxDecoration).color, _doLoi, reason: 'Stitch: ô vuông 14 dp nền #BA1A1A.');
    expect(find.byIcon(Icons.stop_circle), findsNothing, reason: 'Nút dừng là ô vuông trong vòng nền nhạt, không phải icon.');
  });

  testWidgets('đang ghi: chấm đỏ của dòng "Đang ghi âm" màu #BA1A1A', (tester) async {
    await dung(tester, tt: TrangThaiNghe.dangGhi);
    final cham = tester.widget<Container>(find.byKey(const Key('dong-dang-nghe-cham')));
    expect((cham.decoration! as BoxDecoration).color, _doLoi);
  });

  testWidgets('chờ, Premium có micro: nhãn "Giọng nói & Gõ"; Basic thì không', (tester) async {
    await dung(tester);
    expect(find.text('Giọng nói & Gõ'), findsOneWidget);
    expect(find.byKey(const Key('nhap-nhanh-dang-nghe')), findsNothing);

    await dung(tester, laPremium: false);
    expect(find.text('Giọng nói & Gõ'), findsNothing, reason: 'Basic không có micro — nhãn nói sai.');
  });

  testWidgets('khối chọn số tiền nằm TRONG thẻ, dưới cùng', (tester) async {
    await dung(tester, khoiChonSoTien: const SizedBox(key: Key('khoi-thu'), height: 40));
    expect(find.descendant(of: find.byType(ONhapNhanh), matching: find.byKey(const Key('khoi-thu'))),
        findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('khoi-thu'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const Key('nhap-nhanh-o'))).dy));
  });
}
