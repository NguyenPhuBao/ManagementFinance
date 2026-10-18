import 'tran_goi.dart';

/// Phần THUẦN của `redirect` ba route tạo (spec Premium 5.3 / 7.1). Nhận [uri]
/// để tự từ chối chặn đường SỬA `/budget/rules?id=…` — người gọi có thể truyền
/// [ket] bất kỳ cho route sửa, kết quả vẫn `null`. `/budget/rules?category=…`
/// (thẻ *Chưa đặt ngân sách*) là TẠO, chặn như nút +.
String? chuyenHuongTheoGoi(Uri uri, KetQuaTran ket) {
  if (uri.path == '/budget/rules' &&
      (uri.queryParameters['id'] ?? '').isNotEmpty) {
    return null;
  }
  return switch (ket) {
    Vuot(:final loai) => '/premium?tran=${maTran(loai)}',
    Duoc() => null,
  };
}

/// Phần THUẦN của `redirect` route Chi tiết đơn `/premium/don/:orderCode` (spec G94 2026-10-18 mục 5.5): mã không
/// phải số nguyên → về Lịch sử mua, nơi người dùng chọn lại đơn.
String? chuyenHuongChiTietDon(String? ma) => int.tryParse(ma ?? '') == null ? '/premium/lich-su' : null;
