import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
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
        sl<SyncEngine>().start(idaccount: idAcc);
      }
      emit(AuthSuccess(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.register(
          event.name, event.fullname, event.email, event.password);
      if (sl.isRegistered<SyncEngine>()) {
        final idAcc = int.tryParse(user.id) ?? 1;
        sl<SyncEngine>().start(idaccount: idAcc);
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
}
