/// Tên NGẮN của một khoản cho câu trả lời Trợ lý AI (B8 ◐, 2026-10-07). Hàm thuần.
///
/// Tên khoản là `tieuDeGiaoDich` — ghi chú trước — mà khoản ghi từ tin ngân hàng mang
/// NGUYÊN VĂN tin: *"149337921395-TRAN QUANG DAT chuyen tien qua MoMo-CHUYEN
/// TIEN-OQCH000LKViu-MOMO149337921395MOMO"*. Mẫu câu kể ba khoản như thế dài cả trăm
/// ký tự, và mô hình chép lại nguyên chuỗi mã.
///
/// Chỉ dùng ở hàng số liệu của AI (`hangGiaoDich`, `hangTongQuan`). Sổ giao dịch giữ
/// `tieuDeGiaoDich` nguyên văn: ở đó dòng tự cắt bằng "…" và người dùng mở ra xem được.
///
/// Luật: (1) bỏ MÃ — đoạn (tách theo khoảng trắng và `-`) dài ≥ 8 có chữ số, hoặc dài
/// ≥ 10 ký tự liền; ngày *2026-09-04* hay *T9* không phải mã vì từng đoạn ngắn; (2) còn
/// dài hơn [kDaiToiDaTenNgan] thì cắt ở ranh giới từ hoặc dấu `-`. Không thêm "…": tên phải là đoạn
/// đầu của ghi chú để câu mô hình nêu tên vẫn khớp lớp chắn. Toàn mã thì không bỏ gì (vẫn cắt theo trần).
library;

/// Trần độ dài tên ngắn (ký tự).
const int kDaiToiDaTenNgan = 40;

final RegExp _coChuSo = RegExp(r'\d');

bool _laMa(String doan) =>
    (doan.length >= 8 && _coChuSo.hasMatch(doan)) || doan.length >= 10;

String tenNganGiaoDich(String tieuDe) {
  final goc = tieuDe.trim();
  final tu = <String>[];
  for (final cum in goc.split(RegExp(r'\s+'))) {
    final con = cum.split('-').where((d) => d.isNotEmpty && !_laMa(d)).join('-');
    if (con.isNotEmpty) tu.add(con);
  }
  var kq = tu.isEmpty ? goc : tu.join(' ');
  if (kq.length <= kDaiToiDaTenNgan) return kq;
  // Cắt ở khoảng trắng HOẶC "-": đoạn ngăn bằng "-" của tin là một ý trọn — chỉ
  // khoảng trắng thì ra "…chuyen tien qua" và mẫu câu nối thành "qua khoản thu".
  final cat = [kq.lastIndexOf(' ', kDaiToiDaTenNgan), kq.lastIndexOf('-', kDaiToiDaTenNgan)]
      .reduce((a, b) => a > b ? a : b);
  kq = cat > 0 ? kq.substring(0, cat) : kq.substring(0, kDaiToiDaTenNgan);
  return kq.trimRight();
}
