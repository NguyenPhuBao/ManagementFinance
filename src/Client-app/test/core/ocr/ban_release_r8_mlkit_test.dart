/// Bản RELEASE phải dựng được khi có gói đọc chữ ML Kit (đo 2026-10-03). Plugin `google_mlkit_text_recognition`
/// tham chiếu lớp tuỳ chọn của bốn hệ chữ Trung · Devanagari · Nhật · Hàn mà nó chỉ khai `compileOnly` — không đóng gói.
/// R8 (thu gọn mã của bản release) coi lớp thiếu là LỖI: `flutter build apk --release` gãy ở `minifyReleaseWithR8`,
/// trong khi bản debug (không chạy R8), `flutter test` và `flutter analyze` đều xanh. Bản release đã gãy như thế từ
/// lúc spike C4 thêm gói (2026-10-01) tới khi tệp quy tắc ra đời — không ai dựng release giữa hai mốc nên không lộ.
///
/// Flutter Gradle plugin tự nạp `android/app/proguard-rules.pro` khi tệp TỒN TẠI (`FlutterPlugin.kt`), không cần
/// khai trong `build.gradle.kts`. Mã của app chỉ dùng `TextRecognitionScript.latin` (nhánh 0 của
/// `TextRecognizer.initialize` phía Kotlin), nên bốn nhánh kia không bao giờ chạy và `-dontwarn` là an toàn.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('có gói ML Kit thì proguard-rules.pro bỏ qua lớp thiếu của bốn hệ chữ không dùng', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('google_mlkit_text_recognition:'),
        reason: 'tiền đề: gói còn trong pubspec — gỡ gói thì xoá luôn ca này lẫn tệp quy tắc');

    final tep = File('android/app/proguard-rules.pro');
    expect(tep.existsSync(), isTrue,
        reason: 'thiếu tệp thì R8 dừng ở "Missing class com.google.mlkit.vision.text.chinese…" và bản release '
            'không dựng được');
    final quyTac = tep.readAsStringSync();
    for (final heChu in ['chinese', 'devanagari', 'japanese', 'korean']) {
      expect(quyTac, contains('-dontwarn com.google.mlkit.vision.text.$heChu.**'),
          reason: 'lớp tuỳ chọn hệ chữ $heChu chỉ là compileOnly của plugin — R8 phải được dặn bỏ qua');
    }
  });

  test('quy tắc chỉ BỎ QUA cảnh báo, không giữ (keep) gì của ML Kit', () {
    // `-keep` cho cả gói ML Kit làm R8 thôi thu gọn nó: APK phình mà không sửa được gì — lỗi là lớp THIẾU, không phải
    // lớp bị cắt nhầm.
    final quyTac = File('android/app/proguard-rules.pro').readAsStringSync();
    final dong = quyTac.split('\n').map((d) => d.trim()).where((d) => d.isNotEmpty && !d.startsWith('#'));
    expect(dong.where((d) => d.contains('mlkit') && !d.startsWith('-dontwarn ')), isEmpty);
  });
}
