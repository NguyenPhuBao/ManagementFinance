/// Gộp kết quả `timGiaoDich` theo danh mục hoặc ví — cho tool `truy_van_giao_dich`
/// (spec `2026-09-27-tool-truy-van-giao-dich-design.md` mục 2.3). Chạy trên tập
/// `DongTimThay` ĐÃ lọc: không lọc lại, không đọc CSDL, nên gộp và liệt kê luôn
/// nói về một tập (bài học gói hoá đơn 1.3 `AI_EDGE_FEATURE.md`).
///
/// Khoản chuyển tính vào ví NGUỒN (`tenVi`); theo danh mục thì khoản không danh
/// mục vào "Chưa phân loại" — đúng tên tool tổng kết cũ đã dùng.
library;

import 'tim_giao_dich.dart';

enum NhomTheo { danhMuc, vi }

const String kTenChuaPhanLoai = 'Chưa phân loại';

class NhomGiaoDich {
  const NhomGiaoDich({
    required this.ten,
    required this.chi,
    required this.thu,
    required this.chuyen,
    required this.soKhoan,
  });

  final String ten;
  final double chi;
  final double thu;
  final double chuyen;
  final int soKhoan;

  /// Số dùng để xếp và để "chọn": theo chiều đang hỏi; mọi chiều thì theo chi.
  double tongTheo(ChieuTim c) => switch (c) {
        ChieuTim.thu => thu,
        ChieuTim.chuyen => chuyen,
        ChieuTim.chi || ChieuTim.tatCa => chi,
      };
}

List<NhomGiaoDich> gopGiaoDich(
  List<DongTimThay> dong, {
  required NhomTheo theo,
  required ChieuTim chieu,
}) {
  final gom = <String, ({double chi, double thu, double chuyen, int n})>{};
  for (final d in dong) {
    final ten = switch (theo) {
      NhomTheo.danhMuc => d.tenDanhMuc ?? kTenChuaPhanLoai,
      NhomTheo.vi => d.tenVi,
    };
    final cu = gom[ten] ?? (chi: 0.0, thu: 0.0, chuyen: 0.0, n: 0);
    gom[ten] = (
      chi: cu.chi + (d.chieu == ChieuTim.chi ? d.soTien : 0),
      thu: cu.thu + (d.chieu == ChieuTim.thu ? d.soTien : 0),
      chuyen: cu.chuyen + (d.chieu == ChieuTim.chuyen ? d.soTien : 0),
      n: cu.n + 1,
    );
  }
  return [
    for (final e in gom.entries)
      NhomGiaoDich(
        ten: e.key,
        chi: e.value.chi,
        thu: e.value.thu,
        chuyen: e.value.chuyen,
        soKhoan: e.value.n,
      ),
  ]..sort((a, b) => b.tongTheo(chieu).compareTo(a.tongTheo(chieu)));
}
