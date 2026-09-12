/// `AuthBloc` và trạng thái chờ xoá — spec cưỡng chế đăng xuất §4.3, §5.2.
library;

import 'dart:async';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/an_the_cho_xoa.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({String status = 'Active', int? countdown}) => UserModel(
      id: '11',
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
      status: status,
      countdown: countdown,
    );

class _RepoGia implements AuthRepository {
  _RepoGia(this.cached);

  UserModel? cached;
  int getCurrentUserCalls = 0;

  /// Mô phỏng `verifySession` đồng bộ `status` từ `/auth/profile` vào bộ nhớ đệm.
  UserModel? sauKhiXacMinh;

  /// Chặn `getCurrentUser()` lại giữa chừng để dựng race với một handler khác
  /// (đăng xuất) đang chạy đồng thời — khác `null` thì đợi tới khi được `complete()`.
  Completer<void>? chanDoc;

  @override
  Future<bool> checkAuthStatus() async => true;

  @override
  Future<UserModel?> getCurrentUser() async {
    getCurrentUserCalls++;
    if (chanDoc != null) await chanDoc!.future;
    return cached;
  }

  @override
  Future<SessionStatus> verifySession() async {
    if (sauKhiXacMinh != null) cached = sauKhiXacMinh;
    return SessionStatus.valid;
  }

  @override
  Future<UserModel> login(String username, String password) async => cached!;

  /// `_onLogoutRequested` gọi hàm này trước `emit(AuthUnauthenticated())`; không
  /// override thì rơi vào `noSuchMethod` và ném lỗi, chặn luôn state ấy.
  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() async => sl.reset());

  Future<AuthBloc> moApp(_RepoGia repo) async {
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    final xong = bloc.stream
        .firstWhere((s) => s is AuthSuccess || s is AuthUnauthenticated);
    bloc.add(AuthCheckRequested());
    await xong.timeout(const Duration(seconds: 5));
    return bloc;
  }

  test('mở app đọc người dùng SAU khi xác minh phiên', () async {
    final repo = _RepoGia(_user())..sauKhiXacMinh = _user(status: 'PendingDelete');
    final bloc = await moApp(repo);
    expect((bloc.state as AuthSuccess).user!.dangChoXoa, isTrue,
        reason: 'Đọc trước verifySession là bỏ lỡ yêu cầu xoá gửi từ máy khác cho tới lần mở app sau nữa.');
  });

  test('ThongTinTaiKhoanThayDoi đọc lại bộ nhớ đệm và phát AuthSuccess mới', () async {
    final repo = _RepoGia(_user());
    final bloc = await moApp(repo);
    repo.cached = _user(status: 'PendingDelete', countdown: 30);
    final moi = bloc.stream.first;
    bloc.add(ThongTinTaiKhoanThayDoi());
    final state = await moi.timeout(const Duration(seconds: 5));
    expect(state, isA<AuthSuccess>());
    expect((state as AuthSuccess).user!.countdown, 30);
  });

  test('ThongTinTaiKhoanThayDoi khi chưa đăng nhập thì bỏ qua', () async {
    final repo = _RepoGia(_user());
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    bloc.add(ThongTinTaiKhoanThayDoi());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state, isA<AuthInitial>());
    expect(repo.getCurrentUserCalls, 0);
  });

  test('đăng nhập thành công đặt lại cờ "Để sau"', () async {
    final anThe = AnTheChoXoa()..value = true;
    sl.registerSingleton<AnTheChoXoa>(anThe);
    final repo = _RepoGia(_user());
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    final xong = bloc.stream.firstWhere((s) => s is AuthSuccess);
    bloc.add(const LoginSubmitted(email: 'dat', password: 'mat-khau-thu'));
    await xong.timeout(const Duration(seconds: 5));
    expect(anThe.value, isFalse,
        reason: 'Người đăng nhập sau không được thừa hưởng lựa chọn "Để sau" của người trước.');
  });

  test(
      'đăng xuất trong lúc ThongTinTaiKhoanThayDoi đang đọc bộ nhớ đệm → '
      'không được quay lại AuthSuccess cũ', () async {
    final repo = _RepoGia(_user());
    final bloc = await moApp(repo);

    // Chặn getCurrentUser() của ThongTinTaiKhoanThayDoi giữa chừng, rồi cho
    // đăng xuất chạy và phát AuthUnauthenticated TRƯỚC khi lượt đọc kia xong.
    repo.chanDoc = Completer<void>();
    bloc.add(ThongTinTaiKhoanThayDoi());
    await Future<void>.delayed(Duration.zero);

    final dangXuat = bloc.stream.firstWhere((s) => s is AuthUnauthenticated);
    bloc.add(LogoutRequested());
    await dangXuat.timeout(const Duration(seconds: 5));

    // Giờ mở khoá: getCurrentUser() trả về, ThongTinTaiKhoanThayDoi được đi tiếp.
    repo.chanDoc!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state, isA<AuthUnauthenticated>(),
        reason: 'Handler của hai loại sự kiện chạy đồng thời (mặc định của '
            'flutter_bloc) — ThongTinTaiKhoanThayDoi đọc xong SAU khi đăng xuất '
            'không được phát AuthSuccess cũ đè lên AuthUnauthenticated.');
  });
}
