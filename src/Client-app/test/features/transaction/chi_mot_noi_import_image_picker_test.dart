/// Test quét `lib/` thứ 20 (A5, 2026-10-08): chỉ màn Quét (và màn đo spike C4) được import `image_picker` — cùng khuôn
/// `chi_mot_noi_import_mlkit_test.dart`. Gói native lọt vào tệp khác là tệp ấy hết test được bằng `flutter test`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chỉ quet_anh_page.dart và màn spike C4 được import image_picker', () {
    const duocPhep = {
      'lib/features/transaction/presentation/pages/quet_anh_page.dart',
      // Màn đo của spike C4 — gỡ khỏi danh sách khi spike gỡ.
      'lib/features/ai_chat/spike/spike_c4_page.dart',
    };
    final coImport = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart'))
          if (f.readAsStringSync().contains('package:image_picker')) f.path.replaceAll(r'\', '/'),
    ];
    expect(coImport, contains('lib/features/transaction/presentation/pages/quet_anh_page.dart'),
        reason: 'tiền đề: phép quét phải thấy được chính tệp được phép — không thấy là quét sai thư mục và xanh giả');
    expect(coImport.where((p) => !duocPhep.contains(p)), isEmpty, reason: 'chọn ảnh chỉ đi qua moQuet');
  });
}
