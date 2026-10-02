/// Lớp chắn thứ SÁU — CHỮ KỲ lệch kỳ của con số (G5 (b) cổng F, spec
/// `2026-09-28-g5-chan-menh-de-sai-design.md` §3). E21 bậc 1: *"Thu hôm nay là
/// 15.135.000 đ"* — số là thu THÁNG NÀY của Trang chủ, nhãn "Thu" có trong câu,
/// năm lớp cũ cho qua. Họ lỗi ấy không chỉ ở câu hỏi ngày giờ: *"hôm nay tôi chi
/// bao nhiêu"* rơi bậc 1 cũng nhận đúng câu SAI ấy.
///
/// Luật: vế (`cacVeCua`) có chữ kỳ tương đối P; với mỗi số của vế, nếu MỌI mục
/// khớp nó có kỳ đã biết (`GoiSo.kyCua` khác `null`) và không P nào thuộc hợp các
/// kỳ ấy → chặn. Kỳ không biết thì không xét — sai theo chiều an toàn ở tầng này
/// là CHO QUA, vì chắn oan đã vấp nhiều lần (bẫy 4.49, 4.50).
///
/// ⚠️ "Kỳ không biết" KHÔNG gồm lượt tra cứu *mọi thời gian* và *kỳ tự do* (từ
/// 2026-10-02, mục 9.45 `AI_EDGE_FEATURE.md`): kỳ của chúng đã biết, chỉ là
/// không phải chữ kỳ tương đối — `GoiSoTraCuu.kyCua` trả tập chỉ gồm kỳ TƯƠNG
/// ĐƯƠNG (`KetQuaCongCu.kyTuongDuong`), nên *"Tháng này bạn đã chi…"* cho số
/// của tháng 9 bị chặn. Đo Realme: câu ấy từng được hiện.
library;

import '../../../core/category/category_name.dart';
import 'goi_so.dart';
import 'kiem_nhan.dart';
import 'kiem_so.dart';

/// Chữ kỳ TƯƠNG ĐỐI — không có *hiện tại, bây giờ*: số dư ví "hiện tại" đúng
/// với mọi kỳ.
const List<String> kChuKyTuongDoi = [
  'hôm nay', 'hôm qua', 'tuần này', 'tuần trước', 'tháng này', 'tháng trước',
  'quý này', 'quý trước', 'năm nay', 'năm trước', 'năm ngoái',
];

String _bo(String s) => removeVietnameseTones(normalizeCategoryName(s));

/// "năm ngoái" và "năm trước" là một kỳ.
String _quy(String boDau) => boDau == 'nam ngoai' ? 'nam truoc' : boDau;

/// Chữ kỳ tương đối có trong [chuoi] — dạng bỏ dấu, trọn từ, đã quy.
Set<String> chuKyTrong(String chuoi) {
  final q = _bo(chuoi);
  return {
    for (final k in kChuKyTuongDoi)
      if (RegExp('(?<![a-z0-9])${RegExp.escape(_bo(k))}(?![a-z0-9])').hasMatch(q))
        _quy(_bo(k)),
  };
}

/// [chuoi] là ĐÚNG một chữ kỳ tương đối (khoá `ky` của một lượt tool).
bool laChuKyTuongDoi(String chuoi) =>
    kChuKyTuongDoi.any((k) => _bo(k) == _bo(chuoi));

bool kiemKy(String cau, List<GoiSo> goi) {
  for (final ve in cacVeCua(cau)) {
    final p = chuKyTrong(ve);
    if (p.isEmpty) continue;
    for (final x in trichSoNgoaiTen(ve, goi)) {
      final ky = <String>{};
      var coMuc = false;
      var biet = true;
      for (final g in goi) {
        for (final s in soLieuKhop(x, [g])) {
          coMuc = true;
          final k = g.kyCua(s);
          if (k == null) {
            biet = false;
          } else {
            ky.addAll(k.map((e) => _quy(_bo(e))));
          }
        }
      }
      if (coMuc && biet && p.intersection(ky).isEmpty) return false;
    }
  }
  return true;
}
