/// C3 — lệnh "tạo hoá đơn / mục tiêu / ngân sách" ở màn Trợ lý AI (spec
/// `2026-09-28-c3-lenh-tao-hoa-don-muc-tieu-ngan-sach-design.md`). **Chỉ luật**,
/// không mô hình: màn chat gọi nó TRƯỚC mọi thứ khác, câu là lệnh thì trả một thẻ
/// mở form điền sẵn — người dùng bấm Lưu (bất biến ④ nhóm C).
///
/// Đặt ở `ai_edge/domain` cạnh `congCuTheoCauHoi` vì nó là định tuyến câu của trợ
/// lý. ⚠️ Nhận nhầm một câu hỏi thành lệnh là câu hỏi ấy mất câu trả lời — lưới
/// là 72 câu cổng F (`lenh_tao_test.dart`).
library;

import '../../../core/category/category_name.dart';

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
