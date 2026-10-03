/// Chỉ MỘT tệp của `lib/` (ngoài màn đo spike C4) được import gói đọc chữ ML Kit — cùng khuôn
/// `chi_mot_noi_import_gemma_test.dart`. Gói native lọt vào một tệp thuần thì tệp ấy hết test được bằng `flutter test`,
/// và phần đọc biên lai mất lưới an toàn duy nhất của nó.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chỉ doc_chu_anh_mlkit.dart và màn spike C4 được import google_mlkit_text_recognition', () {
    const duocPhep = {
      'lib/core/ocr/doc_chu_anh_mlkit.dart',
      // Màn đo của spike C4 — gỡ khỏi danh sách khi spike gỡ.
      'lib/features/ai_chat/spike/spike_c4_page.dart',
    };
    final coImport = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart'))
          if (f.readAsStringSync().contains('package:google_mlkit_text_recognition')) f.path.replaceAll(r'\', '/'),
    ];
    expect(coImport, contains('lib/core/ocr/doc_chu_anh_mlkit.dart'),
        reason: 'tiền đề: phép quét phải thấy được chính tệp được phép — không thấy là quét sai thư mục và xanh giả');
    expect(coImport.where((p) => !duocPhep.contains(p)), isEmpty,
        reason: 'gói native chỉ vào app qua giao diện DocChuAnh');
  });
}
