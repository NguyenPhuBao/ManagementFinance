/// Canh chừng G4: bốn trang từng tự chép một hàm lấy `idaccount` với
/// `?? 1` và `return 1`. `idaccount = 1` là tài khoản ADMIN THẬT, không phải
/// giá trị "chưa biết" — ghi dữ liệu dưới id đó là ghi vào tài khoản người
/// khác.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/auth/current_account.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Bloc chỉ để giữ một trạng thái cố định — không chạy luồng đăng nhập thật.
class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());

  final AuthState _fixed;

  @override
  AuthState get state => _fixed;
}

UserModel _user(String id) => UserModel(
      id: id,
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
    );

Future<int?> _readIdWith(WidgetTester tester, AuthState authState) async {
  int? seen;
  var read = false;
  final bloc = _FixedAuthBloc(authState);
  addTearDown(bloc.close);

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: Builder(
        builder: (context) {
          seen = currentAccountIdOrNull(context);
          read = true;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  expect(read, isTrue);
  return seen;
}

void main() {
  testWidgets('Phiên hợp lệ → trả đúng idaccount của phiên', (tester) async {
    expect(await _readIdWith(tester, AuthSuccess(user: _user('10'))), 10);
  });

  testWidgets('Chưa đăng nhập → null, KHÔNG phải 1', (tester) async {
    expect(
      await _readIdWith(tester, AuthInitial()),
      isNull,
      reason: 'Trả 1 ở đây nghĩa là mọi thao tác ghi lúc chưa đăng nhập đều '
          'rơi vào tài khoản admin thật.',
    );
  });

  testWidgets('Đã đăng xuất → null', (tester) async {
    expect(await _readIdWith(tester, AuthUnauthenticated()), isNull);
  });

  testWidgets('id không phân giải được → null, KHÔNG phải 1', (tester) async {
    expect(
      await _readIdWith(tester, AuthSuccess(user: _user('khong-phai-so'))),
      isNull,
      reason: 'Fallback `int.tryParse(...) ?? 1` cũ biến một id hỏng thành '
          'danh tính admin, và hỏng hoàn toàn im lặng.',
    );
  });

  testWidgets('id bằng 0 hoặc âm → null', (tester) async {
    expect(await _readIdWith(tester, AuthSuccess(user: _user('0'))), isNull);
    expect(await _readIdWith(tester, AuthSuccess(user: _user('-3'))), isNull);
  });
}
