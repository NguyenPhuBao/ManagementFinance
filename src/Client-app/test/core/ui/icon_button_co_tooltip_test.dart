/// Mọi `IconButton` trong `lib/` phải có `tooltip` — test quét `lib/` thứ
/// **mười hai** (2026-09-19, UX G1).
///
/// Nút chỉ có icon (chuông, ⋮, lịch, mắt ẩn mật khẩu, tải xuống…) không có
/// nhãn nào cho TalkBack/VoiceOver đọc và không có nhãn nào hiện khi nhấn giữ.
/// Lượt đánh giá UX 2026-09-19 đếm được **0** `Semantics`/`tooltip` ngoài 13
/// nút; `tooltip` của `IconButton` cho cả hai thứ ấy cùng lúc — rẻ nhất trong
/// mọi lối. `flutter analyze` không nói gì về nút thiếu nhãn, nên phải quét.
///
/// Luật: trong **8 dòng** kể từ dòng có `IconButton(` phải xuất hiện
/// `tooltip:`. Nút dựng qua widget khác (`NotificationBell`, `GestureDetector`)
/// không nằm trong phép quét này — chúng có `Semantics` riêng hoặc là việc
/// sau (G1 chỉ khép phần rẻ nhất).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mọi IconButton trong lib/ có tooltip', () {
    final thieu = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final dongs = f.readAsLinesSync();
      for (var i = 0; i < dongs.length; i++) {
        if (!dongs[i].contains('IconButton(')) continue;
        // Bỏ chú thích và các biến thể có sẵn nhãn (`IconButton.filled` vẫn
        // phải có tooltip; chỉ dòng chú thích là bỏ).
        if (dongs[i].trimLeft().startsWith('//')) continue;
        final cuoi = (i + 8).clamp(0, dongs.length);
        final coTooltip =
            dongs.sublist(i, cuoi).any((d) => d.contains('tooltip:'));
        if (!coTooltip) {
          thieu.add('${f.path.replaceAll('\\', '/')}:${i + 1}');
        }
      }
    }
    expect(thieu, isEmpty,
        reason: 'IconButton thiếu tooltip (không nhãn cho trình đọc màn hình, '
            'không nhãn khi nhấn giữ):\n  ${thieu.join('\n  ')}');
  });
}
