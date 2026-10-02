/// Chia sẻ biên lai — tầng Kotlin và manifest là vùng mù của `flutter test` / `analyze` / `build apk`: thiếu
/// intent-filter thì FlowMoney không có trong bảng chia sẻ, lệch tên tệp hàng chờ thì ảnh nhận rồi không bao giờ thành
/// dòng nào — đều im lặng. Tệp này đọc mã nguồn từng mối nối (khuôn `bien_dong_noi_day_test.dart`; đọc tệp cụ thể,
/// không nằm trong chuỗi test quét `lib/`).
library;

import 'dart:io';

import 'package:flowmoney/core/notification/kenh_bien_dong.dart';
import 'package:flowmoney/core/notification/nhap_bien_lai.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(String p) => File(p).readAsStringSync();
const _kt = 'android/app/src/main/kotlin/com/flowmoney/flowmoney/';

void main() {
  test('manifest khai NhanBienLaiActivity: SEND + image/*, exported, không giao diện, không vào Recents', () {
    final m = _doc('android/app/src/main/AndroidManifest.xml');
    final khoi =
        RegExp(r'<activity[^>]*android:name="\.NhanBienLaiActivity"[\s\S]*?</activity>').firstMatch(m)?.group(0);
    expect(khoi, isNotNull);
    expect(khoi, contains('android:exported="true"'), reason: 'không exported thì app khác không chia sẻ tới được');
    expect(khoi, contains('android.intent.action.SEND'));
    expect(khoi, isNot(contains('SEND_MULTIPLE')), reason: 'spec: mỗi lần một ảnh');
    expect(khoi, contains('android.intent.category.DEFAULT'),
        reason: 'thiếu DEFAULT thì bảng chia sẻ không liệt kê app — im lặng');
    expect(khoi, contains('android:mimeType="image/*"'));
    expect(khoi, contains('android:excludeFromRecents="true"'));
    expect(khoi, contains('android:label="Ghi vào FlowMoney"'));
    expect(khoi, anyOf(contains('Theme.NoDisplay'), contains('Theme.Translucent.NoTitleBar')),
        reason: 'người dùng chốt: chia sẻ xong vẫn Ở app ngân hàng — activity không được có giao diện');
  });

  test('activity: cùng tên tệp hàng chờ, thư mục ảnh, ba khoá JSON với phía Dart; KHÔNG mở activity nào', () {
    final kt = _doc('${_kt}NhanBienLaiActivity.kt');
    expect(kt, contains('"$kTepBienLaiCho"'));
    expect(kt, contains('"$kThuMucBienLai"'));
    for (final k in ['tep', 'goi', 'luc']) {
      expect(kt, contains('"$k"'), reason: 'khoá "$k" là thứ docDongBienLai đọc');
    }
    expect(kt, isNot(contains('startActivity')), reason: 'mở MainActivity là kéo người dùng khỏi app ngân hàng');
    expect(kt, contains('finish()'));
    expect(kt, contains('"co_phien"'));
    expect(kt, contains('FLAG_DEBUGGABLE'), reason: 'log thu mẫu chỉ ở bản debug');
  });

  test('tóm tắt đếm CẢ HAI hàng chờ, và kênh flowmoney/bien_dong có datCoPhien ở cả hai đầu', () {
    final sv = _doc('${_kt}BienDongListenerService.kt');
    expect(sv, contains('NhanBienLaiActivity.TEP_HANG_CHO'), reason: 'N của tóm tắt gộp tin ngân hàng và biên lai');
    expect(_doc('${_kt}MainActivity.kt'), contains('"datCoPhien"'));
    expect(_doc('lib/core/notification/kenh_bien_dong.dart'), contains("'datCoPhien'"));
    expect(kKenhBienDong, 'flowmoney/bien_dong');
  });
}
