/// Nhắc ghi sau khi dùng app ngân hàng — tầng Kotlin phải được NỐI vào app thật (spec §5.2).
///
/// Tầng Kotlin là vùng mù của `flutter test`, `flutter analyze` VÀ `flutter build apk` (bẫy 7.11
/// `NOTIFICATION_FEATURE.md`): thiếu quyền, thiếu receiver, lệch tên kênh / phương thức, hay hằng ngưỡng hai bên lệch
/// nhau đều **im lặng**. Tệp này đọc mã nguồn của từng mối nối — khuôn `bien_dong_noi_day_test.dart`.
library;

import 'dart:io';

import 'package:flowmoney/core/notification/kenh_phien_ngan_hang.dart';
import 'package:flowmoney/core/notification/phien_ngan_hang.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(String duongDan) => File(duongDan).readAsStringSync();

const _kt = 'android/app/src/main/kotlin/com/flowmoney/flowmoney/';

void main() {
  test('manifest: PACKAGE_USAGE_STATS (tools:ignore) + NhacGhiReceiver không xuất ra ngoài', () {
    final m = _doc('android/app/src/main/AndroidManifest.xml');
    expect(m, contains('xmlns:tools="http://schemas.android.com/tools"'));
    expect(m, contains('android.permission.PACKAGE_USAGE_STATS'),
        reason: 'thiếu khai báo thì Cài đặt "Truy cập dữ liệu sử dụng" không liệt kê app');
    expect(m, contains('tools:ignore="ProtectedPermissions"'));
    final the = RegExp(r'<receiver[^>]*\.NhacGhiReceiver[^>]*>').firstMatch(m)?.group(0);
    expect(the, isNotNull, reason: 'thiếu receiver thì nút "Không có giao dịch" bấm không tới ai — im lặng');
    expect(the, contains('android:exported="false"'));
  });

  test('MainActivity mở kênh flowmoney/phien_ngan_hang đủ sáu phương thức', () {
    final kt = _doc('${_kt}MainActivity.kt');
    expect(kt, contains('"$kKenhPhienNganHang"'),
        reason: 'tên kênh lệch thì Dart nhận MissingPluginException, đọc thành "không có quyền" — im lặng');
    for (final pt in ['coQuyen', 'moCaiDat', 'suKien', 'boDen', 'datBat', 'huyNhac']) {
      expect(kt, contains('"$pt"'), reason: 'phương thức "$pt" là thứ kenh_phien_ngan_hang.dart gọi');
    }
  });

  test('⭐ hằng ngưỡng Kotlin == Dart (luật dựng phiên viết HAI lần, khớp TAY)', () {
    final kt = _doc('${_kt}PhienNganHang.kt');
    int hang(String ten) {
      final m = RegExp('const val $ten = ([\\d_]+)L').firstMatch(kt);
      expect(m, isNotNull, reason: 'thiếu hằng $ten trong PhienNganHang.kt');
      return int.parse(m!.group(1)!.replaceAll('_', ''));
    }

    expect(hang('GOP_PHIEN_MS'), kGopPhien.inMilliseconds,
        reason: 'lệch là thông báo ở nền hứa một dòng mà danh sách không có (hoặc ngược lại)');
    expect(hang('TOI_THIEU_TREN_MAN_MS'), kToiThieuTrenMan.inMilliseconds);
    expect(hang('TRUOC_PHIEN_MS'), kTruocPhien.inMilliseconds);
    expect(hang('SAU_PHIEN_TIN_MS'), kSauPhienTin.inMilliseconds);
  });

  test('Kotlin: MỘT danh sách gói với D1, bốn khoá sự kiện, dựng phiên theo lớp, chỉ Android 10+', () {
    final kt = _doc('${_kt}PhienNganHang.kt');
    expect(kt, contains('BienDongListenerService.DANH_SACH_TRANG'));
    for (final k in ['"goi"', '"lop"', '"loai"', '"luc"', '"vao"', '"ra"']) {
      expect(kt, contains(k), reason: 'khoá $k là thứ docSuKien đọc');
    }
    expect(kt, contains('ACTIVITY_RESUMED'));
    expect(kt, contains('ACTIVITY_PAUSED'));
    expect(kt, contains('Build.VERSION_CODES.Q'));
  });

  test('⭐ dịch vụ D1 kiểm phiên SAU khi xử lý tin — tin của chính app ngân hàng là bằng chứng của phiên', () {
    final kt = _doc('${_kt}BienDongListenerService.kt');
    final dau = kt.indexOf('override fun onNotificationPosted');
    expect(dau, greaterThanOrEqualTo(0));
    final cuoi = kt.indexOf('fun ', dau + 40);
    final than = kt.substring(dau, cuoi);
    final xuLy = than.indexOf('xuLyBienDong(sbn)');
    final kiem = than.indexOf('PhienNganHang.kiemNen(this)');
    expect(xuLy, greaterThanOrEqualTo(0));
    expect(kiem, greaterThan(xuLy), reason: 'kiểm trước khi tin vào hàng chờ là nhắc oan đúng phiên vừa có tin');
    expect(kt, contains('onListenerConnected'));
  });

  test('thông báo nhắc: kênh LOW, id riêng, nút Không có giao dịch, chỉ báo một lần; log chỉ ở bản debug', () {
    final kt = _doc('${_kt}PhienNganHang.kt');
    expect(kt, contains('IMPORTANCE_LOW'), reason: 'người dùng chốt: im lặng — nhắc oan là chuyện thường');
    expect(kt, contains('ID_NHAC = 20261003'));
    expect(kt, contains('"Không có giao dịch"'));
    expect(kt, contains('setOnlyAlertOnce(true)'));
    expect(kt, contains('FLAG_DEBUGGABLE'));
    for (final d in kt.split('\n').where((d) => d.contains('Log.'))) {
      expect(d, contains('debug(ctx)'), reason: 'log không được chạy ở bản release: $d');
    }
  });

  test('gradle khai WorkManager đúng bản background_downloader 9.6.3 đang kéo vào (không xung đột)', () {
    expect(_doc('android/app/build.gradle.kts'), contains('androidx.work:work-runtime-ktx:2.11.0'));
  });

  test('DI: kênh Android thật trên Android, bản trống nơi khác', () {
    final di = _doc('lib/core/di/injection_container.dart');
    expect(di, contains('KenhPhienNganHangAndroid'));
    expect(di, contains('KenhPhienNganHangTrong'));
  });
}
