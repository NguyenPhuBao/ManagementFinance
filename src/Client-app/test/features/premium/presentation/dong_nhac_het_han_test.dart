/// Dòng nhắc "Premium còn N ngày" ở Trang chủ (spec Premium 9.5): hiện khi
/// còn 0..3 ngày, Gia hạn, ✕ ẩn tới hết ngày; hết hạn / Basic / chưa biết hạn
/// → không dựng gì; không AnNhacHetHan hay GoiCubit trong cây → không dựng.
library;

import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/an_nhac_het_han.dart';
import 'package:flowmoney/features/premium/presentation/cubit/goi_cubit.dart';
import 'package:flowmoney/features/premium/presentation/widgets/dong_nhac_het_han.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
}

void main() {
  var now = DateTime(2026, 10, 6, 10);
  const khoa = Key('dong-nhac-het-han');

  setUp(() => now = DateTime(2026, 10, 6, 10));

  Future<GoiCubit> cubit(DateTime? hetHan, {bool premium = true}) async {
    final store = InMemoryGoiStore();
    if (premium) {
      await store.ghi(10, TrangThaiGoi(loai: LoaiGoi.premium, hetHan: hetHan, nhanLuc: now));
    }
    final repo = GoiRepository(api: _ApiIm(), kho: store, clock: () => now);
    await repo.datTaiKhoan(10);
    final c = GoiCubit(repo, clock: () => now);
    addTearDown(() async {
      await c.close();
      await repo.dispose();
    });
    return c;
  }

  Widget boc(Widget w, {GoiCubit? c}) {
    final than = Scaffold(body: w);
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: c == null ? than : BlocProvider<GoiCubit>.value(value: c, child: than),
    );
  }

  testWidgets('còn 3 ngày → "Premium còn 3 ngày" + Gia hạn + ✕', (tester) async {
    var giaHan = 0;
    final c = await cubit(DateTime(2026, 10, 9, 8));
    await tester.pumpWidget(boc(
        DongNhacHetHan(idaccount: 10, an: AnNhacHetHan(), clock: () => now, onGiaHan: () => giaHan++),
        c: c));
    expect(find.text('Premium còn 3 ngày'), findsOneWidget);
    await tester.tap(find.text('Gia hạn'));
    expect(giaHan, 1);
    expect(find.byTooltip('Ẩn lời nhắc'), findsOneWidget);
  });

  testWidgets('còn 0 ngày → "Premium hết hạn hôm nay"', (tester) async {
    final c = await cubit(DateTime(2026, 10, 6, 23));
    await tester.pumpWidget(boc(DongNhacHetHan(idaccount: 10, an: AnNhacHetHan(), clock: () => now), c: c));
    expect(find.text('Premium hết hạn hôm nay'), findsOneWidget);
  });

  testWidgets('còn 4 ngày / đã hết hạn / Basic / chưa biết hạn → không dựng', (tester) async {
    for (final (hetHan, premium) in [
      (DateTime(2026, 10, 10, 8), true),
      (DateTime(2026, 10, 6, 9), true),
      (null, false),
      (null, true),
    ]) {
      final c = await cubit(hetHan, premium: premium);
      await tester.pumpWidget(boc(DongNhacHetHan(idaccount: 10, an: AnNhacHetHan(), clock: () => now), c: c));
      expect(find.byKey(khoa), findsNothing, reason: 'hetHan=$hetHan premium=$premium');
    }
  });

  testWidgets('✕ → ẩn; dựng lại cùng ngày vẫn ẩn; sang ngày sau hiện lại', (tester) async {
    final an = AnNhacHetHan();
    final c = await cubit(DateTime(2026, 10, 9, 8));
    Widget w() => DongNhacHetHan(idaccount: 10, an: an, clock: () => now);
    await tester.pumpWidget(boc(w(), c: c));
    await tester.tap(find.byTooltip('Ẩn lời nhắc'));
    await tester.pump();
    expect(find.byKey(khoa), findsNothing);
    await tester.pumpWidget(boc(const SizedBox(), c: c));
    await tester.pumpWidget(boc(w(), c: c));
    expect(find.byKey(khoa), findsNothing, reason: 'cùng ngày vẫn ẩn');
    now = DateTime(2026, 10, 7, 8);
    await tester.pumpWidget(boc(const SizedBox(), c: c));
    await tester.pumpWidget(boc(w(), c: c));
    expect(find.text('Premium còn 2 ngày'), findsOneWidget, reason: 'qua ngày hiện lại');
  });

  testWidgets('không GoiCubit / không AnNhacHetHan → không dựng, không ném', (tester) async {
    await tester.pumpWidget(boc(DongNhacHetHan(idaccount: 10, an: AnNhacHetHan(), clock: () => now)));
    expect(find.byKey(khoa), findsNothing);
    final c = await cubit(DateTime(2026, 10, 9, 8));
    await tester.pumpWidget(boc(DongNhacHetHan(idaccount: 10, clock: () => now), c: c));
    expect(find.byKey(khoa), findsNothing, reason: 'an null và sl chưa đăng ký → shrink');
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await cubit(DateTime(2026, 10, 6, 23));
    await tester.pumpWidget(boc(DongNhacHetHan(idaccount: 10, an: AnNhacHetHan(), clock: () => now), c: c));
    expect(tester.takeException(), isNull);
  });
}
