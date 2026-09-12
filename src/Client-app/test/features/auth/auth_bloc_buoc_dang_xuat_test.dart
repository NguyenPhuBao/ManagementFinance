/// Một cửa vào duy nhất cho cả ba nguồn "tài khoản này không dùng được nữa"
/// (spec cưỡng chế đăng xuất §3.5, §3.6b).
///
/// Phần lớn các ca dưới đây là những hình dạng hỏng đã thấy trước ở §9 — nặng
/// nhất là hai ca đồng thời: handler của Bloc chạy ĐỒNG THỜI, nên `state` không
/// đủ để chặn lần nhận thứ hai.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/auth/buoc_dang_xuat.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/notification/notification_scanner.dart';
import 'package:flowmoney/core/realtime/realtime_channel.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
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

class _SpySyncEngine extends SyncEngine {
  _SpySyncEngine({
    required super.dioClient,
    required super.db,
    super.connectivity,
  });

  int stopCalls = 0;

  @override
  Future<void> start({required int idaccount}) async {}

  @override
  void stop() {
    stopCalls++;
    super.stop();
  }
}

class _SpyAuthInterceptor extends AuthInterceptor {
  _SpyAuthInterceptor() : super(secureStorage: const FlutterSecureStorage());

  final _tuChoi = StreamController<ThongBaoBuocDangXuat>.broadcast();

  @override
  Stream<ThongBaoBuocDangXuat> get taiKhoanBiTuChoi => _tuChoi.stream;

  void ban(ThongBaoBuocDangXuat tb) => _tuChoi.add(tb);

  @override
  void dispose() {
    _tuChoi.close();
    super.dispose();
  }
}

class _SpyRealtimeChannel extends RealtimeChannel {
  _SpyRealtimeChannel()
      : super(
          secureStorage: const FlutterSecureStorage(),
          connectivity: _Offline(),
        );

  int stopCalls = 0;
  final _buoc = StreamController<ThongBaoBuocDangXuat>.broadcast();

  @override
  Stream<ThongBaoBuocDangXuat> get buocDangXuat => _buoc.stream;

  void ban(ThongBaoBuocDangXuat tb) => _buoc.add(tb);

  @override
  Future<void> start({required int idaccount}) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  void dispose() => _buoc.close();
}

class _SpyScanner extends NotificationScanner {
  _SpyScanner(AppDatabase db)
      : super(
          dao: db.notificationDao,
          loadBudgets: (id, at) async => [],
          loadBills: (id, at) async => [],
          syncStatus: const Stream.empty(),
        );

  int stopCalls = 0;

  @override
  Future<void> start(int idaccount) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class _RepoGia implements AuthRepository {
  _RepoGia({this.user});

  final UserModel? user;
  int logoutCalls = 0;
  int xoaPhienCalls = 0;

  /// Khác `null` thì `verifySession()` trả `invalid` và **phát thông báo** ngay
  /// trước khi trả lời — đúng thứ tự thật lúc mở app với tài khoản đã bị khoá:
  /// `GET /auth/profile` nhận 401 mang mã, interceptor phát `taiKhoanBiTuChoi`,
  /// rồi repository mới xếp lỗi ấy là `invalid`.
  void Function()? khiVerifySession;

  /// Khác `null` thì `xoaPhienTrenMay()` treo tới khi test `complete()` — dựng
  /// cảnh thông báo thứ hai tới trong lúc lượt đầu CÒN ĐANG CHẠY.
  Completer<void>? treoXoaPhien;
  final daVaoXoaPhien = Completer<void>();

  @override
  Future<bool> checkAuthStatus() async => true;

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  Future<SessionStatus> verifySession() async {
    if (khiVerifySession != null) {
      khiVerifySession!();
      return SessionStatus.invalid;
    }
    return SessionStatus.valid;
  }

  /// Khác `null` thì `logout()` treo tới khi test thả — dựng cảnh THẬT: `logout()`
  /// gọi `/auth/logout` qua mạng nên nó luôn về **sau** handler cưỡng chế đăng
  /// xuất (chỉ đụng bộ nhớ và kho token cục bộ).
  Completer<void>? treoLogout;

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (treoLogout != null) await treoLogout!.future;
  }

