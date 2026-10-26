/// M16 (Realme buổi 4, 2026-10-26 — `KHOA_APP_FEATURE.md` mục 8): có phím của bàn phím vật lý là Android vẽ **khung
/// tiêu điểm mặc định** (xanh-vàng, vài px) quanh cả `FlutterView` — mọi màn, tới khi chạm lại màn hình. Tiêu điểm bên trong
/// app (Tab giữa các nút) do Flutter tự vẽ, nên khung của hệ điều hành chỉ là một viền thừa. Tắt bằng
/// `android:defaultFocusHighlightEnabled=false` trong theme của activity (API 26+; `View` đọc giá trị mặc định từ theme).
///
/// ⚠️ Theme là vùng mù của `flutter test` lẫn `flutter analyze`: thiếu ở một biến thể (tối, v31) thì chỉ máy dùng biến thể
/// ấy còn viền — Realme Android 13 đọc `values-v31`. Ca này đọc cả bốn tệp.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const tep = ['values', 'values-night', 'values-v31', 'values-night-v31'];

  for (final thuMuc in tep) {
    test('$thuMuc/styles.xml: LaunchTheme + NormalTheme tắt khung tiêu điểm mặc định', () {
      final xml = File('android/app/src/main/res/$thuMuc/styles.xml').readAsStringSync();
      for (final ten in ['LaunchTheme', 'NormalTheme']) {
        final m = RegExp('<style name="$ten"[^>]*>(.*?)</style>', dotAll: true).firstMatch(xml);
        expect(m, isNotNull, reason: '$thuMuc thiếu style $ten');
        expect(
          RegExp(r'<item name="android:defaultFocusHighlightEnabled">\s*false\s*</item>').hasMatch(m!.group(1)!),
          isTrue,
          reason: '$thuMuc/$ten: thiếu android:defaultFocusHighlightEnabled=false — gõ phím là viền xanh-vàng quanh màn',
        );
      }
    });
  }
}
