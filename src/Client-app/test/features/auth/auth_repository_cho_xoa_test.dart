/// Bộ nhớ đệm trạng thái chờ xoá của `AuthRepositoryImpl` — spec cưỡng chế đăng
/// xuất §4.3. Canh G33: gửi yêu cầu xoá không còn xoá token.
library;

import 'dart:async';

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
  int getProfileCalls = 0;

  /// Khác `null` thì `deleteAccount`/`cancelDelete` treo tới khi `complete()` —
  /// dựng cảnh đổi tài khoản trong lúc yêu cầu còn chờ server.
  Completer<void>? treo;

  /// Hoàn tất khi yêu cầu treo đã tới server: test chỉ đổi tài khoản SAU mốc này.
  final daToiServer = Completer<void>();

  Future<void> _choNeuTreo() async {
    if (treo == null) return;
    if (!daToiServer.isCompleted) daToiServer.complete();
    await treo!.future;
  }

  @override
  Future<Map<String, dynamic>> login(String username, String password) async => {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'pendingDeleteCancelled': false,
        'user': userDangNhap,
      };

  @override
  Future<void> logout(String accessToken) async {}

  @override
  Future<Map<String, dynamic>> deleteAccount(String password) async {
    await _choNeuTreo();
    return {'idaccount': 11, 'status': 'PendingDelete', 'countdown': 30};
  }

  @override
  Future<Map<String, dynamic>> cancelDelete() async {
    await _choNeuTreo();
    if (loiHuy != null) throw loiHuy!;
    return {'idaccount': 11, 'status': 'Active', 'countdown': null};
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    getProfileCalls++;
    return profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nhanLuc = DateTime.utc(2026, 9, 11, 3);
  /// Đồng hồ tiêm vào repository; test đổi nó để phân biệt mốc nhận cũ và mới.
  late DateTime bayGio;
  late _RemoteGia remote;
  late AuthLocalDataSourceImpl local;
  late AuthRepositoryImpl repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    bayGio = nhanLuc;
    remote = _RemoteGia();
    local = AuthLocalDataSourceImpl(secureStorage: storage);
    repo = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      secureStorage: storage,
      now: () => bayGio,
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

  /// Đăng xuất rồi đăng nhập tài khoản 12 — đường duy nhất để bộ nhớ đệm người
  /// dùng đổi sang tài khoản khác trong app.
  Future<void> doiSangTaiKhoan12({String status = 'Active', int? countdown}) async {
    await repo.logout();
    remote.userDangNhap = {
      'idaccount': 12,
      'username': 'lan',
      'fullname': 'Lan',
      'email': 'lan@example.com',
      'rolename': 'user',
      'status': status,
      'countdown': countdown,
    };
    await repo.login('lan', 'mat-khau-khac');
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

  test('mở app: server PendingDelete KHÔNG kèm countdown (backend cũ) → chờ xoá, không số', () async {
    await repo.login('dat', 'mat-khau-thu');
    remote.profile = {'status': 'PendingDelete'};
    expect(await repo.verifySession(), SessionStatus.valid);
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isTrue);
    expect(user.countdown, isNull,
        reason: 'Yêu cầu gửi từ máy khác và server không nói số ngày: máy này không '
            'có số đúng, hiện câu chung còn hơn hiện số đoán.');
  });

  // ─── `/auth/profile` trả `countdown` từ 2026-09-12 (CAN-LAM 19) ────────────
  // Ba ca thẻ nhắc từng thiếu số hoặc sai số (AUTH_PROFILE_COUNTDOWN.md §2.4):
  // máy giữ phiên từ trước khi máy khác gửi yêu cầu xoá; bộ nhớ đệm của bản
  // client cũ thiếu mốc nhận; và máy còn giữ số của một lần chờ xoá TRƯỚC.

  test('mở app: server PendingDelete kèm countdown mà máy không biết → có số và mốc nhận', () async {
    await repo.login('dat', 'mat-khau-thu');
    remote.profile = {'status': 'PendingDelete', 'countdown': 17};
    expect(await repo.verifySession(), SessionStatus.valid);
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isTrue);
    expect(user.countdown, 17,
        reason: 'Máy giữ phiên từ trước khi máy khác gửi yêu cầu xoá chỉ thấy '
            'PendingDelete qua /auth/profile — có countdown ở đó là có số để hiện.');
    expect(user.countdownNhanLuc, nhanLuc,
        reason: 'Số là số LÚC NHẬN; không có mốc thì không đếm lùi được.');
  });

  test('mở app: trạng thái khớp nhưng server trả countdown khác → ghi lại số VÀ mốc nhận', () async {
    await dangNhapChoXoa(countdown: 30);
    remote.profile = {'status': 'PendingDelete', 'countdown': 9};
    bayGio = nhanLuc.add(const Duration(days: 2));
    await repo.verifySession();
    final user = await repo.getCurrentUser();
    expect(user!.countdown, 9,
        reason: 'Máy giữ số của một lần chờ xoá trước; máy khác huỷ rồi gửi lại. '
            'Trạng thái khớp nên bản cũ giữ số cũ và hiện ÍT ngày hơn thật.');
    expect(user.countdownNhanLuc, bayGio,
        reason: 'Mốc nhận phải đi cùng số mới — giữ mốc cũ là đếm lùi từ sai chỗ.');
  });

  test('mở app: server trả countdown rác (không phải số) → như không có, giữ số cũ', () async {
    await dangNhapChoXoa(countdown: 30);
    remote.profile = {'status': 'PendingDelete', 'countdown': 'ba'};
    bayGio = nhanLuc.add(const Duration(days: 2));
    await repo.verifySession();
    final user = await repo.getCurrentUser();
    expect(user!.countdown, 30);
    expect(user.countdownNhanLuc, nhanLuc,
        reason: 'Giá trị lạ không được đổi mốc nhận: mốc mới với số cũ là số ngày '
            'đứng yên thêm hai ngày.');
  });

  test('mở app: server Active kèm countdown null mà máy đang chờ xoá → Active, bỏ số', () async {
    await dangNhapChoXoa();
    remote.profile = {'status': 'Active', 'countdown': null};
    await repo.verifySession();
    final user = await repo.getCurrentUser();
    expect(user!.dangChoXoa, isFalse);
    expect(user.countdown, isNull);
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

  // ─── Đổi tài khoản trong lúc yêu cầu còn treo (soát cuối nhánh G33) ─────────
  // Yêu cầu chờ server tới 30 giây; trong lúc ấy người dùng đăng xuất rồi đăng
  // nhập tài khoản khác được. Kết quả của tài khoản cũ không được ghi vào bộ nhớ
  // đệm của tài khoản mới.

  test('gửi yêu cầu xoá: đổi tài khoản giữa lúc chờ → tài khoản mới không bị ghi chờ xoá', () async {
    await repo.login('dat', 'mat-khau-thu');
    remote.treo = Completer<void>();
    final guiXoa = repo.deleteAccount('mat-khau-thu');
    await remote.daToiServer.future;
    await doiSangTaiKhoan12();

    remote.treo!.complete();
    await guiXoa;

    final user = await repo.getCurrentUser();
    expect(user!.id, '12');
    expect(user.dangChoXoa, isFalse,
        reason: 'Yêu cầu xoá là của tài khoản 11 — ghi vào bộ nhớ đệm của tài khoản 12 '
            'là hiện thẻ "đang chờ xoá" cho người không hề gửi yêu cầu.');
    expect(user.countdown, isNull);
  });

  test('huỷ yêu cầu: đổi tài khoản giữa lúc chờ → tài khoản mới giữ trạng thái chờ xoá của nó', () async {
    await dangNhapChoXoa();
    remote.treo = Completer<void>();
    final huy = repo.cancelDelete();
    await remote.daToiServer.future;
    await doiSangTaiKhoan12(status: 'PendingDelete', countdown: 12);

    remote.treo!.complete();
    await huy;

    final user = await repo.getCurrentUser();
    expect(user!.id, '12');
    expect(user.dangChoXoa, isTrue,
        reason: 'Huỷ là của tài khoản 11 — ghi Active vào tài khoản 12 là giấu thẻ nhắc '
            'của một tài khoản thật sự đang chờ xoá.');
    expect(user.countdown, 12);
    expect(user.countdownNhanLuc, nhanLuc);
  });

  test('huỷ hỏng sau khi đổi tài khoản → không hỏi lại server cho phiên mới, vẫn ném lỗi', () async {
    await dangNhapChoXoa();
    remote.treo = Completer<void>();
    remote.loiHuy = Exception('Không có kết nối mạng');
    final huy = repo.cancelDelete();
    await remote.daToiServer.future;
    await doiSangTaiKhoan12();
    remote.profile = {'status': 'Active'};

    remote.treo!.complete();
    await expectLater(huy, throwsA(isA<Exception>()),
        reason: 'Tài khoản 12 không chờ xoá không có nghĩa tài khoản 11 đã huỷ được — '
            'nuốt lỗi là người dùng tưởng đã huỷ.');
    expect(remote.getProfileCalls, 0,
        reason: 'Nhánh hỏi lại server là để kiểm tài khoản đã gửi yêu cầu huỷ; gọi nó lúc '
            'này là hỏi cho phiên của tài khoản 12.');
    final user = await repo.getCurrentUser();
    expect(user!.id, '12');
    expect(user.dangChoXoa, isFalse);
  });
}
