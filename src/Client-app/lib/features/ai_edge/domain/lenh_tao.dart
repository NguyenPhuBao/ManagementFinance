/// C3 — lệnh "tạo hoá đơn / mục tiêu / ngân sách" ở màn Trợ lý AI (spec
/// `2026-09-28-c3-lenh-tao-hoa-don-muc-tieu-ngan-sach-design.md`). **Chỉ luật**,
/// không mô hình: màn chat gọi nó TRƯỚC mọi thứ khác, câu là lệnh thì trả một thẻ
/// mở form điền sẵn — người dùng bấm Lưu (bất biến ④ nhóm C).
///
/// Đặt ở `ai_edge/domain` cạnh `congCuTheoCauHoi` vì nó là định tuyến câu của trợ
/// lý. ⚠️ Nhận nhầm một câu hỏi thành lệnh là câu hỏi ấy mất câu trả lời — lưới
/// là 72 câu cổng F (`lenh_tao_test.dart`).
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../../../core/bill/bill_recurrence.dart';
import '../../../core/category/category_name.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/khop_ten.dart';
import '../../../core/utils/ngay_trong_cau.dart';
import '../../transaction/domain/doc_cau_giao_dich.dart' show cachDocSoTien, cauNhacViTheoTen, chonSoTienTrongCau;

enum LoaiLenhTao { hoaDon, mucTieu, nganSach }

/// Tiền tố lịch sự bỏ trước khi xét động từ — có thể chồng nhau (*"làm ơn giúp mình tạo…"*).
const List<List<String>> _tienTo = [
  ['hay'],
  ['giup', 'toi'],
  ['giup', 'minh'],
  ['cho', 'toi'],
  ['cho', 'minh'],
  ['lam', 'on'],
  ['vui', 'long'],
];

const Set<String> _dongTu = {'tao', 'them', 'dat', 'lap'};

/// Chữ được đứng giữa động từ và danh từ (≤ 2): *"tạo một / tạo mới hoá đơn"*. Danh sách TRẮNG — cho mọi chữ là nhận
/// *"đặt lịch nhắc hoá đơn"* thành lệnh tạo hoá đơn.
const Set<String> _chuDem = {'mot', 'moi', 'cai', '1'};

const List<(List<String>, LoaiLenhTao)> _danhTu = [
  (['hoa', 'don'], LoaiLenhTao.hoaDon),
  (['muc', 'tieu'], LoaiLenhTao.mucTieu),
  (['ngan', 'sach'], LoaiLenhTao.nganSach),
];

/// Có một trong các cụm này ở đâu đó trong câu → câu HỎI, không phải lệnh.
const List<List<String>> _tuHoi = [
  ['bao', 'nhieu'],
  ['nao'],
  ['nen'],
  ['khong'],
  ['la', 'gi'],
  ['o', 'dau'],
  ['sao'],
];

/// Âm tiết bỏ dấu, chữ thường, bỏ mọi ký tự không phải chữ / số.
List<String> amTietKhongDau(String cau) => removeVietnameseTones(cau.toLowerCase())
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.isNotEmpty)
    .toList();

bool _batDauBang(List<String> t, int i, List<String> cum) {
  if (i + cum.length > t.length) return false;
  for (var k = 0; k < cum.length; k++) {
    if (t[i + k] != cum[k]) return false;
  }
  return true;
}

bool _coCum(List<String> t, List<String> cum) {
  for (var i = 0; i < t.length; i++) {
    if (_batDauBang(t, i, cum)) return true;
  }
  return false;
}

/// Kết quả nhận: loại lệnh và vị trí (chỉ số âm tiết) ngay SAU danh từ — nơi phần nội dung bắt đầu.
({LoaiLenhTao loai, int sauDanhTu})? _nhan(String cau) {
  if (cau.contains('?')) return null;
  final t = amTietKhongDau(cau);
  if (_tuHoi.any((c) => _coCum(t, c))) return null;
  var i = 0;
  for (var doi = true; doi;) {
    doi = false;
    for (final p in _tienTo) {
      if (_batDauBang(t, i, p)) {
        i += p.length;
        doi = true;
      }
    }
  }
  if (i >= t.length || !_dongTu.contains(t[i])) return null;
  i++;
  for (var dem = 0; dem <= 2; dem++) {
    for (final (cum, loai) in _danhTu) {
      if (_batDauBang(t, i, cum)) return (loai: loai, sauDanhTu: i + cum.length);
    }
    if (i >= t.length || !_chuDem.contains(t[i])) return null;
    i++;
  }
  return null;
}

/// Loại lệnh tạo của [cau], hoặc `null` khi đó không phải lệnh (câu hỏi, câu khác).
LoaiLenhTao? loaiLenhTao(String cau) => _nhan(cau)?.loai;

/// Đối tượng tạo được — cụm âm tiết bỏ dấu (§8.1). ⚠️ Không có `quy` trần: *"quý này"* của câu hỏi cổng F cũng ra
/// `quy`; *quỹ* chỉ nhận trong cụm dài.
const List<List<String>> _doiTuongTao = [
  ['hoa', 'don'],
  ['muc', 'tieu'],
  ['ngan', 'sach'],
  ['de', 'danh'],
  ['tiet', 'kiem'],
  ['danh', 'dum'],
  ['quy', 'khan', 'cap'],
  ['han', 'muc'],
  ['gioi', 'han'],
  ['dinh', 'ky'],
  ['hang', 'tuan'],
  ['hang', 'thang'],
  ['hang', 'quy'],
  ['hang', 'nam'],
  ['moi', 'tuan'],
  ['moi', 'thang'],
  ['moi', 'quy'],
  ['moi', 'nam'],
  ['mot', 'thang'],
];

