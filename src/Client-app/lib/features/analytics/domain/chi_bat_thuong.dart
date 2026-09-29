/// Chi bất thường theo danh mục (B3) — *"tháng này cả danh mục X có lạ so với
/// chính tôi không"*. Trung vị + MAD, z hiệu chỉnh (Iglewicz–Hoaglin) > 3,5,
/// cộng phần vượt > ngưỡng có nghĩa.
///
/// Khác *Khoản chi lớn* (17/09, ngưỡng người dùng đặt cho MỘT khoản): hai câu
/// hỏi khác nhau, không thay nhau. Người dùng mở lại quyết định 17/09 (*"bất
/// thường là ngưỡng người dùng đặt, không dùng thống kê"*) cho câu hỏi này, với
/// hai lo ngại của hôm ấy xử lý thẳng: thiếu mẫu (< 4 tháng) thì **im hẳn**; z
/// chặt và vế tiền để ưu tiên bỏ sót hơn báo nhầm.
///
/// Spec: docs/superpowers/specs/2026-09-28-b3-chi-bat-thuong-theo-danh-muc-design.md
library;

import 'khoan_vao_thong_ke.dart';
import 'phan_loai_dong_tien.dart';
import 'thong_ke_thang.dart';

/// Cần ít nhất chừng này tháng đã đóng **có phát sinh** mới xét.
const int kSoThangMauToiThieu = 4;

/// Nhìn lại tối đa chừng này tháng lịch đã đóng trước tháng đang xét.
const int kSoThangNhinLai = 12;

/// Ngưỡng z hiệu chỉnh (Iglewicz–Hoaglin).
const double kNguongZ = 3.5;

class ChiBatThuong {
  final String categoryId;

  /// Tổng chi của danh mục trong tháng đang xét (tới `now` nếu tháng chưa hết;
  /// không dự phóng).
  final double chi;

  /// Trung vị chi của các tháng lịch sử có phát sinh.
  final double thuongLe;
  final int soThangMau;

  const ChiBatThuong({
    required this.categoryId,
    required this.chi,
    required this.thuongLe,
    required this.soThangMau,
  });

  double get vuot => chi - thuongLe;
}

double _trungVi(List<double> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// z hiệu chỉnh. MAD = 0 (hơn nửa mẫu bằng trung vị) thì rơi về độ lệch tuyệt
/// đối trung bình với hệ số 1,2533; cả hai bằng 0 (lịch sử y hệt nhau) thì mọi
/// mức cao hơn đều "vô cùng lạ" — vế tiền quyết.
double _z(double x, List<double> ls) {
  final m = _trungVi(ls);
  final lech = [for (final v in ls) (v - m).abs()];
  final mad = _trungVi(lech);
  if (mad > 0) return 0.6745 * (x - m) / mad;
  final tb = lech.reduce((a, b) => a + b) / lech.length;
  if (tb > 0) return (x - m) / (1.2533 * tb);
  return x > m ? double.infinity : 0;
}

/// Danh mục chi bất thường trong tháng chứa [thang], xếp theo phần vượt giảm
/// dần. [khoan] là **toàn bộ** giao dịch đã dựng (kèm `classify`, `ghiChu`).
///
/// Chuỗi chỉ gồm khoản thuộc nhóm *Chi* của donut (`phanLoaiCua == 'chi'`) **và**
/// vào thống kê (`khoanVaoThongKe`) — vay/nợ, khoản chuyển, điều chỉnh số dư, mở
/// sổ đều bị loại. Khoản không danh mục bỏ qua.
///
/// ⚠️ Lịch sử chỉ lấy tháng **có phát sinh**: danh mục chi thưa (du lịch) mà
/// tính cả tháng 0 đồng thì trung vị 0 và mọi lần chi đều thành bất thường.
List<ChiBatThuong> chiBatThuong(
  List<KhoanThuChi> khoan, {
  required DateTime thang,
  required DateTime now,
  required double nguong,
}) {
  final dauThang = DateTime(thang.year, thang.month);
  final dauThangSau = DateTime(thang.year, thang.month + 1);
  final dauLichSu = DateTime(thang.year, thang.month - kSoThangNhinLai);

  // categoryId → (khoá tháng `năm × 12 + tháng` → tổng).
  final theoThang = <String, Map<int, double>>{};
  final hienTai = <String, double>{};
  for (final k in khoan) {
    final cat = k.categoryId;
    if (cat == null) continue;
    if (phanLoaiCua(loai: k.loai, classifyDanhMuc: k.classify) != 'chi') continue;
    if (!khoanVaoThongKe(loai: k.loai, categoryId: k.categoryId, ghiChu: k.ghiChu)) continue;
    if (k.ngay.isAfter(now)) continue;
    if (!k.ngay.isBefore(dauThang) && k.ngay.isBefore(dauThangSau)) {
      hienTai[cat] = (hienTai[cat] ?? 0) + k.soTien;
    } else if (!k.ngay.isBefore(dauLichSu) && k.ngay.isBefore(dauThang)) {
      final khoa = k.ngay.year * 12 + k.ngay.month;
      final m = theoThang.putIfAbsent(cat, () => {});
      m[khoa] = (m[khoa] ?? 0) + k.soTien;
    }
  }

  final ra = <ChiBatThuong>[];
  for (final e in hienTai.entries) {
    final ls = [
      for (final v in (theoThang[e.key]?.values ?? const <double>[]))
        if (v > 0) v,
    ];
    if (ls.length < kSoThangMauToiThieu) continue;
    final m = _trungVi(ls);
    if (_z(e.value, ls) > kNguongZ && e.value - m > nguong) {
      ra.add(ChiBatThuong(
        categoryId: e.key,
        chi: e.value,
        thuongLe: m,
        soThangMau: ls.length,
      ));
    }
  }
  ra.sort((a, b) => b.vuot.compareTo(a.vuot));
  return ra;
}
