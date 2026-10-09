/// Câu chào ở màn Trợ lý AI — nhận ra TRƯỚC vòng lặp tool, để Gemma đáp trong một lượt sinh KHÔNG tool.
///
/// Đo OnePlus 2026-10-09: *"xin chao ban"* đi phiên sáu tool, mô hình gọi nhầm `truy_van_giao_dich` rồi đáp *"Tôi đã
/// tìm thấy các giao dịch trong kỳ tháng này."* sau 15 s; trên Realme câu chào từng mất ~23 s (L1 vứt câu mô hình rồi
/// sinh lại ở bậc 1). Người dùng chọn: mô hình vẫn đáp (tính năng AI phải dùng mô hình), chỉ không tra cứu.
///
/// Hàm thuần, không đồng hồ, không truy vấn.
library;

import '../../../core/category/category_name.dart';
import 'gac_cau.dart';
import 'kiem_so.dart';

/// Cụm LÕI — câu phải chứa ít nhất một cụm (so trên chữ đã bỏ dấu: nhận dạng, đoán sai chỉ tốn một lượt sinh).
const List<List<String>> _cumLoi = [
  ['chao'],
  ['hello'],
  ['hi'],
  ['alo'],
  ['hey'],
  ['cam', 'on'],
  ['thanks'],
  ['thank'],
  ['tam', 'biet'],
  ['bye'],
  ['la', 'ai'],
  ['giup', 'duoc', 'gi'],
  ['lam', 'duoc', 'gi'],
];

/// Từ đệm được phép đứng cạnh cụm lõi. Có một từ ngoài tập này (*chi tiêu*, *tháng*, *ví*…) là câu có nội dung cần
/// tra cứu → đi đường tool như cũ. ⚠️ Không có *chị*: chuỗi `'chi'` đứng riêng bị test quét 14 cấm trong `ai_edge/`
/// (dễ thành phép so chiều tiền) — *"chào chị"* đi đường tool, mất mát nhỏ.
const Set<String> _tuDem = {
  'xin', 'ban', 'oi', 'nhe', 'nha', 'a', 'ah', 'minh', 'toi', 'em', 'anh', 'nhieu', 'rat', 'buoi', 'sang',
  'trua', 'chieu', 'good', 'morning', 'you', 'so', 'much', 'ha', 'co', 'the', 've',
};

List<String> _tu(String cau) => removeVietnameseTones(cau.toLowerCase())
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toList();

bool _coCum(List<String> tu, List<String> cum) {
  for (var i = 0; i + cum.length <= tu.length; i++) {
    var khop = true;
    for (var j = 0; j < cum.length; j++) {
      if (tu[i + j] != cum[j]) {
        khop = false;
        break;
      }
    }
    if (khop) return true;
  }
  return false;
}

/// Câu chỉ gồm lời chào / cảm ơn / tạm biệt / hỏi trợ lý là ai — không nội dung nào cần tra cứu.
bool laCauChao(String cau) {
  final tu = _tu(cau);
  if (tu.isEmpty) return false;
  final cum = [for (final c in _cumLoi) if (_coCum(tu, c)) c];
  if (cum.isEmpty) return false;
  final choPhep = {..._tuDem, for (final c in cum) ...c};
  return tu.every(choPhep.contains);
}

/// Bộ kiểm cho câu chào: CHỈ chốt chữ số — gói rỗng nên mọi con số đều là bịa. ⚠️ Không dùng `kiemCauTraLoi`:
/// `kiemTen` của nó đọc *"mục tiêu tiết kiệm"*, *"ví của bạn"* là tên đối tượng không có trong gói và chặn oan câu gợi
/// ý của Gemma (nghiệm thu OnePlus 2026-10-09).
bool kiemCauChao(String cau) => kiemSoNhieuGoi(cau, const []);

/// Câu khi mọi câu Gemma viết đều bị bộ kiểm chặn (vd. bịa một con số) — giữ lời mở đầu của màn.
const String kCauChaoDuPhong =
    'Xin chào! Mình trả lời dựa trên số liệu trong app của bạn — chi tiêu, ngân sách, hoá đơn, mục tiêu, ví. '
    'Bạn muốn biết gì?';

/// Không câu nào qua kiểm thì nối [kCauChaoDuPhong] — để màn không hiện câu *"không chắc chắn"* cho một lời chào.
Stream<SuKienGac> kemDuPhongChao(Stream<SuKienGac> luong) async* {
  var coCau = false;
  await for (final sk in luong) {
    if (sk is CauQua) coCau = true;
    yield sk;
  }
  if (!coCau) yield const CauQua(kCauChaoDuPhong);
}
