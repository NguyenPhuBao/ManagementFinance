/// Tầng Kotlin của tự chuyển tiền chạy nền là vùng mù của `flutter test`, `flutter analyze` VÀ `flutter build apk`
/// (bẫy 7.11 `NOTIFICATION_FEATURE.md`): lệch tên kênh / phương thức / entrypoint đều **im lặng**. Tệp này đọc mã nguồn
/// từng mối nối — khuôn `phien_ngan_hang_noi_day_test.dart`.
library;

import 'dart:io';

import 'package:flowmoney/core/nen/kenh_tu_chuyen_tien.dart';
import 'package:flutter_test/flutter_test.dart';

const _kt = 'android/app/src/main/kotlin/com/flowmoney/flowmoney/';
String _doc(String p) => File(p).readAsStringSync();

void main() {
  test('TuChuyenTien.kt dùng đúng hai kênh, tên entrypoint và ba phương thức', () {
    final kt = _doc('${_kt}TuChuyenTien.kt');
    expect(kt, contains('"$kKenhTuChuyenTien"'),
        reason: 'lệch tên kênh thì Dart nhận MissingPluginException — bị nuốt, không hẹn gì');
    expect(kt, contains('"$kKenhNen"'));
    expect(kt, contains('"$kEntrypointNen"'), reason: 'lệch tên là engine nền không tìm thấy hàm — lượt nền chết im');
    for (final pt in ['quetNgay', 'nenXong']) {
      expect(kt, contains('"$pt"'));
    }
  });

  test('MainActivity mở kênh henNen, gắn và GỠ engine của app', () {
    final kt = _doc('${_kt}MainActivity.kt');
    expect(kt, contains('"henNen"'));
    expect(kt, contains('TuChuyenTien.ganEngineApp(flutterEngine)'));
    expect(kt, contains('TuChuyenTien.ganEngineApp(null)'),
        reason: 'không gỡ thì worker gửi quetNgay vào engine đã chết, chờ hết 3 phút');
    expect(kt, contains('override fun cleanUpFlutterEngine'));
  });

  test('worker chờ cả nhánh app đang mở lẫn nhánh headless (không trả success ngay)', () {
    final kt = _doc('${_kt}TuChuyenTien.kt');
    expect(RegExp(r'await\(3, TimeUnit\.MINUTES\)').allMatches(kt).length, greaterThanOrEqualTo(2),
        reason: 'trả ngay là WorkManager thả tiến trình — Android đóng băng app giữa lượt quét');
  });

  test('lượt một-lần tự hẹn lượt kế bằng APPEND_OR_REPLACE (REPLACE lên chính nó là tự huỷ)', () {
    expect(_doc('${_kt}TuChuyenTienWorker.kt'), contains('APPEND_OR_REPLACE'));
  });

  test('worker luôn trả success (retry dễ thành vòng lặp tốn pin)', () {
    final kt = _doc('${_kt}TuChuyenTienWorker.kt');
    expect(kt, isNot(contains('Result.retry()')));
    expect(kt, isNot(contains('Result.failure()')));
  });
}
