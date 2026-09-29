/// C2 — đọc MỘT câu tiếng Việt thành các ô của form Thêm giao dịch (spec
/// `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2). Hàm thuần, **chỉ luật**: nhanh, chạy trên mọi máy, và **không
/// bao giờ bịa số** — ô nào không đọc chắc được thì `null`, form giữ nguyên ô ấy.
///
/// Bất biến ④ của nhóm C: đây chỉ là điền sẵn. Người dùng xem lại rồi bấm **Lưu** mới ghi.
///
/// Thứ tự: ngày (`timNgayTrongCau`) → số tiền (§2.1) → loại (§2.2, trên câu đã bỏ đoạn ngày và số tiền, để *"thứ 2"*
/// không đọc thành *"thu"*) → ghi chú (§2.7: câu gốc bỏ các đoạn đã dùng).
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../../../core/category/category_name.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/ngay_trong_cau.dart';
import '../../../core/utils/so_bang_chu.dart';
import '../../category/domain/phan_loai_ghi_chu.dart';

/// Kết quả đọc. Mọi trường `null` nghĩa là *không đọc được* — form **giữ nguyên** ô ấy.
class KetQuaDocCau {
  final double? soTien;

  /// `'thu'` hoặc `null` (form giữ chiều đang chọn). Không bao giờ `'chi'`: chi là mặc định của form, và câu không có
  /// từ chỉ thu thì không chứng minh được gì.
  final String? loai;

  /// Đầu ngày. Form chỉ đổi phần ngày, giữ giờ.
  final DateTime? ngay;
  final String? walletId;
  final String? categoryId;

  /// Khác `null` khi danh mục đến từ B1 — màn dùng nó để ghi phản hồi `chon` / `khac` lúc lưu, như thẻ gợi ý.
  final DoanDanhMuc? doan;

  /// `cauLyDoHoc(...)` khi danh mục đến từ B1.
  final String? lyDoDanhMuc;

  /// Câu gốc (dựng sẵn — NFC) bỏ các đoạn đã dùng, gom khoảng trắng.
  final String ghiChu;
  final List<String> canhBao;

  const KetQuaDocCau({
    this.soTien,
    this.loai,
    this.ngay,
    this.walletId,
    this.categoryId,
    this.doan,
    this.lyDoDanhMuc,
    required this.ghiChu,
    this.canhBao = const [],
  });

  bool get khongDocDuocGi =>
      soTien == null && loai == null && ngay == null && walletId == null && categoryId == null;
}

const String kCanhBaoNhieuSoTien = 'Câu có nhiều số tiền — mình chỉ điền khoản đầu.';
const String kCanhBaoSoTienQuaLon = 'Số tiền quá lớn — mình không điền.';
const String kCanhBaoSoTienKhongHopLe = 'Số tiền không hợp lệ — mình không điền.';
const String kCanhBaoSoChuChuaRo = 'Số tiền viết bằng chữ chưa rõ — bạn nhập tay nhé.';

typedef _Khoang = ({int batDau, int ketThuc});
typedef _CumTien = ({int batDau, int ketThuc, double giaTri, bool lit});

/// Số + đơn vị trên câu đã bỏ dấu: `45k`, `45 nghìn`, `2tr`, `1tr2`, `1,2 triệu`, `2 củ`, `2 lít`, `3 xị`. Nhóm 3 là
/// phần lẻ dính liền sau `tr` (`1tr2`, `1tr25`, `1tr200`).
final RegExp _mauSoDonVi = RegExp(
  r'(?<![\p{L}\p{N}.,/])(\d+(?:[.,]\d+)?)\s*(trieu|tr|cu|nghin|ngan|k|lit|xi)(\d{1,3})?(?![\p{L}\p{N}])',
  unicode: true,
);

/// Số trần: có chấm / phẩy nghìn (`45.000`) hoặc không (`45000`), tuỳ chọn `đ / đồng / vnd` theo sau (nằm trong cụm để
/// ghi chú bỏ luôn). Không dính `/` (ngày) hay chữ.
final RegExp _mauSoTran = RegExp(
  r'(?<![\p{L}\p{N}.,/])(\d{1,3}(?:[.,]\d{3})+|\d+)(?:\s*(?:dong|vnd|d)(?!\p{L}))?(?![\p{L}\p{N}/]|[.,]\d)',
  unicode: true,
);

final RegExp _truocLaNam = RegExp(r'(?<![a-z])nam\s*$');
final RegExp _sauLaChuSoChu = RegExp(r'^\s+(?:mot|hai|ba|bon|tu|nam|sau|bay|tam|chin)(?![a-z])');
final RegExp _sauLaDonViTien = RegExp(r'^\s*(?:dong|vnd|d)(?!\p{L})', unicode: true);
final RegExp _tuCuoi = RegExp(r'([\p{L}\p{M}]+)\s+$', unicode: true);
final RegExp _tu = RegExp(r'[\p{L}\p{M}]+', unicode: true);
final RegExp _chiAscii = RegExp(r'^[a-z]+$');

