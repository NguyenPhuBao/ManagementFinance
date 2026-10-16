/// Test quét `lib/` thứ 26 (C4, 2026-10-12): mỗi gói giọng nói chỉ được import ở ĐÚNG một tệp — khuôn quét 17 / 20. Gói
/// native lọt vào tệp khác là tệp ấy hết test được bằng `flutter test`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (goi, tep) in [
    ('package:speech_to_text/', 'lib/features/transaction/data/datasources/nghe_android.dart'),
    ('package:record/', 'lib/features/transaction/data/datasources/ghi_am.dart'),
  ]) {
    test('chỉ $tep được import $goi', () {
      final coImport = [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart') && f.readAsStringSync().contains(goi)) f.path.replaceAll(r'\', '/'),
      ];
      expect(coImport, contains(tep),
          reason: 'tiền đề: phép quét phải thấy chính tệp được phép — không thấy là quét sai thư mục và xanh giả');
      expect(coImport.where((p) => p != tep), isEmpty, reason: 'giọng nói chỉ đi qua NguonGiongNoi');
    });
  }
}
