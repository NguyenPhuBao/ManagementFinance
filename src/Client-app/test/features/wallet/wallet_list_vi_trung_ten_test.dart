/// G63 — chỗ nối của thẻ "VÍ TRÙNG TÊN" và nhãn CHƯA ĐỒNG BỘ trên trang Quản lý ví (spec mục 5.1, 5.2; màn
/// Stitch `c5a2cecebc9f4959966346b3e99b4d47`).
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/data/vi_trung_ten_nguon.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flowmoney/features/wallet/presentation/pages/wallet_list_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<double> getTotalBalance(int idaccount) async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NguonGia implements ViTrungTenNguon {
  _NguonGia(this.ds);
  final List<CapViHienThi> ds;
  @override
  Stream<List<CapViHienThi>> theoDoi(int idaccount) => Stream.value(ds);
  @override
  Future<Set<String>> viCanTha(int idaccount) async => {};
  @override
  Future<Set<String>> viDangBiGiu(int idaccount) async => {for (final c in ds) c.idViMayNay};
}

WalletEntity _vi(String id, String ten, {bool tuChoi = false, bool macDinh = false}) => WalletEntity(
      id: id,
      idaccount: 10,
      name: ten,
      type: 'bank',
      balance: 1000000,
      isDefault: macDinh,
      biTuChoiTrungTen: tuChoi,
      updatedAt: DateTime(2026, 10, 5),
    );

const _capMau = CapViHienThi(
  idViMayNay: 'r',
  idViDaDongBo: 'p',
  ten: 'Ví MB Bank',
  soDuMayNay: 1000000,
  soDuDaDongBo: 1000000,
  soGiaoDich: 2,
);

Future<void> _moTrang(
  WidgetTester tester,
  List<WalletEntity> vis,
  ViTrungTenNguon nguon, {
  Size kho = const Size(411, 2400),
}) async {
  tester.view.physicalSize = kho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
  sl.registerFactory<WalletCubit>(() => WalletCubit(repository: _Repo(vis)));
  if (sl.isRegistered<ViTrungTenNguon>()) await sl.unregister<ViTrungTenNguon>();
  sl.registerSingleton<ViTrungTenNguon>(nguon);
  addTearDown(() async {
    if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
    if (sl.isRegistered<ViTrungTenNguon>()) await sl.unregister<ViTrungTenNguon>();
  });

  final auth = _AuthBlocGia();
  addTearDown(auth.close);
  auth.dat(AuthSuccess(user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com')));

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      // Bẫy 4.11: theme của app ép mọi `ElevatedButton` rộng vô hạn.
      child: MaterialApp(theme: AppTheme.lightTheme, home: const WalletListPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('⭐ thẻ đứng TRÊN thẻ Tổng tài sản', (tester) async {
    await _moTrang(tester, [_vi('p', 'Ví MB Bank'), _vi('r', 'Ví MB Bank', tuChoi: true)], _NguonGia([_capMau]));
    expect(find.byKey(const ValueKey('the-vi-trung-ten')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('the-vi-trung-ten'))).dy,
        lessThan(tester.getTopLeft(find.text('TỔNG TÀI SẢN')).dy));
  });

  testWidgets('⭐ nhãn CHƯA ĐỒNG BỘ chỉ trên ví bị giữ (tính từ danh sách của trang)', (tester) async {
    await _moTrang(tester, [_vi('p', 'Ví MB Bank'), _vi('r', 'Ví MB Bank', tuChoi: true)], _NguonGia([_capMau]));
    expect(find.byKey(const ValueKey('nhan-chua-dong-bo')), findsOneWidget);
    expect(find.text('CHƯA ĐỒNG BỘ'), findsOneWidget);
  });

  testWidgets('cờ mà không còn ví cùng tên → KHÔNG có nhãn (bẫy 2)', (tester) async {
    await _moTrang(tester, [_vi('p', 'Ví MoMo'), _vi('r', 'Ví MB Bank', tuChoi: true)], _NguonGia(const []));
    expect(find.byKey(const ValueKey('nhan-chua-dong-bo')), findsNothing);
  });

  testWidgets('360 dp: tên ví dài + MẶC ĐỊNH + CHƯA ĐỒNG BỘ → không tràn', (tester) async {
    const ten = 'Ví ngân hàng MB Bank chi nhánh Hà Nội số hai của gia đình';
    await _moTrang(
      tester,
      [_vi('p', ten), _vi('r', ten, tuChoi: true, macDinh: true)],
      _NguonGia(const []),
      kho: const Size(360, 2400),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('nhan-chua-dong-bo')), findsOneWidget,
        reason: 'không tràn mà nhãn bị đẩy khỏi màn thì cũng là hỏng — tên phải co, nhãn phải còn');
    final nhan = tester.getRect(find.byKey(const ValueKey('nhan-chua-dong-bo')));
    expect(nhan.right, lessThanOrEqualTo(360), reason: 'nhãn phải nằm trọn trong khổ màn');
  });
}