const Map<String, double> _giaTriDonVi = {
  'trieu': 1000000,
  'tr': 1000000,
  'cu': 1000000,
  'nghin': 1000,
  'ngan': 1000,
  'k': 1000,
  'lit': 100000,
  'xi': 100000,
};

/// Chữ đứng ngay trước số tiền mà không mang nghĩa gì cho ghi chú (*"ăn phở hết 45k"*). ⚠️ `mat` không dấu cố ý vắng:
/// đó còn là *mặt* của *"tiền mặt"*.
const Set<String> _tuDemTruocTien = {'hết', 'mất', 'tốn', 'het', 'ton'};

KetQuaDocCau docCauGiaoDich(
  String cau, {
  required DateTime now,
  required List<Wallet> vi,
  required List<Category> chonDuoc,
  BoPhanLoaiGhiChu? mo,
  Set<(String, String)> tatCap = const {},
}) {
  final s = unorm.nfc(cau);
  final thuong = s.toLowerCase();
  final b = removeVietnameseTones(thuong);
  // Bỏ dấu giữ độ dài với câu dựng sẵn; khác đi (ký tự lạ) thì vị trí không tin được — không đọc gì.
  if (b.length != s.length) return KetQuaDocCau(ghiChu: cau.trim());

  final canhBao = <String>[];
  final daDung = <_Khoang>[];

  // Ngày.
  final ng = timNgayTrongCau(s, now);
  if (ng != null) daDung.add((batDau: ng.batDau, ketThuc: ng.ketThuc));

  // Số tiền.
  final tien = _chonSoTien(s, b, ngay: ng, canhBao: canhBao);
  double? soTien;
  if (tien != null) {
    if (tien.giaTri >= 1e13) {
      canhBao.add(kCanhBaoSoTienQuaLon);
    } else if (!(tien.giaTri > 0)) {
      canhBao.add(kCanhBaoSoTienKhongHopLe);
    } else {
      soTien = tien.giaTri.roundToDouble();
      daDung.add(_moRongCumTien(thuong, b, tien));
    }
  }

  final loai = _loaiCua(_boKhoang(thuong, daDung));

  return KetQuaDocCau(
    soTien: soTien,
    loai: loai,
    ngay: ng?.ngay,
    ghiChu: _ghiChuTu(s, daDung),
    canhBao: canhBao,
  );
}

/// Cụm số tiền được chọn (§2.1), hoặc `null`. Hạng ưu tiên: *k / nghìn / tr / củ*, số chữ, số trần ≥ 1.000 trước; *lít /
/// xị* sau (*"đổ 2 lít xăng 50k"* → 50.000). Còn ≥ 2 cụm cùng hạng → cụm đầu + cảnh báo.
_CumTien? _chonSoTien(
  String s,
  String b, {
  required NgayTrongCau? ngay,
  required List<String> canhBao,
}) {
  final cum = <_CumTien>[];
  bool trungNgay(int bd, int kt) => ngay != null && bd < ngay.ketThuc && kt > ngay.batDau;

  for (final m in _mauSoDonVi.allMatches(b)) {
    final dv = m.group(2)!;
    final le = m.group(3);
    if (le != null && dv != 'tr') continue; // "2k5" — không chắc thì không đọc
    var gt = double.parse(m.group(1)!.replaceAll(',', '.')) * _giaTriDonVi[dv]!;
    if (le != null) gt += int.parse(le) * const [0, 100000, 10000, 1000][le.length];
    if (trungNgay(m.start, m.end)) continue;
    cum.add((batDau: m.start, ketThuc: m.end, giaTri: gt, lit: dv == 'lit' || dv == 'xi'));
  }

  for (final m in _mauSoTran.allMatches(b)) {
    if (cum.any((c) => m.start < c.ketThuc && m.end > c.batDau) || trungNgay(m.start, m.end)) continue;
    final chuSo = m.group(1)!.replaceAll(RegExp(r'[.,]'), '');
    if (chuSo.length >= 2 && chuSo.startsWith('0')) continue; // số điện thoại, mã
    if (_truocLaNam.hasMatch(b.substring(0, m.start))) continue; // "năm 2026"
    final gt = double.parse(chuSo);
    if (gt < 1000) continue; // số lượng: "2 ly cà phê"
    cum.add((batDau: m.start, ketThuc: m.end, giaTri: gt, lit: false));
  }

  var chuaRo = false;
  for (final c in timSoBangChu(s)) {
    if (trungNgay(c.batDau, c.ketThuc)) continue;
    // "một triệu hai" = 1.200.000 hay 1.000.000 rồi chữ khác? Không chắc thì không đọc.
    if (c.giaTri.isNaN || _sauLaChuSoChu.hasMatch(b.substring(c.ketThuc))) {
      chuaRo = true;
      continue;
    }
    if (c.giaTri < 1000) continue;
    cum.add((batDau: c.batDau, ketThuc: c.ketThuc, giaTri: c.giaTri, lit: false));
  }

  cum.sort((x, y) => x.batDau.compareTo(y.batDau));
  final truoc = [for (final c in cum) if (!c.lit) c];
  final hang = truoc.isNotEmpty ? truoc : [for (final c in cum) if (c.lit) c];
  if (hang.isEmpty) {
    if (chuaRo) canhBao.add(kCanhBaoSoChuChuaRo);
    return null;
  }
  if (hang.length >= 2) canhBao.add(kCanhBaoNhieuSoTien);
  return hang.first;
}

