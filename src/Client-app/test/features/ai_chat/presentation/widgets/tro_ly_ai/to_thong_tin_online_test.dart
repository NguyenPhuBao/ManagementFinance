import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_chat/presentation/widgets/tro_ly_ai/to_thong_tin_online.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  Future<LuaChonToThongTin?> mo(WidgetTester t, {Size khung = const Size(411, 914)}) async {
    LuaChonToThongTin? kq;
    var daMo = false;
    await t.binding.setSurfaceSize(khung);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Builder(builder: (ctx) {
        if (!daMo) {
          daMo = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async => kq = await moToThongTinOnline(ctx));
        }
        return const SizedBox();
      })),
    ));
    await t.pumpAndSettle();
    return kq;
  }

  testWidgets('hiện tiêu đề + đủ câu thân + hai nút', (t) async {
    await mo(t);
    expect(find.text(kTieuDeToOnline), findsOneWidget);
    expect(find.text(kThanToOnline), findsOneWidget);
    expect(find.textContaining('Google Gemini'), findsOneWidget);
    expect(find.textContaining('không gửi gì'), findsOneWidget);
    expect(find.byKey(const Key('to-da-hieu')), findsOneWidget);
    expect(find.byKey(const Key('to-chi-tren-may')), findsOneWidget);
  });

  testWidgets('Đã hiểu → daHieu; Chỉ dùng AI trên máy → chiTrenMay; vuốt tắt → null', (t) async {
    LuaChonToThongTin? kq;
    Future<void> chay(Future<void> Function() thaoTac) async {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: Builder(builder: (ctx) => TextButton(
          key: const Key('mo'), onPressed: () async => kq = await moToThongTinOnline(ctx), child: const Text('mở')))),
      ));
      await t.tap(find.byKey(const Key('mo')));
      await t.pumpAndSettle();
      await thaoTac();
      await t.pumpAndSettle();
    }
    await chay(() async => t.tap(find.byKey(const Key('to-da-hieu'))));
    expect(kq, LuaChonToThongTin.daHieu);
    await chay(() async => t.tap(find.byKey(const Key('to-chi-tren-may'))));
    expect(kq, LuaChonToThongTin.chiTrenMay);
    await chay(() async => t.tapAt(const Offset(10, 10))); // chạm ngoài tờ
    expect(kq, isNull);
  });

  testWidgets('khổ thấp 360×640 không tràn (bẫy G60: bottom sheet nhiều dòng phải cuộn)', (t) async {
    await mo(t, khung: const Size(360, 640));
    expect(t.takeException(), isNull);
  });
}
