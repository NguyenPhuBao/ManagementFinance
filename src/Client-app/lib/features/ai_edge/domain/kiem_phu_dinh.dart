/// Bộ kiểm PHỦ ĐỊNH — lớp chắn thứ năm (bẫy 4.52, 2026-09-28).
///
/// Bốn lớp trước kiểm con số, nhãn của con số, giọng và tên. Một câu **không
/// số, không tên** đi qua cả bốn — và lượt đo lát 1 mở rộng tool (mục 9.33
/// `AI_EDGE_FEATURE.md`, câu L5) cho thấy vẫn sai được: tool `danh_sach_vi`
/// vừa trả bốn hàng, mô hình viết *"Không có dữ liệu về ví nào được cung
/// cấp."*. Cùng họ bẫy 4.40 (đọc lời từ chối thành "không có dữ liệu"), nhưng
/// ở một lượt **thành công có hàng**.
///
/// Luật: gói tra cứu đang có **ít nhất một hàng**, mà câu **không có con số
/// nào** và chứa một lời phủ định **về dữ liệu** → chặn, vòng lặp rơi về mẫu
/// câu của gói.
///
/// Giới hạn cố ý, cả ba để lớp này không chặn câu thật:
/// - chỉ lời phủ định về **dữ liệu** (*"không có dữ liệu / thông tin / số
///   liệu"*, *"không tìm thấy"*), KHÔNG phải *"không có … nào"* — *"không có
///   hoá đơn nào quá hạn"* là câu thật về một trạng thái;
/// - chỉ câu **không số**: *"không có dữ liệu tháng trước, tháng này chi …"*
///   là câu thật khi nền so sánh bằng 0, và số của nó đã có bốn lớp kia kiểm;
/// - chỉ `GoiSoTraCuu` (bậc tool): ở bậc 1, *"không có dữ liệu"* về thứ sáu gói
///   không mang là câu ĐÚNG — cổng A điểm 4.
library;

import 'goi_so.dart';
import 'goi_so_tra_cuu.dart';
import 'kiem_so.dart';

/// Lời phủ định về dữ liệu — chữ thường, có dấu (không bỏ dấu: quy tắc 7).
final RegExp _mauPhuDinhDuLieu = RegExp(
  r'(không|chưa|chẳng)\s+(có|tìm thấy|tìm được|nhận được|được cung cấp)'
  r'(\s+\p{L}+){0,2}?\s*(dữ liệu|thông tin|số liệu)'
  r'|(không|chưa)\s+tìm thấy'
  r'|(dữ liệu|thông tin|số liệu)(\s+\p{L}+){0,4}?\s+(không|chưa)\s+(có|được cung cấp|tồn tại)',
  unicode: true,
);

/// `false` khi [cau] phủ định dữ liệu trong lúc gói tra cứu đang có hàng.
bool kiemPhuDinh(String cau, List<GoiSo> goi) {
  final coHang = goi.whereType<GoiSoTraCuu>().any((g) => g.hang.isNotEmpty);
  if (!coHang) return true;
  if (trichSoNgoaiTen(cau, goi).isNotEmpty) return true;
  return !_mauPhuDinhDuLieu.hasMatch(cau.toLowerCase());
}