/// Đoạn ghi chú bỏ cho số tiền: cụm, cộng *"đồng"* ngay sau, cộng *"hết / mất / tốn"* ngay trước.
_Khoang _moRongCumTien(String thuong, String b, _CumTien c) {
  var bd = c.batDau;
  var kt = c.ketThuc;
  final sau = _sauLaDonViTien.firstMatch(b.substring(kt));
  if (sau != null) kt += sau.end;
  final truoc = _tuCuoi.firstMatch(thuong.substring(0, bd));
  if (truoc != null && _tuDemTruocTien.contains(truoc.group(1))) bd = truoc.start;
  return (batDau: bd, ketThuc: kt);
}

/// [s] với mọi [khoang] thay bằng khoảng trắng cùng độ dài — giữ vị trí.
String _boKhoang(String s, List<_Khoang> khoang) {
  final c = s.split('');
  for (final k in khoang) {
    for (var i = k.batDau; i < k.ketThuc && i < c.length; i++) {
      c[i] = ' ';
    }
  }
  return c.join();
}

String _ghiChuTu(String s, List<_Khoang> daDung) {
  var g = _boKhoang(s, daDung).replaceAll(RegExp(r'\s+'), ' ');
  g = g.replaceAllMapped(RegExp(r' ([,.;:!?])'), (m) => m[1]!);
  g = g.replaceAllMapped(RegExp(r'([,.;:])(?:[\s,.;:])*[,.;:]'), (m) => m[1]!);
  return g.replaceAll(RegExp(r'^[\s,.;:\-–]+|[\s,.;:\-–]+$'), '');
}

// §2.2 — từ chỉ THU. Khớp theo TỪNG TỪ, phân biệt dấu: bỏ dấu cả câu thì "bạn" thành "ban" (= bán), "lại" thành "lai"
// (= lãi), "bình thường" chứa "thuong" (= thưởng) — câu rất thường gặp "ăn với bạn 200k" sẽ thành khoản thu. Từ gõ
// KHÔNG dấu chỉ nhận những dạng không lẫn được.
const Set<String> _thuCoDau = {'lương', 'thưởng', 'thu', 'bán', 'lãi'};
const Set<String> _thuKhongDau = {'luong', 'thu'};
const Set<String> _thuHaiTu = {
  'được cho', 'được tặng', 'được biếu', 'được trả', 'được hoàn', 'hoàn tiền', 'hoàn trả', 'lì xì', //
  'duoc cho', 'duoc tang', 'duoc bieu', 'duoc tra', 'duoc hoan', 'hoan tien', 'hoan tra', 'li xi', 'tien thuong',
};

/// *nhận* là thu, trừ *nhận hàng / đồ / đơn / gói* (nhận hàng thường là trả tiền).
const Set<String> _sauNhanKhongPhaiThu = {'hàng', 'đồ', 'đơn', 'gói', 'hang', 'do', 'don', 'goi'};

/// Vay / nợ: chiều tiền đọc từ danh mục + ô *Chiều tiền*, không đoán từ câu. So bỏ dấu (bắt nhầm *"nó"* chỉ làm câu
/// không đặt loại — vô hại).
const Set<String> _vayNo = {'no', 'vay'};

String? _loaiCua(String thuong) {
  final tu = [for (final m in _tu.allMatches(thuong)) unorm.nfc(m.group(0)!)];
  final bo = [for (final t in tu) removeVietnameseTones(t)];
  if (bo.any(_vayNo.contains)) return null;
  for (var i = 0; i < tu.length; i++) {
    final t = tu[i];
    final ascii = _chiAscii.hasMatch(t);
    final ke = i + 1 < tu.length ? tu[i + 1] : null;
    if (ke != null && _thuHaiTu.contains('$t $ke')) return 'thu';
    if (ascii ? _thuKhongDau.contains(t) : _thuCoDau.contains(t)) return 'thu';
    if ((t == 'nhận' || t == 'nhan') && (ke == null || !_sauNhanKhongPhaiThu.contains(ke))) return 'thu';
  }
  return null;
}
