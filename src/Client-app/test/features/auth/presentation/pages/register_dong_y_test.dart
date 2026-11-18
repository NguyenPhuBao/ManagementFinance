/// Màn Đăng ký: ô tick bắt buộc đồng ý Điều khoản sử dụng + Chính sách bảo mật (spec điều khoản viết cứng 2026-11-16).
/// Dựng router thật vì trang Đăng ký nằm ngoài shell và hai liên kết đi `/chinh-sach/:ma`.
library;

import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';

class _Repo implements AuthRepository {
  int guiOtp = 0;

  @override
  Future<void> registerSendOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    String? phone,
  }) async {
    guiOtp++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Font thật: Ahem (chữ rộng 1 em) báo trang Đăng ký GỐC tràn 162 px ở 320 dp — tràn giả, đo 2026-11-16.
  setUpAll(napFontThat);
  late _Repo repo;

  Future<void> moDangKy(WidgetTester t, {Size kho = const Size(1080, 2400)}) async {
    t.view.physicalSize = kho;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    repo = _Repo();
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    final router = AppRouter.createRouter('/register', bloc);
    addTearDown(router.dispose);
    await t.pumpWidget(BlocProvider<AuthBloc>.value(value: bloc, child: MaterialApp.router(routerConfig: router)));
    await t.pump();
  }

  Future<void> dienForm(WidgetTester t) async {
    final o = find.byType(TextFormField);
    await t.enterText(o.at(0), 'new-user');
    await t.enterText(o.at(1), 'New User');
    await t.enterText(o.at(2), 'new@example.com');
    await t.enterText(o.at(3), 'password123');
    await t.enterText(o.at(4), 'password123');
  }

  Finder nutDangKy() => find.widgetWithText(ElevatedButton, 'Đăng ký');

  testWidgets('chưa tick → dòng lỗi, KHÔNG gửi OTP; tick → lỗi ẩn, gửi OTP', (t) async {
    await moDangKy(t);
    await dienForm(t);
    await t.ensureVisible(nutDangKy());
    await t.tap(nutDangKy());
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('loi-dong-y')), findsOneWidget);
    expect(repo.guiOtp, 0, reason: 'chưa đồng ý thì không được gửi yêu cầu đăng ký');

    await t.tap(find.byKey(const Key('o-dong-y')));
    await t.pump();
    expect(find.byKey(const Key('loi-dong-y')), findsNothing);
    await t.tap(nutDangKy());
    await t.pump(const Duration(milliseconds: 50));
    expect(repo.guiOtp, 1);
  });

  testWidgets('bấm "Chính sách bảo mật" → trang đọc; Back về Đăng ký giữ chữ đã gõ', (t) async {
    await moDangKy(t);
    await dienForm(t);
    await t.ensureVisible(find.byKey(const Key('o-dong-y')));
    await t.tapOnText(find.textRange.ofSubstring('Chính sách bảo mật'));
    await t.pumpAndSettle();
    expect(find.text('Chính sách bảo mật và xử lý dữ liệu cá nhân của FlowMoney'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('new@example.com'), findsOneWidget);
  });

  testWidgets('bấm "Điều khoản sử dụng" → trang Điều khoản', (t) async {
    await moDangKy(t);
    await t.ensureVisible(find.byKey(const Key('o-dong-y')));
    await t.tapOnText(find.textRange.ofSubstring('Điều khoản sử dụng'));
    await t.pumpAndSettle();
    expect(find.text('Điều khoản sử dụng FlowMoney'), findsOneWidget);
  });

  testWidgets('320 dp: ô tick + dòng lỗi không tràn', (t) async {
    await moDangKy(t, kho: const Size(320, 1400));
    await dienForm(t);
    await t.ensureVisible(nutDangKy());
    await t.tap(nutDangKy());
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('loi-dong-y')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
