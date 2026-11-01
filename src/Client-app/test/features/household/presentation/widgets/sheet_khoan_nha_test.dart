// Sheet chi tiết một khoản của nhà (Stitch a8d53198): hàng nút theo quyền, màu và dấu số tiền, hàng Ghi chú.
import 'package:flowmoney/features/household/domain/hoat_dong_nha.dart';
import 'package:flowmoney/features/household/presentation/widgets/sheet_khoan_nha.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

TransactionEntity _k({String type = 'chi', String? cap, String note = '', String? cat = 'c'}) => TransactionEntity(
      id: 'k',
      walletId: 'v1',
      idaccount: 25,
      idhousehold: 12,
      fundPairId: cap,
      categoryId: cat,
      amount: 2000000,
      type: type,
      note: note,
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

Widget _bo(TransactionEntity k, {required ({bool sua, bool xoa}) quyen, TenNguoi nguoi = const TenNguoi('Minh')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SheetKhoanNha(khoan: k, nguoi: nguoi, nhanNgay: 'Hôm nay', viHienThi: 'Tiền chợ', tenDanhMuc: null, quyen: quyen),
      ),
    );

void main() {
  setUpAll(napFontThat);

  testWidgets('khoản góp: dấu +, màu xanh sheet, đủ hàng như Stitch, nút Xoá + Sửa', (t) async {
    await t.pumpWidget(_bo(_k(type: 'thu', cap: 'p', cat: null, note: 'Tiền chợ tháng 11'), quyen: (sua: true, xoa: true)));
    final so = t.widget<Text>(find.byKey(const Key('sheet-so-tien')));
    expect(so.data, '+2.000.000 đ');
    expect(so.style?.color, const Color(0xFF006E1C));
    for (final c in ['Loại', 'Góp vào quỹ', 'Ví chung', 'Tiền chợ', 'Người ghi', 'Minh', 'Ngày', '01/11/2026', 'Ghi chú', 'Tiền chợ tháng 11']) {
      expect(find.text(c), findsWidgets, reason: c);
    }
    expect(find.text('Minh góp'), findsOneWidget);
    expect(find.byKey(const Key('sheet-xoa')), findsOneWidget);
    expect(find.byKey(const Key('sheet-sua')), findsOneWidget);
  });

  testWidgets('không quyền: không hàng nút; ghi chú trống: không hàng Ghi chú', (t) async {
    await t.pumpWidget(_bo(_k(), quyen: (sua: false, xoa: false)));
    expect(find.byKey(const Key('sheet-xoa')), findsNothing);
    expect(find.byKey(const Key('sheet-sua')), findsNothing);
    expect(find.text('Ghi chú'), findsNothing);
    expect(t.widget<Text>(find.byKey(const Key('sheet-so-tien'))).data, '-2.000.000 đ');
  });

  testWidgets('chỉ Xoá: nút Xoá chiếm cả hàng; người đã rời có hậu tố', (t) async {
    await t.pumpWidget(_bo(_k(), quyen: (sua: false, xoa: true), nguoi: const TenNguoi('Hoa', daRoi: true)));
    expect(find.byKey(const Key('sheet-sua')), findsNothing);
    expect(find.text('Hoa (đã rời)'), findsOneWidget, reason: 'hàng Người ghi');
    expect(t.getSize(find.byKey(const Key('sheet-xoa'))).width, greaterThan(250));
  });
}
