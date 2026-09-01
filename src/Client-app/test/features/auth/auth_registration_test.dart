import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flowmoney/core/constants/app_constants.dart';
import 'package:flowmoney/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:flowmoney/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';

class RecordingLocalDataSource implements AuthLocalDataSource {
  bool saveTokensCalled = false;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    saveTokensCalled = true;
  }

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> deleteTokens() async {}
}

class InMemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = {};
  final Set<String> writtenKeys = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writtenKeys.add(key);
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}

class RegisterOtpRemoteStub implements AuthRemoteDataSource {
  @override
  Future<Map<String, dynamic>> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async =>
      {
        'accessToken': 'must-not-be-stored',
        'refreshToken': 'must-not-be-stored',
        'user': {
          'idaccount': 17,
          'username': username,
          'fullname': fullname,
          'email': email,
        },
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RegistrationRepositoryStub implements AuthRepository {
  bool verified = false;

  @override
  Future<void> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async {
    verified = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AuthCheckRepositoryStub implements AuthRepository {
  final Completer<bool> result = Completer<bool>();

  @override
  Future<bool> checkAuthStatus() => result.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('auth restoration uses AuthChecking while token status is unresolved',
      () async {
    final repository = AuthCheckRepositoryStub();
    final bloc = AuthBloc(authRepository: repository);
    final checking = bloc.stream.first;

    bloc.add(AuthCheckRequested());

    expect(await checking, isA<AuthChecking>());

    final unauthenticated = bloc.stream.firstWhere(
      (state) => state is AuthUnauthenticated,
    );
    repository.result.complete(false);
    await unauthenticated;
    await bloc.close();
  });

  test('OTP registration does not write offline credentials', () async {
    final local = RecordingLocalDataSource();
    final storage = InMemorySecureStorage();
    final repository = AuthRepositoryImpl(
      remoteDataSource: RegisterOtpRemoteStub(),
      localDataSource: local,
      secureStorage: storage,
    );

    await repository.registerVerifyOtp(
      username: 'new-user',
      fullname: 'New User',
      email: 'new@example.com',
      password: 'password123',
      otp: '123456',
    );

    expect(local.saveTokensCalled, isFalse);
    for (final key in [
      AppConstants.offlineUsernameKey,
      AppConstants.offlinePasswordHashKey,
      AppConstants.offlineUserDataKey,
    ]) {
      expect(storage.writtenKeys, isNot(contains(key)));
      expect(await storage.read(key: key), isNull);
    }
  });

  test('OTP registration completes without authenticating the user', () async {
    final repository = RegistrationRepositoryStub();
    final bloc = AuthBloc(authRepository: repository);
    final states = <AuthState>[];
    final subscription = bloc.stream.listen(states.add);
    final completion = bloc.stream.firstWhere(
      (state) => state is RegistrationCompleted,
    );

    bloc.add(const RegisterVerifyOtpSubmitted(
      username: 'new-user',
      fullname: 'New User',
      email: 'new@example.com',
      password: 'password123',
      otp: '123456',
    ));
    await completion;

    expect(repository.verified, isTrue);
    expect(states, contains(isA<RegisterOtpLoading>()));
    expect(states, contains(isA<RegistrationCompleted>()));
    expect(states.whereType<AuthSuccess>(), isEmpty);
    expect(bloc.state, isNot(isA<AuthSuccess>()));
    await subscription.cancel();
    await bloc.close();
  });
}
