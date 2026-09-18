/// Liên kết ngân hàng đã bị **bỏ khỏi sản phẩm** (quyết định của nhóm,
/// 2026-09-18).
///
/// Phần client của nó chưa bao giờ chạy thật: `bank_link_page.dart` là một màn
/// mockup tĩnh — số điện thoại `0912345678` và sáu ô OTP điền sẵn ghi cứng
/// trong `initState`, nút "Xác nhận" không gọi một endpoint nào. Nó vẫn nối
/// vào router và vẫn có một thẻ dẫn tới nó ở màn Quản lý ví, nên người dùng
/// chạm vào là gặp một màn giả vờ đăng nhập ngân hàng.
///
/// Tệp này canh hai điều, và điều thứ hai mới là cái dễ hỏng:
///
/// 1. Màn Quản lý ví không còn thẻ dẫn vào luồng ấy.
/// 2. **Không tệp nào trong `lib/` còn trỏ tới đường `bank-link`** — dù là
///    định nghĩa route hay một lời `context.push`. Gỡ route mà quên lời gọi
///    (hoặc ngược lại) không làm `flutter analyze` đỏ: chuỗi đường dẫn chỉ là
///    một chuỗi, nên lỗi chỉ hiện ra khi ai đó chạm đúng nút và go_router dựng
///    màn báo lỗi.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flowmoney/features/wallet/presentation/pages/wallet_list_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthBlocGia extends AuthBloc {
  _AuthBlocGia() : super(authRepository: _StubAuthRepository());

  void dat(AuthState moi) => emit(moi);
}

class _RepoMotVi implements WalletRepository {
  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => [
        WalletEntity(
          id: 'w1',
          idaccount: idaccount,
          name: 'Tiền mặt',
          type: 'cash',
          balance: 1500000,
          updatedAt: DateTime(2026, 9, 18),
        ),
      ];

  @override
  Future<double> getTotalBalance(int idaccount) async => 1500000;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _moTrang(WidgetTester tester) async {
  if (sl.isRegistered<WalletCubit>()) {
    await sl.unregister<WalletCubit>();
  }
  sl.registerFactory<WalletCubit>(() => WalletCubit(repository: _RepoMotVi()));
  addTearDown(() async {
    if (sl.isRegistered<WalletCubit>()) {
      await sl.unregister<WalletCubit>();
    }
  });

  final auth = _AuthBlocGia();
  addTearDown(auth.close);
  auth.dat(AuthSuccess(
    user: UserModel(
      id: '10',
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
    ),
  ));

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      // Bẫy 4.11: theme của app ép mọi `ElevatedButton` rộng vô hạn.
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WalletListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('màn Quản lý ví không còn thẻ dẫn vào liên kết ngân hàng',
      (tester) async {
    await _moTrang(tester);

    expect(find.text('LIÊN KẾT NGÂN HÀNG'), findsNothing,
        reason: 'Thẻ này là lối vào duy nhất của một màn mockup không gọi '
            'endpoint nào. Giữ nó lại sau khi tính năng bị bỏ là mời người '
            'dùng nhập tên đăng nhập ngân hàng vào một biểu mẫu không đi đâu '
            'cả.');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('màn Quản lý ví vẫn dựng bình thường sau khi bỏ thẻ ấy',
      (tester) async {
    await _moTrang(tester);

    expect(find.text('Tiền mặt'), findsWidgets,
        reason: 'Ca trên chỉ đòi VẮNG MẶT một chuỗi, nên nó cũng xanh khi cả '
            'trang không dựng nổi. Ca này đòi trang còn sống — cùng bài học '
            'G43: test phải đòi kết quả, không chỉ đòi vắng mặt.');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('không tệp nào trong lib/ còn trỏ tới đường bank-link', () {
    final tro = RegExp(r'''bank-link''');

    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final duongDan = f.path.replaceAll(r'\', '/');
      final dongs = f.readAsLinesSync();
      for (var i = 0; i < dongs.length; i++) {
        if (tro.hasMatch(dongs[i])) viPham.add('$duongDan:${i + 1}');
      }
    }

    expect(viPham, isEmpty,
        reason: 'Route và lời gọi điều hướng là hai chuỗi rời nhau — gỡ một '
            'bên mà quên bên kia thì trình phân tích tĩnh không nói gì, và '
            'người dùng gặp màn báo lỗi của go_router khi chạm đúng nút. '
            'Luật một chiều: đường này đã bỏ, không ai được dựng lại nó.');
  });
}
