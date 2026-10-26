import 'dart:async';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_cubit.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flowmoney/features/khoa_app/presentation/widgets/man_khoa/lop_khoa_app.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/khoa_app_gia.dart';

/// Thanh trạng thái của màn khoá (nghiệm thu Realme 2026-10-25, ghi nhận phụ mục 10): màn khoá không tự đặt
/// `SystemUiOverlayStyle` nên ăn theo trang nằm dưới — dải xám 25 % đen ở Trang chủ, trong suốt ở trang có AppBar. Màn khoá
/// phải luôn MỘT kiểu của chính nó (trong suốt, biểu tượng tối trên nền kem), và mở khoá thì trang dưới lấy lại kiểu của nó.
void main() {
  late KhoaAppService sv;
  late StreamController<int?> phien;
  late StreamController<AppLifecycleState> vongDoi;
  final nay = DateTime(2026, 10, 25, 9);
  KhoaAppCubit? cubit;

  /// Kiểu riêng của trang dưới — giả dải xám mặc định của cửa sổ Android, để phép so không trùng kiểu màn khoá.
  const kieuTrang = SystemUiOverlayStyle(
    statusBarColor: Color(0x40000000),
    statusBarIconBrightness: Brightness.light,
  );

  setUp(() {
    sv = KhoaAppService(store: InMemoryKhoaAppStore(), kenh: KenhGia(), bam: bamNhanh, clock: () => nay);
    phien = StreamController<int?>.broadcast();
    vongDoi = StreamController<AppLifecycleState>.broadcast();
  });

  tearDown(() async {
    await cubit?.close();
    cubit = null;
    await phien.close();
    await vongDoi.close();
  });

  Future<void> dung(WidgetTester t) async {
    await sv.datPin(10, '246810');
    cubit = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream, clock: () => nay);
    await t.pumpWidget(BlocProvider.value(
      value: cubit!,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => LopKhoaApp(khiQuenPin: () {}, dongHo: () => nay, child: child!),
        home: const AnnotatedRegion<SystemUiOverlayStyle>(value: kieuTrang, child: Scaffold(body: Text('Trang'))),
      ),
    ));
  }

  testWidgets('đang khoá: thanh trạng thái theo màn khoá (trong suốt, biểu tượng tối), không theo trang dưới', (t) async {
    await dung(t);
    await cubit!.nhanPhien(10);
    await t.pump();
    await t.pump();
    expect(cubit!.state, isA<KhoaAppKhoa>());
    expect(SystemChrome.latestStyle?.statusBarColor, const Color(0x00000000),
        reason: 'trang dưới đặt dải xám — màn khoá phải đè bằng kiểu của nó');
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark, reason: 'nền kem → biểu tượng tối');
  });

  testWidgets('mở khoá: trang dưới lấy lại kiểu của nó', (t) async {
    await dung(t);
    await cubit!.nhanPhien(10);
    await t.pump();
    for (final c in '246810'.split('')) {
      await t.tap(find.byKey(Key('phim-$c')));
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(cubit!.state, isA<KhoaAppMo>());
    expect(SystemChrome.latestStyle?.statusBarColor, const Color(0x40000000));
  });
}
