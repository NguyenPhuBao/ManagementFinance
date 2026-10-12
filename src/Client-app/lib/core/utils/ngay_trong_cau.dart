/// Ngày nêu trong một câu tiếng Việt (C2 task 2, spec `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2.3) —
/// cho ô *Nhập nhanh* của màn Thêm giao dịch, và sau này D1 / C4 dùng chung.
///
/// Bốn dạng, chữ đứng **đầu câu** thắng khi có nhiều:
/// - *hôm nay · sáng / trưa / chiều / tối nay* → hôm nay; *hôm qua* → hôm qua; *hôm kia* → hai ngày trước.
/// - *thứ 2 … thứ 7*, *thứ hai … thứ bảy*, *chủ nhật / cn* → ngày gần nhất **đã qua hoặc hôm nay** có thứ ấy; kèm
///   *"tuần trước"* / *"tuần này"* thì là ngày ấy của tuần (thứ Hai → Chủ nhật) được nêu. *"thứ sáu tuần trước"* đọc
///   vào thứ Bảy không phải hôm qua.
/// - *ngày X tháng Y* (X, Y bằng chữ hoặc số: *ngày năm tháng chín*, *ngày 5 tháng 9*) → ngày ấy của năm hiện tại;
///   *mùng / mồng X* → ngày X tháng này; *(ngày) mùng X tháng Y* cũng đọc. Cùng nếp *dd/mm*: rơi vào tương lai quá 7
///   ngày thì lùi (năm trước / tháng trước); ngày không tồn tại thì bỏ. *… tháng trước* → ngày X của tháng trước;
///   *… tháng này* → như không nêu tháng; *… tháng sau / tới* (mọi chữ lạ sau *tháng*) → KHÔNG đọc ngày (để C2 hỏi
///   AI). Câu NÓI (C4): máy nghe trả chữ hoặc số. ⚠️ *"… năm Z"* sau tháng bị bỏ qua (Z không được đọc).
///   ⚠️ *mùng / mồng* chỉ nhận dạng CÓ DẤU (*mung* còn là *mừng*, *mong*, *mộng*; cùng quy ước `cauNhacNgay`);
///   *mùng 2/9* là dd/mm (luật dd/mm thắng); số liền chữ (*mùng 5k*) không phải ngày; số tháng ngay trước đơn vị tiền
///   (*mùng 5 tháng 3 triệu*, *… 3 lít*) là tiền, tháng rơi về tháng này.
/// - *dd/mm* (có thể kèm *ngày* đứng trước, hoặc */yyyy* sau) → ngày ấy của năm hiện tại; không tồn tại thì bỏ; rơi
///   vào tương lai quá 7 ngày thì lùi một năm (gõ *30/12* hôm 3/1 là 30/12 năm ngoái).
///
/// So trên chữ bỏ dấu, trọn từ — người gõ nhanh viết không dấu. ⚠️ Hai ngoại lệ: *mùng / mồng* của dạng thứ ba phải có
/// dấu (xem trên); và *thu* không dấu còn là động từ *thu* tiền (*"thu hai triệu"*), nên chỉ *thứ* **có dấu** mới nhận
/// dạng chữ (*thứ hai*); *thu* không dấu chỉ nhận dạng số (*thu 5*) và không được có đơn vị tiền ngay sau (*thu 2
/// triệu*, *thu 2tr*).
///
/// ⚠️ `kyTuCauHoi` (Trợ lý AI) **không** gọi hàm này: nó đọc kỳ nêu cụ thể, còn *"hôm qua"* của nó đi qua mã kỳ
/// `hom_qua`. Thứ hai bên dùng chung là [ngayHopLe].
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../category/category_name.dart';
import 'so_bang_chu.dart';

/// Một ngày đọc được: đầu ngày, và `[batDau, ketThuc)` trong câu **đã NFC** (câu dựng sẵn — câu gõ từ bàn phím — trùng
/// với chính nó).
typedef NgayTrongCau = ({DateTime ngay, int batDau, int ketThuc});

/// `null` khi ngày không tồn tại trên lịch — `DateTime(2026, 6, 31)` tự cuộn sang 1/7, nên phải so lại tháng và ngày.
/// Dời từ `ai_edge/domain/ma_ky.dart` (C2 task 2); tệp ấy gọi lại.
DateTime? ngayHopLe(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final x = DateTime(y, m, d);
  return (x.month == m && x.day == d) ? x : null;
}