/// Tín hiệu muốn tạo — một âm tiết ở bất cứ đâu, hoặc cụm *lên kế hoạch*.
const Set<String> _tinHieuTao = {'tao', 'them', 'dat', 'lap', 'muon', 'nhac'};

/// Cổng RỘNG (§8.1): câu có vẻ muốn tạo hoá đơn / mục tiêu / ngân sách → mở phiên AI riêng. `true` ⇔ câu theo mẫu §2,
/// hoặc (không từ hỏi ∧ nhắc đối tượng tạo được ∧ (có tín hiệu muốn tạo ∨ có số tiền đọc được)). Câu lọt cổng mà mô
/// hình không gọi tool → về vòng hỏi đáp như cũ: giá của cổng rộng là một lượt chờ thừa, không phải câu trả lời sai.
bool coVeLenhTao(String cau, {required DateTime now}) {
  if (loaiLenhTao(cau) != null) return true;
  if (cau.contains('?')) return false;
  final t = amTietKhongDau(cau);
  if (_tuHoi.any((c) => _coCum(t, c))) return false;
  if (!_doiTuongTao.any((c) => _coCum(t, c))) return false;
  return t.any(_tinHieuTao.contains) ||
      _coCum(t, const ['len', 'ke', 'hoach']) ||
      cachDocSoTien(cau, now: now).isNotEmpty;
}

/// Một đối tượng chọn được (ví / danh mục) — record thay kiểu Drift để lớp AI không đụng bảng.
typedef MucChon = ({String id, String ten});

/// Ví HOẠT ĐỘNG và danh mục CHI chọn được — màn chat nạp một lần rồi truyền vào [lenhTaoTheoCauHoi].
typedef NguonLenhTao = ({List<MucChon> vi, List<MucChon> danhMucChi});

/// Ai điền ô: `ai` khi ít nhất một ô do mô hình lấp (§8.3) — thẻ ghi dòng nguồn đúng thứ đã xảy ra.
enum NguonLenh { luat, ai }

const String kTenCongCuTaoHoaDon = 'tao_hoa_don';
const String kTenCongCuTaoMucTieu = 'tao_muc_tieu';
const String kTenCongCuDatNganSach = 'dat_ngan_sach';
const Set<String> kTenCongCuLenhTao = {kTenCongCuTaoHoaDon, kTenCongCuTaoMucTieu, kTenCongCuDatNganSach};

/// Kết quả THÔ của phiên AI lệnh tạo (§8.2) — chưa qua lưới kiểm [lenhTaoTuAi], không bao giờ dùng thẳng.
class KetQuaLenhAi {
  const KetQuaLenhAi({
    required this.loai,
    this.ten,
    this.soTien,
    this.chuKy,
    this.ngayGoc,
    this.vi,
    this.danhMuc,
    this.han,
  });

  final LoaiLenhTao loai;
  final String? ten;
  final double? soTien;
  final String? chuKy;
  final int? ngayGoc;
  final String? vi;
  final String? danhMuc;
  final String? han;

  /// Từ lời gọi tool. Lỏng tay với kiểu (số có thể đến dạng chuỗi); rỗng / 0 → `null`; tên tool lạ → `null`.
  static KetQuaLenhAi? tuLoiGoi(String tenTool, Map<String, dynamic> a) {
    final loai = switch (tenTool) {
      kTenCongCuTaoHoaDon => LoaiLenhTao.hoaDon,
      kTenCongCuTaoMucTieu => LoaiLenhTao.mucTieu,
      kTenCongCuDatNganSach => LoaiLenhTao.nganSach,
      _ => null,
    };
    if (loai == null) return null;
    String? chuoi(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    double? so(Object? v) => switch (v) {
          final num n => n <= 0 ? null : n.toDouble(),
          final String t => switch (double.tryParse(t.replaceAll(RegExp(r'[^\d.]'), ''))) {
              final d? when d > 0 => d,
              _ => null,
            },
          _ => null,
        };
    return KetQuaLenhAi(
      loai: loai,
      ten: chuoi(a['ten']),
      soTien: so(a['so_tien']) ?? so(a['so_tien_dich']) ?? so(a['han_muc']),
      chuKy: chuoi(a['chu_ky']),
      ngayGoc: so(a['ngay_goc'])?.round(),
      vi: chuoi(a['vi']),
      danhMuc: chuoi(a['danh_muc']),
      han: chuoi(a['han']),
    );
  }
}

/// Lệnh đã đọc ô. Trường `null` = không đọc được — form để trống ô ấy. [query] chỉ mang khoá có giá trị; [duongDan] là
/// route form điền sẵn. ⚠️ Tầng 4: không lớp nào mang tham số bật tự trả / trích tự động.
sealed class LenhTao {
  const LenhTao({this.nguon = NguonLenh.luat});

  /// `ai` khi ít nhất một ô do mô hình lấp qua lưới kiểm [lenhTaoTuAi]; bộ luật luôn cho `luat`.
  final NguonLenh nguon;

