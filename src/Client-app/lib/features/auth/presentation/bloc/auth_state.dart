import 'package:equatable/equatable.dart';
import '../../../../core/auth/buoc_dang_xuat.dart';
import '../../data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthChecking extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final UserModel? user;
  const AuthSuccess({this.user});

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.thongBao});

  /// Khác `null` khi người dùng bị **đẩy ra** chứ không tự đăng xuất — màn Đăng
  /// nhập dựng hộp thoại từ đây (spec cưỡng chế đăng xuất §3.7).
  ///
  /// ⚠️ Phải nằm trong [props]: handler của Bloc chạy đồng thời, nên
  /// `_onAuthCheckRequested` có thể đã phát một `AuthUnauthenticated()` trơn
  /// trước. Không có nó trong props thì hai state bằng nhau, Bloc bỏ lần phát
  /// sau, và hộp thoại không bao giờ hiện.
  final ThongBaoBuocDangXuat? thongBao;

  @override
  List<Object?> get props => [thongBao];
}

// ─── OTP Register State ───────────────────────────────────────────────────────

/// Các trạng thái giữ route OTP hoạt động qua những lần router refresh.
abstract class RegisterOtpFlowState extends AuthState {
  const RegisterOtpFlowState();

  RegisterOtpSent get registration;
}

/// State sau khi gửi OTP thành công → chuyển sang trang nhập OTP
class RegisterOtpSent extends RegisterOtpFlowState {
  final String email;
  final String username;
  final String fullname;
  final String password;
  final String? phone;

  const RegisterOtpSent({
    required this.email,
    required this.username,
    required this.fullname,
    required this.password,
    this.phone,
  });

  @override
  List<Object?> get props => [email, username, fullname, password, phone];

  @override
  RegisterOtpSent get registration => this;
}

/// Đang xác thực hoặc gửi lại OTP từ trang OTP.
class RegisterOtpLoading extends RegisterOtpFlowState {
  @override
  final RegisterOtpSent registration;

  const RegisterOtpLoading({required this.registration});

  @override
  List<Object?> get props => [registration];
}

/// Lỗi phát sinh khi thao tác trên trang OTP.
class RegisterOtpError extends RegisterOtpFlowState {
  final String message;
  @override
  final RegisterOtpSent registration;

  const RegisterOtpError({
    required this.message,
    required this.registration,
  });

  @override
  List<Object?> get props => [message, registration];
}

/// State sau khi xác thực OTP và tạo tài khoản thành công.
class RegistrationCompleted extends RegisterOtpFlowState {
  @override
  final RegisterOtpSent registration;

  const RegistrationCompleted({required this.registration});

  @override
  List<Object?> get props => [registration];
}
