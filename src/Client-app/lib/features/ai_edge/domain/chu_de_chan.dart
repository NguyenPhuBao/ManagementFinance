// lib/features/ai_edge/domain/chu_de_chan.dart
/// Blocklist chủ đề cho hỏi đáp tự do (spec mục 4.4).
///
/// App có số liệu chi tiêu của một người; nó **không** có cơ sở nào để khuyên
/// về đầu tư, chứng khoán, tiền mã hoá, vay ngân hàng hay thuế — và một mô hình
/// 2,3 tỉ tham số chạy trên điện thoại thì càng không. Lời khuyên sai ở những
/// chủ đề ấy gây thiệt hại thật.
///
/// ⚠️ So **có dấu** (quy tắc 7 `CLAUDE.md`): bỏ dấu gộp "đầu tư" với "đầu
/// tuần" và từ chối một câu hỏi hợp lệ. (Ngoại lệ có lý do: câu định nghĩa, họ D;
/// bản không dấu của nhóm dữ liệu sống; và lượt B của `_laCauHoiGiaTaiSan`, chỉ
/// cho từ bỏ dấu vẫn một nghĩa.)
///
/// Tệp phục vụ hai đường: `chuDeBiChan` (mô hình trên máy: chặn cả tư vấn chung)
/// và `chuDeBiChanOnline` (Gemini: mở tư vấn chung, chỉ chặn dữ liệu sống và câu
/// hỏi giá tài sản).
library;

import '../../../core/category/category_name.dart';

const String kCauTuChoi =
    'Mình chỉ nhận xét được trên số liệu của bạn trong app.';

/// Nhóm **dữ liệu sống** — thứ không mô hình nào có số đúng hôm nay (giá, tỉ giá,
/// thời tiết, kết quả): chặn ở CẢ hai đường. Spec trợ lý online 2026-10-11 §3.1.
const List<String> _tuKhoaSong = [
  'lãi suất ngân hàng',
  // H2 cổng F lần 2 (DC1): app không lưu lãi suất của ví hay mục tiêu nào.
  'lãi suất',
  // Lát 2 spec mở rộng tool (2026-09-27 §6; E22 cổng E: câu ngoài phạm vi bị ép
  // vào tool). App không có nguồn nào cho những thứ này.
  'giá vàng',
  'giá xăng',
  'tỷ giá',
  'tỉ giá',
  'thời tiết',
  'tin tức',
  'xổ số',
  'bóng đá',
];

/// Nhóm **tư vấn chung** — mô hình trên máy không biết gì ngoài sổ nên chặn; đường
/// online (Gemini + RAG backend) trả lời được → `chuDeBiChanOnline` KHÔNG chặn.
const List<String> _tuKhoaTuVan = [
  'đầu tư',
  'chứng khoán',
  'cổ phiếu',
  'trái phiếu',
  'tiền mã hoá',
  'tiền mã hóa',
  'tiền ảo',
  'bitcoin',
  'crypto',
  'vay ngân hàng',
  'thuế',
];

/// Bản KHÔNG DẤU của nhóm sống — người dùng (và buổi đo qua adb) gõ không dấu.
/// Chỉ những cụm bỏ dấu mà vẫn một nghĩa; nhóm tư vấn KHÔNG có bản này vì "dau tu"
/// trùng "đầu tư" với "đấu từ", "thue" trùng "thuế" với "thuê".
const List<String> _tuKhoaSongKhongDau = [
  'lai suat',
  'gia vang',
  'gia xang',
  'ty gia',
  'ti gia',
  'thoi tiet',
  'xo so',
  'bong da',
];

/// Câu hỏi GIÁ của một tài sản — hai lượt so, chặn khi MỘT lượt khớp cả hai vế.
/// Lượt A so CÓ DẤU, từ trọn: bỏ dấu gộp "vàng" với "vâng / vắng / rượu vang",
/// "đô la" với "đó là", "tiền ảo" với "tiền áo", "cổ phiếu" với "có phiếu".
/// Lượt B so bản bỏ dấu, CHỈ với từ không trùng nghĩa khi bỏ dấu.
RegExp _tuTron(String alt) =>
    RegExp('(?<![\\p{L}\\p{N}])(?:$alt)(?![\\p{L}\\p{N}])', unicode: true);