const Map<String, int> _lui = {
  'hom nay': 0,
  'sang nay': 0,
  'trua nay': 0,
  'chieu nay': 0,
  'toi nay': 0,
  'hom qua': 1,
  'hom kia': 2,
};

final RegExp _mauTuongDoi = RegExp('(?<![a-z0-9])(${_lui.keys.join('|')})(?![a-z0-9])');

/// Thứ bằng chữ → `DateTime.weekday`.
const Map<String, int> _thuChu = {'hai': 1, 'ba': 2, 'tu': 3, 'nam': 4, 'sau': 5, 'bay': 6};

final RegExp _mauThu = RegExp(r'(?<![a-z0-9])thu ([2-7]|hai|ba|tu|nam|sau|bay)(?![a-z0-9])');
final RegExp _mauChuNhat = RegExp(r'(?<![a-z0-9])(?:chu nhat|cn)(?![a-z0-9])');
final RegExp _sauLaDonViTien = RegExp(r'^\s*(?:k|nghin|ngan|tr|trieu|cu|lit|xi|tram|ty|ti)(?![a-z])');
final RegExp _mauNgay = RegExp(r'(?:(?<![a-z0-9])ngay\s+)?(?<![\d/])(\d{1,2})/(\d{1,2})(?:/(\d{4}))?(?![\d/])');

/// *đầu tháng* / *đầu tháng này* → ngày 1 tháng này; *đầu tháng trước* → ngày 1 tháng trước (người dùng chốt 2026-09-30,
/// spec C2 §8 câu 4). Mơ hồ thì không đọc: *đầu tháng sau / tới / nữa*, *đầu tháng 10*.
/// ⚠️ Phép chặn số chỉ áp khi *tháng* đứng trần: đặt chung sau nhánh *trước* thì *"đầu tháng trước 2tr"* bị chặn vì số
/// tiền, regex lùi về *"đầu tháng"* và đọc thành ngày 1 tháng NÀY.
final RegExp _mauDauThang = RegExp(
    r'(?<![a-z0-9])dau\s+thang(?:\s+(nay|truoc)(?![a-z0-9])|(?![a-z0-9])(?!\s+(?:sau|toi|nua|\d)))');
final RegExp _mauCuoiThangTruoc = RegExp(r'(?<![a-z0-9])cuoi\s+thang\s+truoc(?![a-z0-9])');

