/// Nút Google / Apple màn Đăng nhập không gãy chữ ở khổ hẹp, hai nhãn cùng cỡ; cả màn không tràn ở cỡ chữ lớn.
///
/// Realme 320 dp (nghiệm thu khoá app buổi 3, 2026-10-25): nút rộng ~108 dp, đệm mặc định của `OutlinedButton.icon`
/// (16 + 24) và biểu tượng 24 chỉ còn ~36 dp cho chữ → *"Goo / gle"*. Không có sọc vàng (`Text` chỉ ngắt dòng), nên phép đo
/// là **số dòng** chữ vẽ ra, không phải `takeException`.
///
/// Font thật (`napFontThat`, Roboto): ×1,1 ≈ Inter ở cỡ chữ 1 (Roboto hẹp hơn vài phần trăm), ×1,76 ≈ Inter ở cỡ 1,6.
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/auth/presentation/pages/login_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

/// Bloc chỉ cần đứng ở `AuthInitial` — không sự kiện nào được gửi, repository không bị gọi.
class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Số dòng một `Text` thật sự vẽ ra — đếm các đỉnh khác nhau của hộp chọn cả chuỗi.
int _soDong(WidgetTester t, Finder f) {
  final p = t.renderObject<RenderParagraph>(f);
  final dai = p.text.toPlainText().length;
  return p
      .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: dai))
      .map((b) => b.top.round())
      .toSet()
      .length;
}

void main() {
  setUp(napFontThat);

  Future<void> dung(WidgetTester t, double co, {double rong = 320}) async {
    t.view.physicalSize = Size(rong, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final bloc = AuthBloc(authRepository: _RepoGia());
    addTearDown(bloc.close);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<AuthBloc>.value(value: bloc, child: const LoginPage()),
    ));
    await t.pump();
  }

  /// Cỡ vẽ tự nhiên của nhãn nút (cỡ 14 của theme ở cỡ chữ [co]) — độc lập với cách nút co chữ.
  double caoTuNhien(WidgetTester t, String chu, double co) {
    final ctx = t.element(find.text(chu));
    final p = TextPainter(
      text: TextSpan(text: chu, style: DefaultTextStyle.of(ctx).style),
      textScaler: TextScaler.linear(co),
      textDirection: TextDirection.ltr,
    )..layout();
    final h = p.height;
    p.dispose();
    return h;
  }

  testWidgets('320 dp × 1,1: "Google" và "Apple" mỗi chữ một dòng, không bị co', (t) async {
    await dung(t, 1.1);
    expect(_soDong(t, find.text('Google')), 1, reason: 'Realme 320 dp: nút Google gãy "Goo / gle"');
    expect(_soDong(t, find.text('Apple')), 1);
    for (final chu in ['Google', 'Apple']) {
      expect(t.getRect(find.text(chu)).height, greaterThan(caoTuNhien(t, chu, 1.1) - 0.5),
          reason: '$chu: ở cỡ chữ thường đệm phải đủ chỗ — co chữ là đường lùi cho cỡ chữ lớn, không phải cách sửa');
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('320 dp × 1,76: nhãn co lại cho vừa, vẫn một dòng, không cắt — hai nút CÙNG cỡ chữ', (t) async {
    await dung(t, 1.76);
    for (final chu in ['Google', 'Apple']) {
      expect(_soDong(t, find.text(chu)), 1, reason: '$chu: chữ to mà không co thì lại "Goo / gle"');
      expect(t.renderObject<RenderParagraph>(find.text(chu)).didExceedMaxLines, isFalse,
          reason: '$chu: một dòng bằng cách CẮT chữ ("Goo") cũng không đạt');
    }
    // Lượt đo lại 2026-10-26 (máy ảo 320 dp × 1,6): "Apple" to hơn "Google" — mỗi nhãn tự co riêng.
    final g = t.getRect(find.text('Google')).height;
    final a = t.getRect(find.text('Apple')).height;
    expect((g - a).abs(), lessThan(0.3), reason: 'hai nút bằng nhau thì hai nhãn cùng cỡ — đang cao ${g.toStringAsFixed(1)} / ${a.toStringAsFixed(1)}');
  });

  // Máy ảo 320 dp × 1,6 (2026-10-26): "MẬT KHẨU · Quên mật khẩu?" tràn 19 px, "Chưa có tài khoản? Đăng ký ngay" tràn 87 px.
  testWidgets('320 dp × 1,76: cả màn không tràn; "Quên mật khẩu?" vẫn ở mép phải, "Đăng ký ngay" vẽ trọn', (t) async {
    await dung(t, 1.76);
    expect(t.takeException(), isNull, reason: 'hai hàng tràn 19 px / 87 px ở cỡ chữ 1,6');
    final o = t.getRect(find.byType(TextFormField).last);
    final quen = t.getRect(find.text('Quên mật khẩu?'));
    expect(quen.right, closeTo(o.right, 0.5), reason: 'liên kết vẫn căn mép phải ô mật khẩu');
    expect(t.getRect(find.text('MẬT KHẨU')).left, closeTo(o.left, 0.5));
    for (final chu in ['Quên mật khẩu?', 'Chưa có tài khoản? ', 'Đăng ký ngay']) {
      final r = t.getRect(find.text(chu));
      expect(r.left, greaterThanOrEqualTo(-0.5), reason: '"$chu" tràn mép trái màn');
      expect(r.right, lessThanOrEqualTo(320.5), reason: '"$chu" tràn mép phải màn');
      expect(t.renderObject<RenderParagraph>(find.text(chu)).didExceedMaxLines, isFalse);
    }
    expect(_soDong(t, find.text('Đăng ký ngay')), 1, reason: 'liên kết Đăng ký không gãy đôi');
  });

  testWidgets('411 dp × 1,1: "Chưa có tài khoản? Đăng ký ngay" một hàng, "Quên mật khẩu?" cùng hàng nhãn MẬT KHẨU', (t) async {
    await dung(t, 1.1, rong: 411);
    expect(t.takeException(), isNull);
    expect(t.getRect(find.text('Đăng ký ngay')).center.dy, closeTo(t.getRect(find.text('Chưa có tài khoản? ')).center.dy, 0.5));
    expect(t.getRect(find.text('Quên mật khẩu?')).center.dy, closeTo(t.getRect(find.text('MẬT KHẨU')).center.dy, 0.5));
    expect(_soDong(t, find.text('Quên mật khẩu?')), 1);
  });
}
