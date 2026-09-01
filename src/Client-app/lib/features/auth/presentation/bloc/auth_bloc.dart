import 'package:flutter_bloc/flutter_bloc.dart';
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

  AuthBloc({
    required this.authRepository,
    this.defaultAccountDataInitializer,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<RegisterSendOtpRequested>(_onRegisterSendOtpRequested);
    on<RegisterVerifyOtpSubmitted>(_onRegisterVerifyOtpSubmitted);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthChecking());
    try {
      final isLoggedIn = await authRepository.checkAuthStatus();
      if (isLoggedIn) {
        final user = await authRepository.getCurrentUser();
        if (sl.isRegistered<SyncEngine>()) {
          final idAcc = int.tryParse(user?.id ?? '') ?? 1;
          sl<SyncEngine>().start(idaccount: idAcc);
        }
        emit(AuthSuccess(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
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
      if (sl.isRegistered<SyncEngine>()) {
        final idAcc = int.tryParse(user.id) ?? 1;
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
