import 'dart:async';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/domain/luat_khoa_app.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_cubit.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flowmoney/features/khoa_app/presentation/pages/dat_ma_pin_page.dart';
import 'package:flowmoney/features/khoa_app/presentation/pages/khoa_app_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/khoa_app_gia.dart';

void main() {
  late InMemoryKhoaAppStore kho;
  late KenhGia kenh;
  late KhoaAppService sv;
  late List<CheDatPin> goi;

  setUp(() {
    kho = InMemoryKhoaAppStore();
    kenh = KenhGia();
    sv = KhoaAppService(store: kho, kenh: kenh, bam: bamNhanh);
    goi = [];
  });

  Future<bool?> moDatPinGia(BuildContext context, CheDatPin che) async {
    goi.add(che);
    if (che == CheDatPin.dat) await sv.datPin(10, '246810');
    if (che == CheDatPin.tat) await sv.tatKhoa(10);
    return true;
  }

  Widget app() => MaterialApp(
        theme: AppTheme.lightTheme,
        home: KhoaAppPage(service: sv, idaccount: 10, moDatPin: moDatPinGia),
      );

  Future<void> mo(WidgetTester t, Widget w) async {
    await t.pumpWidget(w);
    await t.pumpAndSettle();
  }

  testWidgets('chưa bật: chỉ công tắc khoá', (t) async {
    await mo(t, app());
    expect(find.byKey(const Key('cong-tac-khoa')), findsOneWidget);
    expect(find.byKey(const Key('hang-doi-pin')), findsNothing);
    expect(find.text('MỞ NHANH'), findsNothing);
    expect(find.byKey(const Key('hang-tu-khoa')), findsNothing);
  });

  testWidgets('bật → trang đặt PIN → ba nhóm hiện + tự mở hộp vân tay', (t) async {
    await mo(t, app());
    await t.tap(find.byKey(const Key('cong-tac-khoa')));
    await t.pumpAndSettle();
    expect(goi, [CheDatPin.dat]);
    expect(find.byKey(const Key('hang-doi-pin')), findsOneWidget);
    expect(find.text('Mở bằng vân tay'), findsOneWidget);
    expect(find.byKey(const Key('hang-tu-khoa')), findsOneWidget);
    expect((await kho.doc(10))!.vanTay, isNotNull,
        reason: 'đặt PIN xong tự gọi bật vân tay — hộp hệ thống là câu hỏi "Dùng vân tay để mở?" (spec mục 4)');
  });

  testWidgets('máy chưa đăng ký vân tay: công tắc tắt mờ + câu hướng dẫn', (t) async {
    kenh.may = const TrangThaiSinhTrac(hoTro: true, daDangKy: false);
    await sv.datPin(10, '246810');
    await mo(t, app());
    expect(find.text('Thêm vân tay trong Cài đặt của máy để dùng'), findsOneWidget);
    expect(t.widget<Switch>(find.byKey(const Key('cong-tac-van-tay'))).onChanged, isNull);
  });

  testWidgets('máy không hỗ trợ: không có nhóm MỞ NHANH', (t) async {
    kenh.may = TrangThaiSinhTrac.khong;
    await sv.datPin(10, '246810');
    await mo(t, app());
    expect(find.text('MỞ NHANH'), findsNothing);
    expect(find.byKey(const Key('hang-tu-khoa')), findsOneWidget);
  });

  testWidgets('Tự khoá sau → 5 phút → cất + nhãn đổi', (t) async {
    await sv.datPin(10, '246810');
    await mo(t, app());
    expect(find.text('30 giây'), findsOneWidget);
    await t.tap(find.byKey(const Key('hang-tu-khoa')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tu-khoa-phut5')));
    await t.pumpAndSettle();
    expect(find.text('5 phút'), findsOneWidget);
    expect((await kho.doc(10))!.tuKhoaSau, TuKhoaSau.phut5);
  });

  testWidgets('tắt khoá → trang tat → các nhóm biến mất', (t) async {
    await sv.datPin(10, '246810');
    await mo(t, app());
    await t.tap(find.byKey(const Key('cong-tac-khoa')));
    await t.pumpAndSettle();
    expect(goi, [CheDatPin.tat]);
    expect(find.byKey(const Key('hang-doi-pin')), findsNothing);
    expect(await kho.doc(10), isNull);
  });

  testWidgets('có KhoaAppCubit toàn app: bật khoá → cubit Mo(daBat: true) mà KHÔNG khoá', (t) async {
    final phien = StreamController<int?>.broadcast();
    final vongDoi = StreamController<AppLifecycleState>.broadcast();
    final toanApp = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream);
    addTearDown(() async {
      await toanApp.close();
      await phien.close();
      await vongDoi.close();
    });
    await toanApp.nhanPhien(10);
    expect(toanApp.state, const KhoaAppMo(daBat: false));
    await mo(t, BlocProvider.value(value: toanApp, child: app()));
    await t.tap(find.byKey(const Key('cong-tac-khoa')));
    await t.pumpAndSettle();
    expect(toanApp.state, const KhoaAppMo(daBat: true));
  });

  testWidgets('kho hỏng khi ghi: đổi Tự khoá sau không ném, trang vẫn dựng', (t) async {
    await sv.datPin(10, '246810');
    await mo(t, app());
    kho.hongKhiGhi = true;
    await t.tap(find.byKey(const Key('hang-tu-khoa')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tu-khoa-phut5')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('hang-tu-khoa')), findsOneWidget);
    expect(find.text('30 giây'), findsOneWidget, reason: 'ghi hỏng thì mức cũ giữ nguyên');
  });

  testWidgets('khổ hẹp 320 dp: không tràn', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await sv.datPin(10, '246810');
    await mo(t, app());
    expect(t.takeException(), isNull);
  });
}
