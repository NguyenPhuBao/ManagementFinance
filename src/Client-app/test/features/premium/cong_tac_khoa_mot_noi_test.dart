/// Test quét `lib/` thứ **41** (2026-10-28, G111): công tắc khoá theo quyền đi qua MỘT widget — `CongTacTheoQuyen`
/// (`premium/presentation/widgets/the_khoa_quyen.dart`), nơi công tắc bị khoá được vẽ mờ 50 % + ổ khoá trong núm (Stitch
/// `68593384…`). Khuôn cũ `Switch(onChanged: context.coQuyen(…) ? … : null, activeTrackColor: …)` khoá được mà KHÔNG mờ:
/// màu đặt cứng thắng màu khoá mặc định của Material 3, công tắc bị khoá vẽ y hệt công tắc mở (đo 2026-10-28) — không lỗi
/// nào báo, chỉ mắt người thấy. Cấm: lời gọi `Switch(` / `HangCongTac(` mà đối số nhắc `coQuyen` không qua `biKhoa:`
/// (`HangCongTac` nhận `biKhoa:` và chuyển cho `CongTacTheoQuyen`; `Switch` trần thì không có lối hợp lệ nào).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _mo = RegExp(r'(?<![A-Za-z0-9_])(Switch|HangCongTac)\s*\(');

/// Đối số của lời gọi mở ở [batDau] (vị trí ngay sau `(`), tới ngoặc đóng cân bằng.
String _doiSo(String s, int batDau) {
  var sau = 1;
  for (var i = batDau; i < s.length; i++) {
    final c = s[i];
    if (c == '(') sau++;
    if (c == ')' && --sau == 0) return s.substring(batDau, i);
  }
  return s.substring(batDau);
}

/// Lời gọi hỏi quyền theo gói (`context.coQuyen(…)`, `coQuyenDoc(…)`, `coQuyenNen(…)`) — không khớp `_coQuyenOs` (quyền
/// thông báo của hệ điều hành ở Cài đặt thông báo, không phải quyền theo gói).
final _hoiQuyen = RegExp(r'\bcoQuyen(Doc|Nen)?\s*\(');

bool _khoaBangOnChanged(String doiSo) => _hoiQuyen.hasMatch(doiSo) && !doiSo.contains('biKhoa:');

List<String> _viPham(String tep, String s) => [
      for (final m in _mo.allMatches(s))
        if (_khoaBangOnChanged(_doiSo(s, m.end))) '$tep:${'\n'.allMatches(s.substring(0, m.start)).length + 1}',
    ];

void main() {
  test('đối chứng dương: mẫu bắt được khuôn cũ (Switch + coQuyen, cả khi xuống dòng và có ngoặc lồng)', () {
    const cu = '''
      Switch(
        key: const ValueKey('x'),
        value: bat,
        onChanged: context.coQuyen(MaQuyen.billAutoPay)
            ? (v) => setState(() => bat = v)
            : null,
      ),
      HangCongTac(khoa: k, giaTri: g, onChanged: context.coQuyen(MaQuyen.dailyRecordingReminder) ? f : null),
      Switch(value: a, onChanged: (v) => f(v)),
      HangCongTac(khoa: k, giaTri: g, onChanged: f, biKhoa: !context.coQuyen(MaQuyen.dailyRecordingReminder)),
      HangCongTac(khoa: k, giaTri: _prefs.osBat && _coQuyenOs, onChanged: f),
    ''';
    expect(_viPham('mau', cu), ['mau:1', 'mau:8'],
        reason: 'mẫu không khớp khuôn cũ thì quét dưới xanh vì mù; công tắc không theo quyền, HangCongTac(biKhoa:) và '
            'quyền hệ điều hành (_coQuyenOs) không phải vi phạm');
  });

  test('không Switch( / HangCongTac( nào khoá theo quyền bằng onChanged — đi qua CongTacTheoQuyen (biKhoa:)', () {
    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      viPham.addAll(_viPham(f.path.replaceAll(r'\', '/'), f.readAsStringSync()));
    }
    expect(viPham, isEmpty,
        reason: 'G111: công tắc khoá theo quyền phải vẽ mờ + ổ khoá — dùng CongTacTheoQuyen(biKhoa: !context.coQuyen(…))');
  });
}
