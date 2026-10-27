/// G107 — ảnh của lượt Quét bị bỏ dở khi tiến trình chết lúc máy ảnh / trình chọn ảnh đang mở.
///
/// Android có thể huỷ activity (và tiến trình) của FlowMoney trong lúc app máy ảnh chiếm bộ nhớ — app đang giữ Gemma
/// ~3 GB là ca dễ gặp nhất (bước 21 `KHOA_APP_FEATURE.md`). `pickImage` của lượt ấy không bao giờ trả về; ảnh nằm trong
/// bộ đệm của `image_picker` cho tới khi app gọi `retrieveLostData()`. Trước G107 không ai gọi → ảnh vừa chụp mất, người
/// dùng quay về Trang chủ như chưa từng quét.
///
/// `NhanAnhQuetBoDo` đứng trong cột Trang chủ (không vẽ gì): dựng lần đầu thì hỏi ảnh bỏ dở một lần, có ảnh thì mở
/// `/quet` với đường dẫn ấy — cùng đích với `moQuet`.
library;

import 'dart:io';

import 'package:flowmoney/features/home/presentation/widgets/nhan_anh_quet_bo_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<({List<String?> mo})> dung(WidgetTester tester, Future<String?> Function() layAnhMat) async {
    final mo = <String?>[];
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => Scaffold(body: Column(children: [NhanAnhQuetBoDo(layAnhMat: layAnhMat)])),
        ),
        GoRoute(
          path: '/quet',
          builder: (_, s) {
            mo.add(s.extra as String?);
            return const Scaffold(body: Text('MAN QUET'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return (mo: mo);
  }

  testWidgets('⭐ có ảnh của lượt chụp bị bỏ dở → mở /quet với đúng đường dẫn ấy', (tester) async {
    final r = await dung(tester, () async => '/data/cache/scaled_mat.jpg');
    expect(find.text('MAN QUET'), findsOneWidget,
        reason: 'G107: tiến trình chết lúc máy ảnh mở thì ảnh chỉ còn trong bộ đệm image_picker — không mở /quet là mất ảnh');
    expect(r.mo, ['/data/cache/scaled_mat.jpg']);
  });

  testWidgets('không có ảnh bỏ dở → ở yên Trang chủ', (tester) async {
    final r = await dung(tester, () async => null);
    expect(find.text('MAN QUET'), findsNothing);
    expect(r.mo, isEmpty);
  });

  testWidgets('đọc ảnh bỏ dở ném lỗi → ở yên Trang chủ, không lỗi lan ra', (tester) async {
    final r = await dung(tester, () async => throw Exception('kênh image_picker hỏng'));
    expect(tester.takeException(), isNull);
    expect(find.text('MAN QUET'), findsNothing);
    expect(r.mo, isEmpty);
  });

  testWidgets('dựng lại (đổi tab, AuthSuccess phát lại) không hỏi lần hai', (tester) async {
    var lan = 0;
    final khoa = GlobalKey<_VoState>();
    await tester.pumpWidget(MaterialApp(
      home: _Vo(key: khoa, layAnhMat: () async {
        lan++;
        return null;
      }),
    ));
    await tester.pump();
    khoa.currentState!.dungLai();
    await tester.pump();
    khoa.currentState!.dungLai();
    await tester.pump();
    expect(lan, 1, reason: 'retrieveLostData chỉ có nghĩa một lần mỗi lần trang dựng mới — HomePage dựng lại rất thường');
  });

  test('⭐ Trang chủ có đặt NhanAnhQuetBoDo trong cột (nối dây — dựng HomePage thật đòi nửa cái app)', () {
    final nguon = File('lib/features/home/presentation/pages/home_page.dart').readAsStringSync();
    expect(nguon.contains('const NhanAnhQuetBoDo()'), isTrue,
        reason: 'G107: widget có mà Trang chủ không đặt thì không ai gọi retrieveLostData — ảnh vẫn mất, mọi ca trên vẫn xanh');
  });
}

class _Vo extends StatefulWidget {
  const _Vo({super.key, required this.layAnhMat});
  final Future<String?> Function() layAnhMat;
  @override
  State<_Vo> createState() => _VoState();
}

class _VoState extends State<_Vo> {
  var _n = 0;
  void dungLai() => setState(() => _n++);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Column(children: [Text('$_n'), NhanAnhQuetBoDo(layAnhMat: widget.layAnhMat)]));
}
