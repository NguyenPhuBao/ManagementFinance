/// Kiểm chứng việc phát hiện "phiên mồ côi": JWT còn hạn nhưng tài khoản đã bị
/// xoá khỏi CSDL. Trước đây client chỉ kiểm tra chuỗi token có rỗng hay không,
/// nên vẫn khởi động SyncEngine và mọi lần đẩy dữ liệu đều vỡ khoá ngoại
/// fk_category_account / fk_transaction_account, lặp lại vô hạn.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/ai_edge/data/slm_cache.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';

class _FakeDioClient implements DioClient {
  @override
  final Dio dio = Dio();
}

class _Offline implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.none];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Ghi lại việc SyncEngine có bị khởi động / dừng hay không, và cho phép test
/// tự phát tín hiệu "phiên chết" như engine thật sẽ làm.
class _SpySyncEngine extends SyncEngine {
  _SpySyncEngine({required super.dioClient, required super.db, super.connectivity});

  final List<int> startedWith = [];
  int stopCalls = 0;
  final _sessionInvalid = StreamController<void>.broadcast();

  @override
  Stream<void> get sessionInvalidStream => _sessionInvalid.stream;

  void triggerSessionInvalid() => _sessionInvalid.add(null);

  @override
  Future<void> start({required int idaccount}) async {
    startedWith.add(idaccount);
  }

  @override
  void stop() {
    stopCalls++;
    super.stop();
  }

  @override
  void dispose() {
    _sessionInvalid.close();
    super.dispose();
  }
}

/// Cho phép test tự phát tín hiệu "token vừa bị xoá" như interceptor thật sẽ
/// làm khi `/auth/refresh` thất bại, mà không phải dựng cả một vòng HTTP 401.
class _SpyAuthInterceptor extends AuthInterceptor {
  _SpyAuthInterceptor()
      : super(secureStorage: const FlutterSecureStorage());

  final _expired = StreamController<void>.broadcast();

  @override
  Stream<void> get sessionExpiredStream => _expired.stream;

  void triggerTokensCleared() => _expired.add(null);

  @override
  void dispose() {
    _expired.close();
    super.dispose();
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.session, this.cachedUser});

  final SessionStatus session;
  final UserModel? cachedUser;
  int logoutCalls = 0;

  /// Cho phép đổi câu trả lời của server giữa chừng (mở app thì hợp lệ, tới
  /// lúc đẩy dữ liệu mới phát hiện tài khoản đã bị xoá).
  SessionStatus? sessionOverride;

  @override
  Future<bool> checkAuthStatus() async => true;

  @override
  Future<UserModel?> getCurrentUser() async => cachedUser;

  @override
  Future<SessionStatus> verifySession() async => sessionOverride ?? session;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _user(String id) => UserModel(
      id: id,
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
    );

