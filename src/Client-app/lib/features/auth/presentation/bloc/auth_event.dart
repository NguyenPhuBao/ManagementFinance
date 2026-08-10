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

class RegisterSubmitted extends AuthEvent {
  final String name;     // username
  final String fullname; // họ và tên
  final String email;
  final String password;

  const RegisterSubmitted({
    required this.name,
    required this.fullname,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [name, fullname, email, password];
}

class LogoutRequested extends AuthEvent {}
