/// C6 — lưới kiểm "kể đủ tên" của đường nhanh (người dùng chọn 2026-10-05: *"Gemma viết + lưới kiểm đủ dòng"*).
///
/// Câu hỏi muốn KỂ TÊN các khoản (*"tháng trước tôi có khoản chi nào trên 1 triệu không"*) mà tool trả ≥ 2 hàng thì
/// câu Gemma viết phải nêu tên MỌI hàng. Đo Realme 2026-10-04: sổ trả 2 khoản, Gemma kể 1 — mọi lớp chắn im vì câu
/// không sai số nào, chỉ THIẾU. Thiếu thì màn hiện mẫu câu đủ dòng thay cho câu của Gemma (`_vietCauDuongNhanh`).
///
/// Hàm thuần. Không cùng việc với `cauHoiLietKe` (`chinh_tham_so.dart`): hàm ấy ÉP mẫu câu ngay từ tool cho câu
/// *"những lần / N khoản"* (cổng F, H1); hàm này để Gemma viết rồi mới xét.
library;

import '../../../core/category/category_name.dart';

String _bo(String s) => removeVietnameseTones(normalizeCategoryName(s));

/// *"khoản … nào"*, *"giao dịch nào"*, *"lần nào"*, *"những / các khoản · giao dịch · lần"*, *"liệt kê"*,
/// *"<số> khoản / giao dịch"*. Xét trên chữ đã bỏ dấu. ⚠️ *"bao nhiêu khoản"* là câu ĐẾM, *"danh mục nào"* hỏi một
/// đối tượng — không thuộc đây.
final RegExp _mauKeTen = RegExp(r'(?<![a-z0-9])(?:'
    r'(?:khoan|giao dich|lan)(?: [a-z]+)? nao'
    r'|(?:nhung|cac) (?:khoan|giao dich|lan)'
    r'|liet ke'
    r'|\d+ (?:khoan|giao dich)'
    r')(?![a-z0-9])');

bool cauHoiKeTen(String cauHoi) => _mauKeTen.hasMatch(_bo(cauHoi));

/// Các tên trong [ten] mà [cau] chưa nêu — so bỏ dấu, không phân biệt hoa thường, khớp TRỌN từ. Tên trùng nhau xét
/// một lần. So bỏ dấu ở đây là chủ ý: đoán sai chỉ làm màn hiện mẫu câu (vẫn đúng), không bao giờ làm hiện câu sai.
List<String> tenChuaNeu(String cau, Iterable<String> ten) {
  final c = _bo(cau);
  return [
    for (final t in {...ten})
      if (!RegExp('(?<![a-z0-9])${_bo(t).split(' ').map(RegExp.escape).join(r'\s+')}(?![a-z0-9])').hasMatch(c)) t,
  ];
}
