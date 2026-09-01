import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class LogoutRequested extends AuthEvent {}
// ─── OTP Register Events ─────────────────────────────────────────────────────

/// Bước 1: Gửi OTP đăng ký về email
class RegisterSendOtpRequested extends AuthEvent {
  final String username;
  final String fullname;
  final String email;
  final String password;
  final String? phone;
  final bool isResend;

  const RegisterSendOtpRequested({
    required this.username,
    required this.fullname,
    required this.email,
    required this.password,
    this.phone,
    this.isResend = false,
  });

  @override
  List<Object?> get props =>
      [username, fullname, email, password, phone, isResend];
}

/// Bước 2: Xác thực OTP và tạo tài khoản
class RegisterVerifyOtpSubmitted extends AuthEvent {
  final String username;
  final String fullname;
  final String email;
  final String password;
  final String otp;
  final String? phone;

  const RegisterVerifyOtpSubmitted({
    required this.username,
    required this.fullname,
    required this.email,
    required this.password,
    required this.otp,
    this.phone,
  });

  @override
  List<Object?> get props => [username, fullname, email, password, otp, phone];
}
