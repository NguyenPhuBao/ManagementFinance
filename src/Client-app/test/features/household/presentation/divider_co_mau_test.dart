import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `Divider` không truyền màu lấy `dividerColor` của theme: đen đậm giữa thẻ trắng (máy ảo 2026-11-01). Mọi vạch ngăn trong
/// `household/presentation` phải nêu màu, như `AppColors.outlineVariant`.
void main() {
  test('mọi Divider trong household/presentation đều có color:', () {
    final goc = Directory('lib/features/household/presentation');
    final thieu = <String>[];
    var tong = 0;
    for (final f in goc.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      for (final m in RegExp(r'Divider\(([^)]*)\)').allMatches(s)) {
        tong++;
        if (!m.group(1)!.contains('color:')) thieu.add(f.path);
      }
    }
    expect(tong, greaterThanOrEqualTo(5), reason: 'tiền đề: phép quét phải thấy các vạch ngăn đã biết');
    expect(thieu, isEmpty, reason: 'Divider thiếu màu: $thieu');
  });
}
