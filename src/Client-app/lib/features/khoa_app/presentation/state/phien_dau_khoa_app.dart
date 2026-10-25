import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/current_account.dart';

/// Trạng thái phiên đủ RÕ để khoá ứng dụng quyết định: đăng nhập (có tài khoản) hoặc chưa đăng nhập. `AuthLoading`, OTP… không
/// phải trạng thái phiên.
bool laTrangThaiPhienRo(AuthState s) => s is AuthSuccess || s is AuthUnauthenticated;

/// Phiên khoá ứng dụng phải biết NGAY lúc dựng (`main.dart`), trước khi `AuthBloc` phát gì:
/// - `AuthSuccess` / `AuthUnauthenticated` đã có → dùng luôn;
/// - `AuthInitial` mà route đầu là `/login` → không token (`main()` không gửi `AuthCheckRequested`): chưa có phiên, KHÔNG khoá
///   (nếu không lớp phủ đặc che màn Đăng nhập mãi — P2);
/// - còn lại (`AuthInitial` + route đầu khác, đang kiểm token…) → chưa biết, chờ stream.
({bool daBiet, int? idaccount}) phienDauChoKhoaApp(AuthState dau, String initialRoute) {
  if (laTrangThaiPhienRo(dau)) return (daBiet: true, idaccount: idaccountTuTrangThai(dau));
  if (initialRoute == '/login') return (daBiet: true, idaccount: null);
  return (daBiet: false, idaccount: null);
}
