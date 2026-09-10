/// Màn Thêm ví trước hai ràng buộc của server (xem `rang_buoc_vi_test.dart`).
///
/// Chốt chặn thật nằm ở datasource; màn hình chỉ làm hai việc để người dùng
/// không phải đi tới tận đó rồi nhận lỗi:
///
/// 1. Khoá ô "Tiết kiệm" khi tài khoản đã có một ví Tiết kiệm, kèm một dòng
///    nói vì sao. Ô vẫn hiện — giấu đi là người dùng tưởng app thiếu loại ví.
/// 2. Báo trùng tên ngay lúc bấm Lưu, trước khi gọi cubit.
///
/// Và một lỗ có sẵn mà tệp này bịt luôn: `WalletAddPage` dựng **cubit riêng**
/// (`sl<WalletCubit>()` trong `BlocProvider`), không ai nghe `WalletError`
/// của nó — mọi lỗi ở tầng datasource khi thêm ví đều **im lặng**, rồi trang
/// pop và ví đơn giản là không có. Nay trang đọc lại state sau khi gọi
/// `addWallet`: lỗi thì hiện và ở lại.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/domain/rang_buoc_vi.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flowmoney/features/wallet/presentation/pages/wallet_add_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthBlocGia extends AuthBloc {
  _AuthBlocGia() : super(authRepository: _StubAuthRepository());

  void dat(AuthState moi) => emit(moi);
}

class _RepoGia implements WalletRepository {
  _RepoGia(this.viHienCo);

  final List<WalletEntity> viHienCo;

  /// Lỗi mà `addWallet` ném, nếu ca test dựng đường lỗi của datasource.
  Object? loiKhiThem;

  final List<({String name, String type})> luoiGoiThem = [];

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => viHienCo;

  @override
  Future<double> getTotalBalance(int idaccount) async => 0;

