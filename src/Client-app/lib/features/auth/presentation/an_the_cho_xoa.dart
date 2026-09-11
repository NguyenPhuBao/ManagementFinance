import 'package:flutter/foundation.dart';

/// Người dùng bấm "Để sau" trên thẻ nhắc tài khoản chờ xoá ở Trang chủ.
///
/// Cờ **trong bộ nhớ**, cố ý không lưu xuống đĩa: xoá tài khoản không hoàn tác
/// được, nên lần mở app kế tiếp thẻ phải hiện lại. Đặt lại khi đăng nhập thành
/// công (spec cưỡng chế đăng xuất §5.2). Là lớp riêng thay vì `ValueNotifier<bool>`
/// trần để `sl` không nhầm với một cờ khác cùng kiểu.
class AnTheChoXoa extends ValueNotifier<bool> {
  AnTheChoXoa() : super(false);
}
