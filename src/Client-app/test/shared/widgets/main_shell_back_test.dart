/// Nút Back đi qua GoRouter THẬT — tái hiện lỗi máy ảo 2026-09-19.
///
/// Bản đầu của E3 bọc thân shell bằng `PopScope` và test bằng `MaterialApp`
/// trần: xanh. Trên máy ảo (Android 16, targetSdk 36, **predictive back bật
/// mặc định**), Back ở tab Phân tích **thoát app ra launcher**. Cơ chế, đọc từ
/// `navigator.dart` và `app.dart`: mỗi `Navigator` phát
/// `NavigationNotification(canHandlePop)`; `Navigator` gốc phát đúng (nó cộng
/// cả `PopScope` — `navigatorCanPop || routeBlocksPop`), nhưng khi **navigator
/// của nhánh** mới dựng phát `canHandlePop: false`, listener của navigator gốc
/// chỉ hỏi `canPop()` — không hỏi `PopScope` — nên **cho qua nguyên vẹn**, và
/// `WidgetsApp` gọi `SystemNavigator.setFrameworkHandlesBack(false)`. Từ đó
/// Android tự đóng activity ở lần Back kế mà không hỏi Flutter; logcat ghi
/// `setTopOnBackInvokedCallback: null` đúng lúc chuyển tab.
///
/// Đây đúng là *loại lỗi thứ hai* mà `flutter test` không bắt được (điều hướng
/// qua `StatefulShellRoute` chỉ nổ với cây route thật) — nên test này dựng
/// `MainShell` trong một `GoRouter` thật với `StatefulShellRoute`, giả kênh
/// `SystemChannels.platform` để bắt `SystemNavigator.pop`, và đọc thẳng
/// manifest để canh predictive back đã tắt — lối sửa: tắt nó thì Android luôn
/// giao Back cho Flutter, nơi `PopScope` của shell hoạt động đúng.
library;
import 'dart:io';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/shared/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late List<MethodCall> goiHeThong;
  late List<String> thongBao;
  late GoRouter router;
  final rootKey = GlobalKey<NavigatorState>();

  setUp(() {
    goiHeThong = [];
    thongBao = [];
    final nhanh = ThongBaoNhanh();
    nhanh.stream.listen(thongBao.add);
    sl.registerSingleton<ThongBaoNhanh>(nhanh);
  });
  tearDown(() async {
    await sl.reset();
  });

  Future<void> bom(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        goiHeThong.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/a',
                  builder: (_, __) => const Scaffold(body: Text('TRANG A'))),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/b',
                  builder: (_, __) => const Scaffold(body: Text('TRANG B'))),
            ]),
          ],
        ),
        GoRoute(
          path: '/c',
          parentNavigatorKey: rootKey,
          builder: (_, __) => const Scaffold(body: Text('TRANG C')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  bool daGoiThoat() => goiHeThong.any((c) => c.method == 'SystemNavigator.pop');

  Future<void> nhanBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('ở tab đầu: Back lần đầu báo, không thoát', (tester) async {
    await bom(tester);
    await nhanBack(tester);

    expect(thongBao, ['Nhấn lần nữa để thoát']);
    expect(daGoiThoat(), isFalse);
    expect(find.text('TRANG A'), findsOneWidget);
  });

  testWidgets('ở tab đầu: Back hai lần liền thì thoát', (tester) async {
    await bom(tester);
    await nhanBack(tester);
    await nhanBack(tester);

    expect(daGoiThoat(), isTrue);
  });

  testWidgets('ở tab khác: Back về tab đầu, KHÔNG thoát', (tester) async {
    await bom(tester);
    router.go('/b');
    await tester.pumpAndSettle();
    expect(find.text('TRANG B'), findsOneWidget);

    await nhanBack(tester);

    expect(daGoiThoat(), isFalse,
        reason: 'Máy ảo 2026-09-19: Back ở tab Phân tích ra launcher — '
            'GoRouter không hỏi PopScope trên route của shell.');
    expect(find.text('TRANG A'), findsOneWidget);
    expect(thongBao, isEmpty, reason: 'Về tab đầu không phải là "lần nhấn".');
  });

  testWidgets('có trang đẩy lên trên shell: Back chỉ pop trang ấy',
      (tester) async {
    await bom(tester);
    router.push('/c');
    await tester.pumpAndSettle();
    expect(find.text('TRANG C'), findsOneWidget);

    await nhanBack(tester);

    expect(find.text('TRANG C'), findsNothing);
    expect(find.text('TRANG A'), findsOneWidget);
    expect(thongBao, isEmpty);
    expect(daGoiThoat(), isFalse);
  });

  test('predictive back TẮT trong AndroidManifest — Back luôn tới Flutter', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:enableOnBackInvokedCallback="false"'),
        reason: 'targetSdk 36 bật predictive back mặc định. Khi bật, Android '
            'chỉ giao Back cho Flutter nếu lời gọi setFrameworkHandlesBack cuối '
            'cùng là true — mà navigator của nhánh mới dựng phát '
            'canHandlePop:false, listener của navigator gốc chỉ hỏi canPop() '
            '(không hỏi PopScope) nên cho qua, và Android tự đóng activity ở '
            'lần Back kế. Máy ảo 2026-09-19: sang tab Phân tích rồi Back là ra '
            'launcher. Tắt ở manifest thì Back đi đường KEYCODE_BACK → '
            'popRoute → PopScope, tức đúng đường năm ca trên đã canh.');
  });

  testWidgets('hộp thoại đang mở: Back chỉ đóng hộp thoại', (tester) async {
    await bom(tester);
    showDialog<void>(
      context: rootKey.currentContext!,
      builder: (_) => const AlertDialog(title: Text('HỘP THOẠI')),
    );
    await tester.pumpAndSettle();
    expect(find.text('HỘP THOẠI'), findsOneWidget);

    await nhanBack(tester);

    expect(find.text('HỘP THOẠI'), findsNothing);
    expect(thongBao, isEmpty);
    expect(daGoiThoat(), isFalse);
  });
}
