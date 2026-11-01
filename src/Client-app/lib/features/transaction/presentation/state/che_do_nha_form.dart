/// Cấu hình chế độ nhà của form Thêm giao dịch (gia đình 1B, `02A` mục 4). Dart thuần: mảng giao dịch không biết gia đình, nên
/// mọi thứ thuộc nhà đi vào form qua đối tượng này và qua [ThemGiaoDichNguon] tiêm vào (nguồn nhà ở `household/data`).
library;

class CheDoNhaForm {
  const CheDoNhaForm({
    required this.idNha,
    required this.tenNha,
    required this.choChuyen,
    required this.duongChonDanhMuc,
  });

  final int idNha;
  final String tenNha;

  /// Chip *Chuyển khoản*: chỉ Chủ nhà. Đây cũng là chỗ thi hành "`laChuyen` theo type mới": Thành viên không đổi được khoản
  /// thành chuyển.
  final bool choChuyen;

  /// Route bộ chọn danh mục của nhà (thay cho `/add/category`).
  final String duongChonDanhMuc;
}

/// Đoạn mở sẵn của form nhà. Thành viên (không [choChuyen]) mở `?huong=transfer` thì về Chi tiêu: ô Chuyển khoản không có, và
/// một khoản chuyển do Thành viên ghi bị server từ chối rồi biến mất im lặng (ruling I-4, G120 #7).
String? huongFormNha(String? huong, {required bool choChuyen}) => huong == 'transfer' && !choChuyen ? null : huong;

/// Tiêu đề thanh trên của form nhà (Stitch `5a53df6e`, chữ thay cho "Thêm giao dịch").
String tieuDeFormNha(bool laSua, String huong) {
  if (laSua) return 'Sửa khoản của nhà';
  return switch (huong) {
    'thu' => 'Khoản thu của nhà',
    'transfer' => 'Chuyển giữa ví chung',
    _ => 'Khoản chi của nhà',
  };
}
