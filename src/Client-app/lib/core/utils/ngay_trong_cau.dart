/// Ngày nêu trong một câu tiếng Việt (C2 task 2, spec `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2.3) —
/// cho ô *Nhập nhanh* của màn Thêm giao dịch, và sau này D1 / C4 dùng chung.
///
/// Ba dạng, chữ đứng **đầu câu** thắng khi có nhiều:
/// - *hôm nay · sáng / trưa / chiều / tối nay* → hôm nay; *hôm qua* → hôm qua; *hôm kia* → hai ngày trước.
/// - *thứ 2 … thứ 7*, *thứ hai … thứ bảy*, *chủ nhật / cn* → ngày gần nhất **đã qua hoặc hôm nay** có thứ ấy; kèm *"tuần
///   trước"* / *"tuần này"* thì là ngày ấy của tuần (thứ Hai → Chủ nhật) được nêu. *"thứ sáu tuần trước"* đọc vào thứ
///   Bảy không phải hôm qua.
/// - *dd/mm* (có thể kèm *ngày* đứng trước, hoặc */yyyy* sau) → ngày ấy của năm hiện tại; không tồn tại thì bỏ; rơi vào
///   tương lai quá 7 ngày thì lùi một năm (gõ *30/12* hôm 3/1 là 30/12 năm ngoái).
///
/// So trên chữ bỏ dấu, trọn từ — người gõ nhanh viết không dấu. ⚠️ Một ngoại lệ: *thu* không dấu còn là động từ *thu*
/// tiền (*"thu hai triệu"*), nên chỉ *thứ* **có dấu** mới nhận dạng chữ (*thứ hai*); *thu* không dấu chỉ nhận dạng số
/// (*thu 5*) và không được có đơn vị tiền ngay sau (*thu 2 triệu*, *thu 2tr*).
///
/// ⚠️ `kyTuCauHoi` (Trợ lý AI) **không** gọi hàm này: nó đọc kỳ nêu cụ thể, còn *"hôm qua"* của nó đi qua mã kỳ
/// `hom_qua`. Thứ hai bên dùng chung là [ngayHopLe].
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../category/category_name.dart';

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
final RegExp _sauLaDonViTien = RegExp(r'^\s*(?:k|nghin|ngan|tr|trieu|cu|lit|xi|tram)(?![a-z])');
final RegExp _mauNgay = RegExp(r'(?:(?<![a-z0-9])ngay\s+)?(?<![\d/])(\d{1,2})/(\d{1,2})(?:/(\d{4}))?(?![\d/])');

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

  if (ungVien.isEmpty) return null;
  ungVien.sort((a, b) => a.batDau.compareTo(b.batDau));
  return ungVien.first;
}

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