  String get _route;
  Map<String, String> get query;

  String get duongDan => Uri(path: _route, queryParameters: query.isEmpty ? null : query).toString();
}

class LenhTaoHoaDon extends LenhTao {
  const LenhTaoHoaDon({
    this.ten,
    this.soTien,
    this.chuKy = kBillCycleMonth,
    this.ngayGoc,
    this.batDau,
    this.idVi,
    this.idDanhMuc,
    this.tenVi,
    this.tenDanhMuc,
    this.nhacTuTra = false,
    super.nguon,
  });

  final String? ten;
  final double? soTien;

  /// Một trong `kBillCycle*` — câu không nêu thì tháng.
  final String chuKy;
  final int? ngayGoc;

  /// Ngày BẮT ĐẦU hoá đơn — [ngayBatDauHoaDon] của [ngayGoc]. `null` khi câu không nêu ngày: form lấy hôm nay.
  final DateTime? batDau;
  final String? idVi;
  final String? idDanhMuc;

  /// Tên để THẺ in ra (query chỉ mang id). Ví / danh mục điền sẵn — nhất là danh mục mô hình ĐOÁN — phải thấy được
  /// trước khi mở form: không thì thẻ ghi "Đọc bằng AI" mà không cho thấy AI đã điền gì.
  final String? tenVi;
  final String? tenDanhMuc;

  /// Câu nhắc tự trả / trích tự động — CHỈ để thẻ nói "bật trong form" (tầng 4, AI không bật).
  final bool nhacTuTra;

  @override
  String get _route => '/bills/add';

  /// Khoá của B2 (`dienSanTuQuery`). `start` chỉ có khi câu nêu ngày (người dùng chốt 2026-10-01 — bản đầu spec C3
  /// §4 không gửi `start`, form luôn bắt đầu hôm nay); `anchor` vẫn đi kèm vì ngày bắt đầu có thể đã bị kẹp về cuối
  /// tháng ngắn trong khi chuỗi kỳ sau phải neo đúng ngày người dùng nói.
  @override
  Map<String, String> get query => {
        if (ten != null) 'name': ten!,
        if (soTien != null) 'amount': soTien!.round().toString(),
        'cycle': chuKy,
        if (ngayGoc != null) 'anchor': '$ngayGoc',
        if (batDau != null) 'start': _iso(batDau!),
        if (idDanhMuc != null) 'category': idDanhMuc!,
        if (idVi != null) 'wallet': idVi!,
      };
}

class LenhTaoMucTieu extends LenhTao {
  const LenhTaoMucTieu({this.ten, this.soTienDich, this.han, super.nguon});

  final String? ten;
  final double? soTienDich;
  final DateTime? han;

  @override
  String get _route => '/goals/add';

  @override
  Map<String, String> get query => {
        if (ten != null) 'name': ten!,
        if (soTienDich != null) 'target': soTienDich!.round().toString(),
        if (han != null) 'deadline': _iso(han!),
      };
}

class LenhTaoNganSach extends LenhTao {
  const LenhTaoNganSach({this.idDanhMuc, this.tenDanhMuc, this.hanMuc, super.nguon});

  /// `null` = không khớp danh mục chi nào — thẻ nói "Chưa rõ danh mục".
  final String? idDanhMuc;
  final String? tenDanhMuc;
  final double? hanMuc;

  @override
  String get _route => '/budget/rules';

  /// `/budget/rules` không nhận chu kỳ (soát 2026-09-30) — chỉ danh mục + hạn mức.
  @override
  Map<String, String> get query => {
        if (idDanhMuc != null) 'category': idDanhMuc!,
        if (hanMuc != null) 'amount': hanMuc!.round().toString(),
      };
}

String _hai(int n) => n.toString().padLeft(2, '0');
String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_hai(d.month)}-${_hai(d.day)}';

final RegExp _mauDanhTu = RegExp(r'(?<![a-z0-9])(hoa don|muc tieu|ngan sach)(?![a-z0-9])');
final RegExp _mauHoaDon = RegExp(r'(?<![a-z0-9])hoa don(?![a-z0-9])');
final RegExp _mauChuKy =RegExp(r'(?<![a-z0-9])(?:hang|moi)\s+(tuan|thang|quy|nam)(?![a-z0-9])');
final RegExp _mauNgayGoc = RegExp(r'(?<![a-z0-9])(?:ngay|mung)\s+(\d{1,2})(?![\d/])');
final RegExp _mauTuTra = RegExp(r'(?<![a-z0-9])(?:tu\s+tra|tu\s+dong|trich\s+tu\s+dong)(?![a-z0-9])');
final RegExp _mauMoHan = RegExp(r'(?<![a-z0-9])(?:truoc|den|trong)(?![a-z0-9])');
final RegExp _mauHanNgay = RegExp(r'(?<![a-z0-9])(?:truoc|den)\s+(?:ngay\s+)?(\d{1,2})/(\d{1,2})/(\d{4})(?![\d/])');
final RegExp _mauHanThang =
    RegExp(r'(?<![a-z0-9])(?:truoc|den)\s+thang\s+(\d{1,2})(?:\s+nam\s+(\d{4}|sau))?(?![a-z0-9])');
