import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/khoa_app/presentation/state/phien_dau_khoa_app.dart';
import 'package:flutter_test/flutter_test.dart';

/// M10: dây P2 của `main.dart` (từng là lỗi Chặn — mở app không token bị lớp phủ đặc che màn Đăng nhập mãi) không có test
/// nào dựng `main.dart`; hàm thuần này là chỗ canh.
void main() {
  final user = UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com');

  test('AuthSuccess đã có → biết phiên, kèm tài khoản', () {
    final r = phienDauChoKhoaApp(AuthSuccess(user: user), '/home');
    expect((r.daBiet, r.idaccount), (true, 10));
  });

  test('AuthUnauthenticated đã có → biết: không phiên', () {
    final r = phienDauChoKhoaApp(const AuthUnauthenticated(), '/login');
    expect((r.daBiet, r.idaccount), (true, null));
  });

  test('P2: AuthInitial + route đầu /login (không token) → biết: không phiên (không kẹt lớp phủ đặc)', () {
    final r = phienDauChoKhoaApp(AuthInitial(), '/login');
    expect((r.daBiet, r.idaccount), (true, null));
  });

  test('AuthInitial + route đầu /home (có token, đang kiểm) → chưa biết, chờ stream', () {
    final r = phienDauChoKhoaApp(AuthInitial(), '/home');
    expect((r.daBiet, r.idaccount), (false, null));
    expect(phienDauChoKhoaApp(AuthChecking(), '/home').daBiet, isFalse);
  });

  test('laTrangThaiPhienRo: chỉ AuthSuccess / AuthUnauthenticated', () {
    expect(laTrangThaiPhienRo(AuthSuccess(user: user)), isTrue);
    expect(laTrangThaiPhienRo(const AuthUnauthenticated()), isTrue);
    expect(laTrangThaiPhienRo(AuthLoading()), isFalse);
    expect(laTrangThaiPhienRo(AuthInitial()), isFalse);
  });
}
