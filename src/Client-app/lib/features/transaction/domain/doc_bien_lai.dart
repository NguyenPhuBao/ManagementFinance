/// Chia sẻ biên lai — chữ trên ảnh biên lai → các trường của một khoản chờ ghi (spec
/// `2026-10-02-chia-se-bien-lai-design.md` mục 5). Hàm thuần, không bao giờ ném.
///
/// `vanBan` là đầu ra của `ghepDongTheoHang` (`core/ocr/dong_ocr.dart`) — mỗi HÀNG của ảnh một dòng chữ. Mẫu riêng theo
/// nguồn đi trước; không khớp thì luật chung. Luật chung luôn cho chiều `chi`: biên lai là của khoản người dùng vừa
/// chuyển; `thu` chỉ khi một mẫu riêng nhận ra biên lai nhận tiền.
///
/// ⚠️ Biên lai chỉ mang tài khoản của người NHẬN, nên [BienLaiDoc.duoiTaiKhoan] (khoá của bảng *nguồn + đuôi → ví*)
/// luôn `null` trừ khi một mẫu riêng tìm được tài khoản NGUỒN.
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../../../core/category/category_name.dart';
import '../../../core/ocr/so_tien_tren_anh.dart';
import 'doc_tin_bien_dong.dart';

/// Giá trị tham số `doc` của deeplink: đọc bằng mẫu riêng · luật chung · không đọc ra số tiền.
const String kCachDocMau = 'mau';
const String kCachDocChung = 'chung';
const String kCachDocKhong = 'khong';

class BienLaiDoc {
  /// Luôn DƯƠNG; `null` = không đọc ra.
  final double? soTien;

  /// `'chi'` | `'thu'`.
  final String chieu;

  /// Ngày giờ in trên biên lai; không có thì là lúc chia sẻ.
  final DateTime thoiGian;
  final String? maGiaoDich;

  /// Nội dung chuyển khoản — input cho gợi ý danh mục và ghi chú. Rỗng khi không có.
  final String noiDung;
  final String? duoiTaiKhoan;

  /// [kCachDocMau] | [kCachDocChung] | [kCachDocKhong].
  final String cachDoc;
  const BienLaiDoc({
    required this.soTien,
    required this.chieu,
    required this.thoiGian,
    required this.noiDung,
    required this.cachDoc,
    this.maGiaoDich,
    this.duoiTaiKhoan,
  });
}

/// Cột tiền là numeric(15,2) — dưới 13 chữ số phần nguyên (`kSoChuSoToiDaSoTien`). Lưới thứ hai: `tienTrenDong` vốn
/// đã chỉ nhận số dưới 1 tỷ.
const double _tranTien = 1e13;

final RegExp _khoangTrang = RegExp(r'\s+');
final RegExp _nhanTien = RegExp(r'\b(so tien|amount|tong tien)\b');

/// Hàng mang một con số KHÔNG phải số tiền giao dịch.
final RegExp _nhanLoai = RegExp(r'\b(phi|so du|han muc|bang chu)\b');

/// Số kèm đơn vị, xét trên chữ đã bỏ dấu viết thường (`đ` → `d`).
final RegExp _donVi = RegExp(r'\d\s?(?:₫|(?:d|vnd|dong)\b)');
final RegExp _nhanMa = RegExp(r'\b(ma giao dich|ma gd|so tham chieu|ma tham chieu|so giao dich|ma lenh)\b');
final RegExp _ma = RegExp(r'\b[A-Z0-9]{6,}\b');
final RegExp _nhanNoiDung = RegExp(r'\b(noi dung|loi nhan|dien giai)\b');
final RegExp _ngay = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b');
final RegExp _gio = RegExp(r'\b(\d{1,2}):(\d{2})(?::\d{2})?\b');
final RegExp _dauNhan = RegExp(r'^[\s:\-]+');

/// Bỏ dấu + viết thường, GIỮ độ dài (chữ đã chuẩn NFC thì mỗi ký tự có dấu về đúng một ký tự gốc) — để vị trí tìm
/// trên chuỗi bỏ dấu dùng được cho chuỗi gốc.
String _bo(String s) => removeVietnameseTones(s.toLowerCase());

BienLaiDoc docBienLai({required String vanBan, required String? nguon, required DateTime luc}) {
  try {
    final dong = [
      for (final d in unorm.nfc(vanBan).split('\n'))
        if (d.replaceAll(_khoangTrang, ' ').trim() case final s when s.isNotEmpty) s,
    ];
    final bo = [for (final d in dong) _bo(d)];
    return _theoNguon(nguon, dong, bo, luc) ?? _chung(dong, bo, luc);
  } catch (_) {
    return BienLaiDoc(soTien: null, chieu: 'chi', thoiGian: luc, noiDung: '', cachDoc: kCachDocKhong);
  }
}

