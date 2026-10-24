import 'dart:async';

import 'khoa_app_service.dart';

/// Đường lùi của "Quên mã PIN?" (spec khoá app mục 4): `PhienDieuPhoiThat.dongPhien` đã xoá mọi `khoa_app_*`, nhưng
/// `SecureStorageKhoaAppStore.xoaHet` thoát êm khi `readAll` hỏng — cấu hình còn sót thì đăng nhập lại cùng tài khoản vẫn
/// bị khoá bằng đúng PIN đã quên. Nên xoá THẲNG theo khoá của tài khoản vừa rời.
///
/// ⚠️ Chỉ SAU khi [daDangXuat] hoàn tất (AuthBloc tới `AuthUnauthenticated`). Xoá trước mà đăng xuất hỏng giữa chừng
/// (token còn) thì lần mở lạnh kế vào thẳng app không cần PIN — vượt khoá. [daDangXuat] phải được tạo (đăng ký nghe)
/// TRƯỚC khi gửi `LogoutRequested`. Không bao giờ ném.
Future<void> xoaKhoaSauDangXuat({
  required Future<Object?> daDangXuat,
  required int? idaccount,
  required KhoaAppService service,
}) async {
  if (idaccount == null) return;
  try {
    await daDangXuat;
    await service.tatKhoa(idaccount);
  } catch (_) {
    // Luồng đóng / đăng xuất không tới: giữ nguyên khoá (an toàn hơn xoá).
  }
}
