/// Xác suất vượt ngân sách cuối kỳ bằng ba phương pháp của đề tài NCKH — BẢN THỬ
/// (nhánh TranQuangDat, không phát hành): M1 trung vị nhịp chi (thêm xác suất
/// thực nghiệm K+1 mức), M2 làm trơn hàm mũ (EWMA), M3 hồi quy phân vị.
///
/// Chép nguyên `research/du-bao-vuot-ngan-sach/experiment/core.py` (`build_rows`,
/// `m3_features`) theo NGÀY: khoản chi của hôm nay tính trọn, kỳ trước cắt ở ngày
/// `floor(x · số ngày kỳ ấy)`. Khác chip nhịp chi của app (đo theo giờ thật,
/// `nhip_chi.dart`) — cố ý, để ba phương pháp đo trên cùng một định nghĩa với bài.
/// Logic thuần: không Drift, không đồng hồ.
library;

import 'dart:math' as math;

import 'he_so_m3_vn.g.dart';

/// Số kỳ đã đóng nhìn lại (bài: HISTORY = 6, cùng `kSoKyHocToiDa`).
const int kSoKyDuBao = 6;

/// Dưới chừng này kỳ có chi thì M1 rơi về M0 (cùng `kSoKyHocToiThieu`).
const int kSoKyM1ToiThieu = 3;

/// Số ngày đầu dùng khởi tạo trung bình / phương sai của M2.
const int kNgayKhoiTaoM2 = 30;

class DuBaoVuot {
  final double p0;
  final double p1;
  final double p2;
  final double p3;

  /// Số kỳ có chi trong [kSoKyDuBao] kỳ trước.
  final int soKy;

  const DuBaoVuot({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.soKy,
  });
}

