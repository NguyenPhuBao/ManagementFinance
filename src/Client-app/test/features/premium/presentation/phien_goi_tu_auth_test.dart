/// `phienGoiTu` dịch `AuthState` sang phiên mà `GoiRepository.noiPhien` hiểu
/// (spec Premium 6.4) — repository không biết `AuthBloc`.
library;

import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/premium/presentation/phien_goi_tu_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthSuccess có user → (idaccount, type); user null / id rác / state khác → null',
      () {
    final p = phienGoiTu(AuthSuccess(
        user: UserModel(
            id: '10',
            username: 'a',
            name: 'A',
            email: 'a@x',
            loaiTaiKhoan: 'Premium')))!;
    expect(p.idaccount, 10);
    expect(p.loaiPhien, 'Premium');
    expect(phienGoiTu(const AuthSuccess()), isNull);
    expect(
        phienGoiTu(AuthSuccess(
            user: UserModel(id: 'x', username: 'a', name: 'A', email: 'a@x'))),
        isNull);
    expect(phienGoiTu(const AuthUnauthenticated()), isNull);
    expect(phienGoiTu(AuthLoading()), isNull);
  });
}
