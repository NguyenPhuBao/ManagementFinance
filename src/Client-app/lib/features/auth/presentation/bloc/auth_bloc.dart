import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/buoc_dang_xuat.dart';
import '../../../../core/auth/phien_dieu_phoi.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final PhienDieuPhoi? _phien;

  StreamSubscription<void>? _phienChetSub;
  StreamSubscription<ThongBaoBuocDangXuat>? _buocDangXuatSub;

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

  /// [phien] `null` = không điều phối gì — đúng hành vi cũ khi `sl` chưa đăng ký dịch vụ; widget test dựng Bloc trần.
  AuthBloc({required this.authRepository, PhienDieuPhoi? phien})
      : _phien = phien,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionInvalidated>(_onSessionInvalidated);
    on<ThongTinTaiKhoanThayDoi>(_onThongTinTaiKhoanThayDoi);
    on<RegisterSendOtpRequested>(_onRegisterSendOtpRequested);
    on<RegisterVerifyOtpSubmitted>(_onRegisterVerifyOtpSubmitted);
    on<TaiKhoanBiBuocDangXuat>(_onTaiKhoanBiBuocDangXuat);

    // Hai luồng gộp thay cho bốn subscription qua `sl`: phiên có thể chết → hỏi lại server (không tin ngay tín hiệu,
    // nó khớp chuỗi tên constraint); lời từ chối mang LÝ DO → không hỏi lại, server vừa nói xong (§3.5).
    _phienChetSub = phien?.phienCoTheChet.listen((_) => add(SessionInvalidated()));
    _buocDangXuatSub = phien?.buocDangXuat.listen((tb) => add(TaiKhoanBiBuocDangXuat(tb)));
  }

  @override
  Future<void> close() async {
    await _phienChetSub?.cancel();
    await _buocDangXuatSub?.cancel();
    return super.close();
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

    await _phien?.dongPhien();

    // Dọn bản sao cục bộ CHỈ khi tài khoản thật sự đã bị xoá, và chỉ khi lời ấy
    // không đến từ nhánh làm mới token — ở đó một lỗi lược đồ phía server từng
    // đội lốt được `ACCOUNT_DELETED` (CAN-LAM 17 §2.5, spec §3.6b). Backend đã
    // sửa (gộp 2026-09-12).
    //
    // ⚠️ Chú thích cũ ở đây nói *"xoá qua admin thu hồi refresh token nên nhánh
    // làm mới trả 401 không mã — `daXoa` không tới được đây"*. Đúng tới bản
    // `cbbeeb4`, **sai từ `7779999`**: đo đầu-cuối 2026-09-13 cho thấy xoá mềm
    // qua admin trả **401 + `ACCOUNT_DELETED`** dù 4/4 refresh token đã bị thu
    // hồi (G36 đóng). Nên nhánh này **có** chạy thật, và ngoại lệ dưới đây đang
    // giữ lại SQLite cho một ca có thật — không còn là lớp che ca giả định.
    //
    // ✅ Người dùng chốt 2026-09-13: **GIỮ** ngoại lệ (spec §3.6b). SQLite là
    // bản duy nhất trên máy, nên dọn nhầm là mất thật; nếu xoá là đúng thì
    // `purgeDataForOtherAccounts` vẫn dọn khi tài khoản khác đăng nhập — chỉ
    // hoãn chứ không bỏ. Đừng gỡ điều kiện `nguon != lamMoi` dưới đây.
    if (thongBao.lyDo == LyDoBuocDangXuat.daXoa &&
        thongBao.nguon != NguonBuocDangXuat.lamMoi) {
      // `idaccount` chỉ đến từ chính lời server nói, hoặc từ phiên đăng nhập —
      // không suy từ SQLite, không mặc định về 1 (quy tắc 2 `CLAUDE.md`).
      final idTuThongBao = thongBao.idaccount;
      final idTuPhien =
          int.tryParse((await authRepository.getCurrentUser())?.id ?? '');
      final id = idTuThongBao ?? idTuPhien;
      if (id != null && id > 0) await _phien?.xoaDuLieu(id);
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

    await _phien?.dongPhien();
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

      // ── Phần không chạm mạng: hiện dữ liệu trên máy NGAY (2026-10-09). ──
      // Trước đây `AuthSuccess` chỉ phát sau `verifySession()` (GET
      // /auth/profile, trần 30 s): server chậm, Render đang ngủ, Wi-Fi không ra
      // Internet là mọi trang quay vòng tới 30 s và Trang chủ in "0 đ" /
      // "Người dùng" — trong khi dữ liệu nằm sẵn trong SQLite (offline-first).
      final user = await authRepository.getCurrentUser();

      // Không còn fallback `?? 1`: id hỏng mà mặc định thành 1 nghĩa là ghi dữ
      // liệu dưới danh nghĩa tài khoản admin.
      final idAcc = int.tryParse(user?.id ?? '');
      if (idAcc == null || idAcc <= 0) {
        await authRepository.logout();
        _phatChuaDangNhap(emit);
        return;
      }

      // Dọn tài khoản khác (cả khi mở lại app không đăng nhập lại), chuyển hàng seed `cat_*` cũ TRƯỚC start(), rồi bộ quét
      // (nhập hàng chờ D1, số trên chuông, nhắc, quá hạn, tự trả/trích) — TRƯỚC `AuthSuccess` (2026-10-09):
      // `MoTuTomTatBienDong` điều hướng ngay khi thấy `AuthSuccess`, danh sách chờ ghi phải đủ kể cả khi server không tới được.
      await _phien?.moPhienCucBo(idAcc);
      emit(AuthSuccess(user: user));

      // ── Phần chạm mạng: hỏi server xem phiên còn trỏ tới tài khoản CÓ THẬT. ──
      // Trước khi có bước này client chỉ thấy "có chuỗi token" là coi như đăng
      // nhập hợp lệ. Nếu tài khoản đã bị xoá khỏi CSDL mà JWT còn hạn,
      // SyncEngine vẫn khởi động và mọi lần đẩy dữ liệu đều vỡ khoá ngoại
      // fk_category_account / fk_transaction_account — lặp lại vô hạn.
      final session = await authRepository.verifySession();

      // Trong lúc chờ, các handler khác chạy đồng thời (mặc định của
      // flutter_bloc): người dùng đã đăng xuất, bị cưỡng chế đăng xuất, hoặc
      // phiên bị báo chết — lượt mở app về muộn KHÔNG được khởi động gì, cũng
      // không được phát lại AuthSuccess đè lên (ca test "đăng xuất trong lúc
      // chờ server" — lỗi có sẵn trước bản này).
      if (!_vanLaPhien(user)) return;

      if (session == SessionStatus.invalid) {
        await _phien?.dongPhien(); // bộ quét đã chạy từ phần không chạm mạng
        await authRepository.logout();
        _phatChuaDangNhap(emit);
        return; // KHÔNG khởi động SyncEngine với phiên đã chết
      }
      // valid hoặc unknown (mất mạng / lỗi 5xx) → giữ phiên, đúng offline-first.

      // Đọc lại SAU khi xác minh: `verifySession` đồng bộ `status` chờ xoá từ
      // `/auth/profile` vào bộ nhớ đệm (spec cưỡng chế đăng xuất §4.3).
      final moi = await authRepository.getCurrentUser();
      if (!_vanLaPhien(user)) return;
      // `UserModel` không có `==`: so bằng dạng lưu, chỉ phát khi thật sự đổi.
      if (moi != null &&
          moi.id == user!.id &&
          !mapEquals(moi.toJson(), user.toJson())) {
        emit(AuthSuccess(user: moi));
      }

      // Kênh thời gian thực sống đúng bằng vòng đời phiên; đồng bộ KHÔNG await ở đường mở app (chờ một vòng mạng làm
      // màn đầu đứng hình) — bản sao danh mục nối vào sau chu kỳ đầu, pull hỏng thì lần mở app sau thử lại.
      final phien = _phien;
      if (phien != null) {
        await phien.batThoiGianThuc(idAcc);
        if (!_vanLaPhien(user)) return;
        await phien.batDongBo(idAcc, cho: false);
      }
    } catch (e) {
      _phatChuaDangNhap(emit);
    }
  }

  /// Bloc còn đang ở phiên của [user] không — sau mỗi `await` của lượt mở app.
  bool _vanLaPhien(UserModel? user) {
    final s = state;
    return s is AuthSuccess && s.user?.id == user?.id;
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
      // Dọn tài khoản khác TRƯỚC khi bật đồng bộ (dòng sót lại bị đẩy dưới id cũ và luôn thất bại).
      await _phien?.moPhienCucBo(idAcc);
      await _phien?.batThoiGianThuc(idAcc);
      // Đợi chu kỳ đầu rồi mới tạo bản sao danh mục (G14: đừng quyết định về danh mục khi CSDL cục bộ chưa đáng tin).
      await _phien?.batDongBo(idAcc, cho: true);
      // Seed hai ví tài khoản mới; cờ "Để sau" và ✕ ví trùng tên chỉ sống một phiên app (spec §5.2, G63).
      await _phien?.sauDangNhap(idAcc);
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
    await _phien?.dongPhien();
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
}
