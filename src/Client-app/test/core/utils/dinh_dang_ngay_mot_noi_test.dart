/// Test quét `lib/` thứ **32** — `DateFormat` chỉ được dựng trong `core/utils/date_formatter.dart` (báo cáo soát kiến
/// trúc 2026-10-18 mục 6, quyết định phiên 2 điểm 6, sửa 2026-10-19).
///
/// Vì sao: tới 2026-10-19 có 37 dòng mã nhắc `DateFormat` ở 31 tệp trong khi `DateFormatter` có sẵn — hai đường song song
/// cho cùng chữ "03/08/2026", và ba kiểu ngày-giờ (`dd/MM/yyyy HH:mm`, `HH:mm dd/MM/yyyy`, cộng `HH:mm, dd/MM/yyyy` của
/// `DateFormatter` cũ không ai gọi). Mẫu mới thì thêm HÀM vào `DateFormatter`.
///
/// Quét: ngoài tệp định nghĩa, không dòng MÃ nào (dòng bắt đầu bằng `//` bỏ qua) chứa từ trọn `DateFormat` — bắt cả lời
/// dựng `DateFormat(` lẫn kiểu tham số `DateFormat formatter` (cách cũ truyền bộ định dạng xuống hàm con), cả
/// `import … show DateFormat`. Không bắt `DateFormatter` / `initializeDateFormatting` (khác từ trọn).
///
/// Giới hạn đã biết: không bắt dựng ngày bằng tay (`'${d.day}/${d.month}'` — vd. `chuKhoangNgay` ở `ai_edge/domain/ma_ky.dart`,
/// `_ngayGon` ở `notification_rules.dart`); những chỗ ấy là câu chữ / khoá thuần không đi qua `intl`, cố ý giữ.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _mau = RegExp(r'\bDateFormat\b');
const _tepDinhNghia = 'lib/core/utils/date_formatter.dart';

void main() {
  test('ngoài date_formatter.dart không dòng mã nào nhắc DateFormat', () {
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
    expect(vi, isEmpty,
        reason: 'Gọi hàm của `DateFormatter` (thêm hàm nếu mẫu chưa có) thay vì dựng `DateFormat` tại chỗ. '
            'Thấy ${vi.length} dòng: $vi');
  });

  test('tệp định nghĩa còn dựng DateFormat (quét không chạy trên tệp rỗng)', () {
    expect(File(_tepDinhNghia).readAsStringSync(), contains('DateFormat('),
        reason: 'đổi tên / dời DateFormatter thì phải sửa _tepDinhNghia, không thì quét miễn nhầm tệp');
  });
}
