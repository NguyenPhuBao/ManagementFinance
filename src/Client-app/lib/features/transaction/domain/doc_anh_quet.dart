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

/// Ô luật KHÔNG đọc ra — form để trống / dùng lúc quét cho người dùng sửa.
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

  /// Số tiền đến từ mô hình nhìn ảnh, hoặc có chip chọn giữa số AI và số luật (dải nguồn trên form nói *"Đọc bằng AI"*).
  final bool aiLap;

  /// Đặt số tiền đã CHỐT (A5 mục 13, `chotTongQuet`) — kể cả `null` (hai số lệch, ô để trống cho chip chọn).
  KetQuaAnhQuet voiSoTien(double? v, {required bool aiLap}) => KetQuaAnhQuet(
        loai: loai,
        soTien: v,
        chieu: chieu,
        thoiGian: thoiGian,
        ghiChu: ghiChu,
        mon: mon,
        oThieu: {...oThieu.where((o) => o != OAnhQuet.soTien), if (v == null) OAnhQuet.soTien},
        aiLap: aiLap || this.aiLap,
      );

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
///
/// Ngày ở TƯƠNG LAI so với [luc] (nghiệm thu 2026-10-08: hoá đơn MAXIDI in *9/11/2026* khi hôm nay là 08/10 — máy POS
/// in tháng trước ngày) → thử ĐẢO ngày/tháng; đảo ra ngày có thật và không ở tương lai thì nhận (người dùng chốt), không
/// thì `null` (form dùng lúc quét).
///
/// Ngày in THIẾU số 0 (*9/2/2026* — [KetQuaHoaDon.ngayDuHaiSo] `false`): thứ tự chưa chắc, vì máy POS MAXIDI in
/// tháng/ngày (Realme 2026-10-08: *9/2/2026* là 02/09, *10/1/2026* là 01/10 — luật cũ nhận 09/02 và 10/01, sai im
/// lặng). Khi ấy chọn cách đọc GẦN lúc quét nhất mà không ở tương lai — người ta quét hoá đơn vừa mua. Ngày in đủ hai
/// chữ số (*05/03/2026*) vẫn đọc ngày/tháng trước.
DateTime? _ngayGio(String? ngay, String? gio, DateTime luc, {bool duHaiSo = true}) {
  if (ngay == null) return null;
  try {
    final p = ngay.split('/');
    final g = gio?.split(':');
    final nam = int.parse(p[2]), a = int.parse(p[0]), b = int.parse(p[1]);
    final h = g == null ? 0 : int.parse(g[0]), phut = g == null ? 0 : int.parse(g[1]);
    DateTime? dung(int ngayThu, int thang) {
      final d = DateTime(nam, thang, ngayThu, h, phut);
      return d.day == ngayThu && d.month == thang ? d : null;
    }

    final d = dung(a, b);
    final dao = dung(b, a);
    bool qua(DateTime? x) => x != null && !x.isAfter(luc);
    if (!duHaiSo && qua(d) && qua(dao)) return d!.isAfter(dao!) ? d : dao;
    if (qua(d)) return d;
    return qua(dao) ? dao : null;
  } catch (_) {
    return null;
  }
}

KetQuaAnhQuet docAnhQuet({required String vanBan, required DateTime luc}) {
  try {
    final hang = [for (final d in vanBan.split('\n')) if (d.trim().isNotEmpty) d.trim()];
    if (loaiAnhQuet(hang) == LoaiAnhQuet.hoaDon) {
      final hd = docHoaDonTuChu(vanBan);
      final t = _ngayGio(hd.ngay, hd.gio, luc, duHaiSo: hd.ngayDuHaiSo);
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
