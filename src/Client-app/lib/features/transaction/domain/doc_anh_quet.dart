/// A5 mục 4–5.2 — đọc chữ OCR (đã `ghepDongTheoHang`) của một ảnh người dùng QUÉT bằng nút Quét ở Trang chủ. Hàm thuần.
///
/// App tự nhận loại ảnh (hoá đơn giấy hay biên lai chuyển khoản) rồi đọc bằng đúng luật đã có: biên lai → `docBienLai`
/// (đã đo trên ảnh thật), hoá đơn → `docHoaDonTuChu` + `docMonHang`.
///
/// ⚠️ Ở `transaction/`, không ở `ai_edge/`: trả chiều `'thu'` / `'chi'`, mà test quét 14 cấm chúng trong `ai_edge/`.
library;

import 'doc_bien_lai.dart';
import 'doc_hoa_don.dart';
import 'doc_mon_hang.dart';

export 'doc_mon_hang.dart' show MonHang;

enum LoaiAnhQuet { bienLai, hoaDon }

/// Ô luật KHÔNG đọc ra — AI (Premium) chỉ được lấp những ô này.
enum OAnhQuet { soTien, thoiGian, ghiChu }

class KetQuaAnhQuet {
  const KetQuaAnhQuet({
    required this.loai,
    required this.soTien,
    required this.chieu,
    required this.thoiGian,
    required this.ghiChu,
    required this.mon,
    required this.oThieu,
    this.aiLap = false,
  });

  final LoaiAnhQuet loai;

  /// Luôn dương; `null` = không đọc ra.
  final double? soTien;

  /// `'thu'` | `'chi'`.
  final String chieu;

  /// Ngày giờ in trên ảnh; không in thì là lúc quét (và [oThieu] chứa [OAnhQuet.thoiGian]).
  final DateTime thoiGian;

  /// Tên cửa hàng (hoá đơn) hoặc nội dung chuyển khoản (biên lai). Rỗng khi không đọc ra.
  final String ghiChu;

  /// Danh sách món — chỉ hoá đơn; biên lai luôn rỗng.
  final List<MonHang> mon;
  final Set<OAnhQuet> oThieu;

  /// Ít nhất một ô do AI lấp (dải nguồn trên form nói *"Đọc bằng AI"*).
  final bool aiLap;

  KetQuaAnhQuet copyWith({double? soTien, DateTime? thoiGian, String? ghiChu, Set<OAnhQuet>? oThieu, bool? aiLap}) =>
      KetQuaAnhQuet(
        loai: loai,
        soTien: soTien ?? this.soTien,
        chieu: chieu,
        thoiGian: thoiGian ?? this.thoiGian,
        ghiChu: ghiChu ?? this.ghiChu,
        mon: mon,
        oThieu: oThieu ?? this.oThieu,
        aiLap: aiLap ?? this.aiLap,
      );
}

final List<RegExp> _dauBienLai = [
  RegExp(r'thanh cong'),
  RegExp(r'nguoi nhan'),
  RegExp(r'tai khoan nhan'),
  RegExp(r'\bma (giao dich|gd)\b'),
  RegExp(r'noi dung'),
  RegExp(r'chuyen (khoan|tien)'),
  RegExp(r'^nhan (tien|chuyen khoan)'),
];

final List<RegExp> _dauHoaDon = [
  RegExp(r'don gia'),
  RegExp(r'so luong|\bsl\b'),
  RegExp(r'thanh tien'),
  RegExp(r'khach dua'),
  RegExp(r'tien (thoi|thua)'),
  RegExp(r'tong cong'),
  RegExp(r'tam tinh'),
  RegExp(r'\bvat\b'),
  RegExp(r'hoa don'),
];

/// Điểm = số HÀNG khớp một dấu hiệu. Hoá đơn thắng khi điểm hoá đơn LỚN HƠN điểm biên lai; hoà (kể cả 0–0) → biên lai,
/// vì luật biên lai đã đo trên ảnh thật và luật chung của nó có đường "số có đơn vị lớn nhất" cho ảnh lạ.
///
/// ⚠️ Máy POS in *"GIAO DỊCH THÀNH CÔNG"* trên hoá đơn quẹt thẻ — một điểm biên lai, nhưng hoá đơn có nhiều nhãn hơn.
LoaiAnhQuet loaiAnhQuet(List<String> hang) {
  var bl = 0, hd = 0;
  for (final h in hang) {
    final b = boDauHoaDon(h);
    if (_dauBienLai.any((r) => r.hasMatch(b))) bl++;
    if (_dauHoaDon.any((r) => r.hasMatch(b))) hd++;
  }
  return hd > bl ? LoaiAnhQuet.hoaDon : LoaiAnhQuet.bienLai;
}

/// `dd/MM/yyyy` + `HH:mm` → ngày giờ; ngày không có thật (31/02 trôi sang tháng sau) → `null`.
DateTime? _ngayGio(String? ngay, String? gio) {
  if (ngay == null) return null;
  try {
    final p = ngay.split('/');
    final g = gio?.split(':');
    final ngayThu = int.parse(p[0]), thang = int.parse(p[1]);
    final d = DateTime(int.parse(p[2]), thang, ngayThu, g == null ? 0 : int.parse(g[0]), g == null ? 0 : int.parse(g[1]));
    return d.day == ngayThu && d.month == thang ? d : null;
  } catch (_) {
    return null;
  }
}

KetQuaAnhQuet docAnhQuet({required String vanBan, required DateTime luc}) {
  try {
    final hang = [for (final d in vanBan.split('\n')) if (d.trim().isNotEmpty) d.trim()];
    if (loaiAnhQuet(hang) == LoaiAnhQuet.hoaDon) {
      final hd = docHoaDonTuChu(vanBan);
      final t = _ngayGio(hd.ngay, hd.gio);
      final ghi = hd.cuaHang ?? '';
      return KetQuaAnhQuet(
        loai: LoaiAnhQuet.hoaDon,
        soTien: hd.tong?.toDouble(),
        chieu: 'chi',
        thoiGian: t ?? luc,
        ghiChu: ghi,
        mon: docMonHang(vanBan),
        oThieu: {
          if (hd.tong == null) OAnhQuet.soTien,
          if (t == null) OAnhQuet.thoiGian,
          if (ghi.isEmpty) OAnhQuet.ghiChu,
        },
      );
    }
    final bl = docBienLai(vanBan: vanBan, nguon: null, luc: luc);
    return KetQuaAnhQuet(
      loai: LoaiAnhQuet.bienLai,
      soTien: bl.soTien,
      chieu: bl.chieu,
      thoiGian: bl.thoiGian,
      ghiChu: bl.noiDung,
      mon: const [],
      oThieu: {
        if (bl.soTien == null) OAnhQuet.soTien,
        // `docBienLai` trả đúng `luc` khi ảnh không in ngày giờ.
        if (bl.thoiGian == luc) OAnhQuet.thoiGian,
        if (bl.noiDung.isEmpty) OAnhQuet.ghiChu,
      },
    );
  } catch (_) {
    return KetQuaAnhQuet(
      loai: LoaiAnhQuet.bienLai,
      soTien: null,
      chieu: 'chi',
      thoiGian: luc,
      ghiChu: '',
      mon: const [],
      oThieu: OAnhQuet.values.toSet(),
    );
  }
}
