/// Menu hành động trên mỗi hàng ví.
///
/// `_WalletItem` chọn giữa hai widget bằng `useSwitch = wallet.type == 'bank'`:
/// ví ngân hàng hiện một `Switch`, mọi ví khác hiện `PopupMenuButton`. Hai hệ
/// quả, cả hai đều im lặng:
///
/// 1. Công tắc ấy **không ghi đi đâu cả** — `_walletSwitches` chỉ là một `Map`
///    trong `State`, rời trang là mất. Thiết kế Stitch nói rõ nó là bật/tắt ví
///    (đoạn JS của màn "Quản lý ví" log `'Wallet activated'`), tức cột `status`
///    đã có ở cả hai đầu CSDL nhưng client chưa mang.
/// 2. Vì công tắc thay CHỖ của menu, ví ngân hàng **không có** mục "Chỉnh sửa"
///    lẫn "Xóa ví" trên màn danh sách.
///
/// Tệp này canh hệ quả thứ hai. Cố ý KHÔNG canh "không được có `Switch` nào":
/// tính năng lưu trữ ví sẽ mang công tắc trở lại, gắn vào `status` thật, và một
/// phép cấm như thế sẽ chặn đúng việc cần làm.
library;

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
  _RepoMotVi(this.loai);

  final String loai;

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => [
        WalletEntity(
          id: 'w1',
          idaccount: idaccount,
          name: 'Techcombank',
          type: loai,
          balance: 35000000,
          updatedAt: DateTime(2026, 9, 9),
        ),
      ];

  @override
  Future<double> getTotalBalance(int idaccount) async => 35000000;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _moTrang(WidgetTester tester, WalletRepository repo) async {
  if (sl.isRegistered<WalletCubit>()) {
    await sl.unregister<WalletCubit>();
  }
  sl.registerFactory<WalletCubit>(() => WalletCubit(repository: repo));
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
      // Bẫy 4.11: theme của app ép mọi `ElevatedButton` rộng vô hạn, nên widget
      // test phải dựng bằng chính theme ấy thay vì theme mặc định.
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WalletListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final loai in ['bank', 'cash', 'saving']) {
    testWidgets('ví loại "$loai" có menu hành động trên hàng', (tester) async {
      await _moTrang(tester, _RepoMotVi(loai));

      expect(find.byIcon(Icons.more_vert), findsOneWidget,
          reason: 'Mọi loại ví phải có cùng bộ hành động. Ví ngân hàng trước '
              'đây hiện công tắc THAY CHỖ menu, nên nó không có đường nào tới '
              '"Chỉnh sửa" hay "Xóa ví" từ màn danh sách.');

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Xóa ví'), findsOneWidget,
          reason: 'Xoá ví là hành động duy nhất trên màn này không làm được '
              'bằng cách chạm vào hàng — chạm vào hàng chỉ mở trang sửa.');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
