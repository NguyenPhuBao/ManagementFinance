/// Test quét `lib/` thứ **33** — chữ phần trăm từ một tỉ lệ (`0.42` → `42%`) có MỘT định nghĩa: `chuPhanTram`
/// (`core/utils/phan_tram.dart`; báo cáo soát kiến trúc 2026-10-18 mục 6, sửa 2026-10-19).
///
/// Vì sao: tới 2026-10-19 có bảy bản viết tay `'${(x * 100).round()}%'` ở năm tệp (màn tải mô hình, hai khối Phân tích,
/// luật thông báo ngân sách, dòng log tải nền) và một bản thứ tám dạng biến nhân 100 sẵn (`home_budget_card`), gỡ cùng
/// ngày sau review toàn nhánh — quét không bắt dạng ấy (giới hạn bên dưới) — cùng phép, không chỗ nào nói phép ấy làm tròn kiểu gì.
///
/// Quét: ngoài tệp định nghĩa, không dòng MÃ nào (dòng bắt đầu bằng `//` bỏ qua) khớp `* 100).round()}%`.
///
/// Giới hạn đã biết: chỉ bắt đúng dạng nội suy ấy — không bắt `toStringAsFixed(…)}%`, biến đã nhân 100 sẵn (`'$p%'`),
/// hay phép làm tròn khác (`floor`, `ceil`). Những dạng ấy có thể cố ý khác — thêm vào quét thì phải xét từng chỗ.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _mau = RegExp(r'\*\s*100\)\.round\(\)\}%');
const _tepDinhNghia = 'lib/core/utils/phan_tram.dart';

void main() {
  test('ngoài phan_tram.dart không dòng mã nào tự viết (x * 100).round()}%', () {
    final vi = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      final p = f.path.replaceAll(r'\', '/');
      if (p.endsWith(_tepDinhNghia)) continue;
      final dong = f.readAsLinesSync();
      for (var i = 0; i < dong.length; i++) {
        final d = dong[i].trimLeft();
        if (d.startsWith('//')) continue;
        if (_mau.hasMatch(d)) vi.add('$p:${i + 1}: ${d.trim()}');
      }
    }
    expect(vi, isEmpty, reason: 'Gọi `chuPhanTram(tiLe)` thay cho bản viết tay. Thấy: $vi');
  });
}
