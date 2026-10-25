/// G100 (đường gỡ task, 2026-10-21) — kênh `flowmoney/giu_mo_hinh`: Dart báo `MainActivity` tiến trình đang giữ một bản
/// mô hình Gemma; activity bị huỷ thật mà cờ bật thì Kotlin giết tiến trình, vì engine dựng lại trong tiến trình còn sống
/// (dịch vụ D1 giữ nó) sẽ nạp THÊM một bản và bản cũ không ai giải phóng được. `flutter test` không chạy Kotlin — phần
/// native canh bằng cách đọc tệp nguồn (cùng khuôn `thoat_hai_lan_test`).
library;

import 'dart:io';

import 'package:flowmoney/features/ai_edge/data/datasources/kenh_giu_mo_hinh.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kenh = MethodChannel(kKenhGiuMoHinh);
  final may = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => may.setMockMethodCallHandler(kenh, null));

  test('dat(true) / dat(false) gửi datGiu kèm cờ, đúng thứ tự', () async {
    final nhan = <(String, Object?)>[];
    may.setMockMethodCallHandler(kenh, (call) async {
      nhan.add((call.method, (call.arguments as Map)['giu']));
      return null;
    });

    await const KenhGiuMoHinh().dat(true);
    await const KenhGiuMoHinh().dat(false);

    expect(nhan, [('datGiu', true), ('datGiu', false)]);
  });

  test('kênh chưa có (web, test, bản native cũ) → không ném', () async {
    await expectLater(const KenhGiuMoHinh().dat(true), completes,
        reason: 'lời báo đi trên đường nạp mô hình — ném ra là hỏng cả lượt hỏi AI');
  });

  test('native báo lỗi → không ném', () async {
    may.setMockMethodCallHandler(kenh, (call) async => throw PlatformException(code: 'x'));
    await expectLater(const KenhGiuMoHinh().dat(true), completes);
  });

  test('nối dây Kotlin: kênh / hàm khớp MainActivity.kt; chỉ giết khi huỷ thật, activity cuối cùng, đang giữ mô hình', () {
    final kt = File('android/app/src/main/kotlin/com/flowmoney/flowmoney/MainActivity.kt').readAsStringSync();
    expect(kKenhGiuMoHinh, 'flowmoney/giu_mo_hinh');
    expect(kt, contains('"flowmoney/giu_mo_hinh"'));
    expect(kt, contains('"datGiu"'));
    expect(kt, contains('override fun onDestroy()'));
    // Ba vế, mỗi vế một lý do: đổi cấu hình (xoay màn) cũng huỷ activity — giết lúc ấy là đóng app trước mặt người
    // dùng; còn một MainActivity khác sống thì giết là đóng luôn nó; chưa nạp mô hình thì không có gì rò.
    expect(kt, contains('val giet = !isChangingConfigurations && soActivitySong <= 0 && dangGiuMoHinh'));
    expect(kt, contains('soActivitySong++'));
    expect(kt, contains('soActivitySong--'));
    expect(kt, contains('dangGiuMoHinh = call.argument<Boolean>("giu") ?: false'));
    expect(kt, contains('Process.killProcess(Process.myPid())'));
    expect(kt.indexOf('super.onDestroy()'), lessThan(kt.indexOf('Process.killProcess(Process.myPid())')),
        reason: 'giết SAU khi engine đã huỷ và plugin đã gỡ');
  });

  test('nối dây Dart: DI đưa kênh thật vào SlmRuntimeThat, SlmRuntimeThat chuyển cho BoNapMoHinh', () {
    final di = File('lib/core/di/injection_container.dart').readAsStringSync();
    expect(di, contains('baoGiuMoHinh: const KenhGiuMoHinh().dat'),
        reason: 'thiếu dòng này thì cờ không bao giờ bật và G100 đường gỡ task vẫn nạp thêm một bản');
    final rt = File('lib/features/ai_edge/data/datasources/slm_runtime.dart').readAsStringSync();
    expect(rt, contains('baoGiu: baoGiuMoHinh'));
  });
}
