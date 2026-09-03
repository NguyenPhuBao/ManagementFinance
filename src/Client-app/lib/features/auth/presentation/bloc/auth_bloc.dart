import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/repositories/auth_repository.dart';
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

  AuthBloc({
    required this.authRepository,
    this.defaultAccountDataInitializer,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionInvalidated>(_onSessionInvalidated);
    on<RegisterSendOtpRequested>(_onRegisterSendOtpRequested);
    on<RegisterVerifyOtpSubmitted>(_onRegisterVerifyOtpSubmitted);

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
  }

  @override
  Future<void> close() async {
    await _sessionInvalidSub?.cancel();
    await _tokenClearedSub?.cancel();
    return super.close();
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

    if (sl.isRegistered<SyncEngine>()) {
      sl<SyncEngine>().stop();
    }
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthChecking());
    try {
      final isLoggedIn = await authRepository.checkAuthStatus();
      if (!isLoggedIn) {
        emit(AuthUnauthenticated());
        return;
      }

      final user = await authRepository.getCurrentUser();

      // Hỏi server xem phiên còn trỏ tới tài khoản CÓ THẬT không.
      // Trước đây bước này không tồn tại: client chỉ thấy "có chuỗi token" là
      // coi như đăng nhập hợp lệ. Nếu tài khoản đã bị xoá khỏi CSDL mà JWT còn
      // hạn, SyncEngine vẫn khởi động và mọi lần đẩy dữ liệu đều vỡ khoá ngoại
      // fk_category_account / fk_transaction_account — lặp lại vô hạn.
      final session = await authRepository.verifySession();
      if (session == SessionStatus.invalid) {
        await authRepository.logout();
        emit(AuthUnauthenticated());
        return; // KHÔNG khởi động SyncEngine với phiên đã chết
      }
      // valid hoặc unknown (mất mạng / lỗi 5xx) → giữ phiên, đúng offline-first.

      // Không còn fallback `?? 1`: id hỏng mà mặc định thành 1 nghĩa là ghi dữ
      // liệu dưới danh nghĩa tài khoản admin.
      final idAcc = int.tryParse(user?.id ?? '');
      if (idAcc == null || idAcc <= 0) {
        await authRepository.logout();
        emit(AuthUnauthenticated());
        return;
      }

      if (sl.isRegistered<SyncEngine>()) {
        // Dọn dữ liệu tài khoản khác Ở ĐÂY NỮA, không chỉ ở luồng đăng nhập:
        // người dùng mở lại app mà không đăng xuất/đăng nhập lại thì dữ liệu
        // rác của tài khoản cũ vẫn nằm nguyên trong máy.
        await sl<AppDatabase>().purgeDataForOtherAccounts(idAcc);
        sl<SyncEngine>().start(idaccount: idAcc);
      }
      emit(AuthSuccess(user: user));
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
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
        await sl<SyncEngine>().start(idaccount: idAcc);
        await defaultAccountDataInitializer?.ensureForAccount(idAcc);
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
    if (sl.isRegistered<SyncEngine>()) {
      sl<SyncEngine>().stop();
    }
    await authRepository.logout();
    emit(AuthUnauthenticated());
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
