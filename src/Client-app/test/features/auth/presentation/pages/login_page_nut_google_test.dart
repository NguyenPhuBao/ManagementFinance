/// Nút Google / Apple màn Đăng nhập không gãy chữ ở khổ hẹp.
///
/// Realme 320 dp (nghiệm thu khoá app buổi 3, 2026-10-25): nút rộng ~108 dp, đệm mặc định của `OutlinedButton.icon`
/// (16 + 24) và biểu tượng 24 chỉ còn ~36 dp cho chữ → *"Goo / gle"*. Không có sọc vàng (`Text` chỉ ngắt dòng), nên phép đo
/// là **số dòng** chữ vẽ ra, không phải `takeException`.
///
/// ⚠️ Font của bộ test rộng ~gấp đôi Inter (bẫy 4.4 `ANALYTICS_FEATURE.md`): ở 320 dp cỡ chữ 1 thì ba hàng KHÁC của trang
/// tràn (hàng *MẬT KHẨU*, *hoặc tiếp tục với*, *Chưa có tài khoản?*) — trên máy chỉ nút Google gãy. Ca đặt cỡ chữ **0,55**
/// để tỷ lệ chữ / đệm gần máy thật: *"Google"* 84 → ~46 dp (Inter 14 thật ~47 dp), đệm và biểu tượng không co.
library;

import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/auth/presentation/pages/login_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('320 dp (tỷ lệ chữ gần Inter): "Google" và "Apple" mỗi chữ một dòng', (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = 0.55;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final bloc = AuthBloc(authRepository: _RepoGia());
    addTearDown(bloc.close);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<AuthBloc>.value(value: bloc, child: const LoginPage()),
    ));
    await t.pump();
    expect(_soDong(t, find.text('Google')), 1, reason: 'Realme 320 dp: nút Google gãy "Goo / gle"');
    expect(_soDong(t, find.text('Apple')), 1);
    for (final chu in ['Google', 'Apple']) {
      final hop = find.ancestor(of: find.text(chu), matching: find.byType(FittedBox));
      expect(t.getSize(hop).width, closeTo(t.getSize(find.text(chu)).width, 0.01),
          reason: '$chu: ở cỡ chữ thường đệm phải đủ chỗ — co chữ là đường lùi cho cỡ chữ lớn, không phải cách sửa');
    }
    expect(t.takeException(), isNull);
  });

  // Font test ở cỡ 1 ≈ Inter ở cỡ ~1,8: đúng tình huống `FittedBox` sinh ra để đỡ. Ba hàng khác của trang tràn ở đây
  // (gom lại, không khẳng định) — chúng thuộc phép đo cỡ chữ lớn trên máy, không phải phạm vi ca này.
  testWidgets('320 dp, chữ to: nhãn co lại cho vừa, vẫn một dòng', (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final bloc = AuthBloc(authRepository: _RepoGia());
    addTearDown(bloc.close);
    final loi = <FlutterErrorDetails>[];
    final cu = FlutterError.onError;
    FlutterError.onError = loi.add;
    try {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider<AuthBloc>.value(value: bloc, child: const LoginPage()),
      ));
      await t.pump();
    } finally {
      FlutterError.onError = cu;
    }
    expect(loi.every((d) => d.exceptionAsString().contains('overflowed')), isTrue,
        reason: loi.map((d) => d.exceptionAsString()).join('\n'));
    for (final chu in ['Google', 'Apple']) {
      expect(_soDong(t, find.text(chu)), 1, reason: '$chu: chữ to mà không co thì lại "Goo / gle"');
      expect(t.renderObject<RenderParagraph>(find.text(chu)).didExceedMaxLines, isFalse,
          reason: '$chu: một dòng bằng cách CẮT chữ ("Goo") cũng không đạt');
    }
  });
}
