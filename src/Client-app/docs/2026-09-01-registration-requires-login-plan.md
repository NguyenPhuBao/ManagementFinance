# Registration Requires a Separate Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create an account after registration OTP verification without creating an authenticated Client-app session, then return the user to a blank login form.

**Architecture:** Registration is a distinct account-creation workflow, not a login workflow. The repository will discard the successful registration response rather than persisting credentials; `AuthBloc` will communicate completion using a dedicated state, which the OTP page consumes to navigate to `/login`.

**Tech Stack:** Flutter, flutter_bloc, GoRouter, Flutter Secure Storage, flutter_test.

## Global Constraints

- Modify or create files only under `src/Client-app`; do not modify Backend files.
- Preserve the user’s existing uncommitted changes in the Client-app Auth files.
- A registration OTP success must not save access/refresh tokens, cache offline credentials, start `SyncEngine`, or emit `AuthSuccess`.
- The login form must open with empty username and password fields.

---

## File structure

- Modify `lib/features/auth/data/datasources/auth_remote_data_source.dart`: retain only the OTP registration API; remove the unused direct-registration API contract.
- Modify `lib/features/auth/data/repositories/auth_repository.dart`: expose OTP verification as `Future<void>` and remove the obsolete direct registration method.
- Modify `lib/features/auth/data/repositories/auth_repository_impl.dart`: perform OTP verification without persisting a session.
- Modify `lib/features/auth/presentation/bloc/auth_event.dart`: remove the unreachable direct-registration event.
- Modify `lib/features/auth/presentation/bloc/auth_state.dart`: add `RegistrationCompleted` as a non-authenticated completion signal.
- Modify `lib/features/auth/presentation/bloc/auth_bloc.dart`: emit `RegistrationCompleted` after OTP account creation and remove the direct-registration handler.
- Modify `lib/features/auth/presentation/pages/register_page.dart`: stop treating a registration result as login success.
- Modify `lib/features/auth/presentation/pages/register_otp_page.dart`: show success feedback and navigate to `/login` when registration completes.
- Create `test/features/auth/auth_registration_test.dart`: regression tests for the repository and BLoC contracts.

## Task 1: Lock down the non-authenticated registration contract

**Files:**
- Create: `src/Client-app/test/features/auth/auth_registration_test.dart`
- Modify: `src/Client-app/lib/features/auth/data/repositories/auth_repository.dart`
- Modify: `src/Client-app/lib/features/auth/presentation/bloc/auth_state.dart`
- Modify: `src/Client-app/lib/features/auth/presentation/bloc/auth_bloc.dart`

**Interfaces:**
- Consumes: `AuthRepository.registerVerifyOtp(...)`.
- Produces: `RegistrationCompleted`, an `AuthState` emitted only after account creation succeeds.

- [ ] **Step 1: Write the failing BLoC test**

```dart
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

test('OTP registration completes without authenticating the user', () async {
  final repository = RegistrationRepositoryStub();
  final bloc = AuthBloc(authRepository: repository);
  final states = <AuthState>[];
  final subscription = bloc.stream.listen(states.add);

  bloc.add(const RegisterVerifyOtpSubmitted(
    username: 'new-user', fullname: 'New User', email: 'new@example.com',
    password: 'password123', otp: '123456',
  ));
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  expect(repository.verified, isTrue);
  expect(states, contains(isA<RegistrationCompleted>()));
  expect(states.whereType<AuthSuccess>(), isEmpty);
  await subscription.cancel();
  await bloc.close();
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/auth/auth_registration_test.dart`

Expected: compilation failure because `RegistrationCompleted` does not exist and `registerVerifyOtp` still returns `Future<UserModel>`.

- [ ] **Step 3: Define the dedicated state and change the BLoC contract**

```dart
class RegistrationCompleted extends AuthState {
  const RegistrationCompleted();
}

Future<void> _onRegisterVerifyOtpSubmitted(
  RegisterVerifyOtpSubmitted event,
  Emitter<AuthState> emit,
) async {
  emit(AuthLoading());
  try {
    await authRepository.registerVerifyOtp(
      username: event.username, fullname: event.fullname, email: event.email,
      password: event.password, otp: event.otp, phone: event.phone,
    );
    emit(const RegistrationCompleted());
  } catch (e) {
    emit(AuthError(message: e.toString().replaceAll('Exception: ', '')));
  }
}
```

Remove the `RegisterSubmitted` registration event, its `on<RegisterSubmitted>` registration, and `_onRegisterSubmitted`; it has no Client-app caller and its automatic-login behavior violates the requirement.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/auth/auth_registration_test.dart`

Expected: PASS; the state sequence contains loading and `RegistrationCompleted`, never `AuthSuccess`.

- [ ] **Step 5: Commit only intentional Client-app hunks**

Run: `git diff -- src/Client-app/lib/features/auth src/Client-app/test/features/auth`

Verify unrelated, pre-existing changes are absent from the staged diff, then stage only the intentional hunks and commit with: `test(client): cover registration without session`.

## Task 2: Remove session persistence from the OTP registration repository

**Files:**
- Modify: `src/Client-app/lib/features/auth/data/datasources/auth_remote_data_source.dart`
- Modify: `src/Client-app/lib/features/auth/data/repositories/auth_repository.dart`
- Modify: `src/Client-app/lib/features/auth/data/repositories/auth_repository_impl.dart`
- Modify: `src/Client-app/test/features/auth/auth_registration_test.dart`

**Interfaces:**
- Consumes: `AuthRemoteDataSource.registerVerifyOtp(...)`, which may return server data but does not imply login.
- Produces: `AuthRepository.registerVerifyOtp(...) -> Future<void>` with no secure-storage writes.

- [ ] **Step 1: Add the failing repository assertion**

```dart
class RecordingLocalDataSource implements AuthLocalDataSource {
  bool saveTokensCalled = false;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    saveTokensCalled = true;
  }

  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> deleteTokens() async {}
}

