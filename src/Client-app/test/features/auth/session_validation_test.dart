/// Kiểm chứng việc phát hiện "phiên mồ côi": JWT còn hạn nhưng tài khoản đã bị
/// xoá khỏi CSDL. Trước đây client chỉ kiểm tra chuỗi token có rỗng hay không,
/// nên vẫn khởi động SyncEngine và mọi lần đẩy dữ liệu đều vỡ khoá ngoại
/// fk_category_account / fk_transaction_account, lặp lại vô hạn.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
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

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _SpySyncEngine(
      dioClient: _FakeDioClient(),
      db: db,
      connectivity: _Offline(),
    );
    sl.registerSingleton<SyncEngine>(sync);
    sl.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    await sl.reset();
    sync.dispose();
    await db.close();
  });

  Future<AuthState> checkAuth(_FakeAuthRepository repo) async {
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    final done = bloc.stream
        .where((s) => s is AuthSuccess || s is AuthUnauthenticated)
        .first;
    bloc.add(AuthCheckRequested());
    return done.timeout(const Duration(seconds: 5));
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

      final defaultsBefore = (await db.categoryDao.getAll(10))
          .where((c) => c.idaccount == 0)
          .length;
      expect(defaultsBefore, greaterThan(0));

      final removed = await db.purgeDataForOtherAccounts(10);

      expect(removed, greaterThan(0));
      expect(await db.walletDao.getById('w-old'), null);
      expect((await db.walletDao.getById('w-current'))?.id, 'w-current');
      expect(await db.categoryDao.getById('cat-old'), null);
      expect((await db.categoryDao.getById('cat-current'))?.id, 'cat-current');
      // Danh mục mặc định (idaccount = 0) là dữ liệu dùng chung → phải còn.
      final defaultsAfter =
          (await db.categoryDao.getAll(10)).where((c) => c.idaccount == 0).length;
      expect(defaultsAfter, defaultsBefore);
    });

    test('Không xoá gì khi id không hợp lệ', () async {
      expect(await db.purgeDataForOtherAccounts(0), 0);
      expect(await db.purgeDataForOtherAccounts(-1), 0);
    });
  });
}
