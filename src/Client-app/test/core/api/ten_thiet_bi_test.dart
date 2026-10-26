/// Tên máy gửi qua header `x-device-name` (2026-10-26) — backend ghi lịch sử thiết bị theo tên + IP, và tên ĐỔI là thêm một
/// dòng mới (`device-history.service.js`). Nên mọi đường gọi backend của một máy phải gửi CÙNG một tên: Dio chung, Dio làm
/// mới token, engine app và engine nền.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/api/ten_thiet_bi.dart';

const _kt = 'android/app/src/main/kotlin/com/flowmoney/flowmoney/';
String _doc(String p) => File(p).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chuanHoaTenThietBi', () {
    test('tên bình thường giữ nguyên', () {
      expect(chuanHoaTenThietBi('Realme RMX2205 (Android 13)'), 'Realme RMX2205 (Android 13)');
    });

    test('trống / chỉ khoảng trắng / null → null (không gửi header)', () {
      for (final t in [null, '', '   ']) {
        expect(chuanHoaTenThietBi(t), isNull, reason: '"$t"');
      }
    });

    test('ký tự xuống dòng / điều khiển bị bỏ — không chèn được header', () {
      expect(chuanHoaTenThietBi('Pixel 8\r\nX-Evil: 1'), 'Pixel 8 X-Evil: 1');
      expect(chuanHoaTenThietBi('A\tB\u0000C'), 'A B C');
    });

    test('ký tự ngoài ASCII in được bị bỏ, khoảng trắng gom lại', () {
      expect(chuanHoaTenThietBi('  Máy   của tôi  '), 'My ca ti',
          reason: 'header ngoài Latin-1 là HttpClient của Dart ném — mọi request hỏng');
    });

    test('dài hơn 150 ký tự → cắt còn 150 (trần của backend)', () {
      final ten = chuanHoaTenThietBi('x' * 300);
      expect(ten!.length, kDoDaiTenThietBiToiDa);
      expect(kDoDaiTenThietBiToiDa, 150);
    });
  });

  group('docTenThietBi', () {
    const kenh = MethodChannel(kKenhThietBi);
    final may = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() {
      may.setMockMethodCallHandler(kenh, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: hỏi kênh phương thức "ten", chuẩn hoá kết quả', () async {
      final goi = <String>[];
      may.setMockMethodCallHandler(kenh, (c) async {
        goi.add(c.method);
        return '  Realme RMX2205 (Android 13) ';
      });
      expect(await docTenThietBi(), 'Realme RMX2205 (Android 13)');
      expect(goi, ['ten']);
    });

    test('kênh không có (engine thiếu đăng ký) / ném lỗi → null, không ném', () async {
      expect(await docTenThietBi(), isNull, reason: 'MissingPluginException bị nuốt');
      may.setMockMethodCallHandler(kenh, (c) async => throw PlatformException(code: 'x'));
      expect(await docTenThietBi(), isNull);
    });

    test('không phải Android (iOS chưa có mã gốc) → null, không gọi kênh', () async {
      var soLan = 0;
      may.setMockMethodCallHandler(kenh, (c) async {
        soLan++;
        return 'iPhone';
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await docTenThietBi(), isNull);
      expect(soLan, 0);
    });
  });

  group('header trên hai Dio gọi backend', () {
    test('DioClient gắn x-device-name khi có tên, không gắn khi null', () {
      final co = DioClient(secureStorage: const FlutterSecureStorage(), tenThietBi: 'Realme RMX2205 (Android 13)');
      expect(co.dio.options.headers[kHeaderTenThietBi], 'Realme RMX2205 (Android 13)');
      final khong = DioClient(secureStorage: const FlutterSecureStorage());
      expect(khong.dio.options.headers.containsKey(kHeaderTenThietBi), isFalse,
          reason: 'không biết tên thì im — backend tự rơi về user-agent');
    });

    test('Dio làm mới token (/auth/refresh) mang CÙNG tên — backend cũng ghi lịch sử ở đó', () {
      final d = Dio();
      AuthInterceptor(secureStorage: const FlutterSecureStorage(), dioLamMoi: d, tenThietBi: 'OnePlus CPH2691 (Android 15)');
      expect(d.options.headers[kHeaderTenThietBi], 'OnePlus CPH2691 (Android 15)',
          reason: 'auth.service.js:542 ghi lịch sử ở mỗi lượt làm mới — tên khác Dio chung là thêm dòng mỗi lần');
    });
  });

  group('nối dây (Kotlin, DI) — vùng mù của flutter test / analyze / build', () {
    test('ThietBi.kt mở đúng kênh + phương thức', () {
      final kt = _doc('${_kt}ThietBi.kt');
      expect(kt, contains('"$kKenhThietBi"'), reason: 'lệch tên kênh → MissingPluginException bị nuốt → không header');
      expect(kt, contains('"ten"'));
    });

    test('kênh đăng ký ở CẢ engine app lẫn engine nền', () {
      expect(_doc('${_kt}MainActivity.kt'), contains('ThietBi.dangKy(flutterEngine.dartExecutor.binaryMessenger)'));
      expect(_doc('${_kt}TuChuyenTien.kt'), contains('ThietBi.dangKy(e.dartExecutor.binaryMessenger)'),
          reason: 'lượt nền gửi user-agent Dart/… còn app gửi tên máy → backend thêm một dòng lịch sử mỗi lần tên đổi');
    });

    test('DI đọc tên MỘT lần và đưa cho cả DioClient lẫn AuthInterceptor', () {
      final di = _doc('lib/core/di/injection_container.dart');
      expect(RegExp(r'await docTenThietBi\(\)').allMatches(di).length, 1);
      expect(RegExp(r'tenThietBi: tenThietBi').allMatches(di).length, 2);
    });
  });
}
