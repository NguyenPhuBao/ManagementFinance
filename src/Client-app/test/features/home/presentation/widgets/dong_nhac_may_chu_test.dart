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

  /// Tiêu đề phải MỘT dòng. `maxLines: 1` và `overflow: ellipsis` THAY ĐƯỢC CHO NHAU (maxLines null thì ellipsis tự cắt ở
  /// dòng tràn đầu tiên) nên bỏ riêng một cái vẫn xanh — bản sai phải bỏ CẢ HAI. Vùng chữ ở 320 dp = 206 px (viền 1 px mỗi
  /// bên); bề rộng tự nhiên của tiêu đề 331 px (cỡ 1,0) / 494 px (cỡ 1,5). Bỏ cả hai: cỡ 1,0 → 32 px (hai dòng), 1,5 → 72 px.
  Future<void> tieuDeMotDong(WidgetTester t, double chuTo) async {
    tt.value = MayChuPhongToa(hetHanLuc: DateTime(2026, 10, 21, 9, 0));
    await dung(t, rong: 320, chuTo: chuTo);
    expect(t.takeException(), isNull);
    final mot = 13 * chuTo * 1.25;
    expect(t.getSize(find.text('Mạng này đang bị tạm chặn')).height, lessThan(mot * 1.5),
        reason:
            'Text ngắt dòng IM LẶNG (không sọc vàng) — chỉ chiều cao thật bắt được. Một dòng ≈ $mot; bỏ cả maxLines lẫn '
            'overflow thì tiêu đề xuống dòng (32 px ở cỡ 1,0; 72 px ở cỡ 1,5)');
  }

  testWidgets('320 dp, cỡ chữ mặc định: không tràn; tiêu đề MỘT dòng', (t) => tieuDeMotDong(t, 1));

  testWidgets('320 dp, chữ phóng 1,5: không tràn; tiêu đề MỘT dòng', (t) => tieuDeMotDong(t, 1.5));

  testWidgets('chưa đăng ký TrangThaiMayChu và không truyền → không dựng (test cũ Trang chủ không đổi)', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: DongNhacMayChu())));
    expect(the, findsNothing);
  });
}
