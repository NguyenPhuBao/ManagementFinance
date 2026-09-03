import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Mã tài khoản của phiên đăng nhập hiện tại, hoặc `null` khi CHƯA có phiên
/// dùng được.
///
/// Vì sao trả `null` chứ không phải một số mặc định: `idaccount = 1` là tài
/// khoản **admin THẬT** chứ không phải giá trị "chưa biết". Trước đây bốn trang
/// (`bill_add_page`, `bill_edit_page`, `bill_page`, `goal_detail_page`) mỗi
/// trang tự chép một bản `int.tryParse(...) ?? 1` kèm `return 1` ở nhánh chưa
/// đăng nhập — nghĩa là hoá đơn hay khoản gửi tiết kiệm tạo ra trong lúc trạng
/// thái đăng nhập chưa kịp sẵn sàng sẽ được ghi dưới danh nghĩa admin, rồi đẩy
/// lên backend và thất bại với "Ownership mismatch" mà không ai hiểu vì sao.
///
/// Nơi gọi phải tự quyết định làm gì với `null` — thường là không đọc/không ghi
/// gì cả. Xem `docs/CLIENT_APP_KNOWN_GAPS.md` mục G4.
int? currentAccountIdOrNull(BuildContext context) {
  final authState = context.read<AuthBloc>().state;
  if (authState is! AuthSuccess || authState.user == null) return null;
  final parsed = int.tryParse(authState.user!.id);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}
