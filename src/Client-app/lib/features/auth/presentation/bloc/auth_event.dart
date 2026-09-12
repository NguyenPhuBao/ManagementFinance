import 'package:equatable/equatable.dart';
import '../../../../core/auth/buoc_dang_xuat.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

/// SyncEngine phát hiện phiên đang trỏ tới một tài khoản không còn tồn tại
/// trên server (đẩy dữ liệu bị vỡ khoá ngoại `fk_*_account`).
class SessionInvalidated extends AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class LogoutRequested extends AuthEvent {}

/// Server nói tài khoản này không được dùng nữa.
///
/// Một cửa vào duy nhất cho cả ba nguồn — sự kiện socket `account.force_logout`,
/// body 401 của một request thường, và body 401 của `/auth/refresh` — nên chỉ có
/// một chỗ trong app quyết định *dừng cái gì, dọn cái gì, hiện câu nào* (spec
/// cưỡng chế đăng xuất §3.5, Hướng A).
class TaiKhoanBiBuocDangXuat extends AuthEvent {
  const TaiKhoanBiBuocDangXuat(this.thongBao);

  final ThongBaoBuocDangXuat thongBao;

  @override
  List<Object?> get props => [thongBao];
}

/// Bộ nhớ đệm người dùng vừa đổi — gửi hoặc huỷ yêu cầu xoá tài khoản. Bloc đọc
/// lại `getCurrentUser()` và phát `AuthSuccess` mới để thẻ nhắc hiện/ẩn ngay.
class ThongTinTaiKhoanThayDoi extends AuthEvent {}
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
