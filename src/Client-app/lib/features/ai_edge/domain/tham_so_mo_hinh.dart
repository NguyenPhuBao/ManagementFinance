/// Tham số do MÔ HÌNH sinh — đọc giá trị tên / từ khoá, nhận ra giá trị giữ chỗ
/// và số tiền nằm nhầm chỗ (spec bước 2b mục 2.4, bẫy 4.43).
///
/// Cổng D lần 1: E2B nhét `"tat_ca"`, `"tất_cả"` vào tham số TUỲ CHỌN để nói
/// "không lọc" — tool từ chối vì không có danh mục / ví nào tên ấy, rồi mô hình
/// đọc lời từ chối thành "không có dữ liệu" (bẫy 4.40). Và nó nhét số tiền vào
/// `tu_khoa`: tìm "500k" trong ghi chú ra 0 khoản — một lượt THÀNH CÔNG, nên câu
/// "không có khoản nào" được phép hiện dù thực tế có.
///
/// Bỏ dấu ở đây là đúng chỗ của `removeVietnameseTones` (đọc tham số, không
/// phải quy tắc trùng tên — quy tắc 7 `CLAUDE.md`).
library;

import '../../../core/category/category_name.dart';

/// Giá trị giữ chỗ nghĩa là KHÔNG LỌC — so sau chuẩn hoá, đổi `_` thành dấu
/// cách, bỏ dấu. Cố ý hẹp: "mọi" bỏ dấu trùng "mới", và "tất cả danh mục" chưa
/// đo được mô hình viết — mô tả tool dặn bỏ trống.
const Set<String> _giuCho = {'tat ca', 'tatca', 'all'};

/// `null` = không lọc: [v] là `null`, trống sau khi cắt, hoặc là giá trị giữ
/// chỗ. Còn lại trả `v.toString().trim()` — khớp tên vẫn là việc của
/// `khopTheoTen`. Nhận mọi kiểu (cả số): phép "điền" của `GoiSoTraCuu` dùng hàm
/// này cho mọi tham số.
String? thamSoTen(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final khoa = removeVietnameseTones(normalizeCategoryName(s.replaceAll('_', ' ')));
  return _giuCho.contains(khoa) ? null : s;
}

/// Một con số kèm đơn vị tiền, đơn vị đứng TRỌN từ ("2 kg", "1 trà" không phải).
final RegExp _soKemDonVi =
    RegExp(r'\d[\d.,]*\s*(k|nghin|ngan|tr|trieu|cu|d|dong|vnd)(?![a-z0-9])');
final RegExp _chiGomSo = RegExp(r'^[\d.,\s]+$');
final RegExp _coChuSo = RegExp(r'\d');

/// `true` khi [s] là (hoặc chứa) một số tiền: số kèm đơn vị, chỉ gồm chữ số và
/// dấu ngăn, hoặc "nửa triệu". So trên chữ thường, bỏ dấu.
bool laSoTien(String s) {
  final k = removeVietnameseTones(normalizeCategoryName(s));
  if (k.isEmpty) return false;
  if (_chiGomSo.hasMatch(k) && _coChuSo.hasMatch(k)) return true;
  if (k.contains('nua trieu')) return true;
  return _soKemDonVi.hasMatch(k);
}
