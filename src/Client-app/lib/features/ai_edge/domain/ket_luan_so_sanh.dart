/// B14 — lưới "nói đúng kết luận" của đường nhanh (2026-10-05, cùng khuôn lưới kể tên C6 người dùng chọn).
///
/// Câu hỏi so hai kỳ (*"tháng này tiêu nhiều hơn tháng trước không"*): tool đã rút sẵn HƯỚNG vào `chuThem['so_sanh_*']`
/// (`themSoSanh`, `hang_giao_dich.dart`), nhưng Gemma có thể chỉ đưa hai con số tổng — đúng số, mọi lớp chắn im, mà không
/// trả lời câu hỏi. Đo Realme 2026-10-05 B14. Câu thiếu hướng, hoặc nói ngược hướng, → mẫu câu (mẫu câu luôn in kết luận,
/// `GoiSoTraCuu._ketLuan`).
///
/// Hàm thuần. So trên chữ đã bỏ dấu: đoán sai chỉ làm màn hiện mẫu câu (vẫn đúng).
library;

import '../../../core/category/category_name.dart';

enum HuongSoSanh { nhieuHon, itHon, bang, khongDuLieu }

String _bo(String s) => removeVietnameseTones(normalizeCategoryName(s));

/// Cách nói từng hướng (đã bỏ dấu). *"thấp hơn"* có thật trong câu Gemma đo 04/10 (F3).
const Map<HuongSoSanh, List<String>> _cachNoi = {
  HuongSoSanh.nhieuHon: ['nhieu hon', 'tang', 'cao hon', 'lon hon', 'vuot'],
  HuongSoSanh.itHon: ['it hon', 'giam', 'thap hon', 'nho hon', 'kem hon'], // không 'kem' trần: bỏ dấu trùng *"kèm"*
  HuongSoSanh.bang: ['bang', 'nhu nhau', 'khong doi'],
  HuongSoSanh.khongDuLieu: ['khong co du lieu', 'chua co du lieu'],
};

bool _co(String c, String cum) => RegExp('(?<![a-z0-9])${RegExp.escape(cum)}(?![a-z0-9])').hasMatch(c);

bool _noi(String c, HuongSoSanh h) => _cachNoi[h]!.any((cum) => _co(c, cum));

/// Các hướng tool đã rút ở khoá `so_sanh_*` của [chuThem]. Rỗng = không phải câu so sánh.
Set<HuongSoSanh> huongCanNoi(Map<String, String> chuThem) => {
      for (final e in chuThem.entries)
        if (e.key.startsWith('so_sanh_'))
          if (_bo(e.value) case final v)
            if (_co(v, 'khong co du lieu'))
              HuongSoSanh.khongDuLieu
            else if (_co(v, 'nhieu hon'))
              HuongSoSanh.nhieuHon
            else if (_co(v, 'it hon'))
              HuongSoSanh.itHon
            else if (_co(v, 'bang'))
              HuongSoSanh.bang,
    };

/// [cau] nêu MỌI hướng trong [can] và không nêu hướng so sánh nào khác (nói ngược, hoặc mơ hồ hai chiều).
bool cauNoiDungHuong(String cau, Set<HuongSoSanh> can) {
  if (can.isEmpty) return true;
  final c = _bo(cau);
  if (!can.every((h) => _noi(c, h))) return false;
  return ![HuongSoSanh.nhieuHon, HuongSoSanh.itHon, HuongSoSanh.bang]
      .where((h) => !can.contains(h))
      .any((h) => _noi(c, h));
}