  @override
  Future<void> xoaPhienTrenMay() async {
    xoaPhienCalls++;
    if (treoXoaPhien != null) {
      if (!daVaoXoaPhien.isCompleted) daVaoXoaPhien.complete();
      await treoXoaPhien!.future;
    }
  }

  @override
  Future<UserModel> login(String username, String password) async => user!;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

UserModel _user(String id) => UserModel(
      id: id,
      username: 'dat',
      name: 'Đạt',
      email: 'dat@example.com',
    );

const _thongBaoDaXoa = ThongBaoBuocDangXuat(
  lyDo: LyDoBuocDangXuat.daXoa,
  nguon: NguonBuocDangXuat.socket,
  loiNhan: 'Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên.',
  idaccount: 11,
);

const _thongBaoBiKhoa = ThongBaoBuocDangXuat(
  lyDo: LyDoBuocDangXuat.biKhoa,
  nguon: NguonBuocDangXuat.socket,
  loiNhan: 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản.',
  idaccount: 11,
);

void main() {
  late AppDatabase db;
  late _SpySyncEngine sync;
  late _SpyAuthInterceptor interceptor;
  late _SpyRealtimeChannel realtime;
  late _SpyScanner scanner;

  final moc = DateTime(2026, 9, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _SpySyncEngine(
      dioClient: _FakeDioClient(),
      db: db,
      connectivity: _Offline(),
    );
    interceptor = _SpyAuthInterceptor();
    realtime = _SpyRealtimeChannel();
    scanner = _SpyScanner(db);
    sl.registerSingleton<SyncEngine>(sync);
    sl.registerSingleton<AuthInterceptor>(interceptor);
    sl.registerSingleton<RealtimeChannel>(realtime);
    sl.registerSingleton<NotificationScanner>(scanner);
    sl.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    await sl.reset();
    sync.dispose();
    interceptor.dispose();
    realtime.dispose();
    await db.close();
  });

  Future<void> themVi(int idaccount) => db.into(db.wallets).insert(
        WalletsCompanion.insert(
          id: 'w_$idaccount',
          idaccount: idaccount,
          name: 'Tien mat',
          updatedAt: moc,
        ),
      );

  Future<int> soVi(int idaccount) async =>
      (await (db.select(db.wallets)..where((t) => t.idaccount.equals(idaccount)))
              .get())
          .length;

  /// Dựng bloc và đưa nó vào `AuthSuccess` qua đúng đường mở app.
  Future<AuthBloc> blocDangDangNhap(_RepoGia repo) async {
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    final xong = bloc.stream.where((s) => s is AuthSuccess).first;
    bloc.add(AuthCheckRequested());
    await xong.timeout(const Duration(seconds: 5));
    return bloc;
  }

  Future<AuthState> choDangXuat(AuthBloc bloc) =>
      bloc.stream.where((s) => s is AuthUnauthenticated).first.timeout(
            const Duration(seconds: 5),
          );