NgayTrongCau? timNgayTrongCau(String cau, DateTime now) {
  final goc = unorm.nfc(cau).toLowerCase();
  final s = removeVietnameseTones(goc);
  if (s.length != goc.length) return null; // chỉ xảy ra với ký tự ngoài tiếng Việt — không đoán vị trí
  final homNay = DateTime(now.year, now.month, now.day);
  final ungVien = <NgayTrongCau>[];

  for (final m in _mauTuongDoi.allMatches(s)) {
    final lui = _lui[m.group(1)]!;
    ungVien.add((ngay: DateTime(now.year, now.month, now.day - lui), batDau: m.start, ketThuc: m.end));
  }

  for (final m in _mauThu.allMatches(s)) {
    final coDau = goc.startsWith('thứ', m.start);
    final tu = m.group(1)!;
    final laSo = RegExp(r'^\d$').hasMatch(tu);
    if (!coDau && (!laSo || _sauLaDonViTien.hasMatch(s.substring(m.end)))) continue;
    final thu = laSo ? int.parse(tu) - 1 : _thuChu[tu]!;
    ungVien.add(_theoTuan(s, homNay, thu, m.start, m.end));
  }

  for (final m in _mauChuNhat.allMatches(s)) {
    ungVien.add(_theoTuan(s, homNay, DateTime.sunday, m.start, m.end));
  }

  for (final m in _mauDauThang.allMatches(s)) {
    final lui = m.group(1) == 'truoc' ? 1 : 0;
    ungVien.add((ngay: DateTime(now.year, now.month - lui, 1), batDau: m.start, ketThuc: m.end));
  }

  for (final m in _mauCuoiThangTruoc.allMatches(s)) {
    // Ngày 0 của tháng này = ngày cuối tháng trước (tháng 30 / 31 ngày, tháng 2 thường / nhuận, biên năm).
    ungVien.add((ngay: DateTime(now.year, now.month, 0), batDau: m.start, ketThuc: m.end));
  }

  for (final m in _mauNgay.allMatches(s)) {
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final namGhi = m.group(3) == null ? null : int.parse(m.group(3)!);
    var x = ngayHopLe(namGhi ?? now.year, mo, d);
    if (x != null && namGhi == null && x.difference(homNay).inDays > 7) {
      x = ngayHopLe(now.year - 1, mo, d);
    }
    if (x == null) continue;
    ungVien.add((ngay: x, batDau: m.start, ketThuc: m.end));
  }

  // C4 (spec 2026-10-12 §3.3): "ngày năm tháng chín", "ngày 5 tháng 9", "(ngày) mùng năm (tháng chín)" — câu NÓI,
  // máy nghe trả chữ hoặc số. Số bằng chữ đọc qua `so_bang_chu.dart` (định nghĩa duy nhất), trên token CÓ DẤU của câu.
  final tk = _tuNgay.allMatches(goc).toList();
  final ws = [for (final m in tk) m.group(0)!];
  DateTime? ngayThang(int d, int mo) {
    var x = ngayHopLe(now.year, mo, d);
    if (x != null && x.difference(homNay).inDays > 7) x = ngayHopLe(now.year - 1, mo, d);
    return x;
  }

  // Ngày X của tháng cách `now` [lui] tháng (0 = tháng này, 1 = tháng trước); ngày không tồn tại → null.
  DateTime? ngayCuaThang(int d, int lui) {
    final m = DateTime(now.year, now.month - lui, 1);
    return ngayHopLe(m.year, m.month, d);
  }

  for (var i = 0; i < ws.length; i++) {
    final t = ws[i];
    if (t == 'ngày' || t == 'ngay') {
      var j = i + 1;
      if (j < ws.length && _laMung(ws[j])) j++; // "ngày mùng năm tháng chín"
      final d = _soNgay(ws, j);
      if (d == null) continue;
      final th = _veThang(ws, d.$2);
      if (th.loai == _LoaiThang.khongNeu || th.loai == _LoaiThang.bo) continue;
      final x = th.loai == _LoaiThang.so ? ngayThang(d.$1, th.gia) : ngayCuaThang(d.$1, th.gia);
      if (x != null) ungVien.add((ngay: x, batDau: tk[i].start, ketThuc: tk[th.ke - 1].end));
    } else if (_laMung(t)) {
      // Chỉ "mùng / mồng" CÓ DẤU (cùng quy ước `cauNhacNgay`): "mung" không dấu còn là "mừng" / "mong" / "mộng".
      final d = _soNgay(ws, i + 1);
      if (d == null) continue;
      final cuoiSo = tk[d.$2 - 1].end;
      if (cuoiSo < goc.length && goc[cuoiSo] == '/') continue; // "mùng 2/9" là dd/mm — luật trên đã đọc
      final th = _veThang(ws, d.$2);
      if (th.loai == _LoaiThang.bo) continue; // "mùng 5 tháng sau": không đoán, để AI hỏi
      DateTime? x;
      var ke = d.$2;
      if (th.loai == _LoaiThang.so) {
        x = ngayThang(d.$1, th.gia);
        ke = th.ke;
      } else if (th.loai == _LoaiThang.tuongDoi) {
        x = ngayCuaThang(d.$1, th.gia);
        ke = th.ke;
      } else {
        x = ngayHopLe(now.year, now.month, d.$1);
        if (x != null && x.difference(homNay).inDays > 7) x = ngayCuaThang(d.$1, 1);
        if (th.loai == _LoaiThang.thangNay) ke = th.ke;
      }
      if (x != null) ungVien.add((ngay: x, batDau: tk[i].start, ketThuc: tk[ke - 1].end));
    }
  }

  if (ungVien.isEmpty) return null;
  ungVien.sort((a, b) => a.batDau.compareTo(b.batDau));
  return ungVien.first;
}