final RegExp _mauTrongThang = RegExp(r'(?<![a-z0-9])trong\s+(\d{1,3})\s+thang(?![a-z0-9])');

const Map<String, String> _chuKyTheoChu = {
  'tuan': kBillCycleWeek,
  'thang': kBillCycleMonth,
  'quy': kBillCycleQuarter,
  'nam': kBillCycleYear,
};

DateTime _cuoiThang(int y, int m) => DateTime(y, m + 1, 0);

/// Cộng [n] tháng, kẹp ngày vào cuối tháng đích (31/1 + 1 → 28 hoặc 29/2).
DateTime _congThang(DateTime d, int n) {
  final cuoi = _cuoiThang(d.year, d.month + n);
  return DateTime(cuoi.year, cuoi.month, d.day > cuoi.day ? cuoi.day : d.day);
}

/// Ngày BẮT ĐẦU hoá đơn khi câu nêu *"ngày N"* — người dùng chốt 2026-10-01: *"khi nhắc tới ngày thì ngày đó là ngày
/// bắt đầu hoá đơn"*, và là ngày N **sắp tới**: chưa qua trong tháng này (kể cả trùng hôm nay) → tháng này; đã qua →
/// tháng sau. Tháng không có ngày N (31 ở tháng 30 ngày, 30 ở tháng 2) thì kẹp về ngày cuối tháng — ngày gốc
/// (`anchor`) vẫn là N. `null` khi [n] ngoài 1–31.
DateTime? ngayBatDauHoaDon(int? n, DateTime now) {
  if (n == null || n < 1 || n > 31) return null;
  final homNay = DateTime(now.year, now.month, now.day);
  DateTime trong(int y, int m) {
    final cuoi = _cuoiThang(y, m).day;
    return DateTime(y, m, n > cuoi ? cuoi : n);
  }

  final thangNay = trong(homNay.year, homNay.month);
  return thangNay.isBefore(homNay) ? trong(homNay.year, homNay.month + 1) : thangNay;
}

DateTime? _hanMucTieu(String b, DateTime now) {
  final homNay = DateTime(now.year, now.month, now.day);
  final ngay = _mauHanNgay.firstMatch(b);
  if (ngay != null) {
    return ngayHopLe(int.parse(ngay.group(3)!), int.parse(ngay.group(2)!), int.parse(ngay.group(1)!));
  }
  final thang = _mauHanThang.firstMatch(b);
  if (thang != null) {
    final m = int.parse(thang.group(1)!);
    if (m < 1 || m > 12) return null;
    final nam = thang.group(2);
    final y = nam == null
        ? (m < homNay.month ? homNay.year + 1 : homNay.year)
        : nam == 'sau'
            ? homNay.year + 1
            : int.parse(nam);
    return _cuoiThang(y, m);
  }
  final trong = _mauTrongThang.firstMatch(b);
  if (trong != null) {
    final n = int.parse(trong.group(1)!);
    return n < 1 ? null : _congThang(homNay, n);
  }
  return null;
}

/// Tên = đoạn sau danh từ tới trước dấu hiệu đầu tiên (số tiền, chu kỳ, ngày gốc, hạn, tự trả, ví / danh mục nêu).
String? _tenSau(String s, int tu, List<int> dau) {
  var het = s.length;
  for (final d in dau) {
    if (d >= tu && d < het) het = d;
  }
  final ten = s.substring(tu, het).replaceAll(RegExp(r'^[\s:,.\-–]+|[\s:,.\-–]+$'), '').trim();
  return ten.isEmpty ? null : ten;
}

int? _viTri(RegExp mau, String b, int tu) {
  for (final m in mau.allMatches(b)) {
    if (m.start >= tu) return m.start;
  }
  return null;
}

String? _idCua(List<MucChon> ds, String? ten) {
  if (ten == null) return null;
  for (final x in ds) {
    if (x.ten == ten) return x.id;
  }
  return null;
}

/// Lệnh tạo của [cau] đã đọc ô, hoặc `null` khi không phải lệnh. [vi]: ví HOẠT ĐỘNG; [danhMucChi]: danh mục chi chọn
/// được — bên gọi lọc sẵn (lớp AI không so chiều tiền, test quét 14).
LenhTao? lenhTaoTheoCauHoi(
  String cau, {
  required DateTime now,
  required List<MucChon> vi,
  required List<MucChon> danhMucChi,
}) {
  final nhan = _nhan(cau);
  if (nhan == null) return null;
  final s = unorm.nfc(cau);
  final b = removeVietnameseTones(s.toLowerCase());
  // Bỏ dấu lệch độ dài (ký tự lạ) thì vị trí không tin được: vẫn là lệnh, chỉ không đọc ô.
  if (b.length != s.length) return _rong(nhan.loai);
  return _docTheoLuat(nhan.loai, s, b, theoMau: true, now: now, vi: vi, danhMucChi: danhMucChi);
}

LenhTao _rong(LoaiLenhTao loai) => switch (loai) {
      LoaiLenhTao.hoaDon => const LenhTaoHoaDon(),
      LoaiLenhTao.mucTieu => const LenhTaoMucTieu(),
      LoaiLenhTao.nganSach => const LenhTaoNganSach(),
    };

