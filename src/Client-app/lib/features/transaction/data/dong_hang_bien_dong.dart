// lib/features/transaction/data/dong_hang_bien_dong.dart
/// D1 — đóng một hàng biến động sau khi Lưu / Bỏ qua. Dời khỏi `ThemGiaoDichCubit` ngày 2026-10-12 (spec C4 §4.2,
/// khối 🔧 ý 1) để chừa chỗ dưới trần 1.200 dòng của quét 23. Không `emit`; mọi giá trị đã chốt lúc gọi (màn có thể đã
/// `pop`). Không bao giờ ném.
library;

import 'package:flutter/foundation.dart';

import '../domain/dien_san_bien_dong.dart';
import '../domain/goi_y_chuyen_khoan.dart';
import 'them_giao_dich_nguon.dart';

/// Xoá CỨNG hàng loại 20 (`NotificationDao.xoaCung`, ngoại lệ có chủ ý — spec D1 §3.3), và khi Lưu ở lần đầu của cặp
/// nguồn + đuôi thì nhớ ví ([nhoVi]). Ảnh quét (A5): chỉ xoá ảnh (`close` của Cubit cũng xoá — luỹ đẳng).
Future<void> dongHangBienDong(ThemGiaoDichNguon nguon, DienSanBienDong d, int id,
    {String? viDaLuu, bool nhoVi = false}) async {
  if (d.laQuet) {
    await nguon.xoaAnhQuet(d.anh);
    return;
  }
  try {
    if (nhoVi && viDaLuu != null) await nguon.nhoViTheoNguon(id, d.nguon, d.duoi, viDaLuu);
  } catch (e) {
    debugPrint('[BienDong] ghi ví theo nguồn lỗi: $e');
  }
  await nguon.xoaHangBienDong(id, d.khoa);
  await nguon.xoaAnhBienLai(d.anh);
}

/// Lưu sau khi áp gợi ý Chuyển khoản (spec 2026-09-30 §5): nhớ ví cho CẢ HAI nguồn — mỗi phía theo phía của nó. ⚠️ Không
/// theo ví nguồn của form: tin THU ghi thành chuyển khoản thì ví của nguồn tin là ví ĐÍCH. Rồi xoá hàng đang mở và hàng
/// cặp (còn chờ là người dùng ghi đôi).
Future<void> dongHangChuyenKhoan(ThemGiaoDichNguon nguon, DienSanBienDong d, GoiYChuyenKhoan gy, int id,
    {String? viTu, String? viDen, required bool daNhoTu, required bool daNhoDen}) async {
  try {
    if (!daNhoTu && viTu != null) await nguon.nhoViTheoNguon(id, gy.nguonTu, gy.duoiTu, viTu);
    if (!daNhoDen && viDen != null) await nguon.nhoViTheoNguon(id, gy.nguonDen, gy.duoiDen, viDen);
  } catch (e) {
    debugPrint('[BienDong] ghi ví theo nguồn lỗi: $e');
  }
  await nguon.xoaHangBienDong(id, d.khoa);
  await nguon.xoaAnhBienLai(d.anh);
  final cap = gy.khoaCap;
  if (cap != null) await nguon.xoaHangBienDong(id, cap);
}
