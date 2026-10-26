/// Dòng nhắc *"Chưa nhận được dữ liệu mới"* ở Trang chủ (2026-10-26, đơn 53 vế C; biến thể 4 của màn Stitch
/// `006c5a2eafc9461ab630163d1ff85de9`) — nguồn là `SyncEngine.keoVeBiTuChoi`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/home/presentation/widgets/dong_nhac_keo_ve.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  late ValueNotifier<bool> hong;

  setUp(() => hong = ValueNotifier(false));

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
          child: Column(children: [DongNhacKeoVe(nguon: hong)]),
        ),
      ),
    ));
  }

  final the = find.byKey(const ValueKey('dong-nhac-keo-ve'));

  testWidgets('kéo về bình thường → không dựng gì', (t) async {
    await dung(t);
    expect(the, findsNothing);
  });

  testWidgets('bị máy chủ từ chối → hai dòng chữ của Stitch, không nêu mã lỗi', (t) async {
    hong.value = true;
    await dung(t);
    expect(find.text('Chưa nhận được dữ liệu mới'), findsOneWidget);
    expect(find.text('Thay đổi từ máy khác chưa về, thay đổi trên máy này vẫn được gửi lên'), findsOneWidget,
        reason: 'nói đúng sự thật: đẩy vẫn chạy — người dùng không cần ngừng ghi chép');
    expect(find.byIcon(Icons.sync_problem), findsOneWidget);
    expect(find.textContaining('DECRYPT'), findsNothing, reason: 'thông báo tối giản — không mã lỗi, không con số');
  });

  testWidgets('tự ẩn khi lượt kéo sau thành công — không nút, không ✕', (t) async {
    hong.value = true;
    await dung(t);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    hong.value = false;
    await t.pump();
    expect(the, findsNothing);
  });

  /// Tiêu đề MỘT dòng ở 320 dp (khuôn `dong_nhac_may_chu_test`): `Text` ngắt dòng im lặng — chỉ chiều cao thật bắt được.
  Future<void> tieuDeMotDong(WidgetTester t, double chuTo) async {
    hong.value = true;
    await dung(t, rong: 320, chuTo: chuTo);
    expect(t.takeException(), isNull);
    final mot = 13 * chuTo * 1.25;
    expect(t.getSize(find.text('Chưa nhận được dữ liệu mới')).height, lessThan(mot * 1.5));
  }

  testWidgets('320 dp, cỡ chữ mặc định: không tràn; tiêu đề MỘT dòng', (t) => tieuDeMotDong(t, 1));

  testWidgets('320 dp, chữ phóng 1,5: không tràn; tiêu đề MỘT dòng', (t) => tieuDeMotDong(t, 1.5));

  testWidgets('chưa đăng ký SyncEngine và không truyền → không dựng (test cũ Trang chủ không đổi)', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: DongNhacKeoVe())));
    expect(the, findsNothing);
  });

  test('nguồn là ValueListenable — không ép kiểu ValueNotifier', () {
    final ValueListenable<bool> chiDoc = hong;
    expect(DongNhacKeoVe(nguon: chiDoc).nguon, same(hong));
  });
}
