/// Bộ nhớ đệm trạng thái chờ xoá của `AuthRepositoryImpl` — spec cưỡng chế đăng
/// xuất §4.3. Canh G33: gửi yêu cầu xoá không còn xoá token.
library;

import 'package:flowmoney/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:flowmoney/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _RemoteGia implements AuthRemoteDataSource {
  Map<String, dynamic> userDangNhap = {
    'idaccount': 11,
    'username': 'dat',
    'fullname': 'Đạt',
    'email': 'dat@example.com',
    'rolename': 'user',
    'status': 'Active',
    'countdown': null,
  };
  Map<String, dynamic> profile = {'status': 'Active'};
  Object? loiHuy;

  @override
  Future<Map<String, dynamic>> login(String username, String password) async => {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'pendingDeleteCancelled': false,
        'user': userDangNhap,
      };

  @override
  Future<Map<String, dynamic>> deleteAccount(String password) async =>
      {'idaccount': 11, 'status': 'PendingDelete', 'countdown': 30};

  @override
  Future<Map<String, dynamic>> cancelDelete() async {
    if (loiHuy != null) throw loiHuy!;
    return {'idaccount': 11, 'status': 'Active', 'countdown': null};
  }

  @override
  Future<Map<String, dynamic>> getProfile() async => profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nhanLuc = DateTime.utc(2026, 9, 11, 3);
  late _RemoteGia remote;
  late AuthLocalDataSourceImpl local;
  late AuthRepositoryImpl repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    remote = _RemoteGia();
    local = AuthLocalDataSourceImpl(secureStorage: storage);
    repo = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      secureStorage: storage,
      now: () => nhanLuc,
    );
  });

  Future<void> dangNhapChoXoa({int? countdown = 30}) async {
    remote.userDangNhap = {
      ...remote.userDangNhap,
      'status': 'PendingDelete',
      'countdown': countdown,
    };
    await repo.login('dat', 'mat-khau-thu');
  }

  test('đăng nhập ghi status, countdown và mốc nhận vào bộ nhớ đệm', () async {
    await dangNhapChoXoa(countdown: 12);
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isTrue);
    expect(user.countdown, 12);
    expect(user.countdownNhanLuc, nhanLuc,
        reason: 'Không có mốc nhận thì không đếm lùi được — số ngày đứng yên.');
  });

  test('gửi yêu cầu xoá: PendingDelete, countdown 30, KHÔNG xoá token (G33)', () async {
    await repo.login('dat', 'mat-khau-thu');
    await repo.deleteAccount('mat-khau-thu');
    expect(await local.getAccessToken(), 'access',
        reason: 'Bản cũ xoá sạch phiên theo đặc tả 2026-08-17; backend thì cho dùng tiếp 30 ngày.');
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isTrue);
    expect(user.countdown, 30);
    expect(user.countdownNhanLuc, nhanLuc);
  });

  test('huỷ yêu cầu thành công: Active, bỏ countdown', () async {
    await dangNhapChoXoa();
    await repo.cancelDelete();
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isFalse);
    expect(user.countdown, isNull);
  });

  test('huỷ hỏng nhưng server đã Active (huỷ ở máy khác) → không báo lỗi, về Active', () async {
    await dangNhapChoXoa();
    remote.loiHuy = Exception('Tài khoản không ở trạng thái chờ xóa');
    remote.profile = {'status': 'Active'};
    await repo.cancelDelete();
    expect((await repo.getCurrentUser())!.dangChoXoa, isFalse);
  });

  test('huỷ hỏng và server vẫn chờ xoá → ném lỗi, giữ nguyên số ngày', () async {
    await dangNhapChoXoa();
    remote.loiHuy = Exception('Không có kết nối mạng');
    remote.profile = {'status': 'PendingDelete'};
    await expectLater(repo.cancelDelete(), throwsA(isA<Exception>()));
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isTrue);
    expect(user.countdown, 30);
  });

  test('mở app: server PendingDelete mà máy không biết → chờ xoá, không số', () async {
    await repo.login('dat', 'mat-khau-thu');
    remote.profile = {'status': 'PendingDelete'};
    expect(await repo.verifySession(), SessionStatus.valid);
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isTrue);
    expect(user.countdown, isNull,
        reason: 'Yêu cầu gửi từ máy khác: máy này không có số đúng (CAN-LAM 19).');
  });

  test('mở app: server Active mà máy đang chờ xoá → Active', () async {
    await dangNhapChoXoa();
    remote.profile = {'status': 'Active'};
    await repo.verifySession();
    expect((await repo.getCurrentUser())!.dangChoXoa, isFalse);
  });

  test('mở app: trạng thái khớp → giữ countdown và mốc nhận', () async {
    await dangNhapChoXoa();
    remote.profile = {'status': 'PendingDelete'};
    await repo.verifySession();
    final user = await repo.getCurrentUser();
    expect(user!.countdown, 30);
    expect(user.countdownNhanLuc, nhanLuc);
  });
}
