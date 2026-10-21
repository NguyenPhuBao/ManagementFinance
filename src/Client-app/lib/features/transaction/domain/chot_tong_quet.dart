/// A5 mục 13 — chốt SỐ TIỀN của một ảnh HOÁ ĐƠN quét: số luật (`docAnhQuet`), và số mô hình nhìn ảnh khi có (Premium).
/// Hàm thuần. Basic cũng đi qua đây (`ai: null`) — G101.
///
/// Đo Realme 2026-10-08 (15 hoá đơn thật, Gemma CPU): mô hình đúng tổng 10/15, luật 9/15 — nhưng 4/5 lần mô hình sai
/// là một số KHÔNG in trên hoá đơn (lấy giá gạch, cộng nhầm), còn chữ OCR có đúng số tổng ở cả 15/15 tờ. Nên số mô hình
/// chỉ được dùng khi nó là một số có trên ảnh; và chỉ ĐIỀN SẴN khi hai nguồn khớp nhau (người dùng chốt: lệch > 1% thì
/// ô trống + hai chip). Trên bộ đo: 12/15 điền sẵn, cả 12 đúng; 3 tờ hỏi bằng chip, số đúng luôn nằm trong chip.
///
/// G101 (Realme 2026-10-21, ảnh qua `image_picker` của `/quet`): OCR làm mất / đổi chữ số của chính dòng tổng (R13 đọc
/// *2,127* thay 72.127; R08 *75,706* thay 75.700), số mô hình bị bỏ, và số luật được ĐIỀN SẴN không phép kiểm nào — cả
/// Basic lẫn Premium. Ba lưới (người dùng chọn 2026-10-21; đo trên 34 tờ chữ: 0 tờ điền sẵn sai, 1 tờ đang điền đúng
/// chuyển sang hỏi):
/// - **C** — số mô hình không in trên ảnh vẫn là ứng viên khi khác số luật đúng MỘT chữ số, kể cả THÊM / BỚT một chữ số
///   (R13: Gemma 72.127, luật 2.127).
/// - **A** — số luật đứng một mình mà NHỎ HƠN một dòng món in phía trên dòng tổng thì không tin: ô trống (R13 Basic:
///   2.127 trong khi có món 19.800).
/// - **B** — số luật đứng một mình mà trên tờ có một số KHÁC lệch ≤ 1% (dòng VAT, dòng thanh toán) thì không biết số nào
///   bị đọc nhầm: hai chip (R08: *Tổng 75,706* · dòng VAT *75,700*).
library;

import '../../../core/ocr/so_tien_tren_anh.dart';
import 'doc_hoa_don.dart';
import 'doc_mon_hang.dart';

class ChotTong {
  const ChotTong({this.soTien, this.luaChon = const []});

  /// Số điền sẵn vào ô số tiền; `null` = để trống (có [luaChon] thì người dùng chạm chip).
  final double? soTien;

  /// Các số cho người dùng chọn khi [soTien] là `null` — số mô hình trước, số luật sau; hai số OCR thì số luật trước.
  final List<double> luaChon;
}

/// Lệch quá ngưỡng này (tỉ lệ trên số luật) thì hai nguồn được coi là KHÁC nhau.
const double kLechTongToiDa = 0.01;

ChotTong chotTongQuet({required double? luat, required int? ai, required String vanBan}) {
  final aiCo = ai != null && vanBan.split('\n').expand(tienTrenDong).contains(ai);
  // Khác đúng MỘT chữ số với số LUẬT đọc ra: OCR có thể đọc nhầm chính số tổng mà mô hình đọc đúng (OnePlus 2026-10-08:
  // MAXIDI in 75.700, OCR ra 75.706; Realme 2026-10-21: in 72.127, OCR mất chữ 7). So với số luật chứ không với mọi số
  // trên ảnh — Gemma CPU ra 17.800 cho tờ có món 19.800 (Realme), "gần" một dòng món không chứng minh gì.
  final aiGan = ai != null && luat != null && !aiCo && _lechMotChuSo(luat.round(), ai);

  if (ai != null && (aiCo || aiGan)) {
    final soAi = ai.toDouble();
    if (luat == null || (soAi - luat).abs() <= luat * kLechTongToiDa) return ChotTong(soTien: soAi);
    return ChotTong(luaChon: [soAi, luat]);
  }

  // Số luật đứng một mình: không có số mô hình (Basic, biên lai, Huỷ pha AI), hoặc số mô hình đã bị bỏ.
  if (luat == null) return const ChotTong();
  final mon = _monLonNhatTrenTong(vanBan);
  if (mon != null && luat < mon) return const ChotTong();
  final gan = _soGanNhat(vanBan, luat);
  if (gan != null) return ChotTong(luaChon: [luat, gan.toDouble()]);
  return ChotTong(soTien: luat);
}

/// Khác nhau đúng một chữ số: thay một chữ số (cùng độ dài), hoặc thêm / bớt một chữ số.
bool _lechMotChuSo(int a, int b) {
  final x = '$a', y = '$b';
  if (x.length == y.length) {
    var khac = 0;
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) khac++;
    }
    return khac == 1;
  }
  final (ngan, dai) = x.length < y.length ? (x, y) : (y, x);
  if (dai.length - ngan.length != 1) return false;
  for (var i = 0; i < dai.length; i++) {
    if (dai.substring(0, i) + dai.substring(i + 1) == ngan) return true;
  }
  return false;
}

/// Thành tiền lớn nhất của các dòng TRÊN dòng tổng, đọc như luật đọc món (`tienCuoiDong`). Bỏ dòng mang nhãn tổng
/// (*"Thành tiền 246.000"* trước chiết khấu) và nhãn loại (tiền khách đưa…). `null` khi tờ không có nhãn tổng.
///
/// Không dùng `docMonHang`: nó dừng ở dòng đầu mang chữ *tổng* — MAXIDI in *"Tổng"* ở dòng tiêu đề cột, trên mọi món.
double? _monLonNhatTrenTong(String vanBan) {
  final dau = docHoaDonTuChu(vanBan).dongTong;
  if (dau == null) return null;
  final dong = [for (final d in vanBan.split('\n')) if (d.trim().isNotEmpty) d.trim()];
  double? m;
  for (var i = 0; i < dau; i++) {
    final bo = boDauHoaDon(dong[i]);
    if (hangNhanTong(bo) >= 0 || kNhanLoaiHoaDon.any(bo.contains)) continue;
    final v = tienCuoiDong(dong[i]);
    if (v != null && v > 0 && (m == null || v > m)) m = v;
  }
  return m;
}

/// Số trên tờ KHÁC số luật mà lệch ≤ [kLechTongToiDa] — gần nhất (hoà thì số đứng trước). Bỏ dòng nhãn loại: tiền
/// khách đưa / tiền mặt làm tròn (*"Tiền mặt 45.000"* cho tổng 44.745) không phải một cách đọc khác của tổng.
int? _soGanNhat(String vanBan, double luat) {
  int? gan;
  for (final d in vanBan.split('\n')) {
    if (kNhanLoaiHoaDon.any(boDauHoaDon(d).contains)) continue;
    for (final v in tienTrenDongHoaDon(d)) {
      final lech = (v - luat).abs();
      if (lech == 0 || lech > luat * kLechTongToiDa) continue;
      if (gan == null || lech < (gan - luat).abs()) gan = v;
    }
  }
  return gan;
}
