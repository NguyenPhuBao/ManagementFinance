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
import '../../../core/utils/khop_ten.dart';
import '../../../core/utils/ngay_trong_cau.dart';
import '../../transaction/domain/doc_cau_giao_dich.dart' show chonSoTienTrongCau;

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


/// Một đối tượng chọn được (ví / danh mục) — record thay kiểu Drift để lớp AI không đụng bảng.
typedef MucChon = ({String id, String ten});

/// Lệnh đã đọc ô. Trường `null` = không đọc được — form để trống ô ấy. [query] chỉ mang khoá có giá trị; [duongDan] là
/// route form điền sẵn. ⚠️ Tầng 4: không lớp nào mang tham số bật tự trả / trích tự động.
sealed class LenhTao {
  const LenhTao();

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
    this.idVi,
    this.idDanhMuc,
    this.nhacTuTra = false,
  });

  final String? ten;
  final double? soTien;

  /// Một trong `kBillCycle*` — câu không nêu thì tháng.
  final String chuKy;
  final int? ngayGoc;
  final String? idVi;
  final String? idDanhMuc;

  /// Câu nhắc tự trả / trích tự động — CHỈ để thẻ nói "bật trong form" (tầng 4, AI không bật).
  final bool nhacTuTra;

  @override
  String get _route => '/bills/add';

  /// Khoá của B2 (`dienSanTuQuery`), không `start`: hoá đơn mới bắt đầu hôm nay (spec C3 §4).
  @override
  Map<String, String> get query => {
        if (ten != null) 'name': ten!,
        if (soTien != null) 'amount': soTien!.round().toString(),
        'cycle': chuKy,
        if (ngayGoc != null) 'anchor': '$ngayGoc',
        if (idDanhMuc != null) 'category': idDanhMuc!,
        if (idVi != null) 'wallet': idVi!,
      };
}

class LenhTaoMucTieu extends LenhTao {
  const LenhTaoMucTieu({this.ten, this.soTienDich, this.han});

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
  const LenhTaoNganSach({this.idDanhMuc, this.tenDanhMuc, this.hanMuc});

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
final RegExp _mauChuKy = RegExp(r'(?<![a-z0-9])(?:hang|moi)\s+(tuan|thang|quy|nam)(?![a-z0-9])');
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
  if (b.length != s.length) {
    return switch (nhan.loai) {
      LoaiLenhTao.hoaDon => const LenhTaoHoaDon(),
      LoaiLenhTao.mucTieu => const LenhTaoMucTieu(),
      LoaiLenhTao.nganSach => const LenhTaoNganSach(),
    };
  }
  final danhTu = _mauDanhTu.firstMatch(b);
  final tu = danhTu?.end ?? 0;
  final tien = chonSoTienTrongCau(s, now: now);
  final soTien = tien != null && tien.batDau >= tu ? tien.giaTri : null;

  switch (nhan.loai) {
    case LoaiLenhTao.hoaDon:
      final viNeu = timTenTrongCau(s, [for (final v in vi) v.ten], tuLoai: 'ví');
      final dmNeu = timTenTrongCau(s, [for (final d in danhMucChi) d.ten], tuLoai: 'danh mục');
      final chuKy = _mauChuKy.firstMatch(b);
      final ngayGoc = _mauNgayGoc.firstMatch(b);
      final ng = ngayGoc == null ? null : int.parse(ngayGoc.group(1)!);
      final tuTraO = _viTri(_mauTuTra, b, tu);
      final nhanO = _viTri(RegExp(r'(?<![a-z0-9])(?:vi|danh muc)(?![a-z0-9])'), b, tu);
      return LenhTaoHoaDon(
        ten: _tenSau(s, tu, [
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
        idVi: _idCua(vi, viNeu?.ten),
        idDanhMuc: _idCua(danhMucChi, dmNeu?.ten),
        nhacTuTra: _mauTuTra.hasMatch(b),
      );
    case LoaiLenhTao.mucTieu:
      final hanO = _viTri(_mauMoHan, b, tu);
      return LenhTaoMucTieu(
        ten: _tenSau(s, tu, [
          if (soTien != null) tien!.batDau,
          if (hanO != null) hanO,
        ]),
        soTienDich: soTien,
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
