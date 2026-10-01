/// Thu nhập trung bình **MỖI THÁNG** trong một cửa sổ nhìn lại — định nghĩa
/// duy nhất, dùng chung cho phép neo ngưỡng của luật tái phân bổ
/// (`TaiPhanBoNguonImpl`) và của chi bất thường (B3, trang Phân tích).
///
/// Dời từ `TaiPhanBoNguonImpl._thuNhapMoiThang` (2026-09-29, B3) để
/// `analytics` không phải import `ai_edge` / `budget/data`; hành vi **không
/// đổi** — toàn bộ test của `tai_phan_bo_nguon` xanh nguyên kỳ vọng.
library;

import '../../budget/domain/cua_so_nhin_lai.dart';
import 'dong_tien_tu_do.dart';
import 'pham_vi_ky.dart';
import 'thong_ke_thang.dart';
import 'vai_vay_no.dart';

/// Thu nhập trong [cuaSo], quy về mức một tháng (`tổng / số ngày × 30`).
///
/// Vẫn đi qua **đúng** `thuNhapCua` (tổng thu trừ tiền đi vay / thu nợ /
/// khoản vay-nợ tiền vào) — không phải `type = 'thu'` trần (bẫy A8 #8).
///
/// ⚠️ [khoan] là **toàn bộ** giao dịch đã dựng thành `KhoanThuChi` (kèm
/// `classify` và `tenDanhMuc` — `chuoiVayNo` cần tên để xếp vai); hàm tự cắt
/// theo cửa sổ.
double thuNhapMoiThangTu(List<KhoanThuChi> khoan, CuaSoNhinLai cuaSo) {
  // MỘT kỳ đúng bằng cửa sổ, thay cho bốn kỳ tháng rồi `take(3)`.
  // `chuoiVayNo` cần một `Ky`; `Ky.tuyChon` nhận đúng biên `[from, to)`.
  final ky = Ky.tuyChon(from: cuaSo.from, to: cuaSo.to);
  final vayNo = chuoiVayNo(khoan, ky: ky, soKy: 1);
  if (vayNo.isEmpty) return 0;

  final tong = tongThuChi(khoan, from: cuaSo.from, to: cuaSo.to);
  final thuNhapCuaSo = thuNhapCua(tong: tong, vayNo: vayNo.first);
  return thuNhapCuaSo / cuaSo.soNgay * kSoNgayMotThang;
}
