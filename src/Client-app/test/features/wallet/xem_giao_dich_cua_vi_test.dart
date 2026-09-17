/// Đường tắt "Xem giao dịch" từ màn Quản lý ví.
///
/// ## Vì sao là một mục menu chứ không phải cú tap
///
/// Bộ lọc theo ví **vốn đã có** trên trang Sổ giao dịch (chíp "Ví" của
/// `TransactionFilterBar`) — thứ thiếu chỉ là đường tắt. Và cú tap vào thẻ ví
/// đã bị chiếm: nó mở màn **Sửa ví**. Đổi ý nghĩa của nó là lấy mất một thao
/// tác người dùng đã quen, nên "Xem giao dịch" vào **menu ba chấm**, đặt trước
/// "Chỉnh sửa".
///
/// ## Hai điều tệp này canh
///
/// 1. Mục có mặt ở **cả hai** nhóm thẻ — ví thường và ví **đã lưu trữ**. Xem
///    lại lịch sử của một ví đã đóng băng là việc hợp lý; lưu trữ nói về việc
///    ghi chép MỚI, không phải về quyền đọc lịch sử cũ.
/// 2. Nó mở `/transactions` kèm **mã ví** đúng. Query param chứ không `extra`:
///    `extra` mất khi GoRouter dựng lại route, query param thì sống sót.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

class _RepoChiDoc implements WalletRepository {
  _RepoChiDoc(this._vi);

  final List<WalletEntity> _vi;

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => _vi;

  /// ⚠️ `WalletCubit.loadWallets` gọi CẢ hai hàm này. Thiếu hàm dưới thì cubit
  /// kẹt ở `WalletLoading`, trang hiện `CircularProgressIndicator` — một
  /// animation vô hạn — và `pumpAndSettle` **treo vĩnh viễn** thay vì đỏ. Đã
  /// vấp thật khi viết tệp này: một lượt `flutter test` chạy quá 10 phút.
  @override
  Future<double> getTotalBalance(int idaccount) async => _vi
      .where((w) => w.includeInTotal && w.status == 'active')
      .fold<double>(0, (s, w) => s + w.balance);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _viMau(
  String id,
  String ten, {
  String status = 'active',
  bool isDefault = false,
}) =>
    WalletEntity(
      id: id,
      idaccount: 10,
      name: ten,
      type: 'cash',
      balance: 1000000,
      status: status,
      isDefault: isDefault,
      updatedAt: DateTime(2026, 9, 10),
    );

void main() {
  /// Đường mà màn Quản lý ví vừa điều hướng tới, gồm cả query param.
  late String? duongDaMo;

  Future<void> moTrang(WidgetTester tester, List<WalletEntity> vi) async {
    duongDaMo = null;

    if (sl.isRegistered<WalletCubit>()) {
      await sl.unregister<WalletCubit>();
    }
    sl.registerFactory<WalletCubit>(
        () => WalletCubit(repository: _RepoChiDoc(vi)));
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

    // GoRouter thật (không `MaterialApp(home:)`) vì mục menu gọi
    // `context.push`. Route `/transactions` là bản giả chỉ để ghi lại đường
    // đã mở — dựng `TransactionPage` thật ở đây là kéo theo cả DI của nó.
    final router = GoRouter(
      initialLocation: '/wallets',
      routes: [
        GoRoute(
          path: '/wallets',
          builder: (_, __) => const WalletListPage(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (_, state) {
            duongDaMo = state.uri.toString();
            return const Scaffold(body: Text('SỔ GIAO DỊCH'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        // Bẫy 4.11: theme của app ép mọi `ElevatedButton` rộng vô hạn, nên
        // widget test phải dựng bằng chính theme ấy.
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Mở menu ba chấm của thẻ thứ [thu] (đếm từ 0) rồi chọn [muc].
  Future<void> chonTrongMenu(WidgetTester tester, int thu, String muc) async {
    final nut = find.byIcon(Icons.more_vert);
    await tester.ensureVisible(nut.at(thu));
    await tester.tap(nut.at(thu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(muc));
    await tester.pumpAndSettle();
  }

  testWidgets('ví thường: menu có "Xem giao dịch" và nó mở đúng ví',
      (tester) async {
    await moTrang(tester, [_viMau('w-tien-mat', 'Tiền mặt')]);

    await chonTrongMenu(tester, 0, 'Xem giao dịch');

    expect(find.text('SỔ GIAO DỊCH'), findsOneWidget);
    expect(duongDaMo, '/transactions?wallet=w-tien-mat',
        reason: 'Mã ví phải đi kèm trong query param. Mở trang không kèm gì '
            'thì người dùng thấy toàn bộ sổ và tưởng đường tắt hỏng; còn dùng '
            '`extra` thì tham số mất khi GoRouter dựng lại route.');
  });

  testWidgets('ví ĐÃ LƯU TRỮ cũng xem được giao dịch', (tester) async {
    await moTrang(tester, [
      _viMau('w-hoat-dong', 'Tiền mặt', isDefault: true),
      _viMau('w-luu-tru', 'Thẻ cũ', status: 'inactive'),
    ]);

    // Thẻ ví lưu trữ nằm ở mục "ĐÃ LƯU TRỮ" phía dưới — nó là thẻ thứ hai.
    await chonTrongMenu(tester, 1, 'Xem giao dịch');

    expect(duongDaMo, '/transactions?wallet=w-luu-tru',
        reason: 'Lưu trữ nói về việc ghi chép MỚI, không phải về quyền đọc '
            'lịch sử cũ. Giấu mục này ở ví lưu trữ là khoá người dùng khỏi '
            'chính dữ liệu của họ.');
  });

  testWidgets('"Xem giao dịch" đứng TRƯỚC "Chỉnh sửa"', (tester) async {
    await moTrang(tester, [_viMau('w1', 'Tiền mặt')]);

    final nut = find.byIcon(Icons.more_vert);
    await tester.ensureVisible(nut.first);
    await tester.tap(nut.first);
    await tester.pumpAndSettle();

    final yXem = tester.getTopLeft(find.text('Xem giao dịch')).dy;
    final ySua = tester.getTopLeft(find.text('Chỉnh sửa')).dy;
    expect(yXem, lessThan(ySua),
        reason: 'Xem là việc làm thường xuyên hơn sửa, nên nó đứng trước. Và '
            'hành động không hoàn tác được ("Xóa ví") vẫn ở cuối cùng.');
  });
}
