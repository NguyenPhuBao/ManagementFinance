// test/features/ai_edge/chi_mot_noi_import_gemma_test.dart
/// Test quét `lib/` thứ MƯỜI SÁU: chỉ `slm_runtime.dart` được import
/// `flutter_gemma`.
///
/// Cùng khuôn `realtime_socket.dart` và cùng lý do: gói chạy mô hình có API
/// riêng, đổi bản là đổi chữ ký. Một chỗ import là một chỗ phải sửa khi nâng
/// gói — và một chỗ nữa không ai nhớ ra khi P4 đổi mô hình.
///
/// Nó cũng giữ đúng hình dạng kiến trúc: mọi thứ ngoài tệp ấy nói chuyện với
/// `SlmRuntime` (giao diện thuần), nên test dựng được bản giả mà không cần
/// thiết bị arm64.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chỉ slm_runtime.dart import flutter_gemma', () {
    const duocPhep = 'lib/features/ai_edge/data/slm_runtime.dart';
    final pham = <String>[];

    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final duong = f.path.replaceAll(r'\', '/');
      if (duong == duocPhep) continue;
      final dong = f.readAsLinesSync();
      for (var i = 0; i < dong.length; i++) {
        final l = dong[i].trim();
        if (l.startsWith('//') || l.startsWith('///')) continue;
        if (l.contains("package:flutter_gemma")) {
          pham.add('$duong:${i + 1}: ${l.trim()}');
        }
      }
    }

    expect(pham, isEmpty,
        reason: 'Chỉ `$duocPhep` được import flutter_gemma. Chỗ khác cần mô '
            'hình thì nhận `SlmRuntime` qua tham số.\nVi phạm:\n'
            '${pham.join('\n')}');
  });
}
