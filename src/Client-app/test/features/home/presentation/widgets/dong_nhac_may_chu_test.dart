/// Dòng nhắc máy chủ ở Trang chủ (spec G89 mục 4.1; Stitch `006c5a2eafc9461ab630163d1ff85de9`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/network/trang_thai_may_chu.dart';
import 'package:flowmoney/features/home/presentation/widgets/dong_nhac_may_chu.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  final bayGio = DateTime(2026, 10, 20, 10, 0);
  late TrangThaiMayChu tt;

  setUp(() => tt = TrangThaiMayChu());

  /// [rong] = bề rộng màn; Trang chủ đệm ngang 24 mỗi bên.
  Future<void> dung(WidgetTester t, {double rong = 360, double chuTo = 1}) async {
    t.view.physicalSize = Size(rong, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(chuTo)), child: child!),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [DongNhacMayChu(trangThai: tt, clock: () => bayGio)]),
        ),
      ),
    ));
  }

  final the = find.byKey(const ValueKey('dong-nhac-may-chu'));

  testWidgets('bình thường → không dựng gì', (t) async {
    await dung(t);
    expect(the, findsNothing);
  });

  testWidgets('bảo trì → hai dòng chữ của Stitch', (t) async {
    tt.value = MayChuBaoTri(thuLaiLuc: bayGio);
    await dung(t);
    expect(find.text('Máy chủ đang bảo trì'), findsOneWidget);
    expect(find.text('Dữ liệu trên máy vẫn dùng được, tự đồng bộ khi xong'), findsOneWidget);
    expect(find.byIcon(Icons.construction), findsOneWidget);
  });

  testWidgets('phong toả có giờ cùng ngày → "Tới 15:30 · …"', (t) async {
    tt.value = MayChuPhongToa(hetHanLuc: DateTime(2026, 10, 20, 15, 30));
    await dung(t);
    expect(find.text('Mạng này đang bị tạm chặn'), findsOneWidget);
    expect(find.text('Tới 15:30 · dữ liệu trên máy vẫn dùng được'), findsOneWidget);
    expect(find.byIcon(Icons.shield), findsOneWidget);
  });

  testWidgets('phong toả khác ngày → "Tới 09:00 21/10 · …"', (t) async {
    tt.value = MayChuPhongToa(hetHanLuc: DateTime(2026, 10, 21, 9, 0));
    await dung(t);
    expect(find.text('Tới 09:00 21/10 · dữ liệu trên máy vẫn dùng được'), findsOneWidget);
  });

  testWidgets('phong toả không giờ, hoặc giờ đã qua → không hứa giờ', (t) async {
    tt.value = MayChuPhongToa();
    await dung(t);
    expect(find.text('Dữ liệu trên máy vẫn dùng được'), findsOneWidget);
    tt.value = MayChuPhongToa(hetHanLuc: bayGio.subtract(const Duration(minutes: 1)));
    await t.pump();
    expect(find.text('Dữ liệu trên máy vẫn dùng được'), findsOneWidget,
        reason: '"Tới 09:59" khi đã 10:00 là một lời hứa sai — chờ request kế tiếp xoá dòng nhắc');
  });

  testWidgets('tự ẩn khi về bình thường — không nút, không ✕', (t) async {
    tt.value = MayChuBaoTri(thuLaiLuc: bayGio);
    await dung(t);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    tt.value = const MayChuBinhThuong();
    await t.pump();
    expect(the, findsNothing);
  });

  testWidgets('320 dp: không tràn; tiêu đề MỘT dòng (đo chiều cao thật), dòng phụ được xuống dòng', (t) async {
    tt.value = MayChuPhongToa(hetHanLuc: DateTime(2026, 10, 21, 9, 0));
    await dung(t, rong: 320, chuTo: 1.5);
    expect(t.takeException(), isNull);
    // Font thật của app hẹp hơn Ahem: ở 320 dp × cỡ chữ 1,0 tiêu đề vừa MỘT dòng kể cả khi thiếu maxLines (bản sai không đỏ),
    // nên phóng chữ 1,5 (cỡ hệ thống người dùng hay đặt) để tiêu đề (≈ 308 px) vượt vùng chữ (208 px).
    expect(t.getSize(find.text('Mạng này đang bị tạm chặn')).height, lessThan(13 * 1.5 * 1.25 * 1.5),
        reason:
            'Text ngắt dòng IM LẶNG (không sọc vàng) — chỉ chiều cao thật bắt được. Một dòng = 13 × 1,5 × 1,25 = 24,4; '
            'hai dòng = 48,8 — bỏ maxLines là hai dòng');
  });

  testWidgets('chưa đăng ký TrangThaiMayChu và không truyền → không dựng (test cũ Trang chủ không đổi)', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: DongNhacMayChu())));
    expect(the, findsNothing);
  });
}