/// Đọc ô bằng luật cho một [loai] đã biết; [s] là câu NFC, [b] là bản bỏ dấu chữ thường CÙNG độ dài. [theoMau] = câu
/// theo mẫu §2 (động từ + danh từ ở đầu): chỉ khi ấy mới cắt TÊN từ đoạn sau danh từ — ở câu tự nhiên đoạn ấy không
/// phải tên (mô hình đọc, [lenhTaoTuAi] kiểm).
LenhTao _docTheoLuat(
  LoaiLenhTao loai,
  String s,
  String b, {
  required bool theoMau,
  required DateTime now,
  required List<MucChon> vi,
  required List<MucChon> danhMucChi,
}) {
  final tu = theoMau ? (_mauDanhTu.firstMatch(b)?.end ?? 0) : 0;
  final tien = chonSoTienTrongCau(s, now: now);
  final soTien = tien != null && tien.batDau >= tu ? tien.giaTri : null;

  switch (loai) {
    case LoaiLenhTao.hoaDon:
      final viNeu = timTenTrongCau(s, [for (final v in vi) v.ten], tuLoai: 'ví');
      // ⚠️ Chữ "hoá đơn" ĐẦU TIÊN là đối tượng của lệnh, không phải danh mục: bộ mặc định có mục tên "Hóa đơn", nên
      // không che nó đi thì MỌI lệnh tạo hoá đơn tự nhận danh mục ấy — và, vì luật thắng, che luôn danh mục mô hình
      // đoán (đo Realme 2026-10-01: "gym" → AI "Giải trí", form vẫn ra "Hóa đơn"). Che bằng khoảng trắng CÙNG độ dài
      // để vị trí không lệch; lần xuất hiện thứ hai (*"… danh mục hoá đơn"*) vẫn được nhận.
      final doiTuong = _mauHoaDon.firstMatch(b);
      final sDm = doiTuong == null ? s : s.replaceRange(doiTuong.start, doiTuong.end, ' ' * (doiTuong.end - doiTuong.start));
      final dmNeu = timTenTrongCau(sDm, [for (final d in danhMucChi) d.ten], tuLoai: 'danh mục');
      final chuKy = _mauChuKy.firstMatch(b);
      final ngayGoc = _mauNgayGoc.firstMatch(b);
      final ng = ngayGoc == null ? null : int.parse(ngayGoc.group(1)!);
      final tuTraO = _viTri(_mauTuTra, b, tu);
      final nhanO = _viTri(RegExp(r'(?<![a-z0-9])(?:vi|danh muc)(?![a-z0-9])'), b, tu);
      return LenhTaoHoaDon(
        ten: !theoMau
            ? null
            : _tenSau(s, tu, [
                if (soTien != null) tien!.batDau,
                if (chuKy != null) chuKy.start,
                if (ngayGoc != null) ngayGoc.start,
                if (tuTraO != null) tuTraO,
                if (nhanO != null) nhanO,
                if (viNeu != null) viNeu.batDau,
                if (dmNeu != null) dmNeu.batDau,
              ]),
        soTien: soTien,
        chuKy: chuKy == null ? kBillCycleMonth : _chuKyTheoChu[chuKy.group(1)]!,
        ngayGoc: ng != null && ng >= 1 && ng <= 31 ? ng : null,
        batDau: ngayBatDauHoaDon(ng, now),
        idVi: _idCua(vi, viNeu?.ten),
        idDanhMuc: _idCua(danhMucChi, dmNeu?.ten),
        tenVi: viNeu?.ten,
        tenDanhMuc: dmNeu?.ten,
        nhacTuTra: _mauTuTra.hasMatch(b),
      );
    case LoaiLenhTao.mucTieu:
      final hanO = _viTri(_mauMoHan, b, tu);
      return LenhTaoMucTieu(
        ten: !theoMau
            ? null
            : _tenSau(s, tu, [
                if (soTien != null) tien!.batDau,
                if (hanO != null) hanO,
              ]),
        soTienDich: tien != null && _tienTheoKy(b, tien) ? null : soTien,
        han: _hanMucTieu(b, now),
      );
    case LoaiLenhTao.nganSach:
      final dmNeu = timTenTrongCau(s, [for (final d in danhMucChi) d.ten], tuLoai: 'danh mục');
      return LenhTaoNganSach(
        idDanhMuc: _idCua(danhMucChi, dmNeu?.ten),
        tenDanhMuc: dmNeu?.ten,
        hanMuc: soTien,
      );
  }
}

final RegExp _mauHanAi = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
final RegExp _tachTu = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// Chữ chỉ thời gian — hai bộ. ⚠️ Câu CÓ DẤU thì so chữ có dấu: bỏ dấu là *"tôi"* thành *toi* = *tới*, *"cưới"* thành
/// *cuoi* = *cuối* — mọi câu có chủ ngữ thành "câu nói thời gian" và hạn mô hình bịa lọt lưới. Bộ không dấu (cho người
/// gõ không dấu) vì thế KHÔNG có `toi`.
const Set<String> _tuThoiGianCoDau = {
  'tuần', 'tháng', 'quý', 'năm', 'tết', 'hè', 'cuối', 'đầu', 'trước', 'đến', 'tới', 'trong', 'ngày', //
};
const Set<String> _tuThoiGianKhongDau = {
  'tuan', 'thang', 'quy', 'nam', 'tet', 'he', 'cuoi', 'dau', 'truoc', 'den', 'trong', 'ngay', //
};