/// [thang]: chi theo ngày, mỗi tháng một danh sách, từ tháng có giao dịch đầu tiên
/// tới tháng hiện tại; tháng trước dài đủ số ngày, tháng hiện tại dài tới HÔM NAY
/// (độ dài = ngày hiện tại). [soNgayKyNay]: số ngày của tháng hiện tại.
///
/// `null` khi chưa đủ [kSoKyDuBao] tháng trước tháng hiện tại, ngân sách ≤ 0,
/// không kỳ nào có chi, hoặc chưa đủ ngày khởi tạo M2.
DuBaoVuot? duBaoVuotNganSach({
  required List<List<double>> thang,
  required int soNgayKyNay,
  required double nganSach,
}) {
  final m = thang.length - 1;
  final b = nganSach;
  if (m < kSoKyDuBao || b <= 0) return null;
  final t = thang[m].length;
  final tT = soNgayKyNay;
  if (t < 1 || t > tT) return null;

  double tong(List<double> xs, [int? den]) {
    var s = 0.0;
    final n = den ?? xs.length;
    for (var i = 0; i < n; i++) {
      s += xs[i];
    }
    return s;
  }

  final x = t / tT;
  final s = tong(thang[m]);

  final tongKy = <double>[];
  final con = <double>[];
  var k = 0;
  var duoiM0 = 0, coM0 = 0;
  for (var j = m - kSoKyDuBao; j < m; j++) {
    final ky = thang[j];
    final tk = tong(ky);
    if (tk <= 0) continue;
    k++;
    final dk = (x * ky.length + 1e-9).floor();
    final ck = tong(ky, dk);
    tongKy.add(tk);
    con.add(tk - ck);
    if (ck > 0) {
      coM0++;
      if (s * tk / ck > b) duoiM0++;
    }
  }
  if (k < 1) return null;

  final p0 = (duoiM0 + 0.5) / (coM0 + 1);
  final p1 = k >= kSoKyM1ToiThieu
      ? ([for (final r in con) if (s + r > b) r].length + 0.5) / (k + 1)
      : p0;

  // M2 — EWMA trên chuỗi ngày từ tháng đầu tới hôm nay.
  final chuoi = [for (final ky in thang) ...ky];
  if (chuoi.length < kNgayKhoiTaoM2) return null;
  var mu = 0.0;
  for (var i = 0; i < kNgayKhoiTaoM2; i++) {
    mu += chuoi[i];
  }
  mu /= kNgayKhoiTaoM2;
  var v = 0.0;
  for (var i = 0; i < kNgayKhoiTaoM2; i++) {
    v += (chuoi[i] - mu) * (chuoi[i] - mu);
  }
  v /= kNgayKhoiTaoM2;
  const lam = kLambdaM2;
  for (var i = kNgayKhoiTaoM2; i < chuoi.length; i++) {
    final y = chuoi[i];
    final vMoi = lam * (y - mu) * (y - mu) + (1 - lam) * v;
    mu = lam * y + (1 - lam) * mu;
    v = vMoi;
  }
  final conNgay = tT - t;
  final sd = math.sqrt(math.max(conNgay * v, 1e-12));
  final p2 = 0.5 * _erfc((b - s - conNgay * mu) / sd / math.sqrt2);

  // M3 — bảy đặc trưng, chuẩn hoá, 19 phân vị, nội suy hàm phân phối.
  final rmed = _trungVi(con);
  var cal = 0.0;
  for (var i = 0; i < con.length; i++) {
    cal += con[i] / tongKy[i];
  }
  cal /= con.length;
  final tb = tong(tongKy) / tongKy.length;
  var ps = 0.0;
  for (final tk in tongKy) {
    ps += (tk - tb) * (tk - tb);
  }
  final cv = math.sqrt(ps / tongKy.length) / tb;
  final dacTrung = [x, s / b, rmed / b, conNgay * mu / b, sd / b, cal, cv];
  final q = <double>[];
  for (final heSo in kM3HeSo) {
    var y = heSo[0];
    for (var i = 0; i < dacTrung.length; i++) {
      y += heSo[i + 1] * (dacTrung[i] - kM3TrungBinh[i]) / kM3DoLech[i];
    }
    q.add(y);
  }
  q.sort();
  final p3 = 1 - _noiSuy((b - s) / b, q, kM3PhanVi);

  return DuBaoVuot(p0: p0, p1: p1, p2: p2, p3: p3, soKy: k);
}

double _trungVi(List<double> xs) {
  final s = [...xs]..sort();
  final giua = s.length ~/ 2;
  return s.length.isOdd ? s[giua] : (s[giua - 1] + s[giua]) / 2;
}

/// Như `numpy.interp`, ngoài biên trả nửa phân vị đầu / cuối (core.fit_m3).
double _noiSuy(double v, List<double> xp, List<double> fp) {
  if (v < xp.first) return fp.first / 2;
  if (v > xp.last) return 1 - (1 - fp.last) / 2;
  for (var i = 0; i < xp.length - 1; i++) {
    if (v <= xp[i + 1]) {
      final w = xp[i + 1] - xp[i];
      if (w <= 0) return fp[i + 1];
      return fp[i] + (fp[i + 1] - fp[i]) * (v - xp[i]) / w;
    }
  }
  return fp.last;
}

/// erfc — Numerical Recipes `erfcc`, sai số tương đối < 1,2·10⁻⁷.
double _erfc(double x) {
  final z = x.abs();
  final t = 1 / (1 + 0.5 * z);
  final r = t *
      math.exp(-z * z -
          1.26551223 +
          t *
              (1.00002368 +
                  t *
                      (0.37409196 +
                          t *
                              (0.09678418 +
                                  t *
                                      (-0.18628806 +
                                          t *
                                              (0.27886807 +
                                                  t *
                                                      (-1.13520398 +
                                                          t *
                                                              (1.48851587 +
                                                                  t * (-0.82215223 + t * 0.17087277)))))))));
  return x >= 0 ? r : 2 - r;
}
