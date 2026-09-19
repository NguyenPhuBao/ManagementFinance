import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'goi_so.dart';

/// Khoá cache của một gói số: md5 của tên màn + các cặp (nhãn, số thô) **sắp
/// theo nhãn**.
///
/// Sắp xếp để thứ tự dựng danh sách không đổi khoá — stream phát lại sau mỗi
/// chu kỳ đồng bộ dựng lại gói, và đổi khoá vô cớ là gọi mô hình lần hai. Nhãn
/// vào khoá để hai gói cùng số nhưng khác nghĩa không dùng chung câu. Tên màn
/// vào khoá vì cùng con số ở Trang chủ và ở Phân tích là hai câu khác nhau.
String dauVanCua(GoiSo g) {
  final cap = [for (final s in g.soLieu) '${s.nhan}=${s.soTho}']..sort();
  return md5.convert(utf8.encode('${g.man}|${cap.join('|')}')).toString();
}
