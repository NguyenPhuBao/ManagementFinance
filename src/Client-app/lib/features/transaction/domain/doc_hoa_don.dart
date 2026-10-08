/// A5 mục 5.1 — luật đọc HOÁ ĐƠN GIẤY từ chữ OCR (mỗi dòng một hàng, đã `ghepDongTheoHang`): tổng tiền, tên cửa hàng,
/// ngày, giờ. Hàm thuần.
///
/// Nâng từ spike C4 (`features/ai_chat/spike/spike_c4.dart`, lối A) ngày 2026-10-08 cho nút Quét. Spike giữ bí danh
/// gọi lại tệp này để màn đo và `spike_c4_test` không đổi.
library;

import '../../../core/category/category_name.dart';
import '../../../core/ocr/so_tien_tren_anh.dart';

class KetQuaHoaDon {
  final int? tong;
  final String? cuaHang;

  /// `dd/MM/yyyy`.
  final String? ngay;

  /// `HH:mm` in trên hoá đơn (A5 — giờ giao dịch đi cùng ngày).
  final String? gio;

  /// Ngày in đủ hai chữ số cả ngày lẫn tháng (*02/10/2026*) — chắc là ngày/tháng. `false` khi in thiếu số 0 (*9/2/2026*):
  /// máy POS MAXIDI in THÁNG/NGÀY kiểu ấy (nghiệm thu Realme 2026-10-08), nên thứ tự là chưa chắc.
  final bool ngayDuHaiSo;

  /// Dòng mà luật lấy tổng từ đó — để người chấm thấy vì sao.
  final String? canCu;
  const KetQuaHoaDon({this.tong, this.cuaHang, this.ngay, this.gio, this.canCu, this.ngayDuHaiSo = true});

  @override
  String toString() =>
      'tong=$tong | cua_hang=$cuaHang | ngay=$ngay | gio=$gio${canCu == null ? '' : ' | can_cu="$canCu"'}';
}

/// Chữ thường, bỏ dấu, gom khoảng trắng — phép so nhãn của mọi luật đọc ảnh hoá đơn.
///
/// Kèm chữ Latin có dấu mà OCR hay đọc nhầm từ chữ Việt (*"Töng"*, *"nåm"* — Realme 2026-10-08).
String boDauHoaDon(String s) =>
    removeVietnameseTones(normalizeCategoryName(s)).replaceAllMapped(RegExp('[äåöüëïÿ]'), (m) => _latin[m[0]!]!);

const Map<String, String> _latin = {'ä': 'a', 'å': 'a', 'ö': 'o', 'ü': 'u', 'ë': 'e', 'ï': 'i', 'ÿ': 'y'};

/// Nhãn của dòng tổng, theo thứ tự ƯU TIÊN (đứng trước thắng). So trên chữ bỏ dấu.
const List<String> kNhanTongHoaDon = [
  'tong thanh toan',
  'can thanh toan',
  'phai thanh toan',
  'khach phai tra',
  'phai tra',
  // Realme 2026-10-08 (Dookki): *"Payment Amount"* là số thực trả (đã VAT); *"Total"* là trước VAT.
  'payment',
  'tong cong',
  'tong tien',
  'thanh tien',
  'grand total',
  'total',
  'thanh toan',
  'so tien',
  'tong',
];

/// Dòng trông như tổng nhưng không phải số phải trả.
const List<String> kNhanLoaiHoaDon = [
  'khach dua',
  'tien khach',
  'tien thoi',
  'thoi lai',
  'tien thua',
  'tra lai',
  'giam gia',
  'chiet khau',
  'tong so luong',
  'tong sl',
  'subtotal',
  'tam tinh',
  // Nghiệm thu 2026-10-08 (hoá đơn MAXIDI): dòng THANH TOÁN — số tiền khách đưa, lớn hơn tổng.
  'tien mat',
  // Có nhãn 'payment' trong [kNhanTongHoaDon] thì *"Payment Method: Cash"* rồi *"Cash 150,000"* thành tổng — dòng phương
  // thức trả, tiền khách đưa, tiền thối tiếng Anh đều loại.
  'method',
  'phuong thuc',
  'cash',
  'change',
];

/// *"Tổng"* bị OCR đọc nhầm một nguyên âm (*"Teng"*, *"Tung"*) — ảnh nhăn, nghiệm thu 2026-10-08. Một TỪ trọn 4 chữ;
/// cố ý không nhận *"tang"* (*tầng / tăng* hay có trong địa chỉ).
final RegExp kNhanTongDocNham = RegExp(r'\bt[eouy]ng\b');

/// Thứ hạng nhãn tổng của một dòng (bỏ dấu); `-1` = không phải dòng tổng. Nhãn đọc nhầm xếp cùng hạng *"tong"*.
///
/// Từ đọc nhầm được thay bằng *"tong"* TRƯỚC khi so, nên nó xếp đúng hạng ở mọi nhãn ghép (Realme 2026-10-08, ÙA TEA:
/// *"Téng tiên: 217.500"* là *"Tổng tiền"*, phải thắng *"Thành tiền: 246.000"* trước chiết khấu).
int hangNhanTong(String bo) => kNhanTongHoaDon.indexWhere(bo.replaceAll(kNhanTongDocNham, 'tong').contains);