final RegExp _giaCoDau = _tuTron('giá|bao nhiêu tiền');
final RegExp _taiSanCoDau = _tuTron(
    'vàng|cổ phiếu|chứng khoán|tiền ảo|tiền mã hoá|tiền mã hóa|đô la|đô|usd|bitcoin|crypto');
final RegExp _giaKhongDau = _tuTron('gia|bao nhieu tien');
final RegExp _taiSanKhongDau = _tuTron('bitcoin|crypto|usd|dola|chung khoan');

bool _laCauHoiGiaTaiSan(String cauHoi) {
  final q = normalizeCategoryName(cauHoi);
  if (_giaCoDau.hasMatch(q) && _taiSanCoDau.hasMatch(q)) return true;
  final k = removeVietnameseTones(q);
  return _giaKhongDau.hasMatch(k) && _taiSanKhongDau.hasMatch(k);
}

/// Họ D (2026-10-04, người dùng chốt): câu ĐỊNH NGHĨA / CÁCH TÍNH chung — *"dòng
/// tiền tự do là gì"*, *"thuế thu nhập cá nhân tính thế nào"*. Đo Realme: không
/// tool nào nhận nó, mô hình không gọi tool, bậc 1 trả lời lạc đề sau 45 s.
///
/// ⚠️ Đuôi *"là gì"* một mình KHÔNG đủ: *"khoản chi lớn nhất tháng này là gì"*
/// (C18) là câu số liệu. Nên phần TRƯỚC đuôi phải không mang dấu hiệu số liệu
/// riêng nào. Chữ số cố ý không tính — *"quy tắc 50 30 20"* là quy tắc chung.
/// So KHÔNG dấu được ở đây (khác danh sách trên) vì cụm đuôi bỏ dấu vẫn một
/// nghĩa, và người dùng gõ không dấu.
final RegExp _mauDuoiDinhNghia = RegExp(
    r'(?<![a-z0-9])(?:nghia la gi|la gi|tinh nhu the nao|tinh the nao|cach tinh)'
    r'(?: (?:vay|the|a|nhi|ha))?$');

final RegExp _mauSoLieuRieng = RegExp(
    r'(?<![a-z0-9])(?:toi|minh|thang|tuan|nam nay|nam ngoai|hom|ngay|nhat|khoan'
    r'|giao dich|nao|sap toi)(?![a-z0-9])');

bool _laCauDinhNghiaChung(String cauHoi) {
  final q = removeVietnameseTones(normalizeCategoryName(cauHoi))
      .replaceAll(RegExp(r'[?!.]+\s*$'), '')
      .trim();
  final m = _mauDuoiDinhNghia.firstMatch(q);
  return m != null && !_mauSoLieuRieng.hasMatch(q.substring(0, m.start));
}

/// Đường TRÊN MÁY: chặn nhóm sống + nhóm tư vấn + câu định nghĩa chung (như trước
/// 2026-10-11 — hành vi không đổi, có ca canh).
bool chuDeBiChan(String cauHoi) {
  final s = cauHoi.toLowerCase();
  return _tuKhoaSong.any(s.contains) ||
      _tuKhoaTuVan.any(s.contains) ||
      _tuKhoaSongKhongDau.any(s.contains) ||
      _laCauDinhNghiaChung(cauHoi);
}

/// Đường ONLINE: chỉ chặn dữ liệu sống và câu hỏi giá tài sản. Kiến thức / tư vấn
/// chung và câu định nghĩa đi Gemini (người dùng chốt 2026-10-11, câu 2).
bool chuDeBiChanOnline(String cauHoi) {
  final s = cauHoi.toLowerCase();
  return _tuKhoaSong.any(s.contains) ||
      _tuKhoaSongKhongDau.any(s.contains) ||
      _laCauHoiGiaTaiSan(cauHoi);
}
