/// Nhấn Back ở Trang chủ không được thoát app ngay — E3 của lượt UX 2026-09-19.
///
/// Máy ảo đo được: Back ở tab Trang chủ đưa thẳng ra launcher, không cảnh báo.
/// Trong lượt đánh giá chính tôi cũng mất app hai lần vì thế. Luật Android
/// quen thuộc: Back ở tab khác thì về tab đầu; ở tab đầu thì báo "Nhấn lần nữa
/// để thoát", nhấn lại trong cửa sổ ngắn mới thoát.
///
/// Luật là lớp thuần `LuatThoatHaiLan` (test không cần widget); widget
/// `ThoatHaiLan` bọc `PopScope` và gọi `SystemNavigator.pop()` — ở test bắt
/// bằng cách giả kênh `SystemChannels.platform`.
library;

import 'dart:io';

import 'package:flowmoney/shared/widgets/thoat_hai_lan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LuatThoatHaiLan', () {
    final t0 = DateTime(2026, 9, 19, 9);

    test('không ở tab đầu thì về tab đầu, không tính là lần nhấn', () {
      final luat = LuatThoatHaiLan(cuaSo: const Duration(seconds: 2));
      expect(luat.quyetDinh(laTabDau: false, luc: t0), QuyetDinhThoat.veTabDau);
      // Lần nhấn ở tab khác không được "mồi" cho lần thoát kế.
      expect(luat.quyetDinh(laTabDau: true, luc: t0.add(const Duration(milliseconds: 100))),
          QuyetDinhThoat.baoNhanLanNua);
    });

    test('lần đầu ở tab đầu thì báo; lần hai trong cửa sổ thì thoát', () {
      final luat = LuatThoatHaiLan(cuaSo: const Duration(seconds: 2));
      expect(luat.quyetDinh(laTabDau: true, luc: t0), QuyetDinhThoat.baoNhanLanNua);
      expect(luat.quyetDinh(laTabDau: true, luc: t0.add(const Duration(seconds: 1))),
          QuyetDinhThoat.thoat);
    });

    test('lần hai QUÁ cửa sổ thì lại chỉ báo', () {
      final luat = LuatThoatHaiLan(cuaSo: const Duration(seconds: 2));
      luat.quyetDinh(laTabDau: true, luc: t0);
      expect(luat.quyetDinh(laTabDau: true, luc: t0.add(const Duration(seconds: 3))),
          QuyetDinhThoat.baoNhanLanNua,
          reason: 'Người dùng nhấn Back, làm việc khác 3 giây, nhấn lại — không '
              'phải "lần nữa".');
    });
  });

  group('ThoatHaiLan widget', () {
    late List<MethodCall> goiHeThong;
    late int veTabDau;
    late int bao;

    setUp(() {
      goiHeThong = [];
      veTabDau = 0;
      bao = 0;
    });

    Future<void> bom(WidgetTester tester, {required bool laTabDau}) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          goiHeThong.add(call);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(
        home: ThoatHaiLan(
          laTabDau: () => laTabDau,
          veTabDau: () => veTabDau++,
          baoNhanLanNua: () => bao++,
          child: const Scaffold(body: Text('trang')),
        ),
      ));
      await tester.pump();
    }

    bool daGoiThoat() =>
        goiHeThong.any((c) => c.method == 'SystemNavigator.pop');

    Future<void> nhanBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pump();
    }

    testWidgets('Back lần đầu ở tab đầu: báo, KHÔNG thoát', (tester) async {
      await bom(tester, laTabDau: true);
      await nhanBack(tester);

      expect(bao, 1);
      expect(daGoiThoat(), isFalse,
          reason: 'Bản trước không có PopScope nào — Back là ra launcher ngay.');
    });

    testWidgets('Back hai lần liền ở tab đầu: thoát', (tester) async {
      await bom(tester, laTabDau: true);
      await nhanBack(tester);
      await nhanBack(tester);

      expect(daGoiThoat(), isTrue);
    });

    testWidgets('Back ở tab khác: về tab đầu, không báo, không thoát',
        (tester) async {
      await bom(tester, laTabDau: false);
      await nhanBack(tester);

      expect(veTabDau, 1);
      expect(bao, 0);
      expect(daGoiThoat(), isFalse);
    });
  });

  test('MainShell bọc thân bằng ThoatHaiLan', () {
    final ma = File('lib/shared/widgets/main_shell.dart').readAsStringSync();
    expect(ma, contains('ThoatHaiLan('),
        reason: 'Widget chỉ có tác dụng khi shell thật sự dùng nó.');
  });
}
