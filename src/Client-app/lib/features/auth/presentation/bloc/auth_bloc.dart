import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';
import '../../../../core/auth/buoc_dang_xuat.dart';
import '../../../category/data/services/default_category_seeder.dart';
import '../../../category/data/services/personal_default_categories.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/notification/notification_scanner.dart';
import '../../../../core/realtime/realtime_channel.dart';
import '../../data/repositories/auth_repository.dart';
import '../an_the_cho_xoa.dart';
import '../../../wallet/data/services/default_account_data_initializer.dart';
import 'auth_event.dart';
import 'auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final DefaultAccountDataInitializer? defaultAccountDataInitializer;

  StreamSubscription<void>? _sessionInvalidSub;
  StreamSubscription<void>? _tokenClearedSub;
  StreamSubscription<ThongBaoBuocDangXuat>? _buocDangXuatSocketSub;
  StreamSubscription<ThongBaoBuocDangXuat>? _buocDangXuatHttpSub;

  /// Một lượt cưỡng chế đăng xuất đang chạy.
  ///
  /// ⚠️ Không dùng `state` để chặn: state chỉ đổi ở bước cuối, mà handler của
  /// Bloc chạy **đồng thời** — thông báo thứ hai (socket rồi HTTP, hoặc ngược
  /// lại) tới lúc lượt đầu còn đang `await` vẫn thấy `AuthSuccess` và sẽ dọn
  /// SQLite thêm một lần nữa (spec cưỡng chế đăng xuất §9).
  bool _dangBuocDangXuat = false;

  /// Lý do của lượt cưỡng chế đăng xuất đang chạy, giữ lại để **mọi** đường
  /// đăng xuất khác không đè mất nó.
  ///
  /// ⚠️ Vì sao cần: `verifySession()` xếp chính cái 401 mang mã ấy là phiên
  /// chết, nên `_onAuthCheckRequested` cũng đăng xuất — và nó gọi `logout()`,
  /// một lời gọi **mạng**, nên về **sau** handler cưỡng chế đăng xuất (chỉ đụng
  /// bộ nhớ và kho token). Lượt phát trơn về sau ấy đè mất lý do, mà màn Đăng
  /// nhập đọc state ở `initState` — người dùng bị đá ra không kèm hộp thoại.
  /// Đo trên `emulator-5554` ngày 2026-09-12.
  ThongBaoBuocDangXuat? _thongBaoBuocDangXuat;

  /// Phát `AuthUnauthenticated`, **kèm lý do nếu phiên này bị đẩy ra**.
  ///
  /// Dùng ở mọi đường *phiên chết*. Đường người dùng **tự** bấm Đăng xuất thì
  /// không đi qua đây — ở đó không có gì để giải thích.
  void _phatChuaDangNhap(Emitter<AuthState> emit) =>
      emit(AuthUnauthenticated(thongBao: _thongBaoBuocDangXuat));

  AuthBloc({
    required this.authRepository,
    this.defaultAccountDataInitializer,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionInvalidated>(_onSessionInvalidated);
    on<ThongTinTaiKhoanThayDoi>(_onThongTinTaiKhoanThayDoi);
    on<RegisterSendOtpRequested>(_onRegisterSendOtpRequested);
    on<RegisterVerifyOtpSubmitted>(_onRegisterVerifyOtpSubmitted);
    on<TaiKhoanBiBuocDangXuat>(_onTaiKhoanBiBuocDangXuat);

    // SyncEngine phát tín hiệu khi phát hiện phiên trỏ tới tài khoản không còn
    // tồn tại, để không phải chờ tới lần mở app kế tiếp mới xử lý.
    if (sl.isRegistered<SyncEngine>()) {
      _sessionInvalidSub = sl<SyncEngine>()
          .sessionInvalidStream
          .listen((_) => add(SessionInvalidated()));
    }

    // AuthInterceptor xoá token khi không thể làm mới phiên. Trước đây việc đó
    // diễn ra trong im lặng: bloc vẫn ở AuthSuccess với kho token rỗng, còn app
    // quay vòng 401 → refresh hỏng → xoá token. Nối vào cùng một đường xử lý
    // với tín hiệu của SyncEngine — vẫn hỏi lại server trước khi đăng xuất.
    if (sl.isRegistered<AuthInterceptor>()) {
      _tokenClearedSub = sl<AuthInterceptor>()
          .sessionExpiredStream
          .listen((_) => add(SessionInvalidated()));
    }

    // Ba nguồn, một cửa vào (§3.5). Cùng khuôn với `sessionExpiredStream` ngay
    // trên — khác ở chỗ luồng này mang theo LÝ DO, nên không hỏi lại server:
    // server vừa nói xong, không còn gì để hỏi.
    if (sl.isRegistered<RealtimeChannel>()) {
      _buocDangXuatSocketSub = sl<RealtimeChannel>()
          .buocDangXuat
          .listen((tb) => add(TaiKhoanBiBuocDangXuat(tb)));
    }
    if (sl.isRegistered<AuthInterceptor>()) {
      _buocDangXuatHttpSub = sl<AuthInterceptor>()
          .taiKhoanBiTuChoi
          .listen((tb) => add(TaiKhoanBiBuocDangXuat(tb)));
    }
  }

  @override
  Future<void> close() async {
    await _sessionInvalidSub?.cancel();
    await _tokenClearedSub?.cancel();
    await _buocDangXuatSocketSub?.cancel();
    await _buocDangXuatHttpSub?.cancel();
    return super.close();
  }

  /// Dừng mọi thứ sống theo vòng đời của phiên đăng nhập.
  ///
  /// Socket còn sống sau khi đăng xuất nghĩa là máy vẫn nằm trong room
  /// `account_<id>` của người vừa rời đi — lỗi bảo mật, không phải lỗi giao
  /// diện. Bộ quét thông báo còn sống thì nhắc hoá đơn của người trước nổ trên
  /// màn hình khoá của người sau (`NotificationScanner.stop()` gọi `cancelAll`
  /// bên trong, vì lịch nằm trong AlarmManager chứ không trong SQLite).
  ///
  /// Chuỗi này từng được chép ở `_onSessionInvalidated` và `_onLogoutRequested`;
  /// lần thứ ba là lúc gom về một chỗ.
  Future<void> _dungMoiThuCuaPhien() async {
    if (sl.isRegistered<SyncEngine>()) {
      sl<SyncEngine>().stop();
    }
    if (sl.isRegistered<NotificationScanner>()) {
      await sl<NotificationScanner>().stop();
    }
    if (sl.isRegistered<RealtimeChannel>()) {
      await sl<RealtimeChannel>().stop();
    }
  }

  /// Server nói tài khoản này không được dùng nữa — spec §3.5.
  Future<void> _onTaiKhoanBiBuocDangXuat(
    TaiKhoanBiBuocDangXuat event,
    Emitter<AuthState> emit,
  ) async {
    if (_dangBuocDangXuat) return;

    // ⚠️ Phải nhận cả khi state ĐÃ là `AuthUnauthenticated`.
    //
    // Đo trên `emulator-5554` ngày 2026-09-12: mở app với tài khoản vừa bị
    // khoá thì app bị đăng xuất **mà không có hộp thoại**. Lý do: `verifySession()`
    // xếp 401 ấy là phiên chết, nên `_onAuthCheckRequested` phát
    // `AuthUnauthenticated()` **trơn** — và lời từ chối của interceptor tới sau
    // đó một nhịp. Hai handler chạy đồng thời nên thứ tự **không đoán được**;
    // spec §3.5 đoán một chiều, máy thật rơi vào chiều kia.
    //
    // Ở đây chỉ bỏ qua những state mà xen vào là phá chuyện khác: `AuthInitial`
    // (chưa ai đăng nhập), `AuthLoading` (một lượt đăng nhập MỚI đang chạy —
    // lời từ chối của phiên cũ không được giết nó), `AuthError`, và các state
    // của luồng đăng ký.
    final dangCoPhien = state is AuthSuccess || state is AuthChecking;
    final vuaBiDayRa = state is AuthUnauthenticated;
    if (!dangCoPhien && !vuaBiDayRa) return;
    _dangBuocDangXuat = true;

    final thongBao = event.thongBao;
    // Ghi nhớ NGAY, trước mọi `await`: đường "phiên chết" chạy song song cũng
    // đang trên đường phát `AuthUnauthenticated`, và nó phải mang theo lý do
    // này dù về trước hay về sau.
    _thongBaoBuocDangXuat = thongBao;

    await _dungMoiThuCuaPhien();

    // Dọn bản sao cục bộ CHỈ khi tài khoản thật sự đã bị xoá, và chỉ khi lời ấy
    // không đến từ nhánh làm mới token — ở đó một lỗi lược đồ phía server còn
    // đội lốt được `ACCOUNT_DELETED` (CAN-LAM 17 §2.5, spec §3.6b). Bỏ ngoại lệ
    // `lamMoi` khi backend sửa xong.
    if (thongBao.lyDo == LyDoBuocDangXuat.daXoa &&
        thongBao.nguon != NguonBuocDangXuat.lamMoi) {
      // `idaccount` chỉ đến từ chính lời server nói, hoặc từ phiên đăng nhập —
      // không suy từ SQLite, không mặc định về 1 (quy tắc 2 `CLAUDE.md`).
      final idTuThongBao = thongBao.idaccount;
      final idTuPhien =
          int.tryParse((await authRepository.getCurrentUser())?.id ?? '');
      final id = idTuThongBao ?? idTuPhien;
      if (id != null && id > 0 && sl.isRegistered<AppDatabase>()) {
        await sl<AppDatabase>().purgeDataForAccount(id);
      }
    }

    // KHÔNG gọi `logout()`: route `/auth/logout` đi qua `authenticate` và sẽ
    // trả 401 mang mã rồi quay vòng qua interceptor (§3.5 bước 4). Interceptor
    // có thể đã xoá token trước (§3.3) — gọi lại vô hại, bộ nhớ đệm người dùng
    // vẫn phải xoá ở đây.
    await authRepository.xoaPhienTrenMay();
    emit(AuthUnauthenticated(thongBao: thongBao));
  }

  Future<void> _onSessionInvalidated(
    SessionInvalidated event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthSuccess) return; // đã đăng xuất rồi thì thôi

    // KHÔNG tin ngay vào tín hiệu: nó bắt nguồn từ việc khớp chuỗi tên
    // constraint trong thông báo lỗi của Prisma — thứ có thể đổi theo phiên bản.
    // Hỏi lại server cho chắc; chỉ đăng xuất khi server thật sự phủ nhận phiên.
    final session = await authRepository.verifySession();
    if (session != SessionStatus.invalid) return;

    await _dungMoiThuCuaPhien();
    await authRepository.logout();
    _phatChuaDangNhap(emit);
  }

  Future<void> _onThongTinTaiKhoanThayDoi(
    ThongTinTaiKhoanThayDoi event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthSuccess) return;
    final user = await authRepository.getCurrentUser();
    // Kiểm lại: các handler của Bloc chạy đồng thời theo loại sự kiện (mặc định
    // của flutter_bloc), nên trong lúc await ở trên đang chờ, đăng xuất hoặc
    // phiên chết có thể đã phát AuthUnauthenticated — không được emit đè lên.
    if (state is! AuthSuccess) return;
    if (user == null) return;
    emit(AuthSuccess(user: user));
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthChecking());
    try {
      final isLoggedIn = await authRepository.checkAuthStatus();
      if (!isLoggedIn) {
        _phatChuaDangNhap(emit);
        return;
      }

      // Hỏi server xem phiên còn trỏ tới tài khoản CÓ THẬT không.
      // Trước đây bước này không tồn tại: client chỉ thấy "có chuỗi token" là
      // coi như đăng nhập hợp lệ. Nếu tài khoản đã bị xoá khỏi CSDL mà JWT còn
      // hạn, SyncEngine vẫn khởi động và mọi lần đẩy dữ liệu đều vỡ khoá ngoại
      // fk_category_account / fk_transaction_account — lặp lại vô hạn.
      final session = await authRepository.verifySession();
      if (session == SessionStatus.invalid) {
        await authRepository.logout();
        _phatChuaDangNhap(emit);
        return; // KHÔNG khởi động SyncEngine với phiên đã chết
      }
      // valid hoặc unknown (mất mạng / lỗi 5xx) → giữ phiên, đúng offline-first.

      // Đọc người dùng SAU khi xác minh: `verifySession` đồng bộ `status` chờ xoá
      // từ `/auth/profile` vào bộ nhớ đệm (spec cưỡng chế đăng xuất §4.3).
      final user = await authRepository.getCurrentUser();

      // Không còn fallback `?? 1`: id hỏng mà mặc định thành 1 nghĩa là ghi dữ
      // liệu dưới danh nghĩa tài khoản admin.
      final idAcc = int.tryParse(user?.id ?? '');
      if (idAcc == null || idAcc <= 0) {
        await authRepository.logout();
        _phatChuaDangNhap(emit);
        return;
      }

      if (sl.isRegistered<SyncEngine>()) {
        // Dọn dữ liệu tài khoản khác Ở ĐÂY NỮA, không chỉ ở luồng đăng nhập:
        // người dùng mở lại app mà không đăng xuất/đăng nhập lại thì dữ liệu
        // rác của tài khoản cũ vẫn nằm nguyên trong máy.
        await sl<AppDatabase>().purgeDataForOtherAccounts(idAcc);
        final personal = sl.isRegistered<PersonalDefaultCategories>()
            ? sl<PersonalDefaultCategories>()
            : null;
        // Chuyển dữ liệu trỏ vào hàng seed `cat_*` cũ. Chạy TRƯỚC start(): việc
        // này phải xong trước khi chu kỳ đồng bộ đầu tiên chạm vào.
        await personal?.convertLegacyRows(idAcc);
        final engine = sl<SyncEngine>();
        // Không await ở đường mở app: chờ một vòng mạng ở đây làm màn hình đầu
        // tiên đứng hình. Nối phần tạo danh mục vào sau bằng `then`.
        // Bám đúng vòng đời của SyncEngine. Cố ý KHÔNG gắn ở home_page.dart —
        // chỗ đó gọi start() ngay trong build(), tức mỗi lần Home rebuild là
        // một lời gọi nữa.
        if (sl.isRegistered<NotificationScanner>()) {
          await sl<NotificationScanner>().start(idAcc);
        }
        // Kênh thời gian thực sống đúng bằng vòng đời của phiên đăng nhập, y
        // như bộ quét thông báo ngay trên.
        if (sl.isRegistered<RealtimeChannel>()) {
          await sl<RealtimeChannel>().start(idaccount: idAcc);
        }
        unawaited(engine.start(idaccount: idAcc).then((_) async {
          // Pull hỏng (mất mạng, server lỗi) thì CSDL cục bộ chưa đáng tin.
          // Bộ mặc định của backend chưa chắc đã về, mà thiếu nó thì không có
          // khuôn để sao chép — bỏ qua, lần mở app sau thử lại.
          if (!engine.hasCompletedPull) return;
          await _taoBanSaoDanhMuc(idAcc);
        }));
      }
      emit(AuthSuccess(user: user));
    } catch (e) {
      _phatChuaDangNhap(emit);
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    // Phiên mới thì lời từ chối của phiên cũ hết hiệu lực. Không thả cờ ở đây
    // thì lần bị đẩy ra thứ hai trong cùng một lần chạy app sẽ im lặng — app
    // kẹt ở `AuthSuccess` với một tài khoản server đã từ chối.
    _dangBuocDangXuat = false;
    _thongBaoBuocDangXuat = null;
    emit(AuthLoading());
    try {
      final user = await authRepository.login(event.email, event.password);
      // Không dùng `?? 1`: nếu response đăng nhập thiếu idaccount thì phải báo
      // lỗi rõ ràng, thay vì âm thầm ghi dữ liệu dưới danh nghĩa admin (id=1).
      final idAcc = int.tryParse(user.id);
      if (idAcc == null || idAcc <= 0) {
        emit(const AuthError(
            message: 'Máy chủ không trả về mã tài khoản hợp lệ.'));
        return;
      }
      if (sl.isRegistered<SyncEngine>()) {
        // Dọn dữ liệu cục bộ của các tài khoản KHÁC trước khi bật đồng bộ:
        // dòng dữ liệu sót lại từ tài khoản cũ sẽ bị đẩy đi dưới id cũ và
        // luôn thất bại (Ownership mismatch hoặc vỡ khoá ngoại).
        await sl<AppDatabase>().purgeDataForOtherAccounts(idAcc);
        final personal = sl.isRegistered<PersonalDefaultCategories>()
            ? sl<PersonalDefaultCategories>()
            : null;
        // Chuyển dữ liệu trỏ vào hàng seed `cat_*` cũ. Chạy TRƯỚC start(): việc
        // này phải xong trước khi chu kỳ đồng bộ đầu tiên chạm vào.
        await personal?.convertLegacyRows(idAcc);
        final engine = sl<SyncEngine>();
        if (sl.isRegistered<NotificationScanner>()) {
          await sl<NotificationScanner>().start(idAcc);
        }
        // Kênh thời gian thực sống đúng bằng vòng đời của phiên đăng nhập, y
        // như bộ quét thông báo ngay trên.
        if (sl.isRegistered<RealtimeChannel>()) {
          await sl<RealtimeChannel>().start(idaccount: idAcc);
        }
        await engine.start(idaccount: idAcc);
        // Tạo bản sao riêng của bộ danh mục mặc định, SAU khi đã pull — bộ
        // mặc định chỉ có mặt ở máy này sau khi pull mang nó về. Chưa có thì
        // hàm không tạo gì, đúng như G14 dạy: đừng quyết định về danh mục khi
        // CSDL cục bộ chưa đáng tin.
        if (engine.hasCompletedPull) {
          await _taoBanSaoDanhMuc(idAcc);
        }
        await defaultAccountDataInitializer?.ensureForAccount(idAcc);
      }
      // Lựa chọn "Để sau" của thẻ chờ xoá chỉ sống trong một phiên app; người
      // đăng nhập kế tiếp không được thừa hưởng nó (spec §5.2).
      if (sl.isRegistered<AnTheChoXoa>()) {
        sl<AnTheChoXoa>().value = false;
      }
      emit(AuthSuccess(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _dungMoiThuCuaPhien();
    await authRepository.logout();
    emit(const AuthUnauthenticated());
  }

  // ─── OTP Register Handlers ──────────────────────────────────────────────

  Future<void> _onRegisterSendOtpRequested(
    RegisterSendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    final registration = RegisterOtpSent(
      email: event.email,
      username: event.username,
      fullname: event.fullname,
      password: event.password,
      phone: event.phone,
    );
    emit(
      event.isResend
          ? RegisterOtpLoading(registration: registration)
          : AuthLoading(),
    );
    try {
      await authRepository.registerSendOtp(
        username: event.username,
        fullname: event.fullname,
        email: event.email,
        password: event.password,
        phone: event.phone,
      );
      emit(registration);
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      emit(
        event.isResend
            ? RegisterOtpError(message: message, registration: registration)
            : AuthError(message: message),
      );
    }
  }

  Future<void> _onRegisterVerifyOtpSubmitted(
    RegisterVerifyOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final registration = RegisterOtpSent(
      email: event.email,
      username: event.username,
      fullname: event.fullname,
      password: event.password,
      phone: event.phone,
    );
    emit(RegisterOtpLoading(registration: registration));
    try {
      await authRepository.registerVerifyOtp(
        username: event.username,
        fullname: event.fullname,
        email: event.email,
        password: event.password,
        otp: event.otp,
        phone: event.phone,
      );
      emit(RegistrationCompleted(registration: registration));
    } catch (e) {
      emit(
        RegisterOtpError(
          message: e.toString().replaceAll('Exception: ', ''),
          registration: registration,
        ),
      );
    }
  }

  /// Tạo bản sao riêng của bộ danh mục mặc định cho [idAcc].
  ///
  /// ⚠️ **Cố ý KHÔNG bọc `try/catch`.** Bản mặc định toàn cục đã bị ẩn khỏi mọi
  /// danh sách, nên một lượt seed hỏng trong im lặng nghĩa là người dùng mở app
  /// ra thấy danh sách danh mục **rỗng** và không ghi nổi một giao dịch, mà
  /// không ai biết vì sao. Trước đây bộ mặc định toàn cục chính là tấm lưới đỡ
  /// cho tình huống ấy; nay không còn.
  ///
  /// Luật trong `DefaultCategorySeeder` vốn luỹ đẳng nên lần mở app sau tự thử
  /// lại — đó mới là cơ chế phục hồi, không phải việc nuốt lỗi ở đây.
  Future<void> _taoBanSaoDanhMuc(int idAcc) async {
    final seeder = sl.isRegistered<DefaultCategorySeeder>()
        ? sl<DefaultCategorySeeder>()
        : null;
    final daTao = await seeder?.seedForAccount(idAcc) ?? 0;
    if (daTao > 0) {
      debugPrint('[Category] Đã tạo $daTao bản sao danh mục mặc định.');
      // ⚠️ Phải hẹn một chu kỳ đẩy. Bước seed chạy SAU chu kỳ đồng bộ vừa xong
      // (nó nằm trong `.then()` của `engine.start()`), nên những hàng vừa tạo
      // không có ai đẩy đi: chúng nằm ở `pending` cho tới lần khởi động nguội
      // kế tiếp. Đo được trên emulator-5554 ngày 2026-09-07 — 13 bản sao được
      // tạo, app quay lại tiền cảnh, và không một chu kỳ đồng bộ nào chạy.
      //
      // Cùng khuôn với `CategoryManagementRepositoryImpl`: mọi đường ghi danh
      // mục đều kết thúc bằng `scheduleSync()`.
      if (sl.isRegistered<SyncEngine>()) {
        sl<SyncEngine>().scheduleSync();
      }
    }
  }
}
