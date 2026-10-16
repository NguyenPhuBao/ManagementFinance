/// A5 mục 13 — chốt SỐ TIỀN của một ảnh quét khi có hai nguồn: luật (`docAnhQuet`) và mô hình nhìn ảnh. Hàm thuần.
///
/// Đo Realme 2026-10-08 (15 hoá đơn thật, Gemma CPU): mô hình đúng tổng 10/15, luật 9/15 — nhưng 4/5 lần mô hình sai
/// là một số KHÔNG in trên hoá đơn (lấy giá gạch, cộng nhầm), còn chữ OCR có đúng số tổng ở cả 15/15 tờ. Nên số mô hình
/// chỉ được dùng khi nó là một số có trên ảnh; và chỉ ĐIỀN SẴN khi hai nguồn khớp nhau (người dùng chốt: lệch > 1% thì
/// ô trống + hai chip). Trên bộ đo: 12/15 điền sẵn, cả 12 đúng; 3 tờ hỏi bằng chip, số đúng luôn nằm trong chip.
library;

import '../../../core/ocr/so_tien_tren_anh.dart';

class ChotTong {
  const ChotTong({this.soTien, this.luaChon = const []});

  /// Số điền sẵn vào ô số tiền; `null` = để trống (có [luaChon] thì người dùng chạm chip).
  final double? soTien;

  /// Các số cho người dùng chọn khi [soTien] là `null` — số mô hình trước, số luật sau.
  final List<double> luaChon;
}

/// Lệch quá ngưỡng này (tỉ lệ trên số luật) thì hai nguồn được coi là KHÁC nhau.
const double kLechTongToiDa = 0.01;

ChotTong chotTongQuet({required double? luat, required int? ai, required String vanBan}) {
  final aiCo = ai != null && vanBan.split('\n').expand(tienTrenDong).contains(ai);
  // Khác đúng MỘT chữ số với số LUẬT đọc ra: OCR có thể đọc nhầm chính số tổng mà mô hình đọc đúng (OnePlus 2026-10-08:
  // MAXIDI in 75.700, OCR ra 75.706). So với số luật chứ không với mọi số trên ảnh — Gemma CPU ra 17.800 cho tờ có món
  // 19.800 (Realme), "gần" một dòng món không chứng minh gì.
  final aiGan = ai != null && luat != null && !aiCo && _lechMotChuSo(luat.round(), ai);

  if (ai == null || (!aiCo && !aiGan)) return luat == null ? const ChotTong() : ChotTong(soTien: luat);
  final soAi = ai.toDouble();
  if (luat == null || (soAi - luat).abs() <= luat * kLechTongToiDa) return ChotTong(soTien: soAi);
  return ChotTong(luaChon: [soAi, luat]);
}

bool _lechMotChuSo(int a, int b) {
  final x = '$a', y = '$b';
  if (x.length != y.length) return false;
  var khac = 0;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) khac++;
  }
  return khac == 1;
}
