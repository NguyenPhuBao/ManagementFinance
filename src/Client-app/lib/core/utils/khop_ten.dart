/// Khớp một TÊN do mô hình gõ (tham số `danh_muc`, `vi` của tool — bước 2) với
/// danh sách tên thật. Dùng chung cho `goi_y_han_muc` và `tim_giao_dich`.
///
/// Bỏ dấu ở đây là **đúng chỗ** của `removeVietnameseTones` (tìm kiếm — đoán
/// sai chỉ tốn một lần hỏi lại), khác quy tắc trùng tên danh mục (quy tắc 7
/// `CLAUDE.md`), nơi bỏ dấu bị cấm.
///
/// ⚠️ Không so chuỗi con: "tiết kiệm" khớp ví **Tiết kiệm**, không khớp "tiết
/// kiệm mua nhà". ⚠️ Danh sách đem khớp phải là của CHÍNH tài khoản — lẫn hàng
/// khuôn mặc định toàn cục (`idaccount = 0`) thì mọi tên mặc định khớp hai hàng
/// (spec bước 2, bẫy 14).
library;

import '../category/category_name.dart';

sealed class KetQuaKhopTen<T> {
  const KetQuaKhopTen();
}

final class KhopMot<T> extends KetQuaKhopTen<T> {
  const KhopMot(this.muc);
  final T muc;
}

final class KhopNhieu<T> extends KetQuaKhopTen<T> {
  const KhopNhieu(this.ds);
  final List<T> ds;
}

final class KhongKhop<T> extends KetQuaKhopTen<T> {
  const KhongKhop();
}

KetQuaKhopTen<T> khopTheoTen<T>(
  String hoi,
  Iterable<T> ds,
  String Function(T) tenCua,
) {
  final khoa = normalizeCategoryName(hoi);
  if (khoa.isEmpty) return KhongKhop<T>();
  KetQuaKhopTen<T>? theo(String Function(String) chuan) {
    final k = chuan(khoa);
    final trung = [
      for (final x in ds)
        if (chuan(normalizeCategoryName(tenCua(x))) == k) x,
    ];
    if (trung.length == 1) return KhopMot<T>(trung.single);
    if (trung.length > 1) return KhopNhieu<T>(trung);
    return null;
  }

  return theo((s) => s) ?? theo(removeVietnameseTones) ?? KhongKhop<T>();
}