  test('biKhoa: dừng ba thành phần, KHÔNG dọn SQLite, KHÔNG gọi logout từ xa',
      () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = await blocDangDangNhap(repo);
    final cho = choDangXuat(bloc);

    realtime.ban(_thongBaoBiKhoa);
    final state = await cho;

    expect(sync.stopCalls, 1);
    expect(scanner.stopCalls, 1,
        reason: 'sót bộ quét là nhắc hoá đơn của người vừa rời đi nổ trên màn '
            'hình khoá của người sau — stop() gọi cancelAll bên trong');
    expect(realtime.stopCalls, 1,
        reason: 'socket còn sống nghĩa là máy vẫn nằm trong room account_<id> '
            'của người vừa rời đi');
    expect(await soVi(11), 1,
        reason: 'bị khoá thì admin mở lại được, và thay đổi chưa đồng bộ vẫn '
            'còn đường lên server (mục 2, Q2)');
    expect(repo.logoutCalls, 0,
        reason: '/auth/logout đi qua authenticate, sẽ 401 rồi quay vòng qua '
            'interceptor');
    expect(repo.xoaPhienCalls, 1);
    expect(state, isA<AuthUnauthenticated>());
    expect((state as AuthUnauthenticated).thongBao, _thongBaoBiKhoa);
  });

  test('daXoa nguồn socket → dọn SQLite đúng tài khoản, chừa tài khoản khác',
      () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = await blocDangDangNhap(repo);
    // Chèn SAU khi mở app: đường `AuthCheckRequested` chạy
    // `purgeDataForOtherAccounts(11)` nên hàng của 12 sẽ biến mất trước khi ca
    // test kịp nói được điều gì.
    await themVi(12);
    final cho = choDangXuat(bloc);

    realtime.ban(_thongBaoDaXoa);
    await cho;

    expect(await soVi(11), 0,
        reason: 'server đã ẩn danh hoá bên kia (xoá note, images) mà máy vẫn '
            'giữ bản rõ');
    expect(await soVi(12), 1);
  });

  test('daXoa nguồn http → cũng dọn', () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = await blocDangDangNhap(repo);
    final cho = choDangXuat(bloc);

    interceptor.ban(const ThongBaoBuocDangXuat(
      lyDo: LyDoBuocDangXuat.daXoa,
      nguon: NguonBuocDangXuat.http,
      idaccount: 11,
    ));
    await cho;

    expect(await soVi(11), 0);
  });

  test('daXoa nguồn lamMoi → KHÔNG dọn, nhưng VẪN đăng xuất (§3.6b)', () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = await blocDangDangNhap(repo);
    final cho = choDangXuat(bloc);

    interceptor.ban(const ThongBaoBuocDangXuat(
      lyDo: LyDoBuocDangXuat.daXoa,
      nguon: NguonBuocDangXuat.lamMoi,
      idaccount: 11,
    ));
    final state = await cho;

    expect(await soVi(11), 1,
        reason: 'lỗi lược đồ phía server còn đội lốt được ACCOUNT_DELETED ở '
            'nhánh làm mới (CAN-LAM 17 §2.5) — báo động giả mà xoá là mất dữ '
            'liệu thật');
    expect(state, isA<AuthUnauthenticated>());
    expect((state as AuthUnauthenticated).thongBao?.lyDo, LyDoBuocDangXuat.daXoa,
        reason: 'vẫn hiện hộp thoại "Tài khoản đã bị xoá"');
  });

  test('không có phiên → bỏ qua hoàn toàn', () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);

    realtime.ban(_thongBaoDaXoa);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state, isA<AuthInitial>());
    expect(sync.stopCalls, 0);
    expect(repo.xoaPhienCalls, 0);
    expect(await soVi(11), 1,
        reason: 'gói tin tới khi chưa ai đăng nhập không được đụng vào dữ liệu '
            'nằm sẵn trên máy');
  });

  test('hai thông báo dồn dập khi handler đầu CÒN ĐANG CHẠY → chỉ một lần dừng '
      'và một lần dọn', () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'))..treoXoaPhien = Completer<void>();
    final bloc = await blocDangDangNhap(repo);
    final cho = choDangXuat(bloc);

    realtime.ban(_thongBaoDaXoa);
    // Chờ tới khi lượt đầu thật sự đang chạy — state VẪN là AuthSuccess ở mốc
    // này, đúng cái bẫy §9: chặn bằng state là không chặn được gì.
    await repo.daVaoXoaPhien.future.timeout(const Duration(seconds: 5));
    expect(bloc.state, isA<AuthSuccess>());

    interceptor.ban(const ThongBaoBuocDangXuat(
      lyDo: LyDoBuocDangXuat.daXoa,
      nguon: NguonBuocDangXuat.http,
      idaccount: 11,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    repo.treoXoaPhien!.complete();
    await cho;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repo.xoaPhienCalls, 1, reason: 'cờ chặn phải đặt ngay đầu handler');
    expect(sync.stopCalls, 1);
    expect(realtime.stopCalls, 1);
  });

  test('AuthUnauthenticated() trơn và bản có thongBao là HAI state khác nhau',
      () {
    expect(const AuthUnauthenticated(),
        isNot(const AuthUnauthenticated(thongBao: _thongBaoDaXoa)),
        reason: '`_onAuthCheckRequested` có thể đã phát bản trơn trước; không '
            'nằm trong props thì Bloc bỏ lần phát sau và hộp thoại không bao '
            'giờ hiện');
  });

  test('thiếu idaccount trong thông báo → lấy từ phiên đăng nhập', () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = await blocDangDangNhap(repo);
    final cho = choDangXuat(bloc);

    realtime.ban(const ThongBaoBuocDangXuat(
      lyDo: LyDoBuocDangXuat.daXoa,
      nguon: NguonBuocDangXuat.socket,
    ));
    await cho;

    expect(await soVi(11), 0);
  });

  test('không có id hợp lệ ở cả hai chỗ → KHÔNG dọn, vẫn đăng xuất', () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = await blocDangDangNhap(repo);
    final cho = choDangXuat(bloc);
    // Phiên vẫn là tài khoản 11, nhưng thông báo nói về một id hỏng: không
    // được suy id từ SQLite, cũng không được mặc định về 1 (quy tắc 2).
    realtime.ban(const ThongBaoBuocDangXuat(
      lyDo: LyDoBuocDangXuat.daXoa,
      nguon: NguonBuocDangXuat.socket,
      idaccount: 0,
    ));
    final state = await cho;

    expect(await soVi(11), 1,
        reason: 'id 0 là "không biết", không phải "tài khoản 0" — và 1 là '
            'admin thật');
    expect(state, isA<AuthUnauthenticated>());
  });

  test('MỞ APP với tài khoản đã bị khoá → state cuối vẫn mang thongBao', () async {
    // Đo được trên `emulator-5554` ngày 2026-09-12: app bị đăng xuất nhưng
    // KHÔNG hiện hộp thoại. Hai handler chạy đồng thời và
    // `_onAuthCheckRequested` phát `AuthUnauthenticated()` **trơn** sau cùng,
    // đè mất state mang lý do. §3.5 đoán thứ tự ngược lại ("lần phát sau vẫn là
    // state mới") — trên máy thật thứ tự là ngược.
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    repo.khiVerifySession = () => interceptor.ban(const ThongBaoBuocDangXuat(
          lyDo: LyDoBuocDangXuat.biKhoa,
          nguon: NguonBuocDangXuat.http,
          loiNhan: 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản.',
          idaccount: 11,
        ));

    final cho = choDangXuat(bloc);
    bloc.add(AuthCheckRequested());
    await cho;
    // Để mọi handler đang chạy kịp phát nốt state của nó.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state, isA<AuthUnauthenticated>());
    expect((bloc.state as AuthUnauthenticated).thongBao, isNotNull,
        reason: 'state cuối cùng là thứ màn Đăng nhập đọc ở initState — mất '
            'thongBao ở đây là người dùng bị đá ra mà không biết vì sao');
    expect((bloc.state as AuthUnauthenticated).thongBao!.lyDo,
        LyDoBuocDangXuat.biKhoa);
    expect(await soVi(11), 1, reason: 'bị khoá thì giữ nguyên dữ liệu');
  });

  test('phiên chết phát AuthUnauthenticated trơn SAU handler → không được đè '
      'mất lý do', () async {
    // Thứ tự THẬT trên máy ảo 2026-09-12: `_onAuthCheckRequested` gọi
    // `logout()` — một lời gọi MẠNG — nên nó về sau handler cưỡng chế đăng xuất
    // vốn chỉ đụng bộ nhớ và kho token. State trơn phát sau cùng và đè mất lý
    // do; màn Đăng nhập đọc state ở `initState` nên không còn gì để hiện.
    await themVi(11);
    final repo = _RepoGia(user: _user('11'))..treoLogout = Completer<void>();
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);
    repo.khiVerifySession = () => interceptor.ban(const ThongBaoBuocDangXuat(
          lyDo: LyDoBuocDangXuat.biKhoa,
          nguon: NguonBuocDangXuat.http,
          loiNhan: 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản.',
          idaccount: 11,
        ));

    bloc.add(AuthCheckRequested());
    // Chờ handler cưỡng chế đăng xuất phát xong, TRONG LÚC `logout()` còn treo.
    await bloc.stream
        .where((s) => s is AuthUnauthenticated && s.thongBao != null)
        .first
        .timeout(const Duration(seconds: 5));

    repo.treoLogout!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect((bloc.state as AuthUnauthenticated).thongBao, isNotNull,
        reason: 'lượt đăng xuất trơn về sau không được xoá mất lý do — người '
            'dùng bị đá ra mà không biết vì sao');
  });

  test('thông báo tới SAU khi phiên chết đã phát AuthUnauthenticated trơn → '
      'state cuối vẫn phải mang thongBao', () async {
    // Chiều ngược của ca trên. Hai handler chạy đồng thời nên KHÔNG đoán được
    // cái nào phát sau; app phải đúng ở cả hai chiều. Đây là chiều mà máy ảo
    // rơi vào ngày 2026-09-12: bị đăng xuất, không hộp thoại.
    await themVi(11);
    final repo = _RepoGia(user: _user('11'))
      ..khiVerifySession = () {}; // invalid, nhưng chưa phát thông báo
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);

    final cho = choDangXuat(bloc);
    bloc.add(AuthCheckRequested());
    await cho;
    expect((bloc.state as AuthUnauthenticated).thongBao, isNull,
        reason: 'mốc bắt đầu: state trơn, đúng như `_onAuthCheckRequested` phát');

    // Lời từ chối của server tới muộn một nhịp.
    interceptor.ban(const ThongBaoBuocDangXuat(
      lyDo: LyDoBuocDangXuat.biKhoa,
      nguon: NguonBuocDangXuat.http,
      loiNhan: 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản.',
      idaccount: 11,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect((bloc.state as AuthUnauthenticated).thongBao, isNotNull,
        reason: 'chốt `state is! AuthSuccess && state is! AuthChecking` chặn mất '
            'lời từ chối tới muộn — người dùng bị đá ra mà không biết vì sao');
  });

  test('đăng nhập lại rồi bị buộc đăng xuất lần nữa → vẫn xử lý', () async {
    await themVi(11);
    final repo = _RepoGia(user: _user('11'));
    final bloc = await blocDangDangNhap(repo);

    final lanMot = choDangXuat(bloc);
    realtime.ban(_thongBaoBiKhoa);
    await lanMot;

    // Đăng nhập lại: cờ chặn phải được thả, nếu không lần thứ hai im lặng.
    final laiVao = bloc.stream.where((s) => s is AuthSuccess).first;
    bloc.add(const LoginSubmitted(email: 'dat', password: 'x'));
    await laiVao.timeout(const Duration(seconds: 5));

    final lanHai = choDangXuat(bloc);
    realtime.ban(_thongBaoBiKhoa);
    await lanHai;

    expect(repo.xoaPhienCalls, 2,
        reason: 'phiên mới thì lời từ chối của phiên cũ hết hiệu lực');
  });
}
