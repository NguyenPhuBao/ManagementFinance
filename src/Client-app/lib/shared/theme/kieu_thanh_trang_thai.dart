import 'package:flutter/services.dart';

/// Kiểu thanh trạng thái của cả app: trong suốt, biểu tượng tối trên nền kem — Stitch vẽ đầu màn liền nền kem (Trang chủ
/// `c8f09f19…`), và cũng là kiểu AppBar Material 3 tự đặt cho trang có AppBar. MỘT định nghĩa cho vùng gốc
/// (`VungThanhTrangThaiGoc`) và màn khoá.
const SystemUiOverlayStyle kKieuThanhTrangThaiSang = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

/// Trang nền tối toàn màn, không AppBar (màn Quét lúc đang đọc ảnh): biểu tượng sáng — biểu tượng tối chìm trên nền đen.
const SystemUiOverlayStyle kKieuThanhTrangThaiToi = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);