/// Mẫu riêng theo nguồn. `null` = không khớp mẫu (app đổi giao diện biên lai, hoặc nguồn chưa có mẫu) → luật chung.
///
/// ⚠️ CHỈ nguồn đã ĐO trên biên lai thật (nếp *"không đoán"* của D1). MoMo và ZaloPay chưa có biên lai nào được thu
/// (2026-10-02) → đi luật chung; thêm mẫu khi có hình dạng thật. Biên lai MoMo đầu tiên (người dùng gửi 2026-10-05,
/// thanh toán cửa hàng) đọc đúng bằng bước *tiêu đề thành công* của luật chung — chưa cần mẫu riêng.
BienLaiDoc? _theoNguon(String? nguon, List<String> dong, List<String> bo, DateTime luc) => switch (nguon) {
      kNguonMb => _mb(dong, bo, luc),
      _ => null,
    };

final RegExp _mbTieuDe = RegExp(r'^chuyen \S+ thanh cong$');
final RegExp _mbTien = RegExp(r'^([\d.,]+)\s?vnd$');
final RegExp _dongTaiKhoan = RegExp(r'^\S*\d{6,}$');

/// MB Bank — biên lai *"Chuyển tiền thành công"* (đo Realme 2026-10-02, hình dạng đã che). Biên lai KHÔNG có nhãn,
/// các trường nhận theo VỊ TRÍ:
///
/// ```
/// Chuyển tiền thành công
/// 10,000 VND
/// 19:38 - 02/10/2026
/// <tên người nhận>
/// <ngân hàng nhận> …
/// <chữ liền số — TÀI KHOẢN người nhận, không phải mã giao dịch (người dùng xác nhận)>
/// <nội dung chuyển khoản>
/// Giao dịch …            ← chân biên lai
/// ```
///
/// Không có mã giao dịch → chống trùng dựa vào số tiền + giờ. Thiếu một trong ba hàng đầu là không phải mẫu này.
BienLaiDoc? _mb(List<String> dong, List<String> bo, DateTime luc) {
  final i = bo.indexWhere(_mbTieuDe.hasMatch);
  if (i < 0 || i + 2 >= dong.length) return null;
  final t = _mbTien.firstMatch(bo[i + 1]);
  // `docSoTrenAnh` chứ không `tienTrenDong`: hàng này CHẮC là số tiền, nên khoản dưới 1.000 đ và từ 1 tỷ vẫn nhận.
  final tien = t == null ? null : _hopLe(docSoTrenAnh(t.group(1)!));
  final gio = _thoiGian([dong[i + 2]]);
  if (tien == null || gio == null) return null;
  // Nội dung: hàng ngay TRÊN chân biên lai. Hàng ấy trông như số tài khoản (người dùng để trống nội dung và app
  // không tự điền) thì coi như không có nội dung — không bao giờ lấy số tài khoản làm ghi chú.
  final chan = bo.indexWhere((d) => d.startsWith('giao dich'), i + 3);
  final nd = chan > i + 3 && !_dongTaiKhoan.hasMatch(dong[chan - 1]) ? dong[chan - 1] : '';
  return BienLaiDoc(soTien: tien, chieu: 'chi', thoiGian: gio, noiDung: nd, cachDoc: kCachDocMau);
}

BienLaiDoc _chung(List<String> dong, List<String> bo, DateTime luc) {
  final tien = _tienChung(dong, bo);
  return BienLaiDoc(
    soTien: tien,
    chieu: 'chi',
    thoiGian: _thoiGian(dong) ?? luc,
    maGiaoDich: _sauNhan(dong, bo, _nhanMa, lay: (s) => _ma.firstMatch(s)?.group(0)),
    noiDung: _sauNhan(dong, bo, _nhanNoiDung, lay: (s) => s.isEmpty ? null : s) ?? '',
    cachDoc: tien == null ? kCachDocKhong : kCachDocChung,
  );
}

double? _hopLe(int? v) => (v == null || v <= 0 || v >= _tranTien) ? null : v.toDouble();

int? _lonNhat(String d) => tienTrenDong(d).fold<int?>(null, (a, b) => a == null || b > a ? b : a);

