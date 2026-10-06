/// Chỉ MỘT tệp của `lib/` được import `url_launcher` — khuôn `realtime_socket.dart`
/// / `chi_mot_noi_import_mlkit_test.dart` (test quét `lib/` thứ 18). Gói native
/// lọt vào tệp thuần là tệp ấy hết test được, và mọi màn mở link sẽ tự gọi nền
/// tảng thay vì đi qua khe tiêm `MoLienKet`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chỉ premium/data/mo_lien_ket.dart import url_launcher', () {
    const duocPhep = 'lib/features/premium/data/mo_lien_ket.dart';
    final coImport = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart'))
          if (f.readAsStringSync().contains('package:url_launcher'))
            f.path.replaceAll(r'\', '/'),
    ];
    expect(coImport, contains(duocPhep),
        reason: 'tiền đề: phép quét phải thấy chính tệp được phép — không thấy là quét sai thư mục và xanh giả');
    expect(coImport.where((p) => p != duocPhep), isEmpty,
        reason: 'gói native chỉ vào app qua moLienKetNgoai');
  });
}
