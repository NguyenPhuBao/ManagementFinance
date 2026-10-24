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
        await storage.read(key: AppConstants.offlineUserDataKey),
      ];

  Future<List<String?>> docKhoaCu() async => [
        await storage.read(key: AppConstants.offlineUsernameKey),
        await storage.read(key: AppConstants.offlinePasswordHashKey),
      ];

  // Siết bảo mật đợt 2 (2026-10-24): bản cũ ghi tên đăng nhập + SHA-256 KHÔNG salt của mật khẩu thật sau mỗi lần đăng
  // nhập, mà không chỗ nào đọc (không có đăng nhập offline bằng mật khẩu). Băm nhanh không salt của mật khẩu người dùng
  // chọn là bẻ được trong vài giây tới vài giờ — một bản sao thừa của mật khẩu thật nằm trên máy.
  test('đăng nhập KHÔNG lưu tên đăng nhập và băm mật khẩu', () async {
    await repo.login('dat', 'mat-khau-thu');

    expect(await docKho(), everyElement(isNotNull), reason: 'tiền đề: đăng nhập vẫn lưu token + người dùng');
    expect(await docKhoaCu(), everyElement(isNull),
        reason: 'không ai đọc hai khoá này — lưu là giữ một bản bẻ được của mật khẩu thật');
  });

  test('đăng nhập dọn hai khoá cũ do bản trước ghi', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.offlineUsernameKey: 'dat',
      AppConstants.offlinePasswordHashKey: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    });

    await repo.login('dat', 'mat-khau-thu');

    expect(await docKhoaCu(), everyElement(isNull),
        reason: 'máy đã cài bản cũ còn giữ băm mật khẩu tới lần đăng xuất kế — dọn ngay lần đăng nhập đầu');
  });

  test('xoá cả token lẫn bộ nhớ đệm người dùng, KHÔNG gọi logout từ xa',
      () async {
    await repo.login('dat', 'mat-khau-thu');
    expect(await docKho(), everyElement(isNotNull),
        reason: 'phải có gì đó để mất thì ca test này mới nói được điều gì');
    // Khoá cũ của bản trước (máy chưa đăng nhập lại từ khi nâng cấp) — xoá phiên cũng phải dọn.
    await storage.write(key: AppConstants.offlinePasswordHashKey, value: 'bam-cu');

    await repo.xoaPhienTrenMay();

    expect(remote.soLanGoiLogoutTuXa, 0,
        reason: '/auth/logout đi qua authenticate — gọi nó khi tài khoản đã bị '
            'khoá là tự sinh thêm một 401 mang mã quay vòng qua interceptor');
    expect(await docKho(), everyElement(isNull),
        reason: 'bỏ sót bộ nhớ đệm là người kế tiếp mở app thấy tên tài khoản cũ');
    expect(await docKhoaCu(), everyElement(isNull));
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
