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
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
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

  testWidgets('kho hỏng khi ghi: hai lần chạm liền → hai câu báo, mức cũ giữ nguyên', (t) async {
    final bat = batThongBao();
    await sv.datPin(10, '246810');
    await mo(t, app());
    kho.hongKhiGhi = true;
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byKey(const Key('hang-tu-khoa')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tu-khoa-phut5')));
      await t.pumpAndSettle();
    }
    expect(t.takeException(), isNull);
    expect(bat.cau, [kCauKhoAppKhongLuu, kCauKhoAppKhongLuu],
        reason: 'bản nuốt lỗi im lặng phải đỏ; hai lỗi liền cùng câu vẫn báo hai lần');
    expect(find.text('30 giây'), findsOneWidget);
  });

  testWidgets('Đổi mã PIN: mở trang doi, pop(true) thì đọc lại', (t) async {
    await sv.datPin(10, '246810');
    final lanNapToanApp = <int>[];
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<KhoaAppCubit>.value(
        value: KhoaAppCubit(service: sv, vongDoi: const Stream.empty(), phien: const Stream.empty()),
        child: KhoaAppPage(
          service: sv,
          idaccount: 10,
          moDatPin: (c, che) async {
            goi.add(che);
            await sv.datTuKhoaSau(10, TuKhoaSau.phut5);
            lanNapToanApp.add(1);
            return true;
          },
        ),
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('hang-doi-pin')));
    await t.pumpAndSettle();
    expect(goi, [CheDatPin.doi]);
    expect(find.text('5 phút'), findsOneWidget, reason: 'pop(true) → trang đọc lại kho');
  });

  testWidgets('khổ hẹp 320 dp: không tràn', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await sv.datPin(10, '246810');
    await mo(t, app());
    expect(t.takeException(), isNull);
  });

  group('M15 — hàng Tự khoá sau khi chật', () {
    /// Số dòng một `Text` thật sự vẽ ra — đếm các đỉnh khác nhau của hộp chọn cả chuỗi. Ngắt dòng không sinh sọc vàng
    /// (`takeException` trả null), nên ca "khổ hẹp 320 dp: không tràn" ở trên mù với M15.
    int soDong(WidgetTester t, Finder f) {
      final p = t.renderObject<RenderParagraph>(f);
      final dai = p.text.toPlainText().length;
      return p
          .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: dai))
          .map((b) => b.top.round())
          .toSet()
          .length;
    }

    void kho(WidgetTester t, double rong) {
      t.view.physicalSize = Size(rong, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    final tieuDe = find.text('Tự khoá sau');
    final phu = find.text('Khi app ở nền lâu hơn mức này');

    testWidgets('320 dp + "Ngay khi rời app": tiêu đề một dòng, giá trị xuống dưới dòng phụ', (t) async {
      kho(t, 320);
      await sv.datPin(10, '246810');
      await sv.datTuKhoaSau(10, TuKhoaSau.ngay);
      await mo(t, app());
      expect(soDong(t, tieuDe), 1,
          reason: 'Realme 320 dp (buổi 3): giá trị bên phải chiếm chỗ, "Tự khoá sau" gãy hai dòng');
      expect(t.getTopLeft(find.text('Ngay khi rời app')).dy, greaterThanOrEqualTo(t.getBottomLeft(phu).dy),
          reason: 'khi tiêu đề không vừa thì giá trị + mũi tên xuống dưới dòng phụ');
      expect(t.takeException(), isNull);
    });

    testWidgets('khổ rộng: giá trị vẫn bên phải tiêu đề (Stitch 129c2d77), kể cả "Ngay khi rời app"', (t) async {
      kho(t, 600);
      await sv.datPin(10, '246810');
      for (final m in [TuKhoaSau.giay30, TuKhoaSau.ngay]) {
        await sv.datTuKhoaSau(10, m);
        await t.pumpWidget(const SizedBox());
        await mo(t, app());
        final giaTri = find.text(m.nhan);
        expect(t.getCenter(giaTri).dy, lessThan(t.getBottomLeft(phu).dy),
            reason: '${m.nhan}: còn chỗ thì giữ bố cục một hàng — xuống dòng chỉ là đường lùi khi chật');
        expect(t.getTopLeft(giaTri).dx, greaterThan(t.getTopRight(tieuDe).dx));
      }
    });

    // 480 dp: font của bộ test vẽ "30 giây" + "Tự khoá sau" vừa MỘT hàng ở cỡ chữ 1 mà không vừa ở 1,5 — nên chỉ phép đo
    // có `textScaler` mới đưa giá trị xuống (ở 411 dp cỡ 1 cũng đã chật, ca mù với bản bỏ quên `textScaler` — đã thử).
    testWidgets('cỡ chữ 1,5 ở 480 dp + "30 giây": tiêu đề một dòng — đo theo cỡ chữ thật', (t) async {
      kho(t, 480);
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await sv.datPin(10, '246810');
      await mo(t, app());
      expect(soDong(t, tieuDe), 1, reason: 'phép đo bỏ quên textScaler thì cỡ chữ lớn vẫn gãy');
      expect(t.getTopLeft(find.text('30 giây')).dy, greaterThanOrEqualTo(t.getBottomLeft(phu).dy));
    });
  });

  testWidgets('I3: chạm đôi công tắc / hàng Đổi PIN trong lúc trang PIN đang mở → moDatPin gọi đúng một lần', (t) async {
    final cho = Completer<bool?>();
    var lan = 0;
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: KhoaAppPage(
        service: sv,
        idaccount: 10,
        moDatPin: (c, che) {
          lan++;
          return cho.future;
        },
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cong-tac-khoa')));
    await t.pump();
    await t.tap(find.byKey(const Key('cong-tac-khoa')));
    await t.pump();
    expect(lan, 1, reason: 'lần chạm thứ hai khi trang PIN còn mở phải bị bỏ qua');
    cho.complete(false);
    await t.pumpAndSettle();

    await sv.datPin(10, '246810');
    final cho2 = Completer<bool?>();
    lan = 0;
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: KhoaAppPage(
        key: UniqueKey(),
        service: sv,
        idaccount: 10,
        moDatPin: (c, che) {
          lan++;
          return cho2.future;
        },
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('hang-doi-pin')));
    await t.pump();
    await t.tap(find.byKey(const Key('hang-doi-pin')));
    await t.pump();
    expect(lan, 1);
    cho2.complete(false);
    await t.pumpAndSettle();
  });
}
