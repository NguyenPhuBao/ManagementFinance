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
/// Hai nhãn ở hai gói cùng một con số (`Tổng chi` / `Chi`) → **một** thẻ,
/// lấy nhãn gặp trước theo thứ tự gói.
library;

import 'goi_so.dart';
import 'kiem_so.dart';

List<String> theCuaCau(String cau, List<GoiSo> goi) {
  final the = <String>[];
  final daCo = <String>{};
  for (final x in trichSo(cau)) {
    for (final s in soLieuKhop(x, goi)) {
      if (daCo.add(s.chuoi)) the.add('${s.nhan} ${s.chuoi}');
    }
  }
  return the;
}
