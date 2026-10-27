/// B1 (spec 2026-10-27 mục 3) — route dựng `GanDanhMucPage` mang cửa quyền `quick_category_assignment`; khuôn
/// `xuat_bao_cao_co_cua_quyen_test.dart` (đọc thẳng `app_router.dart` — mọi lối vào: thẻ, deeplink).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mọi GoRoute dựng GanDanhMucPage đều có redirectTheoQuyen(MaQuyen.quickCategoryAssignment)', () {
    final nguon = File('lib/core/router/app_router.dart')
        .readAsLinesSync()
        .where((d) => !d.trimLeft().startsWith('//'))
        .join('\n');
    final viTri = RegExp(r'GanDanhMucPage\(').allMatches(nguon).map((m) => m.start).toList();
    expect(viTri, isNotEmpty, reason: 'tiền đề: phép quét phải thấy route dựng màn Gắn danh mục');
    for (final p in viTri) {
      final doan = nguon.substring(nguon.lastIndexOf('GoRoute(', p), p);
      expect(doan, contains('redirectTheoQuyen(MaQuyen.quickCategoryAssignment)'),
          reason: 'thẻ khoá chặn nút; deeplink / lối khác đi thẳng route — cửa phải ở route');
    }
  });
}
