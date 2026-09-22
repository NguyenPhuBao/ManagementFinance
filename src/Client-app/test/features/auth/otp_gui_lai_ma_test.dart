/// Nút "Gửi lại mã OTP" ở màn OTP quên mật khẩu phải GỬI LẠI THẬT.
///
/// Lượt quét `lib/` ngày 2026-09-19 (`khong_co_nut_chet_test`) lộ ra nút này
/// là `onPressed: () { // Resend OTP logic }` — người dùng lỡ mất mã thì bấm
/// vào và không có gì xảy ra, không có cách nào khác ngoài quay lại nhập email
/// từ đầu. Đường đúng là gọi lại chính `forgotPassword(email)` đã gửi mã lần
/// đầu, xoá sáu ô để nhập mã mới, và nói cho người dùng biết đã gửi.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/pages/otp_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGhi implements AuthRepository {
  final daGui = <String>[];
  Object? loi;

  @override
  Future<void> forgotPassword(String email) async {
    daGui.add(email);
    if (loi != null) throw loi!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RepoGhi repo;

  setUp(() {
    repo = _RepoGhi();
    sl.registerSingleton<AuthRepository>(repo);
  });
  tearDown(() async => sl.reset());

  Future<void> moTrang(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OtpPage(email: 'dat@example.com'),
    ));
    await tester.pump();
  }

  testWidgets('bấm "Gửi lại mã OTP" thì gọi forgotPassword với đúng email',
      (tester) async {
    await moTrang(tester);

    await tester.tap(find.text('Gửi lại mã OTP'));
    await tester.pump();

    expect(repo.daGui, ['dat@example.com'],
        reason: 'Nút từng là handler rỗng — bấm không gửi gì. Gửi lại phải đi '
            'đúng đường đã gửi mã lần đầu.');
  });

  testWidgets('gửi lại xong thì báo đã gửi, và xoá sáu ô mã', (tester) async {
    await moTrang(tester);
    await tester.enterText(find.byType(TextField).first, '7');

    await tester.tap(find.text('Gửi lại mã OTP'));
    await tester.pump();

    expect(find.textContaining('Đã gửi lại mã'), findsOneWidget,
        reason: 'Không nói gì thì người dùng không biết có nên mở hộp thư.');
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
      reason: 'Mã cũ đã vô hiệu; giữ chữ số cũ là để người dùng gửi nhầm.',
    );
  });

  testWidgets('gửi lại lỗi thì hiện lỗi thay vì im lặng', (tester) async {
    repo.loi = Exception('Quá nhiều yêu cầu');
    await moTrang(tester);

    await tester.tap(find.text('Gửi lại mã OTP'));
    await tester.pump();

    expect(find.text('Quá nhiều yêu cầu'), findsOneWidget);
  });
}
