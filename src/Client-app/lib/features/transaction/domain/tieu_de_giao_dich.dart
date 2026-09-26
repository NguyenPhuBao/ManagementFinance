/// Tiêu đề MỘT dòng giao dịch — định nghĩa duy nhất (bước 2, 2026-09-23).
///
/// Hai nơi đọc: dòng Sổ giao dịch (`buildTransactionRowContent`, 4 chỗ gọi) và
/// tool tìm giao dịch của Trợ lý AI. Chép luật này ra chỗ thứ hai là hai bản sẽ
/// lệch nhau ngày một bên đổi — và câu AI nói về "khoản Cà phê" sẽ không khớp
/// dòng người dùng thấy trong sổ.
///
/// Luật: ghi chú → tên danh mục → nhãn loại (`transactionTypeLabel`). Khoản
/// chuyển không lấy tên danh mục: nó không thuộc danh mục nào.
library;

import '../data/models/transaction_type_label.dart';

String tieuDeGiaoDich({
  required String loai,
  required String ghiChu,
  required String? tenDanhMuc,
}) {
  final note = ghiChu.trim();
  if (note.isNotEmpty) return note;
  if (loai != 'transfer' && tenDanhMuc != null) return tenDanhMuc;
  return transactionTypeLabel(loai);
}
