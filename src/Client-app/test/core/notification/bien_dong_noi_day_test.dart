/// D1 — dịch vụ đọc thông báo biến động số dư phải được NỐI vào app thật (spec §2, Task 3).
///
/// Tầng Kotlin là vùng mù của `flutter test`, `flutter analyze` VÀ `flutter build apk` (bẫy 7.11
/// `NOTIFICATION_FEATURE.md`): thiếu khai báo service trong manifest, lệch tên kênh, lệch một tên
/// phương thức, hay hai danh sách trắng Dart ↔ Kotlin lệch nhau đều **im lặng** — không lỗi, không
/// log, chỉ là không có tin nào tới. Tệp này đọc mã nguồn của từng mối nối, cùng lối
/// `canary_cong_cu_noi_day_test.dart` (đọc tệp cụ thể, không nằm trong chuỗi test quét `lib/`).
library;

import 'dart:io';

import 'package:flowmoney/core/notification/kenh_bien_dong.dart';
import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(String duongDan) => File(duongDan).readAsStringSync();

const _kt = 'android/app/src/main/kotlin/com/flowmoney/flowmoney/';

void main() {
  test('manifest khai báo BienDongListenerService đúng permission và intent-filter', () {
    final m = _doc('android/app/src/main/AndroidManifest.xml');
    expect(m, contains('android:name=".BienDongListenerService"'));
    expect(m, contains('android.permission.BIND_NOTIFICATION_LISTENER_SERVICE'),
        reason: 'thiếu permission thì hệ thống không bind — service không bao giờ nhận thông báo, im lặng');
    expect(m, contains('android.service.notification.NotificationListenerService'),
        reason: 'thiếu action thì Cài đặt "Truy cập thông báo" không liệt kê app');
  });

  test('MainActivity mở kênh flowmoney/bien_dong với đủ NĂM phương thức và đọc extra mở-từ-tóm-tắt', () {
    final kt = _doc('${_kt}MainActivity.kt');
    expect(kt, contains('"$kKenhBienDong"'),
        reason: 'tên kênh lệch thì phía Dart nhận MissingPluginException, đọc thành "không có quyền" — im lặng');
    for (final pt in ['coQuyen', 'moCaiDat', 'moTuThongBao', 'huyTomTat', 'datBat']) {
      expect(kt, contains('"$pt"'), reason: 'phương thức "$pt" là thứ kenh_bien_dong.dart gọi');
    }
    expect(kt, contains('onNewIntent'),
        reason: 'launchMode singleTop: chạm tóm tắt khi app đang chạy tới bằng onNewIntent, không phải onCreate');
    expect(kt, contains('enabled_notification_listeners'));
  });

  test('⭐ danh sách trắng Kotlin == kNguonTheoGoi phía Dart (đồng bộ TAY, đo trên máy — Task 1)', () {
    final kt = _doc('${_kt}BienDongListenerService.kt');
    final khoi = RegExp(r'DANH_SACH_TRANG[^=]*=\s*mapOf\(([\s\S]*?)\)', multiLine: true).firstMatch(kt);
    expect(khoi, isNotNull, reason: 'hằng DANH_SACH_TRANG phải là một mapOf(...) để test đọc được');
    final kotlin = {
      for (final m in RegExp(r'"([^"]+)"\s+to\s+"([^"]+)"').allMatches(khoi!.group(1)!)) m.group(1)!: m.group(2)!,
    };
    expect(kotlin, kNguonTheoGoi,
        reason: 'Kotlin LỌC theo gói, Dart DỊCH gói → nguồn để chọn khuôn đọc: lệch một gói là tin được ghi đĩa '
            'nhưng không bao giờ thành dòng thông báo (hoặc ngược lại), im lặng');
    for (final nguon in kotlin.values) {
      expect(kNguonBienDong, contains(nguon), reason: 'tên nguồn "$nguon" phải là một trong bảy nguồn');
    }
  });

  test('service: cùng tệp hàng chờ, cùng năm khoá JSON, cùng bộ lọc OTP với phía Dart', () {
    final kt = _doc('${_kt}BienDongListenerService.kt');
    expect(kt, contains('"$kTepBienDongCho"'));
    for (final k in ['goi', 'tieuDe', 'noiDung', 'luc', 'khoa']) {
      expect(kt, contains('"$k"'), reason: 'khoá "$k" là thứ docDongBienDong đọc');
    }
    expect(kt, contains('otp|mã xác thực|ma xac thuc'),
        reason: 'bộ lọc OTP phía Kotlin phải là chính chuỗi của Dart (lớp lọc thứ nhất, trước khi ghi đĩa)');
    expect(kt, contains('FLAG_ACTIVITY_SINGLE_TOP'));
  });

  test('service: KHÔNG log nội dung tin ngoài chế độ thu mẫu, và thu mẫu chỉ ở bản debug', () {
    final kt = _doc('${_kt}BienDongListenerService.kt');
    expect(kt, contains('FLAG_DEBUGGABLE'),
        reason: 'chế độ thu mẫu (Task 1) log nguyên văn thông báo — chỉ được sống ở bản debug');
    final dongLog = kt.split('\n').where((d) => d.contains('Log.')).toList();
    expect(dongLog, hasLength(1),
        reason: 'đúng MỘT chỗ log, là dòng thu mẫu; bản release không được in nội dung tin ra logcat');
    expect(dongLog.single, contains('TAG_THU'));
  });

  test('DI: scanner nhận NhapBienDong nối kênh Android thật', () {
    final di = _doc('lib/core/di/injection_container.dart');
    expect(di, contains('nhapBienDong:'),
        reason: 'NhapBienDong có test riêng xanh hết, nhưng không nối thì tệp hàng chờ nằm mãi trên đĩa');
    expect(di, contains('KenhBienDongAndroid'));
    expect(di, contains('nguonCuaGoi: nguonCuaGoi'));
  });
}