/// Câu có NHẮC một thời điểm đã qua không (C2, người dùng chốt 2026-09-30): ô Nhập nhanh chỉ nhờ AI đọc ngày khi câu có
/// nhắc mà [timNgayTrongCau] không đọc được, và chỉ nhận ngày của AI khi câu có nhắc.
///
/// Nhắc = một **cụm**: *hôm / bữa + trước · qua · kia · nọ*, *sáng · trưa · chiều · tối · đêm + qua · hôm · trước*, *tuần
/// · tháng · năm + trước · rồi · qua · ngoái · kia*, *đầu · giữa · cuối + tuần · tháng · năm*, *ngày + trước · rồi · kia*,
/// *ngày / mùng / mồng + số*. ⚠️ Chữ lẻ không đủ: *vé tháng*, *lương tháng*, *đầu tư*, *mua mấy thứ*, *trả trước* mang
/// nghĩa khác — xét chữ lẻ là gọi AI oan ~18 s mỗi câu. Cụm chỉ KỲ (*tháng này, tháng 9, năm nay*) và cụm tương lai
/// (*tuần sau, tháng tới*) không phải nhắc: ngày giao dịch không đổi.
///
/// Chữ gõ không dấu chỉ nhận dạng không lẫn được (*hom, tuan, thang, trua, chieu*; *dau · giua · cuoi* chỉ trước *tuan ·
/// thang*): *toi* còn là *tôi*, *dem* là *đem*, *nam* là tên *Nam*.
///
/// ⚠️ *cuối tháng · cuối tháng này · cuối tháng sau / tới* trơn **không** là nhắc (người dùng chọn 2026-10-06): ngày ấy
/// là hôm nay hoặc tương lai, mà lớp kiểm ngày của AI bỏ hôm nay — Realme 2026-09-30 câu 11 gọi AI 14 s không thêm gì.
/// *cuối tháng rồi / trước / qua* và *cuối tháng 9* vẫn là nhắc.
bool cauNhacNgay(String cau) {
  var goc = unorm.nfc(cau).toLowerCase();
  final boDau = removeVietnameseTones(goc);
  if (boDau.length == goc.length) {
    for (final m in _mauCuoiThangTron.allMatches(boDau)) {
      goc = goc.replaceRange(m.start, m.end, ' ' * (m.end - m.start));
    }
  }
  final tu = [for (final m in _tuChu.allMatches(goc)) m.group(0)!];
  for (var i = 0; i + 1 < tu.length; i++) {
    final a = tu[i];
    final b = tu[i + 1];
    final bb = removeVietnameseTones(b);
    if ((_hom.contains(a) && _sauHom.contains(bb)) ||
        (_buoi.contains(a) && _sauBuoi.contains(bb)) ||
        (_ky.contains(a) && _sauKyDaQua.contains(bb)) ||
        (_moc.contains(a) && _kyMoc.contains(b)) ||
        (a == 'ngày' && _sauNgay.contains(bb))) {
      return true;
    }
  }
  final s = removeVietnameseTones(goc);
  if (s.length != goc.length) return false;
  for (final m in _mauNgaySo.allMatches(s)) {
    if (_sauLaDonViTien.hasMatch(s.substring(m.end))) continue; // "trả ngay 5k"
    if (m.group(1) == 'ngay' || goc.startsWith('mùng', m.start) || goc.startsWith('mồng', m.start)) return true;
  }
  return false;
}

final RegExp _tuChu = RegExp(r'[\p{L}\p{M}]+', unicode: true);
const Set<String> _hom = {'hôm', 'hom', 'bữa'};
const Set<String> _sauHom = {'truoc', 'qua', 'kia', 'no', 'bua'};
const Set<String> _buoi = {'sáng', 'trưa', 'chiều', 'tối', 'đêm', 'trua', 'chieu'};
const Set<String> _sauBuoi = {'qua', 'hom', 'truoc'};
const Set<String> _ky = {'tuần', 'tháng', 'năm', 'tuan', 'thang'};
const Set<String> _sauKyDaQua = {'truoc', 'roi', 'qua', 'ngoai', 'kia'};
const Set<String> _moc = {'đầu', 'giữa', 'cuối', 'dau', 'giua', 'cuoi'};
const Set<String> _kyMoc = {'tuần', 'tháng', 'năm', 'tuan', 'thang'};
const Set<String> _sauNgay = {'truoc', 'roi', 'kia'};
final RegExp _mauNgaySo = RegExp(r'(?<![a-z0-9])(ngay|mung|mong)\s+\d{1,2}(?![\d/.,])');
final RegExp _mauCuoiThangTron = RegExp(
    r'(?<![a-z0-9])cuoi\s+thang(?:\s+(?:nay|sau|toi))?(?![a-z0-9])(?!\s+(?:truoc|roi|qua|ngoai|kia|\d))');

