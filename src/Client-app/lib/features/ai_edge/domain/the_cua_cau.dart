/// Thẻ số liệu đi kèm một câu trả lời — **những con số câu ấy thật sự nhắc
/// tới** (điều kiện 12 đặc tả gốc: người dùng phải thấy nguồn số cạnh câu).
///
/// Dùng **cùng phép khớp với bộ kiểm số** (`trichSo` + `soLieuKhop`), không
/// so chuỗi con. Bản đầu (`ai_chat_page._theChoCau`, P3 Task 8) viết
/// `cau.contains(s.chuoi)`, và trên máy thật 2026-09-22 tối, ngay khi hai gói
/// hoá đơn và ví mang số đếm ngắn, câu *"…tổng thu 15.135.000 đ"* kéo theo
/// thẻ *Số cam kết 15 · Quá hạn 1 · Số ví 4 · Ví đang âm 1* — "15", "1", "4"
/// đều là chuỗi con của một số tiền. Thẻ thành tiếng ồn thay vì nguồn kiểm
/// chứng, và người đọc tin câu vừa nói tới hoá đơn quá hạn.
///
/// Hai nhãn ở hai gói cùng một con số (`Tổng chi` / `Chi`) → **một** thẻ.
///
/// ⚠️ Nhãn ấy là nhãn mà **câu nhắc tới**, không phải nhãn gặp trước theo thứ
/// tự gói — bẫy **4.27**, máy thật bắt được ở chặng 3 (2026-09-22) khi câu
/// *"Ví đang âm: 1"* hiện thẻ *"Quá hạn 1"*: gói hoá đơn xếp trước gói ví và
/// cả hai cùng mang số **1**, nên thẻ nói về một đại lượng khác hẳn câu. Số
/// nhỏ (0, 1, 2, 3, 4) trùng nhau giữa các gói là chuyện **thường**, không
/// phải ca hiếm. Không nhãn nào khớp câu thì mới rơi về thứ tự gói.
library;

import 'goi_so.dart';
import 'kiem_nhan.dart';
import 'kiem_so.dart';

/// Nhãn hiển thị của một mục — nêu tên đối tượng trước khi có.
String _nhanDayDu(SoLieu s) =>
    s.ten == null ? '${s.nhan} ${s.chuoi}' : '${s.ten} · ${s.nhan} ${s.chuoi}';

/// `true` khi [cau] chứa đủ từ khoá của nhãn **hoặc** của tên [s] — **cùng
/// phép với `kiemNhan`**, nên thẻ và bộ kiểm không bao giờ nói hai chuyện
/// khác nhau về cùng một câu.
bool _cauNhacToi(String cau, SoLieu s) {
  final amTiet = amTietCua(cau);
  if (tuKhoaNhan(s.nhan).every(amTiet.contains)) return true;
  return s.ten != null && tuKhoaNhan(s.ten!).every(amTiet.contains);
}

List<String> theCuaCau(String cau, List<GoiSo> goi) {
  final the = <String>[];
  final daCo = <String>{};
  for (final x in trichSo(cau)) {
    final khop = soLieuKhop(x, goi);
    if (khop.isEmpty) continue;
    // Trong các mục cùng giá trị, ưu tiên mục mà CÂU thật sự nhắc tới. Không
    // mục nào khớp thì giữ hành vi cũ — cái đầu theo thứ tự gói — vì khi ấy
    // không có căn cứ nào để chọn.
    final uuTien = khop.where((s) => _cauNhacToi(cau, s)).toList();
    for (final s in uuTien.isEmpty ? khop : uuTien) {
      if (daCo.add(s.chuoi)) the.add(_nhanDayDu(s));
    }
  }
  return the;
}
