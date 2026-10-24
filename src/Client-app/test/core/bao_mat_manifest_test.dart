/// Cấu hình bảo mật của manifest Android (siết bảo mật đợt 2, 2026-10-24) — vùng mù của `flutter test`, `flutter
/// analyze` và cả `flutter build apk` (bẫy 7.11 `NOTIFICATION_FEATURE.md`), nên canh bằng cách đọc tệp.
///
/// 1. `flutter_deeplinking_enabled=false` ở `MainActivity`: activity khởi chạy phải `exported`, và từ Flutter 3.27
///    deeplink bật mặc định — mọi app trên máy gửi được intent tường minh kèm extra `route` / data để mở BẤT KỲ route
///    nào của go_router với tham số điền sẵn (form `/add` mang nhãn *"Từ thông báo MB Bank"* giả, `/add?noi=1` bật micro).
///    App không dùng lối ấy: bấm thông báo đi qua payload của plugin, thông báo tóm tắt D1 đi qua extra riêng.
/// 2. Tắt sao lưu + chuyển máy: SQLite (KHÔNG mã hoá — toàn bộ sổ), hàng chờ nguyên văn tin ngân hàng, ảnh biên lai,
///    kho token. `allowBackup=false` thôi KHÔNG đủ từ Android 12 — chuyển máy trực tiếp vẫn chép, phải có
///    `dataExtractionRules` loại mọi vùng ở cả `cloud-backup` lẫn `device-transfer`. Đổi máy: đăng nhập lại, phần đã
///    đồng bộ kéo về từ server; phần chỉ có trên máy (lịch sử thông báo, dữ liệu học gợi ý…) không theo — người dùng chốt.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _quyTac = 'android/app/src/main/res/xml/data_extraction_rules.xml';

/// Mọi vùng dữ liệu mà quy tắc trích xuất nhận (kể cả vùng lưu trữ bảo vệ thiết bị `device_*`).
const _vung = [
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
];

String _khoi(String xml, String the) {
  final mo = xml.indexOf('<$the');
  final dong = xml.indexOf('</$the>', mo);
  expect(mo, greaterThanOrEqualTo(0), reason: 'thiếu khối <$the>');
  expect(dong, greaterThan(mo), reason: 'khối <$the> không đóng');
  return xml.substring(mo, dong);
}

void main() {
  final manifest = File(_manifest).readAsStringSync();

  test('MainActivity tắt deeplink route của Flutter', () {
    final dau = manifest.indexOf('android:name=".MainActivity"');
    expect(dau, greaterThanOrEqualTo(0));
    final activity = manifest.substring(dau, manifest.indexOf('</activity>', dau));
    expect(
        RegExp(r'android:name="flutter_deeplinking_enabled"\s+android:value="false"').hasMatch(activity), isTrue,
        reason: 'thiếu là app khác trên máy mở được bất kỳ route nào với tham số điền sẵn (intent tường minh kèm '
            'extra route bỏ qua mọi intent-filter)');
  });

  test('ứng dụng tắt sao lưu và trỏ quy tắc trích xuất dữ liệu', () {
    final app = manifest.substring(manifest.indexOf('<application'), manifest.indexOf('>', manifest.indexOf('<application')));
    expect(app, contains('android:allowBackup="false"'), reason: 'sao lưu đám mây / adb backup');
    expect(app, contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
        reason: 'Android 12+: allowBackup=false không chặn chuyển máy trực tiếp');
  });

  // Siết bảo mật đợt 3 (2026-10-24): ảnh thu nhỏ ở Đa nhiệm (Recents) chụp màn cuối — số dư, sổ giao dịch — ai cầm máy
  // mở Đa nhiệm là thấy. Người dùng chọn CHỈ ẩn ảnh ấy (Android 13+), KHÔNG `FLAG_SECURE`: cờ ấy chặn cả ảnh chụp màn
  // hình của chính người dùng và làm `adb screencap` ra ảnh đen — mọi buổi đo máy thật dựa vào ảnh chụp.
  test('MainActivity ẩn ảnh Đa nhiệm (Android 13+) và KHÔNG chặn chụp màn hình', () {
    final kt = File('android/app/src/main/kotlin/com/flowmoney/flowmoney/MainActivity.kt').readAsStringSync();
    final onCreate = kt.substring(kt.indexOf('override fun onCreate'), kt.indexOf('override fun onDestroy'));
    expect(onCreate, contains('setRecentsScreenshotEnabled(false)'),
        reason: 'thiếu là Đa nhiệm hiện ảnh màn cuối của app — số dư, giao dịch');
    expect(onCreate, contains('Build.VERSION_CODES.TIRAMISU'),
        reason: 'API 33 mới có hàm này — gọi trên máy cũ là NoSuchMethodError lúc mở app');
    expect(kt, isNot(contains('FLAG_SECURE')),
        reason: 'người dùng chọn không chặn chụp màn hình (đo máy thật cần adb screencap)');
  });

  test('quy tắc trích xuất loại MỌI vùng ở cả sao lưu đám mây lẫn chuyển máy', () {
    final f = File(_quyTac);
    expect(f.existsSync(), isTrue, reason: 'manifest trỏ @xml/data_extraction_rules');
    final xml = f.readAsStringSync();
    for (final the in ['cloud-backup', 'device-transfer']) {
      final khoi = _khoi(xml, the);
      for (final v in _vung) {
        expect(khoi, contains('<exclude domain="$v" path="."/>'), reason: '<$the> bỏ sót vùng $v');
      }
      expect(khoi, isNot(contains('<include')), reason: '<$the> không được chép lại thứ gì');
    }
  });
}