test('OTP registration does not save a local session', () async {
  final local = RecordingLocalDataSource();
  final repository = AuthRepositoryImpl(
    remoteDataSource: RegisterOtpRemoteStub(),
    localDataSource: local,
    secureStorage: const FlutterSecureStorage(),
  );

  await repository.registerVerifyOtp(
    username: 'new-user', fullname: 'New User', email: 'new@example.com',
    password: 'password123', otp: '123456',
  );

  expect(local.saveTokensCalled, isFalse);
});
```

```dart
class RegisterOtpRemoteStub implements AuthRemoteDataSource {
  @override
  Future<Map<String, dynamic>> registerVerifyOtp({
    required String username,
    required String fullname,
    required String email,
    required String password,
    required String otp,
    String? phone,
  }) async => {
    'accessToken': 'must-not-be-stored',
    'refreshToken': 'must-not-be-stored',
    'user': {'idaccount': 17, 'username': username, 'fullname': fullname, 'email': email},
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/auth/auth_registration_test.dart`

Expected: FAIL because the current repository calls `localDataSource.saveTokens` after OTP verification.

- [ ] **Step 3: Implement the no-session repository contract**

```dart
@override
Future<void> registerVerifyOtp({
  required String username,
  required String fullname,
  required String email,
  required String password,
  required String otp,
  String? phone,
}) async {
  await remoteDataSource.registerVerifyOtp(
    username: username, fullname: fullname, email: email,
    password: password, otp: otp, phone: phone,
  );
}
```

Remove the direct `/auth/register` declaration and implementation plus the matching `AuthRepository.register` method and implementation. Keep the OTP request and verification endpoints unchanged.

- [ ] **Step 4: Run focused tests and static analysis**

Run: `flutter test test/features/auth/auth_registration_test.dart`

Expected: PASS.

Run: `flutter analyze lib/features/auth test/features/auth`

Expected: no errors in the changed Auth files.

- [ ] **Step 5: Commit only intentional Client-app hunks**

Run: `git diff -- src/Client-app/lib/features/auth src/Client-app/test/features/auth`

After confirming the staged diff excludes existing unrelated edits, commit with: `fix(client): require login after registration`.

## Task 3: Return to a blank login form after OTP success

**Files:**
- Modify: `src/Client-app/lib/features/auth/presentation/pages/register_page.dart`
- Modify: `src/Client-app/lib/features/auth/presentation/pages/register_otp_page.dart`
- Modify: `src/Client-app/test/features/auth/auth_registration_test.dart`

**Interfaces:**
- Consumes: `RegistrationCompleted` from `AuthBloc`.
- Produces: navigation to `/login` without route extra or form values.

- [ ] **Step 1: Add a failing navigation-level assertion**

Extend the BLoC test with the explicit navigation contract represented by state: after the final `RegistrationCompleted`, assert `bloc.state is! AuthSuccess`. This is the condition used by `AppRouter` to keep protected routes unavailable. Verify page-level navigation manually in Step 4 because `RegisterOtpPage` needs the root GoRouter and AuthBloc providers.

- [ ] **Step 2: Run the focused test to verify current behavior fails**

Run: `flutter test test/features/auth/auth_registration_test.dart`

Expected: before Tasks 1–2 are implemented, the OTP success path produces `AuthSuccess`, so the assertion fails.

- [ ] **Step 3: Handle completion in the OTP page and remove stale auto-home behavior**

```dart
if (state is RegistrationCompleted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Đăng ký thành công. Vui lòng đăng nhập.')),
  );
  context.go('/login');
}
```

In `RegisterPage`, remove the `AuthSuccess` branch that sends a registration page to `/home`. Keep its `RegisterOtpSent`, `AuthError`, and loading behavior. Do not pass route extra or populate `LoginPage` controllers; its existing controllers therefore remain empty.

- [ ] **Step 4: Run tests, analyze, and manually verify the user journey**

Run: `flutter test test/features/auth/auth_registration_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: no analyzer errors introduced by the changed Client-app files.

Manual check: launch the Client-app, register a new user, verify the six-digit OTP, confirm the login screen appears with empty username and password fields, confirm `/home` cannot be opened until a successful login, then log in and confirm the normal home navigation works.

- [ ] **Step 5: Final scoped commit and verification**

Run: `git diff --check -- src/Client-app`

Expected: no whitespace errors.

Run: `git status --short src/Client-app`

Confirm that only intended Auth/test/documentation files are staged. Commit the final scoped change with: `fix(client): require login after registration`.

## Self-review

- Spec coverage: Task 2 prevents token and offline-credential persistence; Task 1 prevents `AuthSuccess` and SyncEngine startup; Task 3 redirects to blank login and preserves protected-route behavior.
- Placeholder scan: all source paths, signatures, commands, expected outcomes, and commit boundaries are specified.
- Type consistency: `registerVerifyOtp` changes from `Future<UserModel>` to `Future<void>` in the interface, implementation, test stub, and BLoC handler; `RegistrationCompleted` is the common state name in every task.
