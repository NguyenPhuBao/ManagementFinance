/// Nhận diện app trên máy: nhãn, icon, splash — F1–F3 của lượt UX 2026-09-19.
///
/// Máy ảo đo được: nhãn app là "flowmoney" chữ thường, icon là logo Flutter
/// mặc định, splash là nền trắng với logo Flutter. Đây là thứ đầu tiên người
/// chấm nhìn thấy, và `flutter test`/`flutter analyze`/`flutter build` đều
/// không nói gì về nó — nên test đọc thẳng tệp Android.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// MD5 của `ic_launcher.png` mà `flutter create` sinh ra (đo 2026-09-19 trên
/// bản mdpi 544 byte). Icon còn trùng hash này là còn logo Flutter.
const _md5IconFlutterMacDinh = '6270344430679711b81476e29878caa7';

void main() {
  const res = 'android/app/src/main/res';

  test('nhãn app là "FlowMoney", không phải tên gói chữ thường', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="FlowMoney"'),
        reason: 'Máy ảo hiện "flowmoney" dưới icon và trong khay thông báo.');
  });

  test('icon launcher không còn là logo Flutter mặc định', () {
    final bytes = File('$res/mipmap-mdpi/ic_launcher.png').readAsBytesSync();
    expect(md5.convert(bytes).toString(), isNot(_md5IconFlutterMacDinh),
        reason: 'Còn trùng hash của icon `flutter create` sinh ra.');
    expect(File('$res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(), isTrue,
        reason: 'Adaptive icon (Android 8+) để icon không bị cắt méo.');
  });

  test('splash có ảnh, không phải nền trắng trần', () {
    final xml = File('$res/drawable/launch_background.xml').readAsStringSync();
    expect(xml, contains('@drawable/splash'),
        reason: 'Bản mặc định chỉ có `@android:color/white`.');
  });

  test('ảnh nguồn icon nằm trong assets/icon/ để sinh lại được', () {
    for (final t in ['app_icon.png', 'app_icon_foreground.png', 'splash.png']) {
      expect(File('assets/icon/$t').existsSync(), isTrue, reason: t);
    }
  });

  // ⚠️ Quyền INTERNET phải nằm ở manifest CHÍNH, không chỉ ở bản debug.
  //
  // Flutter tạo sẵn `android/app/src/debug/AndroidManifest.xml` có quyền này
  // (nó cần cho hot reload), nên thiếu ở `main/` KHÔNG hỏng gì mà cả dự án
  // nhìn thấy được: mọi bản debug — tức mọi lượt nghiệm thu máy ảo từ trước
  // tới nay — gọi backend bình thường. Lỗi chỉ hiện khi CHẠY một bản release,
  // và hiện dưới dạng "Không có kết nối mạng", đúng chữ mà app dùng cho lúc
  // rớt sóng — nên nó còn dẫn người đọc đi kiểm tra Wi-Fi thay vì manifest.
  //
  // Đo thật 2026-09-22 (P3 Task 9, OnePlus 13R, bản release đầu tiên của dự
  // án): app không đăng nhập được, trong khi `adb shell curl` tới đúng URL ấy
  // từ chính máy đó trả về HTTP 200 — tức đường mạng tốt, chỉ app bị cấm.
  test('manifest chính khai quyền INTERNET (bản release không có mạng nếu thiếu)',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest,
        contains('android:name="android.permission.INTERNET"'),
        reason: 'Thiếu ở main/ thì chỉ bản debug gọi được backend; bản release '
            'im lặng báo "Không có kết nối mạng" ở mọi màn cần server.');
  });

  test('manifest khai FOREGROUND_SERVICE_DATA_SYNC (Android 14+ đòi)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
        manifest,
        contains(
            'android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"'),
        reason: 'background_downloader chạy foreground service loại dataSync; '
            'thiếu quyền thì build vẫn xanh và lượt tải chết trên máy thật.');
  });
}