final RegExp _ngay = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b');
final RegExp _gio = RegExp(r'\b(\d{1,2}):(\d{2})(?::\d{2})?(?:\s?([AaPp])[Mm]\b|\b)');

/// *"Sep 28, 2026"* (Starbucks) — so trên chữ bỏ dấu.
final RegExp _ngayAnh = RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.? (\d{1,2}),? (\d{4})\b');
const List<String> _thangAnh = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

/// *"Ngày 19 tháng 09 năm 2026"* (KiotViet) — so trên chữ bỏ dấu; OCR hay méo chữ *tháng* / *năm*.
final RegExp _ngayChu = RegExp(r'\bngay (\d{1,2}) th\S* (\d{1,2}) n\S* (\d{4})\b');

/// Dòng dấu ảnh của máy chụp (*"realme Shot on Q3 Pro 5G 2026 10 02 14:46"*) — giờ trên đó là giờ CHỤP, không phải
/// giờ mua (Realme 2026-10-08).
bool _laDauAnh(String bo) => bo.contains('shot on');

String _hai(int v) => v.toString().padLeft(2, '0');

String? _docGio(String vanBan) {
  for (final m in _gio.allMatches(vanBan)) {
    var h = int.parse(m.group(1)!);
    final p = int.parse(m.group(2)!);
    final ap = m.group(3)?.toLowerCase();
    if (ap != null && h >= 1 && h <= 12) h = ap == 'p' ? h % 12 + 12 : h % 12;
    if (h < 24 && p < 60) return '${_hai(h)}:${m.group(2)}';
  }
  return null;
}

/// Ngày in trên hoá đơn → (`dd/MM/yyyy`, in đủ hai chữ số). Dạng số trước, rồi tiếng Anh, rồi chữ.
(String, bool)? _docNgay(String vanBan) {
  final n = _ngay.firstMatch(vanBan);
  if (n != null) {
    final nam = n.group(3)!.length == 2 ? '20${n.group(3)}' : n.group(3)!;
    return (
      '${n.group(1)!.padLeft(2, '0')}/${n.group(2)!.padLeft(2, '0')}/$nam',
      n.group(1)!.length == 2 && n.group(2)!.length == 2,
    );
  }
  final bo = boDauHoaDon(vanBan);
  final a = _ngayAnh.firstMatch(bo);
  if (a != null) {
    return ('${_hai(int.parse(a.group(2)!))}/${_hai(_thangAnh.indexOf(a.group(1)!) + 1)}/${a.group(3)}', true);
  }
  final c = _ngayChu.firstMatch(bo);
  if (c != null) return ('${_hai(int.parse(c.group(1)!))}/${_hai(int.parse(c.group(2)!))}/${c.group(3)}', true);
  return null;
}

/// Dòng đưa cho bộ tìm số tiền: bỏ ngày / giờ (*"20/08/2026 16:43 Thành Tiền"* của Pharmacity từng cho tổng 2026), và
/// chữ *O* dính sau chữ số là số 0 OCR đọc nhầm (*"300,24O"*, Dookki).
String _dongTien(String d) => d
    .replaceAll(_ngay, ' ')
    .replaceAll(_gio, ' ')
    .replaceAllMapped(RegExp(r'(?<=\d)[Oo](?![A-Za-z])'), (_) => '0');

/// Dòng chỉ có một số tiền (kèm đơn vị) — OCR hay để số ở dòng NGAY TRÊN nhãn tổng (*"79.243"* rồi *"Tong tien:"*).
final RegExp _chiSoTien = RegExp(r'^[\d.,\s]+(đ|d|vnd|₫)?$', caseSensitive: false);