final RegExp _mauTuan = RegExp(r'^\s+tuan\s+(truoc|nay)(?![a-z0-9])');

/// Thứ [thu] đọc được ở `[bd, kt)`; ngay sau là *"tuần trước"* / *"tuần này"* thì là ngày ấy của tuần được nêu (tuần
/// bắt đầu thứ Hai) và đoạn nuốt luôn cụm ấy, không thì ngày gần nhất đã qua hoặc hôm nay.
NgayTrongCau _theoTuan(String s, DateTime homNay, int thu, int bd, int kt) {
  final m = _mauTuan.firstMatch(s.substring(kt));
  if (m == null) return (ngay: _ganNhat(homNay, thu), batDau: bd, ketThuc: kt);
  final thuHai = DateTime(homNay.year, homNay.month, homNay.day - (homNay.weekday - 1));
  final lui = m.group(1) == 'truoc' ? 7 : 0;
  return (
    ngay: DateTime(thuHai.year, thuHai.month, thuHai.day - lui + thu - 1),
    batDau: bd,
    ketThuc: kt + m.end,
  );
}

/// Ngày gần nhất đã qua hoặc hôm nay có [thu] (`DateTime.weekday`).
DateTime _ganNhat(DateTime homNay, int thu) =>
    DateTime(homNay.year, homNay.month, homNay.day - (homNay.weekday - thu) % 7);

final RegExp _tuNgay = RegExp(r'[\p{L}\p{M}]+|\d+[\p{L}\p{M}]*', unicode: true);
final RegExp _haiChuSo = RegExp(r'^\d{1,2}$');

bool _laMung(String t) => t == 'mùng' || t == 'mồng';

/// Số ngày 1–31 bắt đầu ở token [i]: chữ số, hoặc chữ qua [docSoNhoBangChu]. `(giá trị, token kế tiếp)` hoặc `null`.
(int, int)? _soNgay(List<String> ws, int i, {bool tu = false}) {
  if (i >= ws.length) return null;
  if (_haiChuSo.hasMatch(ws[i])) return (int.parse(ws[i]), i + 1);
  return docSoNhoBangChu(ws, i, choPhepTu: tu);
}

enum _LoaiThang { khongNeu, so, tuongDoi, thangNay, bo }

/// Mệnh đề tháng ở token [i]: `khongNeu` (không có *tháng*, hoặc *tháng* + số liền trước đơn vị tiền — *"tháng 3
/// triệu"*: số ấy là tiền), `so` (tháng Y, `gia` = Y), `tuongDoi` (*tháng trước*, `gia` = 1), `thangNay` (*tháng này*),
/// `bo` (chữ lạ sau *tháng*, nhất là *sau · tới*: không đọc ngày). `ke` = token kế tiếp mệnh đề.
/// ⚠️ *sau* không dấu KHÔNG là số tháng (không phải 6; *sáu* có dấu mới là 6) nên phải xét trước khi đọc số.
({_LoaiThang loai, int gia, int ke}) _veThang(List<String> ws, int i) {
  const khong = (loai: _LoaiThang.khongNeu, gia: 0, ke: 0);
  if (i >= ws.length || (ws[i] != 'tháng' && ws[i] != 'thang')) return khong;
  if (i + 1 >= ws.length) return khong;
  final tiep = ws[i + 1];
  if (tiep == 'trước' || tiep == 'truoc') return (loai: _LoaiThang.tuongDoi, gia: 1, ke: i + 2);
  if (tiep == 'này' || tiep == 'nay') return (loai: _LoaiThang.thangNay, gia: 0, ke: i + 2);
  if (tiep == 'sau') return (loai: _LoaiThang.bo, gia: 0, ke: i + 2);
  final r = _soNgay(ws, i + 1, tu: true);
  if (r == null) return (loai: _LoaiThang.bo, gia: 0, ke: i + 2);
  // Cùng phép thử đơn vị tiền với nhánh *thu* và `cauNhacNgay` (`_sauLaDonViTien`).
  if (r.$2 < ws.length && _sauLaDonViTien.hasMatch(removeVietnameseTones(ws[r.$2]))) return khong;
  return (loai: _LoaiThang.so, gia: r.$1, ke: r.$2);
}
