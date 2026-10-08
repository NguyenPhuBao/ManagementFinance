/// Mọi route dựng `ExportReportPage` phải mang cửa quyền `export_reports` (spec phân quyền 2026-10-08 mục 4.3).
///
/// Nghiệm thu OnePlus 2026-10-08 bắt: app có HAI route tới trang Xuất báo cáo — `/export-report` (drawer, thông báo
/// Tổng kết tuần) và `/analytics/export` (nút tải ở trang Phân tích) — mà cửa chỉ gắn ở route đầu, nên Basic bị tắt
/// quyền vẫn mở được trang bằng nút tải. `router_chan_theo_goi_test` tự dựng router nhỏ nên mù với route thứ hai;
/// ca này đọc thẳng `app_router.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mọi GoRoute dựng ExportReportPage đều có redirectTheoQuyen(MaQuyen.exportReports)', () {
    final nguon = File('lib/core/constants/app_router.dart')
        .readAsLinesSync()
        .where((d) => !d.trimLeft().startsWith('//'))
        .join('\n');

    final viTri = RegExp(r'ExportReportPage\(').allMatches(nguon).map((m) => m.start).toList();
    expect(viTri, isNotEmpty, reason: 'tiền đề: phép quét phải thấy route dựng trang Xuất báo cáo');

    final thieu = <String>[];
    for (final p in viTri) {
      final dau = nguon.lastIndexOf('GoRoute(', p);
      final doan = nguon.substring(dau, p);
      if (!doan.contains('redirectTheoQuyen(MaQuyen.exportReports)')) {
        final path = RegExp(r"path:\s*'([^']*)'").firstMatch(doan)?.group(1) ?? '?';
        thieu.add(path);
      }
    }
    expect(thieu, isEmpty,
        reason: 'Route tới trang Xuất báo cáo thiếu cửa quyền — Basic bị tắt `export_reports` vẫn vào được: $thieu');
  });
}
