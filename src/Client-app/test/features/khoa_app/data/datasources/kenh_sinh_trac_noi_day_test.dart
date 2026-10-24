/// Khoá ứng dụng — tầng Kotlin + manifest là vùng mù của `flutter test` / `analyze`. Đọc mã từng mối nối (MASVS-AUTH-2:
/// sinh trắc gắn phép mã hoá Keystore, vô hiệu khi thêm vân tay, không rơi về mã máy).
library;

import 'dart:io';

import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(String p) => File(p).readAsStringSync();
const _kt = 'android/app/src/main/kotlin/com/flowmoney/flowmoney/';

void main() {
  test('SinhTrac.kt: khoá bắt buộc xác thực, vô hiệu khi thêm vân tay, sinh trắc mạnh, CryptoObject', () {
    final kt = _doc('${_kt}SinhTrac.kt');
    expect(kt, contains('"$kKenhSinhTrac"'));
    expect(kt, contains('setUserAuthenticationRequired(true)'));
    expect(kt, contains('setInvalidatedByBiometricEnrollment(true)'));
    expect(kt, contains('BIOMETRIC_STRONG'));
    expect(kt, contains('BiometricPrompt.CryptoObject('), reason: 'MASWE-0020: không chỉ dựa callback đúng/sai');
    expect(kt, contains('KeyPermanentlyInvalidatedException'));
    expect(kt, contains('"flowmoney_khoa_app_"'));
    expect(kt, isNot(contains('DEVICE_CREDENTIAL')), reason: 'MASWE-0021: không rơi về mã máy');
    expect(kt, isNot(contains('Log.')), reason: 'không log bí mật / bản mã');
    for (final ma in ['HUY', 'VO_HIEU', 'TAM_KHOA', 'KHONG_HO_TRO', 'LOI']) {
      expect(kt, contains('"$ma"'), reason: 'mã lỗi khớp docLoiSinhTrac');
    }
  });

  test('SinhTrac.kt: tên lệnh và khoá map khớp phía Dart (lệch là hỏng im lặng)', () {
    final kt = _doc('${_kt}SinhTrac.kt');
    for (final lenh in ['trangThai', 'bat', 'mo', 'xoaHet']) {
      expect(kt, contains('"$lenh"'), reason: 'lệnh kênh `$lenh` phải khớp kenh_sinh_trac.dart');
    }
    for (final khoa in ['idaccount', 'biMat', 'banMa', 'iv', 'hoTro', 'daDangKy', 'loi']) {
      expect(kt, contains('"$khoa"'), reason: 'khoá map `$khoa` phải khớp kenh_sinh_trac.dart');
    }
  });

  test('MainActivity đăng ký kênh và VẪN là FlutterActivity (G100 không đổi)', () {
    final m = _doc('${_kt}MainActivity.kt');
    expect(m, contains('SinhTrac.KENH'));
    expect(m, contains('class MainActivity : FlutterActivity()'));
  });

  test('manifest khai USE_BIOMETRIC và USE_FINGERPRINT (API 28–29)', () {
    final x = _doc('android/app/src/main/AndroidManifest.xml');
    expect(x, contains('android.permission.USE_BIOMETRIC'));
    expect(x, contains('android.permission.USE_FINGERPRINT'));
    expect(x, contains('android:maxSdkVersion="29"'), reason: 'P10: FingerprintManager chỉ cần ở API 28–29');
  });
}
