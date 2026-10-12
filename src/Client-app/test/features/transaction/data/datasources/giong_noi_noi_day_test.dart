/// C4 — tầng Android của giọng nói phải được NỐI vào app thật. Manifest và Kotlin là vùng mù của `flutter test`,
/// `flutter analyze` VÀ `flutter build apk` (bẫy 7.11 `NOTIFICATION_FEATURE.md`) — khuôn `bien_dong_noi_day_test.dart`.
library;

import 'dart:io';

import 'package:flowmoney/features/transaction/data/datasources/kenh_micro.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(String p) => File(p).readAsStringSync();

void main() {
  test('manifest CHÍNH xin RECORD_AUDIO và khai RecognitionService; manifest debug thôi mang chúng', () {
    final m = _doc('android/app/src/main/AndroidManifest.xml');
    expect(m, contains('android.permission.RECORD_AUDIO'),
        reason: 'thiếu thì bản release không bao giờ hỏi quyền micro — nút micro im lặng');
    expect(m, contains('android.speech.RecognitionService'),
        reason: 'Android 11+: không khai <queries> thì app không thấy dịch vụ nhận dạng — lối Android luôn "không có"');
    final d = _doc('android/app/src/debug/AndroidManifest.xml');
    expect(d, isNot(contains('RECORD_AUDIO')), reason: 'quyền đã dời sang manifest chính — khai hai nơi là che lỗi');
  });

  test('MainActivity mở kênh flowmoney/micro đủ hai phương thức', () {
    final kt = _doc('android/app/src/main/kotlin/com/flowmoney/flowmoney/MainActivity.kt');
    expect(kt, contains('"$kKenhMicro"'), reason: 'tên kênh lệch thì Dart nhận MissingPluginException — im lặng');
    for (final pt in ['biChan', 'moCaiDat']) {
      expect(kt, contains('"$pt"'));
    }
  });
}
