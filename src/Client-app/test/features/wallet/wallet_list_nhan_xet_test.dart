/// Khối "Nhận xét" trên trang Quản lý ví (chặng 1.5).
///
/// Gói số và mẫu câu có bộ test riêng (`goi_so_vi_test.dart`); ở đây chỉ kiểm
/// **chỗ nối**: khối có dựng không, đứng đúng chỗ không, và nó có nói được
/// đúng chỗ tiền bị loại khỏi tổng hay không.
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

class _Repo implements WalletRepository {
  _Repo(this._vi);
  final List<WalletEntity> _vi;

  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => List.of(_vi);

  @override
  Future<double> getTotalBalance(int idaccount) async => _vi
      .where((w) => w.includeInTotal && w.status == 'active')
      .fold<double>(0, (s, w) => s + w.balance);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _vi(
  String id,
  String ten, {
  double soDu = 1000000,
  String status = 'active',
  bool trongTong = true,
  bool choPhepAm = false,
}) =>
    WalletEntity(
      id: id,
      idaccount: 10,
      name: ten,
      type: 'cash',
      balance: soDu,
      status: status,
      includeInTotal: trongTong,
      allowNegative: choPhepAm,
      updatedAt: DateTime(2026, 9, 10),
    );

Future<void> _moTrang(WidgetTester tester, List<WalletEntity> vis) async {
  tester.view.physicalSize = const Size(411, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  if (sl.isRegistered<WalletCubit>()) {
    await sl.unregister<WalletCubit>();
  }
  sl.registerFactory<WalletCubit>(() => WalletCubit(repository: _Repo(vis)));
  addTearDown(() async {
    if (sl.isRegistered<WalletCubit>()) {
      await sl.unregister<WalletCubit>();
    }
  });

  final auth = _AuthBlocGia();
  addTearDown(auth.close);
  auth.dat(AuthSuccess(
    user: UserModel(
        id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
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
  testWidgets('khối NÓI RA chỗ tiền bị loại khỏi tổng', (tester) async {
    await _moTrang(tester, [
      _vi('w1', 'Tiền mặt', soDu: 3000000),
      _vi('w2', 'Quỹ đen', soDu: 800000, trongTong: false),
      _vi('w3', 'Sổ cũ', soDu: 300000, status: 'inactive'),
    ]);

    expect(find.text('NHẬN XÉT'), findsOneWidget);
    expect(
        find.text('Tổng tài sản 3.000.000 đ từ 1 ví; 2 ví khác giữ '
            '1.100.000 đ không cộng vào tổng.'),
        findsOneWidget,
        reason: 'đây chính là câu trả lời cho "vì sao tổng không khớp"');
  });

  testWidgets('khối đứng GIỮA thẻ tổng quan và tiêu đề danh sách ví',
      (tester) async {
    await _moTrang(tester, [_vi('w1', 'Tiền mặt', soDu: 3000000)]);

    final yNhanXet = tester.getTopLeft(find.text('NHẬN XÉT')).dy;
    final yTieuDe = tester.getTopLeft(find.text('DANH SÁCH VÍ')).dy;
    expect(yNhanXet, lessThan(yTieuDe));
  });

  testWidgets('ví cho phép âm KHÔNG làm khối chuyển sang giọng cảnh báo',
      (tester) async {
    // Cùng luật G27: thẻ tín dụng âm là chuyện bình thường.
    await _moTrang(tester, [
      _vi('w1', 'Tiền mặt', soDu: 3000000),
      _vi('w2', 'Thẻ tín dụng', soDu: -2000000, choPhepAm: true),
    ]);
    expect(find.textContaining('ví đang âm'), findsNothing);
  });

  testWidgets('mọi ví vào tổng → câu gọn, không vế thừa', (tester) async {
    await _moTrang(tester, [_vi('w1', 'Tiền mặt', soDu: 3000000)]);
    expect(find.text('Tổng tài sản 3.000.000 đ từ 1 ví.'), findsOneWidget);
  });
}