bool _cauNoiThoiGian(String s) {
  final thuong = s.toLowerCase();
  if (thuong.contains('/')) return true;
  final tu = thuong.split(_tachTu);
  return thuong != removeVietnameseTones(thuong)
      ? tu.any(_tuThoiGianCoDau.contains)
      : tu.any(_tuThoiGianKhongDau.contains);
}

/// Tên của AI hợp lệ ⇔ không chứa chữ số, và MỌI chữ của nó có trong câu ĐÚNG THỨ TỰ (so âm tiết bỏ dấu; không cần
/// liền nhau — đo Realme: *"tiết kiệm 2 triệu mỗi tháng cho chuyến du lịch"* → mô hình đặt tên *"tiết kiệm du lịch"*,
/// gom từ chính câu). Thêm một chữ câu không có (*"mua xe hơi"*) hay đảo thứ tự là tên mô hình tự nghĩ → bỏ.
String? _tenAiHopLe(String? ten, String cau) {
  if (ten == null || RegExp(r'\d').hasMatch(ten)) return null;
  final chu = amTietKhongDau(ten);
  if (chu.isEmpty) return null;
  final cuaCau = amTietKhongDau(cau);
  var i = 0;
  for (final c in chu) {
    while (i < cuaCau.length && cuaCau[i] != c) {
      i++;
    }
    if (i == cuaCau.length) return null;
    i++;
  }
  // Gọt chữ chu kỳ (*"tiền điện hàng tháng"* → *"tiền điện"*): chu kỳ đã có ô riêng, để nguyên là thẻ in hai lần.
  final gon = ten.replaceAll(_mauChuKyTrongTen, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return gon.isEmpty ? null : gon;
}

final RegExp _mauChuKyTrongTen = RegExp(
  r'(?<![\p{L}\p{N}])(?:hằng|hàng|mỗi|hang|moi)\s+(?:tuần|tháng|quý|năm|tuan|thang|quy|nam)(?![\p{L}\p{N}])',
  unicode: true,
  caseSensitive: false,
);

/// Câu tự nhiên có dấu hiệu NGÂN SÁCH — *hạn mức · giới hạn · tối đa* — thì loại là ngân sách, dù mô hình gọi tool
/// nào (đo Realme 2026-10-01: *"ăn uống tối đa 3 triệu một tháng"* → mô hình gọi `tao_hoa_don`). ⚠️ *"tối đa"* bỏ dấu
/// là `toi da` = *"tôi đã"*: câu CÓ DẤU thì so chữ có dấu; câu gõ không dấu thì chỉ nhận khi ngay sau là một con số.
bool _coDauHieuNganSach(String s) {
  final thuong = s.toLowerCase();
  final t = amTietKhongDau(thuong);
  if (_coCum(t, const ['han', 'muc']) || _coCum(t, const ['gioi', 'han'])) return true;
  if (thuong != removeVietnameseTones(thuong)) {
    return RegExp(r'(?<![\p{L}\p{N}])tối\s+đa(?![\p{L}\p{N}])', unicode: true).hasMatch(thuong);
  }
  for (var i = 0; i + 2 < t.length; i++) {
    if (t[i] == 'toi' && t[i + 1] == 'da' && RegExp(r'^\d').hasMatch(t[i + 2])) return true;
  }
  return false;
}

/// Loại mà chính CÂU nói ra (câu tự nhiên — câu theo mẫu §2 đã có loại của mẫu), `null` khi câu không có dấu hiệu nào
/// và loại theo tool mô hình gọi. Dấu hiệu ngân sách xét TRƯỚC (*"hạn mức tiết kiệm 2 triệu"*). Dấu hiệu tiết kiệm —
/// *tiết kiệm · để dành · dành dụm* — sinh ra từ lượt đo Realme 2026-10-01: *"tiết kiệm 2 triệu mỗi tháng cho chuyến du
/// lịch"* → mô hình gọi `dat_ngan_sach {danh_muc: Di chuyển}`.
LoaiLenhTao? _loaiTheoDauHieu(String s) {
  if (_coDauHieuNganSach(s)) return LoaiLenhTao.nganSach;
  final t = amTietKhongDau(s);
  const tietKiem = [
    ['tiet', 'kiem'],
    ['de', 'danh'],
    ['danh', 'dum'],
  ];
  return tietKiem.any((c) => _coCum(t, c)) ? LoaiLenhTao.mucTieu : null;
}

final RegExp _mauTheoKySau =RegExp(r'^\s*(?:/\s*|(?:moi|hang|mot)\s+)(?:tuan|thang|quy|nam)(?![a-z0-9])');
final RegExp _mauTheoKyTruoc = RegExp(r'(?<![a-z0-9])(?:moi|hang)\s+(?:tuan|thang|quy|nam)\s+(?:[a-z]+\s+){0,3}$');

/// Số tiền [tien] là mức góp THEO KỲ (*"2 triệu mỗi tháng"*, *"mỗi tháng để dành 2 triệu"*, *"500k/tháng"*), không phải
/// số tiền đích của mục tiêu. Form mục tiêu không có ô "mỗi kỳ" điền được qua lệnh (trích tự động là tầng 4), nên con
/// số ấy bị bỏ — thẻ nói "Chưa rõ số tiền" thay vì điền sai nghĩa. *"trong 12 tháng"* là hạn, không khớp.
bool _tienTheoKy(String b, ({int batDau, int ketThuc, double giaTri}) tien) =>
    _mauTheoKySau.hasMatch(b.substring(tien.ketThuc)) || _mauTheoKyTruoc.hasMatch(b.substring(0, tien.batDau));

/// Số của AI hợp lệ ⇔ là một cách đọc được từ chính câu (cùng phép C2).
double? _soAiHopLe(double? so, String cau, DateTime now) {
  if (so == null || so >= 1e13) return null;
  return cachDocSoTien(cau, now: now).any((v) => (v - so).abs() <= 0.5) ? so.roundToDouble() : null;
}

/// Hạn của AI hợp lệ ⇔ dd/mm/yyyy có thật, SAU hôm nay, ≤ 50 năm, và câu có nói tới thời gian (AI không được bịa hạn
/// cho câu không nhắc thời điểm nào).
DateTime? _hanAiHopLe(String? chu, String s, DateTime now) {
  final m = _mauHanAi.firstMatch(chu?.trim() ?? '');
  if (m == null || !_cauNoiThoiGian(s)) return null;
  final x = ngayHopLe(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
  if (x == null) return null;
  final homNay = DateTime(now.year, now.month, now.day);
  if (!x.isAfter(homNay) || x.isAfter(DateTime(now.year + 50, now.month, now.day))) return null;
  return x;
}

/// Ngày gốc của AI hợp lệ ⇔ 1–31 và chữ số ấy đứng riêng trong câu, NGOÀI đoạn số tiền [tien] (số 5 của *"5 triệu"*
/// không phải ngày).
int? _ngayGocAiHopLe(int? n, String b, ({int batDau, int ketThuc, double giaTri})? tien) {
  if (n == null || n < 1 || n > 31) return null;
  final ngoaiTien = tien == null ? b : b.replaceRange(tien.batDau, tien.ketThuc, ' ' * (tien.ketThuc - tien.batDau));
  return RegExp('(?<![0-9])0?$n(?![0-9])').hasMatch(ngoaiTien) ? n : null;
}

MucChon? _mucTheoTenChuan(List<MucChon> ds, String? ten) {
  if (ten == null) return null;
  final k = normalizeCategoryName(ten);
  final khop = [
    for (final x in ds)
      if (normalizeCategoryName(x.ten) == k) x,
  ];
  return khop.length == 1 ? khop.single : null;
}

/// Ví của AI hợp lệ ⇔ khớp đúng một ví VÀ câu nhắc ví ấy (chữ *ví* trần, hoặc viết tắt tên ví — cùng phép C2
/// `cauNhacViTheoTen`). ⚠️ Mô hình hay tự điền ví mặc định cho câu không nói tới ví nào (C2 đo Realme: 9/10 câu); ví
/// điền sẵn sai là ô người dùng dễ bỏ sót nhất trên form hoá đơn.
MucChon? _viAiHopLe(List<MucChon> vi, String? ten, String s) {
  final m = _mucTheoTenChuan(vi, ten);
  return m != null && cauNhacViTheoTen(s.toLowerCase(), m.ten) ? m : null;
}

/// Lưới kiểm (§8.3) — kết quả mô hình KHÔNG BAO GIỜ dùng thẳng. Luật đọc trước trên chính câu; AI chỉ LẤP ô luật để
/// trống, mỗi ô qua một chốt. Loại: câu theo mẫu §2 → loại của luật (AI không đổi được); không thì theo tool AI gọi.
/// Tầng 4 (`nhacTuTra`) chỉ luật quyết.
LenhTao lenhTaoTuAi(
  String cau,
  KetQuaLenhAi ai, {
  required DateTime now,
  required List<MucChon> vi,
  required List<MucChon> danhMucChi,
}) {
  final nhan = _nhan(cau);
  final s = unorm.nfc(cau);
  final loai = nhan?.loai ?? _loaiTheoDauHieu(s) ?? ai.loai;
  final b = removeVietnameseTones(s.toLowerCase());
  final lechDoDai = b.length != s.length;
  final luat = lechDoDai
      ? _rong(loai)
      : _docTheoLuat(loai, s, b, theoMau: nhan != null, now: now, vi: vi, danhMucChi: danhMucChi);
  var quaAi = false;
  T? lap<T>(T? cuaLuat, T? cuaAi) {
    if (cuaLuat != null || cuaAi == null) return cuaLuat;
    quaAi = true;
    return cuaAi;
  }

  // ⚠️ `nguon:` đặt CUỐI mỗi constructor: `lap` đổi `quaAi`, và Dart tính tham số theo thứ tự viết.
  switch (luat) {
    case LenhTaoHoaDon():
      final chuKyAi = _chuKyTheoChu[ai.chuKy];
      final chuKy = _mauChuKy.hasMatch(b) || chuKyAi == null ? luat.chuKy : chuKyAi;
      if (chuKy != luat.chuKy) quaAi = true;
      final viAi = luat.idVi == null ? _viAiHopLe(vi, ai.vi, s) : null;
      final dmAi = luat.idDanhMuc == null ? _mucTheoTenChuan(danhMucChi, ai.danhMuc) : null;
      final ngayGoc =
          lap(luat.ngayGoc, lechDoDai ? null : _ngayGocAiHopLe(ai.ngayGoc, b, chonSoTienTrongCau(s, now: now)));
      return LenhTaoHoaDon(
        ten: lap(luat.ten, _tenAiHopLe(ai.ten, s)),
        soTien: lap(luat.soTien, _soAiHopLe(ai.soTien, s, now)),
        chuKy: chuKy,
        ngayGoc: ngayGoc,
        batDau: ngayBatDauHoaDon(ngayGoc, now),
        idVi: lap(luat.idVi, viAi?.id),
        idDanhMuc: lap(luat.idDanhMuc, dmAi?.id),
        tenVi: luat.tenVi ?? viAi?.ten,
        tenDanhMuc: luat.tenDanhMuc ?? dmAi?.ten,
        nhacTuTra: luat.nhacTuTra,
        nguon: quaAi ? NguonLenh.ai : NguonLenh.luat,
      );
    case LenhTaoMucTieu():
      // Số tiền của câu là mức góp theo kỳ → con số mô hình trả (cũng chính nó) không phải số tiền đích.
      final tien = lechDoDai ? null : chonSoTienTrongCau(s, now: now);
      final theoKy = tien != null && _tienTheoKy(b, tien);
      return LenhTaoMucTieu(
        ten: lap(luat.ten, _tenAiHopLe(ai.ten, s)),
        soTienDich: lap(luat.soTienDich, theoKy ? null : _soAiHopLe(ai.soTien, s, now)),
        han: lap(luat.han, _hanAiHopLe(ai.han, s, now)),
        nguon: quaAi ? NguonLenh.ai : NguonLenh.luat,
      );
    case LenhTaoNganSach():
      final dmAi = luat.idDanhMuc == null ? _mucTheoTenChuan(danhMucChi, ai.danhMuc) : null;
      return LenhTaoNganSach(
        idDanhMuc: lap(luat.idDanhMuc, dmAi?.id),
        tenDanhMuc: luat.tenDanhMuc ?? dmAi?.ten,
        hanMuc: lap(luat.hanMuc, _soAiHopLe(ai.soTien, s, now)),
        nguon: quaAi ? NguonLenh.ai : NguonLenh.luat,
      );
  }
}

const Map<String, String> _nhanChuKy = {
  kBillCycleWeek: 'hằng tuần',
  kBillCycleMonth: 'hằng tháng',
  kBillCycleQuarter: 'hằng quý',
  kBillCycleYear: 'hằng năm',
};

/// Nội dung thẻ lệnh ở màn chat (spec C3 §4): *"Mình hiểu là: {hanhDong} **{ten}** · {chiTiet…}"*, một dòng cho ô thiếu
/// ([thieu] rỗng = đủ), dòng tầng 4 khi [nhacTuTra], và nhãn nút. Chỉ in ô đọc được; tiền qua `CurrencyFormatter`.
({String hanhDong, String? ten, List<String> chiTiet, String thieu, bool nhacTuTra, String nut}) tomTatLenhTao(
    LenhTao l) {
  String thieu(List<String> o) => o.isEmpty ? '' : 'Chưa rõ ${o.join(', ')} — bạn điền trong form';
  String tien(double? x) => CurrencyFormatter.format(x!);
  switch (l) {
    case LenhTaoHoaDon():
      final chuKy = _nhanChuKy[l.chuKy] ?? 'hằng tháng';
      final bd = l.batDau;
      return (
        hanhDong: 'Tạo hoá đơn',
        ten: l.ten,
        chiTiet: [
          if (l.soTien != null) tien(l.soTien),
          // Thẻ nói đúng thứ form sẽ điền: ngày nêu trong câu là NGÀY BẮT ĐẦU (người dùng chốt 2026-10-01).
          if (bd != null)
            '$chuKy, bắt đầu ${_hai(bd.day)}/${_hai(bd.month)}/${bd.year}'
          else if (l.ngayGoc != null)
            '$chuKy, ngày ${l.ngayGoc}'
          else
            chuKy,
          if (l.tenDanhMuc != null) 'danh mục ${l.tenDanhMuc}',
          if (l.tenVi != null) 'ví ${l.tenVi}',
        ],
        thieu: thieu([if (l.ten == null) 'tên', if (l.soTien == null) 'số tiền']),
        nhacTuTra: l.nhacTuTra,
        nut: 'Mở form tạo hoá đơn',
      );
    case LenhTaoMucTieu():
      final h = l.han;
      return (
        hanhDong: 'Tạo mục tiêu',
        ten: l.ten,
        chiTiet: [
          if (l.soTienDich != null) tien(l.soTienDich),
          if (h != null) 'hạn ${_hai(h.day)}/${_hai(h.month)}/${h.year}',
        ],
        thieu: thieu([if (l.ten == null) 'tên', if (l.soTienDich == null) 'số tiền', if (h == null) 'hạn']),
        nhacTuTra: false,
        nut: 'Mở form tạo mục tiêu',
      );
    case LenhTaoNganSach():
      return (
        hanhDong: 'Đặt ngân sách',
        ten: l.tenDanhMuc,
        chiTiet: [if (l.hanMuc != null) tien(l.hanMuc)],
        thieu: thieu([if (l.idDanhMuc == null) 'danh mục', if (l.hanMuc == null) 'hạn mức']),
        nhacTuTra: false,
        nut: 'Mở form đặt ngân sách',
      );
  }
}
