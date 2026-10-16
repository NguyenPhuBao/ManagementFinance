/// Bộ đọc chỉ thị Dart (`import` / `export` / `part`) dùng chung cho test quét 25, 27, 28 (từ 2026-10-16).
///
/// Vì sao có: ba quét từng đọc chỉ thị TỪNG DÒNG bằng regex neo đầu dòng `import|export`. Cách ấy mù bốn thứ, cả bốn là
/// đường phụ thuộc thật: (1) `part 'x.dart';` — kéo tệp khác vào cùng thư viện (không tính `part of`, trỏ ngược về cha);
/// (2) vế `if (dart.library.x) '…'` của import có điều kiện, thường nằm ở dòng kế; (3) chỉ thị trải nhiều dòng (`show` /
/// `as` xuống dòng); (4) `export` ở quét 27. Đọc cả tệp một lần bằng regex nhiều dòng thì bốn thứ ấy thấy hết.
///
/// Ba giới hạn đã biết (preflight 2026-10-16: hiện 0 trường hợp trong `lib/`): dòng DẠNG chỉ thị nằm TRONG chuỗi `'''`
/// bị bắt nhầm; chú thích chen GIỮA các vế `if (…)` làm hụt vế sau;
/// (3) dòng chỉ thị nằm trong chú thích khối `/* … */` bị bắt nhầm (regex cũ cũng vậy).
library;

/// Dựng BOM bằng mã ký tự, không gõ ký tự thật vào mã nguồn.
final _bom = String.fromCharCode(0xFEFF);

/// `import|export|part` ở đầu dòng (thụt lề được, BOM được), `part of` bị loại; nhóm 1 là đường chính, nhóm 2 là chuỗi vế
/// điều kiện.
final _chiThi = RegExp(
  '^$_bom?[ \\t]*(?:import|export|part)\\s*(?!of\\b)[\'"]([^\'"]+)[\'"]'
  '((?:\\s*if\\s*\\([^)]*\\)\\s*[\'"][^\'"]+[\'"])*)',
  multiLine: true,
);

final _veDieuKien = RegExp('if\\s*\\([^)]*\\)\\s*[\'"]([^\'"]+)[\'"]');

/// Mọi đường (URI) trong chỉ thị `import` / `export` / `part` của [noiDung], theo thứ tự xuất hiện; chỉ thị có điều kiện
/// trả cả đường chính lẫn từng vế `if (…) '…'` (không khử trùng).
List<String> duongChiThi(String noiDung) {
  final ra = <String>[];
  for (final m in _chiThi.allMatches(noiDung)) {
    ra.add(m.group(1)!);
    for (final v in _veDieuKien.allMatches(m.group(2) ?? '')) {
      ra.add(v.group(1)!);
    }
  }
  return ra;
}

/// Chuẩn hoá `a/b/../c` → `a/c` (dấu `/`).
String _chuan(String p) {
  final ra = <String>[];
  for (final s in p.replaceAll('\\', '/').split('/')) {
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (ra.isNotEmpty) ra.removeLast();
      continue;
    }
    ra.add(s);
  }
  return ra.join('/');
}

/// Đích (tương đối `src/Client-app`, vd. `lib/features/x/domain/y.dart`) của đường [duong] viết trong tệp [tep]
/// (đường dạng `lib/...`, dấu `/`); `null` = `dart:` / gói ngoài. `package:flowmoney/…` → `lib/…`.
String? dichTrongLib(String tep, String duong) {
  if (duong.startsWith('package:flowmoney/')) return _chuan('lib/${duong.substring('package:flowmoney/'.length)}');
  if (duong.contains(':')) return null;
  return _chuan('${tep.substring(0, tep.lastIndexOf('/'))}/$duong');
}
