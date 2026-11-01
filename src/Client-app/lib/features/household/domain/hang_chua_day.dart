/// Số hàng của nhà còn `pending` (chưa lên server), tách theo loại — nội dung hộp hỏi lại trước khi Rời nhà / Giải tán.
class HangChuaDayNha {
  const HangChuaDayNha({this.khoan = 0, this.gop = 0, this.rut = 0, this.vi = 0, this.danhMuc = 0, this.khac = 0});

  final int khoan, gop, rut, vi, danhMuc, khac;

  bool get rong => khoan + gop + rut + vi + danhMuc + khac == 0;

  /// Còn nửa góp / rút CÒN SỐNG của TÔI: rời nhà thì `traVeKhiBoNha` trả tiền nửa ấy về ví riêng (nửa đã xoá mềm và nửa của
  /// người khác vào [khoan], không được trả).
  bool get coTienTraVe => gop + rut > 0;
}

/// Dòng hiện ở hộp hỏi lại, ví dụ `2 khoản của nhà`, `1 khoản góp, 1 khoản rút`. Không nêu hàng trống.
List<String> dongHangChuaDay(HangChuaDayNha h) {
  final tienTraVe = [
    if (h.gop > 0) '${h.gop} khoản góp',
    if (h.rut > 0) '${h.rut} khoản rút',
  ];
  return [
    if (h.khoan > 0) '${h.khoan} khoản của nhà',
    if (tienTraVe.isNotEmpty) tienTraVe.join(', '),
    if (h.vi > 0) '${h.vi} ví chung',
    if (h.danhMuc > 0) '${h.danhMuc} danh mục của nhà',
    if (h.khac > 0) '${h.khac} mục khác',
  ];
}
