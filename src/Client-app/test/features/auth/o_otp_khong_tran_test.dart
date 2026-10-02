/// Hàng sáu ô OTP không được tràn ở điện thoại hẹp — cả hai màn OTP.
///
/// Người dùng báo ngày 2026-10-02 khi đăng ký trên OnePlus 13R (361 dp): ô thứ
/// sáu bị sọc cảnh báo che, *"RIGHT OVERFLOWED BY 6.9 PIXELS"*. Hàng là sáu
/// `SizedBox(width: 45)` = 270 dp cứng, trong khi chỗ còn lại sau lề trang (24 × 2),
/// lề thẻ (24 × 2) và viền thẻ là 263 dp. Ở 411 dp (máy ảo, khổ mọi lượt nghiệm
/// thu trước đó) hàng vừa, nên lỗi nằm sẵn từ khi màn ra đời mà không ai thấy.
/// Màn OTP quên mật khẩu chép đúng hàng ấy.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/auth/presentation/pages/otp_page.dart';
import 'package:flowmoney/features/auth/presentation/pages/register_otp_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoTrong implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _datKho(WidgetTester tester, Size kho) {
  tester.view.physicalSize = kho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _moDangKy(WidgetTester tester) async {
  final bloc = AuthBloc(authRepository: _RepoTrong());
  addTearDown(bloc.close);
  await tester.pumpWidget(BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const RegisterOtpPage(
        registerState: RegisterOtpSent(
          email: 'dat@example.com',
          username: 'dat',
          fullname: 'Dat',
          password: 'x',
        ),
      ),
    ),
  ));
  await tester.pump();
}

Future<void> _moQuenMatKhau(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: const OtpPage(email: 'dat@example.com'),
  ));
  await tester.pump();
}

/// Sáu ô theo thứ tự trái → phải.
List<Rect> _cacO(WidgetTester tester) {
  final o = find.byType(TextFormField);
  expect(o, findsNWidgets(6));
  return [for (var i = 0; i < 6; i++) tester.getRect(o.at(i))];
}

void main() {
  setUp(() => sl.registerSingleton<AuthRepository>(_RepoTrong()));
  tearDown(() async => sl.reset());

  final man = <String, Future<void> Function(WidgetTester)>{
    'đăng ký': _moDangKy,
    'quên mật khẩu': _moQuenMatKhau,
  };

  for (final e in man.entries) {
    for (final rong in <double>[360, 320]) {
      testWidgets('màn OTP ${e.key} ở $rong dp: hàng sáu ô không tràn',
          (tester) async {
        _datKho(tester, Size(rong, 640));
        await e.value(tester);

        expect(tester.takeException(), isNull,
            reason: 'Sáu ô rộng cứng 45 dp là 270 dp; ở $rong dp chỗ còn lại '
                'sau hai lớp lề 24 và viền thẻ là ${rong - 98} dp.');

        // Không tràn mà ô co về 0, hoặc dính liền nhau, thì cũng là hỏng.
        final o = _cacO(tester);
        for (var i = 0; i < 6; i++) {
          expect(o[i].width, greaterThanOrEqualTo(30),
              reason: 'Ô $i phải đủ rộng cho một chữ số cỡ 22.');
          expect(o[i].width, closeTo(o[0].width, 0.01),
              reason: 'Sáu ô phải rộng bằng nhau.');
          if (i > 0) {
            expect(o[i].left - o[i - 1].right, greaterThanOrEqualTo(4),
                reason: 'Hai ô liền nhau phải có khe — dính nhau thì viền '
                    'xanh của ô đang gõ chồng lên ô bên cạnh.');
          }
        }
      });
    }

    testWidgets('màn OTP ${e.key} ở 411 dp: ô giữ bề rộng 45 như cũ',
        (tester) async {
      _datKho(tester, const Size(411, 914));
      await e.value(tester);

      expect(tester.takeException(), isNull);
      for (final o in _cacO(tester)) {
        expect(o.width, closeTo(45, 0.01),
            reason: 'Đủ chỗ thì hàng trông như trước lượt sửa.');
      }
    });
  }
}
