import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/kieu_thanh_trang_thai.dart';

/// Vùng kiểu thanh trạng thái GỐC của cả app — bọc ngoài router, trong lớp khoá (`main.dart`, `MaterialApp.builder`).
///
/// Flutter chỉ gọi `setSystemUIOverlayStyle` khi TÌM THẤY một `AnnotatedRegion` ở vị trí thanh trạng thái, và không bao
/// giờ tự trả kiểu cũ khi vùng ấy biến mất. Không có vùng gốc thì trang không AppBar (Trang chủ, Phân tích) ăn theo lịch sử:
/// dải xám 25 % đen của cửa sổ Android khi mở lạnh, rồi trong suốt sau khi ghé một trang có AppBar (đo Realme 2026-10-25,
/// bẫy 26 `KHOA_APP_FEATURE.md`). Trang có AppBar hay tự bọc `AnnotatedRegion` (màn khoá, màn Quét) nằm trên vùng này nên
/// kiểu của chúng thắng; rời đi thì vùng gốc được tìm thấy lại.
class VungThanhTrangThaiGoc extends StatelessWidget {
  const VungThanhTrangThaiGoc({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: kKieuThanhTrangThaiSang, child: child);
}
