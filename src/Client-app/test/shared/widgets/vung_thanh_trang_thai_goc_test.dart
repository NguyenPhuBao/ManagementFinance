import 'dart:io';

import 'package:flowmoney/shared/theme/kieu_thanh_trang_thai.dart';
import 'package:flowmoney/shared/widgets/vung_thanh_trang_thai_goc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thanh trạng thái MỘT kiểu cho cả app (2026-10-25, phiên 8). Trước đó kiểu tuỳ trang vừa ghé: trang không AppBar (Trang
/// chủ, Phân tích) mang dải xám 25 % đen của cửa sổ Android khi mở lạnh, rồi mất dải ấy sau khi ghé một trang có AppBar —
/// vì Flutter chỉ gọi `setSystemUIOverlayStyle` khi TÌM THẤY một `AnnotatedRegion`, không bao giờ tự trả kiểu cũ khi vùng biến
/// mất (đo Realme, bẫy 26 `KHOA_APP_FEATURE.md`). Vùng gốc bọc ngoài router để luôn có một vùng được tìm thấy.
void main() {
  /// Kiểu riêng của một trang khác — giả dải xám, để phép so không trùng kiểu gốc.
  const kieuKhac = SystemUiOverlayStyle(statusBarColor: Color(0x40000000), statusBarIconBrightness: Brightness.light);

  testWidgets('trang không AppBar lấy kiểu gốc; ghé trang đặt kiểu khác rồi quay lại → kiểu gốc trở lại', (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: nav,
      builder: (context, child) => VungThanhTrangThaiGoc(child: child!),
      home: const Scaffold(body: Text('Trang chủ')),
    ));
    await t.pump();
    expect(SystemChrome.latestStyle, kKieuThanhTrangThaiSang, reason: 'trong suốt, biểu tượng tối trên nền kem');

    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const AnnotatedRegion<SystemUiOverlayStyle>(value: kieuKhac, child: Scaffold(body: Text('Khác'))),
    ));
    await t.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarColor, const Color(0x40000000), reason: 'trang tự đặt kiểu thì kiểu ấy thắng');

    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarColor, const Color(0x00000000),
        reason: 'Flutter không tự trả kiểu cũ khi vùng biến mất — vùng gốc phải được tìm thấy lại');
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  test('main.dart: vùng gốc nằm TRONG lớp khoá (lớp khoá đè được) và bọc cả router + toast', () {
    final m = File('lib/main.dart').readAsStringSync();
    final khoa = m.indexOf('builder: (context, child) => LopKhoaApp(');
    final goc = m.indexOf('VungThanhTrangThaiGoc(');
    final dongHo = m.indexOf('bocDongHo24Gio(');
    expect(khoa, greaterThan(0));
    expect(goc, greaterThan(khoa), reason: 'vùng gốc phải là con của LopKhoaApp — màn khoá đặt kiểu của nó lên trên');
    expect(dongHo, greaterThan(goc), reason: 'vùng gốc bọc ngoài toast + router để phủ mọi trang');
  });

  test('màn khoá dùng chung hằng kiểu, không tự khai bản thứ hai', () {
    final k = File('lib/features/khoa_app/presentation/widgets/man_khoa/lop_khoa_app.dart').readAsStringSync();
    expect(k, contains('kKieuThanhTrangThaiSang'));
    expect(k, isNot(contains('statusBarIconBrightness')), reason: 'MỘT định nghĩa kiểu — shared/theme/kieu_thanh_trang_thai.dart');
  });
}