void main() {
  late AppDatabase db;
  late _SpySyncEngine sync;
  late _SpyAuthInterceptor interceptor;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _SpySyncEngine(
      dioClient: _FakeDioClient(),
      db: db,
      connectivity: _Offline(),
    );
    sl.registerSingleton<SyncEngine>(sync);
    interceptor = _SpyAuthInterceptor();
    sl.registerSingleton<AuthInterceptor>(interceptor);
    sl.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    await sl.reset();
    sync.dispose();
    interceptor.dispose();
    await db.close();
  });

  /// Trạng thái CUỐI của lượt mở app. Từ 2026-10-09 lượt ấy phát `AuthSuccess`
  /// từ bộ nhớ đệm TRƯỚC khi hỏi server, nên chờ `AuthSuccess` đầu tiên là đọc
  /// trạng thái giữa chừng — đợi hàng sự kiện cạn rồi mới đọc.
  Future<AuthState> checkAuth(_FakeAuthRepository repo) async {
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    bloc.add(AuthCheckRequested());
    await pumpEventQueue();
    return bloc.state;
  }

  group('Khôi phục phiên lúc mở app', () {
    test(
        'Phiên trỏ tới tài khoản đã bị xoá (server trả invalid) → đăng xuất, '
        'KHÔNG khởi động đồng bộ', () async {
      final repo = _FakeAuthRepository(
        session: SessionStatus.invalid,
        cachedUser: _user('9'),
      );

      final state = await checkAuth(repo);

      expect(state, isA<AuthUnauthenticated>());
      expect(repo.logoutCalls, 1);
      expect(sync.startedWith, isEmpty,
          reason: 'Khởi động đồng bộ với phiên đã chết chính là thứ gây ra '
              'vòng lặp lỗi khoá ngoại fk_*_account');
    });

    test('Mất mạng (unknown) → GIỮ phiên, vẫn đồng bộ được — offline-first',
        () async {
      final repo = _FakeAuthRepository(
        session: SessionStatus.unknown,
        cachedUser: _user('10'),
      );

      final state = await checkAuth(repo);

      expect(state, isA<AuthSuccess>());
      expect(repo.logoutCalls, 0,
          reason: 'Đăng xuất người dùng offline sẽ phá vỡ offline-first');
      expect(sync.startedWith, [10]);
    });

    test('Phiên hợp lệ → khởi động đồng bộ đúng tài khoản', () async {
      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('10'),
      );

      final state = await checkAuth(repo);

      expect(state, isA<AuthSuccess>());
      expect(sync.startedWith, [10]);
    });

    test(
        'Khôi phục phiên cũng dọn dữ liệu tài khoản khác, không chỉ lúc đăng nhập',
        () async {
      await db.walletDao.insert(WalletsCompanion(
        id: const Value('w-cua-tai-khoan-cu'),
        idaccount: const Value(9),
        name: const Value('Ví cũ'),
        type: const Value('cash'),
        balance: const Value(0),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));

      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('10'),
      );
      final state = await checkAuth(repo);

      expect(state, isA<AuthSuccess>());
      expect(await db.walletDao.getById('w-cua-tai-khoan-cu'), null,
          reason: 'Người dùng mở lại app mà không đăng xuất/đăng nhập lại thì '
              'dữ liệu rác của tài khoản cũ vẫn phải được dọn');
    });

    /// Cache câu SLM (`data/slm_cache.dart`) nằm ngoài SQLite — một tệp JSON
    /// duy nhất cho cả máy — nên `purgeDataForOtherAccounts` không chạm tới
    /// được. Hai ca dưới đây canh **hai chiều** của cùng một luật.
    test('Đổi tài khoản thì cache câu SLM cũng bị dọn', () async {
      final thuMuc = Directory.systemTemp.createTempSync('slm_cache_doi_tk');
      addTearDown(() => thuMuc.deleteSync(recursive: true));
      final cache = SlmCache(thuMuc: () async => thuMuc);
      await cache.nap();
      await cache.ghi('van-tay-cua-9', 'Tháng này bạn chi 4,2 triệu.');
      sl.registerSingleton<SlmCache>(cache);

      await db.walletDao.insert(WalletsCompanion(
        id: const Value('w-cua-tai-khoan-cu'),
        idaccount: const Value(9),
        name: const Value('Ví cũ'),
        type: const Value('cash'),
        balance: const Value(0),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));

      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('10'),
      );
      expect(await checkAuth(repo), isA<AuthSuccess>());

      expect(cache.doc('van-tay-cua-9'), isNull,
          reason: 'Câu trong cache nói về số liệu tài chính của MỘT tài '
              'khoản. Trên máy dùng chung, người sau không được thấy câu của '
              'người trước.');
    });

    test('Đăng nhập lại CÙNG tài khoản thì cache câu SLM được GIỮ', () async {
      final thuMuc = Directory.systemTemp.createTempSync('slm_cache_cung_tk');
      addTearDown(() => thuMuc.deleteSync(recursive: true));
      final cache = SlmCache(thuMuc: () async => thuMuc);
      await cache.nap();
      await cache.ghi('van-tay-cua-10', 'Tháng này bạn chi 4,2 triệu.');
      sl.registerSingleton<SlmCache>(cache);

      // KHÔNG có hàng nào của tài khoản khác → `purgeDataForOtherAccounts`
      // xoá 0 hàng → không có "đổi người dùng" nào xảy ra.
      await db.walletDao.insert(WalletsCompanion(
        id: const Value('w-cua-chinh-minh'),
        idaccount: const Value(10),
        name: const Value('Ví của tôi'),
        type: const Value('cash'),
        balance: const Value(0),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));

      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('10'),
      );
      expect(await checkAuth(repo), isA<AuthSuccess>());

      expect(cache.doc('van-tay-cua-10'), isNotNull,
          reason: 'Dọn ở đây là vứt tới 200 câu, mỗi câu đã trả 2,3 giây chạy '
              'mô hình để có — trong khi chẳng có người dùng nào đổi.');
    });

    test('idaccount hỏng/rỗng → KHÔNG mặc định thành admin (id 1)', () async {
      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user(''),
      );

      final state = await checkAuth(repo);

      expect(state, isA<AuthUnauthenticated>());
      expect(sync.startedWith, isEmpty,
          reason: 'Fallback `?? 1` cũ sẽ ghi dữ liệu dưới danh nghĩa admin');
    });
  });

  group('Phát hiện phiên chết NGAY khi đẩy dữ liệu (không chờ mở lại app)', () {
    test('Server xác nhận phiên đã chết → dừng đồng bộ và đăng xuất', () async {
      // valid lúc mở app, invalid khi hỏi lại sau tín hiệu.
      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('9'),
      );
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      final loggedIn = bloc.stream.where((s) => s is AuthSuccess).first;
      bloc.add(AuthCheckRequested());
      await loggedIn.timeout(const Duration(seconds: 5));

      repo.sessionOverride = SessionStatus.invalid; // server phủ nhận phiên
      final after = bloc.stream.first;
      sync.triggerSessionInvalid();

      expect(await after.timeout(const Duration(seconds: 5)),
          isA<AuthUnauthenticated>());
      expect(repo.logoutCalls, 1);
      expect(sync.stopCalls, greaterThan(0),
          reason: 'Phải dừng engine, nếu không nó vẫn đẩy lỗi mỗi chu kỳ');
    });

    test(
        'Tín hiệu nhưng server nói phiên vẫn hợp lệ → KHÔNG đăng xuất '
        '(chống dương tính giả do khớp chuỗi tên constraint)', () async {
      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('10'),
      );
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      final loggedIn = bloc.stream.where((s) => s is AuthSuccess).first;
      bloc.add(AuthCheckRequested());
      await loggedIn.timeout(const Duration(seconds: 5));

      sync.triggerSessionInvalid();
      // Không chờ state mới: đúng hành vi mong muốn là KHÔNG phát gì cả.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(bloc.state, isA<AuthSuccess>(),
          reason: 'Tên constraint trong thông báo lỗi Prisma có thể đổi theo '
              'phiên bản — không được đăng xuất chỉ vì khớp chuỗi');
      expect(repo.logoutCalls, 0);
      expect(sync.stopCalls, 0);
    });

    test(
        'AuthInterceptor xoá token → bloc cũng phản ứng, không chỉ SyncEngine',
        () async {
      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('9'),
      );
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      final loggedIn = bloc.stream.where((s) => s is AuthSuccess).first;
      bloc.add(AuthCheckRequested());
      await loggedIn.timeout(const Duration(seconds: 5));

      repo.sessionOverride = SessionStatus.invalid;
      final after = bloc.stream.first;
      interceptor.triggerTokensCleared();

      expect(
        await after.timeout(const Duration(seconds: 5)),
        isA<AuthUnauthenticated>(),
        reason: 'Canh chừng G12: kênh sessionInvalidStream trước đây chỉ nối '
            'từ SyncEngine. Khi refresh token hỏng, interceptor xoá token mà '
            'không ai hay, app kẹt ở AuthSuccess với kho token rỗng.',
      );
      expect(repo.logoutCalls, 1);
    });

    test(
        'Interceptor báo mất token nhưng server nói phiên vẫn sống → KHÔNG đăng xuất',
        () async {
      final repo = _FakeAuthRepository(
        session: SessionStatus.valid,
        cachedUser: _user('10'),
      );
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      final loggedIn = bloc.stream.where((s) => s is AuthSuccess).first;
      bloc.add(AuthCheckRequested());
      await loggedIn.timeout(const Duration(seconds: 5));

      interceptor.triggerTokensCleared();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(bloc.state, isA<AuthSuccess>(),
          reason: 'Mất token có thể do một lần refresh trượt vì mạng chập '
              'chờn; quyết định đăng xuất vẫn phải do server đưa ra.');
      expect(repo.logoutCalls, 0);
    });
  });

  group('SyncEngine không tự suy ra danh tính từ dữ liệu cục bộ', () {
    test('Chưa đăng nhập nhưng SQLite còn ví của tài khoản cũ → không đồng bộ',
        () async {
      await db.walletDao.insert(WalletsCompanion(
        id: const Value('11111111-1111-4111-8111-111111111111'),
        idaccount: const Value(9), // tài khoản đã bị xoá khỏi server
        name: const Value('Ví cũ'),
        type: const Value('cash'),
        balance: const Value(0),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));

      // Engine thật (không phải spy) nhưng CHƯA gọi start().
      final engine = SyncEngine(
        dioClient: _FakeDioClient(),
        db: db,
        connectivity: _Offline(),
      );
      addTearDown(engine.dispose);

      await engine.syncNow();

      expect(engine.status, SyncStatus.idle,
          reason: 'Trước đây engine đọc walletDao.getAllNonDeleted() và hồi '
              'sinh idaccount = 9 từ chính dòng dữ liệu chết này');
    });
  });

  group('Dọn dữ liệu của tài khoản khác', () {
    test('Xoá dữ liệu tài khoản cũ, giữ tài khoản hiện tại và danh mục mặc định',
        () async {
      Future<void> addWallet(String id, int account) => db.walletDao.insert(
            WalletsCompanion(
              id: Value(id),
              idaccount: Value(account),
              name: Value('Ví $account'),
              type: const Value('cash'),
              balance: const Value(0),
              updatedAt: Value(DateTime(2026, 9, 1)),
            ),
          );
      await addWallet('w-old', 9);
      await addWallet('w-current', 10);
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'cat-old',
        idaccount: 9,
        name: 'Danh mục cũ',
        classify: 'chi',
        updatedAt: DateTime(2026, 9, 1),
      ));
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'cat-current',
        idaccount: 10,
        name: 'Danh mục hiện tại',
        classify: 'chi',
        updatedAt: DateTime(2026, 9, 1),
      ));

      // Đếm qua `getBackendDefaults` chứ không qua `getAll`: từ 2026-09-07
      // danh mục mặc định KHÔNG còn hiện trong các truy vấn hiển thị, nhưng
      // hàng của chúng vẫn phải nằm nguyên trong CSDL — chúng là khuôn để
      // `DefaultCategorySeeder` sao chép cho từng tài khoản.
      final defaultsBefore = (await db.categoryDao.getBackendDefaults()).length;
      expect(defaultsBefore, greaterThan(0));

      final removed = await db.purgeDataForOtherAccounts(10);

      expect(removed, greaterThan(0));
      expect(await db.walletDao.getById('w-old'), null);
      expect((await db.walletDao.getById('w-current'))?.id, 'w-current');
      expect(await db.categoryDao.getById('cat-old'), null);
      expect((await db.categoryDao.getById('cat-current'))?.id, 'cat-current');
      // Danh mục mặc định (idaccount = 0) là khuôn dùng chung → phải còn.
      // Dọn mất chúng nghĩa là tài khoản kế tiếp đăng nhập trên máy này không
      // có gì để sao chép, và người dùng thấy danh sách danh mục rỗng.
      final defaultsAfter = (await db.categoryDao.getBackendDefaults()).length;
      expect(defaultsAfter, defaultsBefore);
    });

    test('Không xoá gì khi id không hợp lệ', () async {
      expect(await db.purgeDataForOtherAccounts(0), 0);
      expect(await db.purgeDataForOtherAccounts(-1), 0);
    });
  });

  // ── Mở app không chờ mạng (2026-10-09) ──────────────────────────────────
  // Trước đây mọi trang đợi `verifySession()` (GET /auth/profile, trần 30 s)
  // xong mới có `AuthSuccess`: server chậm / Render đang ngủ / Wi-Fi không ra
  // Internet là 30 s vòng xoay, còn Trang chủ in "0 đ" và "Người dùng". Người
  // dùng chọn: hiện dữ liệu trên máy ngay, hỏi server ở nền.
  group('Mở app không chờ mạng', () {
    test('server chưa trả lời → AuthSuccess từ bộ nhớ đệm ĐÃ phát, đồng bộ CHƯA khởi động',
        () async {
      final cho = Completer<SessionStatus>();
      final repo = _RepoCho(cho, _user('10'));
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      bloc.add(AuthCheckRequested());
      await pumpEventQueue();

      expect(bloc.state, isA<AuthSuccess>(),
          reason: 'dữ liệu nằm sẵn trong SQLite — không được đợi một lượt gọi mạng');
      expect((bloc.state as AuthSuccess).user!.id, '10');
      expect(sync.startedWith, isEmpty,
          reason: 'chốt cũ giữ nguyên: không khởi động đồng bộ trước khi biết phiên còn sống');

      cho.complete(SessionStatus.valid);
      await pumpEventQueue();
      expect(sync.startedWith, [10]);
      expect(bloc.state, isA<AuthSuccess>());
    });

    test('server trả lời phiên chết SAU khi đã hiện dữ liệu → đăng xuất, không đồng bộ',
        () async {
      final cho = Completer<SessionStatus>();
      final repo = _RepoCho(cho, _user('10'));
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);
      bloc.add(AuthCheckRequested());
      await pumpEventQueue();
      cho.complete(SessionStatus.invalid);
      await pumpEventQueue();

      expect(states.map((s) => s.runtimeType).toList(),
          [AuthChecking, AuthSuccess, AuthUnauthenticated]);
      expect(repo.logoutCalls, 1);
      expect(sync.startedWith, isEmpty);
    });

    test('đăng xuất trong lúc chờ server → server trả lời hợp lệ cũng KHÔNG khởi động gì',
        () async {
      final cho = Completer<SessionStatus>();
      final repo = _RepoCho(cho, _user('10'));
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      bloc.add(AuthCheckRequested());
      await pumpEventQueue();
      bloc.add(LogoutRequested());
      await pumpEventQueue();
      expect(bloc.state, isA<AuthUnauthenticated>());

      cho.complete(SessionStatus.valid);
      await pumpEventQueue();
      expect(bloc.state, isA<AuthUnauthenticated>(),
          reason: 'lượt mở app về muộn không được phát lại AuthSuccess đè lên đăng xuất');
      expect(sync.startedWith, isEmpty,
          reason: 'đồng bộ cho phiên vừa đăng xuất là ghi dữ liệu dưới danh nghĩa người đã rời đi');
    });

    test('server báo tài khoản đang chờ xoá → phát lại AuthSuccess mang trạng thái mới',
        () async {
      final cho = Completer<SessionStatus>();
      final repo = _RepoCho(cho, _user('10'));
      final bloc = AuthBloc(authRepository: repo);
      addTearDown(bloc.close);
      bloc.add(AuthCheckRequested());
      await pumpEventQueue();
      expect((bloc.state as AuthSuccess).user!.dangChoXoa, isFalse);

      // verifySession đồng bộ `status` từ /auth/profile vào bộ nhớ đệm.
      repo.cached = _user('10').voiTrangThai(status: 'PendingDelete');
      cho.complete(SessionStatus.valid);
      await pumpEventQueue();
      expect((bloc.state as AuthSuccess).user!.dangChoXoa, isTrue,
          reason: 'thẻ "chờ xoá" ở Trang chủ phải theo câu trả lời của server');
    });
  });
}

/// `verifySession` treo tới khi test `complete()` — mô phỏng server chậm.
class _RepoCho implements AuthRepository {
  _RepoCho(this.cho, this.cached);

  final Completer<SessionStatus> cho;
  UserModel? cached;
  int logoutCalls = 0;

  @override
  Future<bool> checkAuthStatus() async => true;

  @override
  Future<UserModel?> getCurrentUser() async => cached;

  @override
  Future<SessionStatus> verifySession() => cho.future;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
