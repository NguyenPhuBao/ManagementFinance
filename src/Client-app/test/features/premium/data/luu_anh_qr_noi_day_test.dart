/// Nối dây kênh `flowmoney/luu_anh` (spec G94 2026-10-18 mục 5.3): tên kênh / hàm ở Dart phải khớp `MainActivity.kt`,
/// và phía Kotlin ghi vào Thư viện ảnh (MediaStore.Images), không phải thư mục Tải về. `flutter test` không chạy Kotlin
/// — test đọc tệp nguồn.
library;

import 'dart:io';

import 'package:flowmoney/features/premium/data/luu_anh_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tên kênh / hàm khớp MainActivity.kt; Kotlin ghi MediaStore.Images ở Pictures/FlowMoney', () {
    final kt = File('android/app/src/main/kotlin/com/flowmoney/flowmoney/MainActivity.kt').readAsStringSync();
    expect(LuuAnhQr.kenh.name, 'flowmoney/luu_anh');
    expect(kt, contains('"flowmoney/luu_anh"'));
    expect(kt, contains('"luuAnh"'));
    expect(kt, contains('MediaStore.Images.Media.EXTERNAL_CONTENT_URI'));
    expect(kt, contains('Environment.DIRECTORY_PICTURES'));
    expect(kt, contains('Build.VERSION_CODES.Q'), reason: 'RELATIVE_PATH cần Android 10 — máy cũ trả false');
  });
}
