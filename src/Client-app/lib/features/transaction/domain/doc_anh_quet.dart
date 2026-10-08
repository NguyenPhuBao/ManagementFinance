/// A5 mục 4–5.2 — đọc chữ OCR (đã `ghepDongTheoHang`) của một ảnh người dùng QUÉT bằng nút Quét ở Trang chủ. Hàm thuần.
///
/// App tự nhận loại ảnh (hoá đơn giấy hay biên lai chuyển khoản) rồi đọc bằng đúng luật đã có: biên lai → `docBienLai`
/// (đã đo trên ảnh thật), hoá đơn → `docHoaDonTuChu` + `docMonHang`.
///
/// ⚠️ Ở `transaction/`, không ở `ai_edge/`: trả chiều `'thu'` / `'chi'`, mà test quét 14 cấm chúng trong `ai_edge/`.
library;

import '../../../core/category/category_name.dart';
import '../../../core/ocr/so_tien_tren_anh.dart';
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

// ── A5 mục 5.4: AI lấp ô thiếu ─────────────────────────────────────────────────────────────────────────────────────

/// Các ô THÔ mô hình trả (tool `dien_anh_quet`) — chưa qua lưới, chỉ [lapTuAi] được dùng chúng.
class KetQuaAiAnh {
  const KetQuaAiAnh({this.soTien, this.ngay, this.noiDung});
  final int? soTien;

  /// `dd/mm/yyyy` như mô hình viết.
  final String? ngay;
  final String? noiDung;

  static KetQuaAiAnh tuThamSo(Map<String, Object?> a) {
    final st = a['so_tien'];
    String? chu(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    return KetQuaAiAnh(
      soTien: st is num && st > 0 ? st.round() : null,
      ngay: chu(a['ngay']),
      noiDung: chu(a['noi_dung']),
    );
  }
}

/// Phần chữ gửi mô hình (bẫy 4.51 — prompt dài làm hỏng chuỗi số; trần `maxTokens` là trần TỔNG). Giữ: 3 dòng đầu (tên
/// cửa hàng), dòng có chữ số, và dòng NHÃN tổng / loại đứng riêng (OCR hay tách *"Tổng thanh toán"* khỏi số ở dòng
/// kế). Trần 1.200 ký tự.
String chuGuiMoHinh(String vanBan) {
  final dong = [for (final d in vanBan.split('\n')) if (d.trim().isNotEmpty) d.trim()];
  bool nhan(String d) {
    final b = boDauHoaDon(d);
    return kNhanTongHoaDon.any(b.contains) || kNhanLoaiHoaDon.any(b.contains);
  }

  final giu = [
    for (var i = 0; i < dong.length; i++)
      if (i < 3 || RegExp(r'\d').hasMatch(dong[i]) || nhan(dong[i])) dong[i],
  ];
  final s = giu.join('\n');
  return s.length <= 1200 ? s : s.substring(0, 1200);
}

final RegExp _ngayChu = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b');

/// Lưới kiểm: luật thắng mọi ô đã điền; AI chỉ lấp ô trong [KetQuaAnhQuet.oThieu], mỗi ô một chốt —
/// số tiền phải là một số tiền CÓ trên ảnh (AI chọn, không viết); ngày phải in trên ảnh và không ở tương lai; nội dung
/// phải là chuỗi con (đã chuẩn hoá) của chữ trên ảnh.
KetQuaAnhQuet lapTuAi(KetQuaAnhQuet luat, KetQuaAiAnh ai, {required String vanBan, required DateTime now}) {
  var r = luat;
  var lap = false;
  final thieu = {...luat.oThieu};
  if (ai.soTien case final st? when thieu.contains(OAnhQuet.soTien)) {
    final coTrongChu = vanBan.split('\n').expand(tienTrenDong).any((v) => (v - st).abs() <= 0.5);
    if (coTrongChu && st < 1e13) {
      r = r.copyWith(soTien: st.toDouble());
      thieu.remove(OAnhQuet.soTien);
      lap = true;
    }
  }
  if (ai.ngay case final n? when thieu.contains(OAnhQuet.thoiGian)) {
    final m = _ngayChu.firstMatch(n);
    if (m != null) {
      final ngay = int.parse(m.group(1)!), thang = int.parse(m.group(2)!), nam = int.parse(m.group(3)!);
      final d = DateTime(nam, thang, ngay);
      final coThat = d.day == ngay && d.month == thang;
      final trongChu = _ngayChu.allMatches(vanBan).any((x) =>
          int.parse(x.group(1)!) == ngay && int.parse(x.group(2)!) == thang && int.parse(x.group(3)!) == nam);
      if (coThat && trongChu && !d.isAfter(DateTime(now.year, now.month, now.day))) {
        r = r.copyWith(thoiGian: d);
        thieu.remove(OAnhQuet.thoiGian);
        lap = true;
      }
    }
  }
  if (ai.noiDung case final nd? when thieu.contains(OAnhQuet.ghiChu)) {
    final c = normalizeCategoryName(nd);
    if (c.length >= 2 && normalizeCategoryName(vanBan).contains(c)) {
      r = r.copyWith(ghiChu: nd);
      thieu.remove(OAnhQuet.ghiChu);
      lap = true;
    }
  }
  return r.copyWith(oThieu: thieu, aiLap: lap || luat.aiLap);
}