  @override
  Future<WalletEntity> addWallet({
    required int idaccount,
    required String name,
    required String type,
    required double balance,
    String currency = 'VND',
    String icon = 'wallet',
    String colour = '#4CAF50',
    bool isDefault = false,
    bool includeInTotal = true,
  }) async {
    if (loiKhiThem != null) throw loiKhiThem!;
    luoiGoiThem.add((name: name, type: type));
    return WalletEntity(
      id: 'moi',
      idaccount: idaccount,
      name: name,
      type: type,
      balance: balance,
      updatedAt: DateTime(2026, 9, 10),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _vi(String id, {required String name, String type = 'cash'}) =>
    WalletEntity(
      id: id,
      idaccount: 10,
      name: name,
      type: type,
      balance: 0,
      updatedAt: DateTime(2026, 9, 10),
    );

Future<void> _chamSauKhiCuon(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _moTrang(WidgetTester tester, _RepoGia repo) async {
  if (sl.isRegistered<WalletRepository>()) {
    await sl.unregister<WalletRepository>();
  }
  sl.registerSingleton<WalletRepository>(repo);
  if (sl.isRegistered<WalletCubit>()) {
    await sl.unregister<WalletCubit>();
  }
  sl.registerFactory<WalletCubit>(() => WalletCubit(repository: repo));
  addTearDown(() async {
    if (sl.isRegistered<WalletRepository>()) {
      await sl.unregister<WalletRepository>();
    }
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

  tester.view.physicalSize = const Size(411 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // Trang gọi `context.pop(true)` của go_router khi lưu xong, nên phải có một
  // router thật để đường thành công không nổ vì thiếu `GoRouter`.
  final router = GoRouter(
    initialLocation: '/them',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('GỐC')),
        // Route CON, để ngăn xếp là [/, /them] và `pop` có chỗ để về.
        routes: [
          GoRoute(path: 'them', builder: (_, __) => const WalletAddPage()),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Ô tên ví tìm theo hint, KHÔNG theo thứ tự: ô đầu tiên trên màn là ô số dư
/// (theo thiết kế Stitch), và gõ tên vào đó là tên rỗng — trang dừng ở "Vui
/// lòng nhập tên ví" và mọi ca bên dưới đỏ với thông điệp không liên quan.
final Finder _oTenVi = find.byWidgetPredicate((w) =>
    w is TextField && w.decoration?.hintText == 'Ví Tiền Mặt, Techcombank...');

Future<void> _dienTenVaLuu(WidgetTester tester, String ten) async {
  await tester.enterText(_oTenVi, ten);
  await _chamSauKhiCuon(tester, find.text('Hoàn tất & Lưu ví'));
}

void main() {
  group('ô "Tiết kiệm"', () {
    testWidgets('đã có ví Tiết kiệm thì ô bị khoá và có dòng giải thích',
        (tester) async {
      final repo = _RepoGia([_vi('a', name: 'Tiết kiệm', type: 'saving')]);
      await _moTrang(tester, repo);

      expect(find.text(thongBaoMotViTietKiem), findsOneWidget,
          reason: 'Một ô không bấm được mà không nói gì trông như app hỏng.');

      await _chamSauKhiCuon(tester, find.text('Tiết kiệm'));
      await _dienTenVaLuu(tester, 'Ví mới');

      expect(repo.luoiGoiThem.single.type, isNot('saving'),
          reason: 'Chạm vào ô bị khoá không được đổi loại ví đang chọn.');
    });

    testWidgets('chưa có ví Tiết kiệm thì chọn được như thường',
        (tester) async {
      final repo = _RepoGia([_vi('a', name: 'Tiền mặt')]);
      await _moTrang(tester, repo);

      expect(find.text(thongBaoMotViTietKiem), findsNothing);

      await _chamSauKhiCuon(tester, find.text('Tiết kiệm'));
      await _dienTenVaLuu(tester, 'Quỹ dự phòng');

      expect(repo.luoiGoiThem.single.type, 'saving');
    });
  });

  testWidgets('tên ví dừng ở độ rộng cột trên server — G31', (tester) async {
    await _moTrang(tester, _RepoGia([]));
    final boDieuKhien = tester.widget<TextField>(_oTenVi).controller!;

    await tester.enterText(_oTenVi, 'a' * (DoRongCot.tenVi + 50));
    await tester.pump();

    expect(boDieuKhien.text.length, DoRongCot.tenVi,
        reason: '`wallet.Name` là varchar(100). Với ví, server không kẹt mà CẮT '
            'âm thầm (`upsertWallet` lấy 100 ký tự đầu), rồi lượt kéo về mang '
            'bản đã cắt đè lên máy — người dùng mất đuôi tên mà không hay.');
  });

  testWidgets('trùng tên thì báo ngay, không gọi thêm ví, không rời trang',
      (tester) async {
    final repo = _RepoGia([_vi('a', name: 'Tiền mặt')]);
    await _moTrang(tester, repo);

    await _dienTenVaLuu(tester, 'tiền mặt');

    expect(find.text(thongBaoTrungTen('tiền mặt')), findsOneWidget);
    expect(repo.luoiGoiThem, isEmpty);
    expect(find.text('Thêm Ví Mới'), findsOneWidget,
        reason: 'Rời trang là mất hết những gì người dùng vừa điền.');
  });

  testWidgets('datasource từ chối thì lỗi hiện ra và trang ở lại',
      (tester) async {
    final repo = _RepoGia([])..loiKhiThem = const CacheException('Bị từ chối');
    await _moTrang(tester, repo);

    await _dienTenVaLuu(tester, 'Ví mới');

    expect(find.textContaining('Bị từ chối'), findsOneWidget,
        reason: 'Cubit của trang này không có ai nghe `WalletError`. Trước '
            'bản này mọi lỗi thêm ví đều im lặng: trang pop, ví không có.');
    expect(find.text('Thêm Ví Mới'), findsOneWidget);
    expect(find.text('GỐC'), findsNothing);
  });
}
