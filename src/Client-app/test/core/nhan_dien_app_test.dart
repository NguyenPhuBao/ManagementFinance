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
}