/// Chữ OCR (mỗi dòng một dòng) → tổng tiền + tên cửa hàng + ngày + giờ.
///
/// Tổng: dòng mang nhãn tổng (ưu tiên theo [kNhanTongHoaDon], hoà thì dòng SAU thắng — tổng cuối cùng nằm dưới), lấy số
/// lớn nhất trên dòng ấy; dòng nhãn không có số thì nhìn dòng kế (OCR hay tách nhãn và số). Không có nhãn nào → số lớn
/// nhất của cả hoá đơn.
KetQuaHoaDon docHoaDonTuChu(String vanBan) {
  final dong = [for (final d in vanBan.split('\n')) if (d.trim().isNotEmpty) d.trim()];
  if (dong.isEmpty) return const KetQuaHoaDon();
  final bo = [for (final d in dong) boDauHoaDon(d)];

  int? tong;
  String? canCu;
  var hang = kNhanTongHoaDon.length;
  for (var i = 0; i < dong.length; i++) {
    if (kNhanLoaiHoaDon.any(bo[i].contains)) continue;
    final h = hangNhanTong(bo[i]);
    if (h < 0 || h > hang) continue;
    var tien = tienTrenDong(_dongTien(dong[i]));
    var nguon = dong[i];
    // Nhãn không có số: dòng TRÊN chỉ có số thắng dòng dưới (BHX, MAXIDI in số cao hơn nhãn một chút; dòng dưới là
    // dòng kế — điểm, chuyển khoản — Realme 2026-10-08).
    if (tien.isEmpty && i > 0 && _chiSoTien.hasMatch(dong[i - 1])) {
      tien = tienTrenDong(dong[i - 1]);
      nguon = '${dong[i - 1]} ⏎ ${dong[i]}';
    }
    if (tien.isEmpty && i + 1 < dong.length && !kNhanLoaiHoaDon.any(bo[i + 1].contains)) {
      tien = tienTrenDong(_dongTien(dong[i + 1]));
      nguon = '${dong[i]} ⏎ ${dong[i + 1]}';
    }
    if (tien.isEmpty) continue;
    hang = h;
    tong = tien.reduce((a, b) => a > b ? a : b);
    canCu = nguon;
  }
  if (tong == null) {
    for (var i = 0; i < dong.length; i++) {
      if (kNhanLoaiHoaDon.any(bo[i].contains)) continue;
      for (final v in tienTrenDong(_dongTien(dong[i]))) {
        if (tong == null || v > tong) {
          tong = v;
          canCu = '(không nhãn — số lớn nhất) ${dong[i]}';
        }
      }
    }
  }

  final chuNgay = [for (var i = 0; i < dong.length; i++) if (!_laDauAnh(bo[i])) dong[i]].join('\n');
  final ngay = _docNgay(chuNgay);
  return KetQuaHoaDon(
    tong: tong,
    cuaHang: _cuaHang(dong, bo),
    ngay: ngay?.$1,
    ngayDuHaiSo: ngay?.$2 ?? true,
    gio: _docGio(chuNgay),
    canCu: canCu,
  );
}

/// Chữ trên đồ vật phía sau tờ hoá đơn (nhãn laptop, dấu ảnh) — Realme 2026-10-08 lấy *"ASUS Vivobook"*, *"CORE"*,
/// *"el IRIS"* làm tên cửa hàng.
final RegExp _chuDoVat =
    RegExp(r'\b(intel|core|iris|asus|vivobook|sonicmaster|realme|lenovo|macbook|thinkpad)\b|shot on');

/// Dòng địa chỉ / liên hệ.
final RegExp _diaChi = RegExp(
    r'^(dia ch|dc\b)|\bhcm\b|ha noi|\bquan \d|\bq\. ?\d|\bphuong\b|sdt|hotline|dien thoai|website|www|\bmst\b|^\d+/\d+');

/// Dòng chỉ là TIÊU ĐỀ chứng từ (*"BIÊN LAI"*, *"HÓA ĐƠN THANH TOÁN"*).
final RegExp _tieuDe =
    RegExp(r'^\W*(hoa don( thanh toan| ban hang)?|bien lai|phieu (thanh toan|tinh tien)|receipt)\W*$');

/// Dòng bắt đầu phần thân hoá đơn — tên cửa hàng chỉ nằm TRƯỚC nó.
final RegExp _thanHoaDon =
    RegExp(r'^(sl|stt)\b|\b(so hd|so bien lai|ma hd|order number|ten mon|mat hang|hang hoa|don gia)\b');

final RegExp _tuChu = RegExp(r'\p{L}+', unicode: true);

/// Một dòng chắc KHÔNG phải tên cửa hàng: chữ trên đồ vật phía sau, địa chỉ / liên hệ, tiêu đề chứng từ.
bool _khongPhaiTenCuaHang(String dong) {
  final b = boDauHoaDon(dong);
  return _chuDoVat.hasMatch(b) || _diaChi.hasMatch(b) || _tieuDe.hasMatch(b);
}

/// Tên cửa hàng: dòng có chữ đầu tiên TRƯỚC thân hoá đơn (dòng có số tiền, mã HĐ, tiêu đề cột), bỏ chữ trên đồ vật
/// phía sau, mẩu chữ lẻ (một từ ≤ 4 chữ cái — *"tel"*, *"M"*), địa chỉ / liên hệ và tiêu đề chứng từ. Không thấy →
/// `null`: ô trống để người dùng gõ tốt hơn một tên đoán sai (MAXIDI bị cắt mất logo chỉ còn dòng địa chỉ chợ).
String? _cuaHang(List<String> dong, List<String> bo) {
  for (var i = 0; i < dong.length; i++) {
    final b = bo[i];
    if (_thanHoaDon.hasMatch(b) || tienTrenDong(_dongTien(dong[i])).isNotEmpty) return null;
    final tu = _tuChu.allMatches(dong[i]).toList();
    if (tu.isEmpty || (tu.length == 1 && tu.first.group(0)!.length <= 4)) continue;
    if (_khongPhaiTenCuaHang(dong[i])) continue;
    return dong[i];
  }
  return null;
}
