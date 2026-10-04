/// Nhịp chi riêng của một ngân sách, học từ các kỳ đã đóng — dự án C việc hai,
/// spec `docs/superpowers/specs/2026-10-04-du-an-c-nhip-chi-ngan-sach-design.md`.
/// Logic thuần: không Drift, không đồng hồ.
///
/// Trả lời hai câu, cả hai theo PHẦN THỜI GIAN ĐÃ TRÔI của kỳ (`x` ∈ [0, 1], đo bằng
/// [viTriTrongKy] — cùng phép với `budgetPaceOf`, nên tháng 28 và 31 ngày so được):
/// - [NhipChi.phanDaChiMoiKhi]: mọi khi tới thời điểm này đã chi bao nhiêu PHẦN của
///   cả kỳ — cho chip nhịp chi;
/// - [NhipChi.conChiMoiKhi]: mọi khi từ thời điểm này tới cuối kỳ còn chi bao nhiêu
///   TIỀN — cho dự phóng cuối kỳ.
///
/// Cả hai lấy TRUNG VỊ trên các kỳ CÓ CHI: một tháng bất thường không kéo lệch, và
/// kỳ không chi không tính (người dùng chốt, spec quyết định 7). Dưới
/// [kSoKyHocToiThieu] kỳ có chi thì [hocNhipChi] trả `null` — nghĩa DUY NHẤT là
/// *chưa biết*, mọi chỗ dùng rơi về giả định chi đều như trước.
library;

/// Dưới chừng này kỳ có chi thì im hẳn (luật chung mục 11.4 `AI_EDGE_FEATURE.md`).
const int kSoKyHocToiThieu = 3;

/// Nhìn lại nhiều nhất chừng này kỳ đã đóng.
const int kSoKyHocToiDa = 6;

/// Một khoản chi: ngày ghi và số tiền DƯƠNG (client lưu `amount` dương).
typedef KhoanChi = ({DateTime ngay, double soTien});

/// Một kỳ đã đóng kèm các khoản chi của nó, `[from, to)`.
class KyChi {
  final DateTime from;
  final DateTime to;
  final List<KhoanChi> khoan;
  const KyChi({required this.from, required this.to, required this.khoan});
}

/// Vị trí của [moc] trong `[from, to)` theo thời gian, kẹp `[0, 1]`; kỳ rỗng → 0.
/// Định nghĩa DUY NHẤT của "phần thời gian đã trôi" — `budgetPaceOf` gọi lại nó.
double viTriTrongKy(DateTime from, DateTime to, DateTime moc) {
  final tong = to.difference(from).inMicroseconds;
  if (tong <= 0) return 0;
  return (moc.difference(from).inMicroseconds / tong).clamp(0.0, 1.0).toDouble();
}

class _DuongKy {
  /// (vị trí trong kỳ, số tiền), không cần sắp — số khoản một kỳ nhỏ.
  final List<(double, double)> diem;
  final double tong;
  const _DuongKy(this.diem, this.tong);

  double daChiToi(double x) {
    var s = 0.0;
    for (final (viTri, tien) in diem) {
      if (viTri <= x) s += tien;
    }
    return s;
  }
}

class NhipChi {
  final List<_DuongKy> _ky;
  const NhipChi._(this._ky);

  /// Số kỳ học được (kỳ có chi).
  int get soKy => _ky.length;

  /// Tổng chi từng kỳ học được, cũ trước mới sau — cho công cụ đo và ca test.
  List<double> get tongTheoKy => [for (final k in _ky) k.tong];

  double phanDaChiMoiKhi(double x) =>
      _trungVi([for (final k in _ky) k.daChiToi(x) / k.tong]);

  double conChiMoiKhi(double x) =>
      _trungVi([for (final k in _ky) k.tong - k.daChiToi(x)]);
}

/// Học nhịp từ các kỳ đã đóng; `null` khi dưới [kSoKyHocToiThieu] kỳ có chi.
NhipChi? hocNhipChi(List<KyChi> ky) {
  final hoc = <_DuongKy>[];
  for (final k in ky) {
    var tong = 0.0;
    final diem = <(double, double)>[];
    for (final c in k.khoan) {
      tong += c.soTien;
      diem.add((viTriTrongKy(k.from, k.to, c.ngay), c.soTien));
    }
    if (tong > 0) hoc.add(_DuongKy(diem, tong));
  }
  if (hoc.length < kSoKyHocToiThieu) return null;
  return NhipChi._(hoc);
}

double _trungVi(List<double> xs) {
  final s = [...xs]..sort();
  final giua = s.length ~/ 2;
  return s.length.isOdd ? s[giua] : (s[giua - 1] + s[giua]) / 2;
}
