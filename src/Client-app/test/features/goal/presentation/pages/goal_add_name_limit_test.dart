/// Ô tên ở màn Thêm / Sửa mục tiêu dừng ở độ rộng cột trên server — G31.
///
/// Vì sao tệp riêng: màn này chưa có widget test nào, và nó dựng hai cubit qua
/// `sl`, nên cần một khung dựng riêng. Tệp chỉ canh MỘT điều — ô tên — vì phép
/// đếm code point đã có test thuần ở `core/utils/gioi_han_do_dai_test.dart`.
///
/// Một ca canh cả hai đường ghi: màn này dùng chung cho Thêm và Sửa (`goalId`).
///
/// Hai thứ trong khung dựng không liên quan tới ô tên — ghi lại để khỏi gỡ nhầm:
///
/// - **Ảnh đầu trang tải từ mạng** (`NetworkImage` ở đầu biểu mẫu). Trong
///   `flutter test` mọi request HTTP trả 400, nên ảnh ném
///   `NetworkImageLoadException` và làm đỏ test. Khung dựng đưa vào một
///   `HttpClient` giả trả ảnh PNG trong suốt 1×1, qua móc
///   `debugNetworkImageHttpClientProvider` có sẵn của Flutter.
/// - **Bề ngang dựng rộng**, không phải 411dp. Ở 411dp bộ test báo tràn ở hai
///   hàng chữ của trang (35px và 157px), mà font của bộ test rộng hơn ngoài
///   đời nhiều (bẫy 4.4 `docs/ANALYTICS_FEATURE.md`). Đã kiểm trên
///   `emulator-5554` ngày 2026-09-10: cuộn hết form ở 411dp, không một pixel
///   vàng nào — hai con số ấy là của font bộ test, không phải lỗi bố cục thật.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/goal/presentation/bloc/goal_cubit.dart';
import 'package:flowmoney/features/goal/presentation/pages/goal_add_page.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());
  final AuthState _fixed;
  @override
  AuthState get state => _fixed;
}

class _StubGoalRepository implements GoalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubWalletRepository implements WalletRepository {
  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => [
        WalletEntity(
          id: 'w1',
          idaccount: 10,
          name: 'Tiết kiệm',
          type: 'saving',
          balance: 0,
          updatedAt: DateTime(2026, 9, 10),
        ),
      ];

  @override
  Future<double> getTotalBalance(int idaccount) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// PNG trong suốt 1×1, thay cho ảnh mạng ở đầu trang.
const List<int> _pngTrongSuot = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
];

class _HttpClientGia implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _YeuCauGia();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _YeuCauGia implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _PhanHoiGia();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhanHoiGia extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _pngTrongSuot.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_pngTrongSuot).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    sl.registerFactory<GoalCubit>(
        () => GoalCubit(repository: _StubGoalRepository()));
    if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
    sl.registerFactory<WalletCubit>(
        () => WalletCubit(repository: _StubWalletRepository()));
  });

  tearDown(() async {
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
  });

  testWidgets('tên mục tiêu dừng ở độ rộng cột trên server — G31',
      (tester) async {
    // Đặt lại TRONG thân test: bộ test kiểm biến debug của painting đã được
    // trả về null ngay khi thân test kết thúc, trước cả `tearDown`.
    debugNetworkImageHttpClientProvider = _HttpClientGia.new;
    try {
      tester.view.physicalSize = const Size(1600, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = _FixedAuthBloc(AuthSuccess(
        user: UserModel(
          id: '10',
          username: 'dat',
          name: 'Đạt',
          email: 'dat@example.com',
        ),
      ));
      addTearDown(auth.close);

      await tester.pumpWidget(BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GoalAddPage(),
        ),
      ));
      await tester.pumpAndSettle();

      final oTen = find.byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.hintText == 'e.g. Mua Laptop MacBook Pro');
      final boDieuKhien = tester.widget<TextField>(oTen).controller!;

      await tester.enterText(oTen, 'a' * (DoRongCot.tenMucTieu + 50));
      await tester.pump();

      expect(boDieuKhien.text.length, DoRongCot.tenMucTieu,
          reason: '`goal.Name` là varchar(100) và `upsertGoal` không cắt chuỗi. '
              'Tên dài hơn vỡ P2000 ở /sync/push; backend trả '
              'CONSTRAINT_VIOLATION (trước 7675b35 là DB_ERROR, gửi lại mãi), '
              'nên mục tiêu thành lỗi vĩnh viễn và không bao giờ lên server.');
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });
}