final RegExp _tieuDeThanhCong = RegExp(r'\bthanh cong\b');

/// Hàng là một CÂU HỎI — chữ quảng cáo / gợi ý của app (*"Liệu đã tới 5.000.000đ?"*), không phải trường của biên lai.
final RegExp _cauHoi = RegExp(r'\?\s*$');

/// Hàng có thể mang số tiền giao dịch khi không có nhãn: có đơn vị tiền, không phải phí / số dư, không phải câu hỏi.
bool _coTheLaTien(String dong, String bo) => _donVi.hasMatch(bo) && !_nhanLoai.hasMatch(bo) && !_cauHoi.hasMatch(dong);

double? _tienChung(List<String> dong, List<String> bo) {
  // 1) Hàng mang nhãn số tiền (không phải phí / số dư / bằng chữ): số trên hàng ấy, không có thì hàng kế.
  for (var i = 0; i < dong.length; i++) {
    if (!_nhanTien.hasMatch(bo[i]) || _nhanLoai.hasMatch(bo[i])) continue;
    final v = _lonNhat(dong[i]) ??
        (i + 1 < dong.length && !_nhanLoai.hasMatch(bo[i + 1]) ? _lonNhat(dong[i + 1]) : null);
    if (v != null) return _hopLe(v);
  }
  // 2) Không nhãn, có tiêu đề "… thành công": số có đơn vị ĐẦU TIÊN trên chính hàng ấy hoặc hai hàng kế. Biên lai ví
  //    điện tử in số tiền ngay dưới tiêu đề rồi mới tới khối quảng cáo của app — quảng cáo có thể mang số to hơn
  //    (*"Liệu đã tới 5.000.000đ?"*, ảnh người dùng gửi 2026-10-05: bản cũ điền 5.000.000 cho khoản 39.000).
  for (var i = 0; i < dong.length; i++) {
    if (!_tieuDeThanhCong.hasMatch(bo[i])) continue;
    for (var j = i; j < dong.length && j <= i + 2; j++) {
      if (!_coTheLaTien(dong[j], bo[j])) continue;
      final v = _lonNhat(dong[j]);
      if (v != null) return _hopLe(v);
    }
  }
  // 3) Không nhãn, không tiêu đề: số có đơn vị đ / ₫ / VND lớn nhất, bỏ hàng phí / số dư / câu hỏi.
  int? ra;
  for (var i = 0; i < dong.length; i++) {
    if (!_coTheLaTien(dong[i], bo[i])) continue;
    final v = _lonNhat(dong[i]);
    if (v != null && (ra == null || v > ra)) ra = v;
  }
  return _hopLe(ra);
}

/// Ngày `dd/MM/yyyy` đầu tiên hợp lệ, kèm giờ `HH:mm` trên CÙNG hàng nếu có (trước hay sau ngày đều được).
DateTime? _thoiGian(List<String> dong) {
  for (final d in dong) {
    final n = _ngay.firstMatch(d);
    if (n == null) continue;
    final ngay = int.parse(n.group(1)!), thang = int.parse(n.group(2)!), nam = int.parse(n.group(3)!);
    if (thang < 1 || thang > 12 || ngay < 1 || ngay > 31) continue;
    // Tìm giờ NGOÀI đoạn ngày.
    final g = _gio.firstMatch(d.replaceRange(n.start, n.end, ' '));
    final gio = g == null ? 0 : int.parse(g.group(1)!), phut = g == null ? 0 : int.parse(g.group(2)!);
    if (gio > 23 || phut > 59) return DateTime(nam, thang, ngay);
    return DateTime(nam, thang, ngay, gio, phut);
  }
  return null;
}

/// Phần chữ đứng sau nhãn trên cùng hàng (giữ dấu); hàng chỉ có nhãn thì lấy hàng kế. [lay] lọc / rút giá trị.
T? _sauNhan<T>(List<String> dong, List<String> bo, RegExp nhan, {required T? Function(String) lay}) {
  for (var i = 0; i < dong.length; i++) {
    final m = nhan.firstMatch(bo[i]);
    if (m == null) continue;
    // Chuỗi bỏ dấu lệch độ dài với chuỗi gốc (ký tự lạ) thì không cắt được — coi như hàng chỉ có nhãn.
    final sau = bo[i].length == dong[i].length ? dong[i].substring(m.end).replaceFirst(_dauNhan, '').trim() : '';
    final v = lay(sau) ?? (i + 1 < dong.length ? lay(dong[i + 1].trim()) : null);
    if (v != null) return v;
  }
  return null;
}
