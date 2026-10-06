import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/goi_repository.dart';

/// Dịch trạng thái `AuthBloc` sang phiên mà `GoiRepository.noiPhien` hiểu
/// (spec Premium 6.4). Nằm ở presentation vì nó biết `AuthState`; repository
/// thì không. `main.dart` nối `authBloc.stream.map(phienGoiTu)`.
PhienGoi? phienGoiTu(AuthState s) {
  if (s is! AuthSuccess) return null;
  final user = s.user;
  if (user == null) return null;
  final id = int.tryParse(user.id);
  if (id == null) return null;
  return (idaccount: id, loaiPhien: user.loaiTaiKhoan);
}
