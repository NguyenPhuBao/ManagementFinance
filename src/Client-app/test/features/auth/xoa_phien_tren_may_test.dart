/// `xoaPhienTrenMay()` — xoá phiên trên máy mà KHÔNG gọi `/auth/logout`.
///
/// Vì sao cần một đường riêng cạnh `logout()`: route `/auth/logout` đi qua
/// `authenticate` (`auth.routes.js:33`). Khi tài khoản đã bị khoá hoặc xoá, nó
/// trả 401 **mang mã** rồi quay vòng qua `AuthInterceptor` — thêm một thông báo
/// cưỡng chế đăng xuất nữa, ngay giữa lúc app đang đăng xuất vì thông báo thứ
/// nhất. Spec cưỡng chế đăng xuất §3.5 bước 4.
library;

import 'package:flowmoney/core/constants/app_constants.dart';
import 'package:flowmoney/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:flowmoney/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _RemoteGia implements AuthRemoteDataSource {
  int soLanGoiLogoutTuXa = 0;

  @override
  Future<Map<String, dynamic>> login(String username, String password) async => {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'pendingDeleteCancelled': false,
        'user': {
          'idaccount': 11,
          'username': 'dat',
          'fullname': 'Đạt',
          'email': 'dat@example.com',
          'rolename': 'user',
          'status': 'Active',
          'countdown': null,
        },
      };

  @override
  Future<void> logout(String accessToken) async {
    soLanGoiLogoutTuXa++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RemoteGia remote;
  late AuthRepositoryImpl repo;
  late FlutterSecureStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    remote = _RemoteGia();
    repo = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(secureStorage: storage),
      secureStorage: storage,
    );
  });

  Future<List<String?>> docKho() async => [
        await storage.read(key: AppConstants.accessTokenKey),
        await storage.read(key: AppConstants.refreshTokenKey),
        await storage.read(key: AppConstants.offlineUsernameKey),
        await storage.read(key: AppConstants.offlinePasswordHashKey),
        await storage.read(key: AppConstants.offlineUserDataKey),
      ];

  test('xoá cả token lẫn bộ nhớ đệm người dùng, KHÔNG gọi logout từ xa',
      () async {
    await repo.login('dat', 'mat-khau-thu');
    expect(await docKho(), everyElement(isNotNull),
        reason: 'phải có gì đó để mất thì ca test này mới nói được điều gì');

    await repo.xoaPhienTrenMay();

    expect(remote.soLanGoiLogoutTuXa, 0,
        reason: '/auth/logout đi qua authenticate — gọi nó khi tài khoản đã bị '
            'khoá là tự sinh thêm một 401 mang mã quay vòng qua interceptor');
    expect(await docKho(), everyElement(isNull),
        reason: 'bỏ sót bộ nhớ đệm là người kế tiếp mở app thấy tên tài khoản cũ');
  });

  test('gọi hai lần liên tiếp cũng không sao', () async {
    await repo.login('dat', 'mat-khau-thu');

    await repo.xoaPhienTrenMay();
    await repo.xoaPhienTrenMay();

    expect(await docKho(), everyElement(isNull),
        reason: 'AuthBloc gọi nó SAU khi interceptor đã xoá token (§3.3), nên '
            'lần thứ hai là chuyện thường');
  });

  test('logout() vẫn gọi server như cũ — không bị đường mới thay mất', () async {
    await repo.login('dat', 'mat-khau-thu');

    await repo.logout();

    expect(remote.soLanGoiLogoutTuXa, 1,
        reason: 'người dùng tự bấm Đăng xuất thì server PHẢI thu hồi token');
  });
}
