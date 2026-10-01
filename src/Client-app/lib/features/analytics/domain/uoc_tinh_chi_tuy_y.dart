/// Tầng 3 của khối Dự báo (B4, 2026-09-29): ước tính **CHI TUỲ Ý** 30 ngày tới
/// theo thói quen, dạng **khoảng** thấp – cao, suy từ các tuần ISO đã đóng trong
/// cửa sổ nhìn lại.
///
/// Người dùng mở lại quyết định 16/09 (*dự báo chỉ chiếu thứ đã biết chắc*) nhưng
/// **không** làm lại lỗi mà quyết định ấy tránh — một con số đoán ngồi cạnh những
/// con số thật sẽ mượn độ tin của chúng:
///
/// - Tầng 3 là **một dòng riêng**; hai con số cũ và biểu đồ không đổi.
/// - Nó là một **khoảng** p25–p75, kèm số tuần đã dùng, không phải một con số.
/// - Nó chỉ tính **phần chưa ai tính**: bỏ khoản gắn hoá đơn / mục tiêu (tầng 1)
///   và danh mục có ngân sách đang chạy (tầng 2); có ngân sách **tổng** thì im.
///
/// Spec `docs/superpowers/specs/2026-09-28-b4-uoc-tinh-chi-tuy-y-design.md`.
library;

import '../../../core/notification/tuan_iso.dart';
import '../../budget/domain/cua_so_nhin_lai.dart';
import 'khoan_vao_thong_ke.dart';
import 'nguong_co_nghia.dart';
import 'phan_loai_dong_tien.dart';
import 'thong_ke_thang.dart';

/// Dưới chừng này tuần đóng thì im: phân vị của ba điểm là tiếng ồn.
const int kSoTuanToiThieu = 4;

/// Khoảng chi tuỳ ý 30 ngày tới, đã làm tròn 10.000 đ.
class UocTinhChiTuyY {
  final double thap;
  final double cao;

  /// Số tuần đóng đã dùng làm mẫu — câu hiển thị nói ra con số này.
  final int soTuan;

  const UocTinhChiTuyY({
    required this.thap,
    required this.cao,
    required this.soTuan,
  });
}

/// Phân vị nội suy tuyến tính trên chỉ số `p × (n − 1)` của dãy **đã sắp**.
double _phanVi(List<double> s, double p) {
  final viTri = p * (s.length - 1);
  final duoi = viTri.floor();
  final tren = viTri.ceil();
  return s[duoi] + (s[tren] - s[duoi]) * (viTri - duoi);
}

/// Ước tính chi tuỳ ý 30 ngày tới; `null` = **im hẳn** (không `?? 0`).
///
/// - [cuaSo] `null` (tài khoản quá trẻ) hoặc [coNganSachTong] → `null`.
/// - Tuần = tuần ISO qua `bienTuan` (một định nghĩa với bộ chọn kỳ và *Tổng
///   kết tuần*); chỉ tuần **đã đóng** nằm **trọn** trong `[cuaSo.from, now)`.
///   Tuần đầu bị cửa sổ cắt ngang thì bỏ — nửa tuần kéo phân vị xuống.
/// - Cần ≥ [kSoTuanToiThieu] tuần. Tuần không có khoản nào vẫn là **0** — số
///   liệu thật (khác B3, nơi tháng 0 bị bỏ vì câu hỏi khác).
/// - Chi tuỳ ý = nhóm *Chi* (`phanLoaiCua`) **và** vào thống kê
///   (`khoanVaoThongKe`), **không** `laKhoanCamKet`, **không** thuộc
///   [danhMucCoNganSach] — đúng định nghĩa của donut và B3, trừ phần đã ở tầng
///   1 và 2.
/// - `thap`/`cao` = p25/p75 của tổng tuần × 30/7, làm tròn 10.000; `cao == 0`
///   (không có chi tuỳ ý) → `null`, vì *"khoảng 0 – 0 đ"* chỉ là tiếng ồn.
UocTinhChiTuyY? uocTinhChiTuyY(
  List<KhoanThuChi> khoan, {
  required DateTime now,
  required CuaSoNhinLai? cuaSo,
  required Set<String> danhMucCoNganSach,
  required bool coNganSachTong,
}) {
  if (cuaSo == null || coNganSachTong) return null;

  // Các tuần đóng TRỌN trong [cuaSo.from, đầu tuần của now).
  final dauTuanNay = bienTuan(now).from;
  final tuan = <({DateTime from, DateTime to})>[];
  var b = bienTuan(cuaSo.from);
  if (b.from.isBefore(cuaSo.from)) b = bienTuan(b.to); // tuần đầu bị cắt → bỏ
  while (!b.to.isAfter(dauTuanNay)) {
    tuan.add(b);
    b = bienTuan(b.to);
  }
  if (tuan.length < kSoTuanToiThieu) return null;

  final tong = List<double>.filled(tuan.length, 0);
  for (final k in khoan) {
    if (k.laKhoanCamKet) continue;
    if (phanLoaiCua(loai: k.loai, classifyDanhMuc: k.classify) != 'chi') continue;
    if (!khoanVaoThongKe(loai: k.loai, categoryId: k.categoryId, ghiChu: k.ghiChu)) {
      continue;
    }
    final cat = k.categoryId;
    if (cat != null && danhMucCoNganSach.contains(cat)) continue;
    for (var i = 0; i < tuan.length; i++) {
      if (!k.ngay.isBefore(tuan[i].from) && k.ngay.isBefore(tuan[i].to)) {
        tong[i] += k.soTien;
        break;
      }
    }
  }

  final s = [...tong]..sort();
  final cao = lamTronBuoc(_phanVi(s, 0.75) * 30 / 7, 10000);
  if (cao <= 0) return null;
  return UocTinhChiTuyY(
    thap: lamTronBuoc(_phanVi(s, 0.25) * 30 / 7, 10000),
    cao: cao,
    soTuan: tuan.length,
  );
}
