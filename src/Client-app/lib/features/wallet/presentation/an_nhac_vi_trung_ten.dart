import 'package:flutter/foundation.dart';

/// Người dùng bấm ✕ trên dòng nhắc ví trùng tên ở Trang chủ (G63, spec mục 5.5).
///
/// Cờ **trong bộ nhớ**, cố ý không lưu xuống đĩa: dữ liệu của ví ấy đang không
/// đồng bộ, nên lần mở app sau dòng nhắc phải hiện lại. Đặt lại khi đăng nhập
/// thành công — cùng chỗ với `AnTheChoXoa`. Lớp riêng thay vì
/// `ValueNotifier<bool>` trần để `sl` không nhầm với cờ khác cùng kiểu.
class AnNhacViTrungTen extends ValueNotifier<bool> {
  AnNhacViTrungTen() : super(false);
}
