# Registration requires a separate login

## Goal

After a user verifies the registration OTP, the account is created but the user is not authenticated. The application returns to `/login` with empty credentials; access to protected routes requires a subsequent successful login.

## Scope

Only the Flutter Client-app authentication flow is changed. Backend contracts and files are out of scope.

## Design

`registerVerifyOtp` will submit the OTP and return the created user information without persisting access or refresh tokens and without writing offline-login credentials.

`AuthBloc` will emit a dedicated `RegistrationCompleted` state after this operation. It will not start `SyncEngine` and will not emit `AuthSuccess`; consequently the router continues to treat the user as unauthenticated.

`RegisterOtpPage` will handle `RegistrationCompleted` by navigating with `context.go('/login')`. No route extra is passed, so `LoginPage` starts with blank form fields. A success message confirms that the account was created and the user must sign in.

The legacy direct-register event and repository method will follow the same no-session contract or be removed when no longer reachable, so no registration path can authenticate a user automatically.

## Error handling

Existing OTP validation and error presentation remain unchanged. On an error, the user stays on the OTP page and no authentication data is saved.

## Verification

Tests will cover successful OTP registration not saving tokens, emitting `RegistrationCompleted` rather than `AuthSuccess`, and redirecting to `/login` with no credentials populated. Existing login behavior remains unchanged.

## Acceptance criteria

1. A successful registration OTP verification does not persist access/refresh tokens or offline credentials.
2. The user is sent to the login page with empty fields.
3. Protected routes remain inaccessible until login succeeds.
4. The client-only change does not modify Backend files.
