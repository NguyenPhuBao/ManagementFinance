/// Thẻ số liệu đi kèm một câu trả lời — **những con số câu ấy thật sự nhắc
/// tới** (điều kiện 12 đặc tả gốc: người dùng phải thấy nguồn số cạnh câu).
///
/// Dùng **cùng phép khớp với bộ kiểm số** (`trichSoNgoaiTen` + `soLieuKhop`),
/// không so chuỗi con. Bản đầu (`ai_chat_page._theChoCau`, P3 Task 8) viết
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
///
/// ⚠️ "Câu nhắc tới" xét theo **từng câu**, không theo cả tin nhắn — bẫy
/// **4.34**, OnePlus bắt được ở chặng 4b (2026-09-23): tool ngân sách trả Di
/// chuyển (hạn mức **450.000**) trước Ăn uống (còn lại **450.000**), câu trả
/// lời nhắc cả hai tên ở **hai câu khác nhau**, và xét cả tin nhắn thì mục của
/// Di chuyển cũng "được nhắc" nên nó thắng vì đứng trước — thẻ in *"Di chuyển ·
/// Hạn mức 450.000 đ"* dưới câu về Ăn uống. Tách câu bằng đúng
/// `tachCauHoanChinh` của `gacTheoCau`, nên đơn vị ở đây trùng đơn vị mà
/// `kiemNhan` đã kiểm.
library;

import 'gac_cau.dart';
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
  // Khử trùng theo giá trị trên CẢ tin nhắn: cùng một con số ở hai câu vẫn
  // là một thẻ.
  final daCo = <String>{};
  final (cacCau, du) = tachCauHoanChinh(cau);
  for (final c in [...cacCau, if (du.trim().isNotEmpty) du.trim()]) {
    // Số NGOÀI tên đối tượng (bước 1c): chữ số của `Tiền nhà T9` không được đẻ
    // ra thẻ "Còn 9 ngày" của một gói khác.
    for (final x in trichSoNgoaiTen(c, goi)) {
      final khop = soLieuKhop(x, goi);
      if (khop.isEmpty) continue;
      // Trong các mục cùng giá trị, ưu tiên mục mà CÂU NÀY thật sự nhắc tới.
      // Không mục nào khớp thì giữ hành vi cũ — cái đầu theo thứ tự gói — vì
      // khi ấy không có căn cứ nào để chọn.
      final uuTien = khop.where((s) => _cauNhacToi(c, s)).toList();
      for (final s in uuTien.isEmpty ? khop : uuTien) {
        if (daCo.add(s.chuoi)) the.add(_nhanDayDu(s));
      }
    }
  }
  return the;
}
