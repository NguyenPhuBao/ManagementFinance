/// Hai engine Dart (app + nền của WorkManager) mỗi engine phải nối bộ nghe kết quả đẩy ĐÚNG MỘT LẦN (spec
/// 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 4). Lượt nền đẩy mà không nối thì `BILL_ALREADY_PAID` về mà không
/// ai gỡ khoản trả — khoản chi lỗi vĩnh viễn. Test quét mã nguồn: `flutter test` không dựng được engine nền.
library;

import 'dart:io';

import 'package:flowmoney/core/nen/kenh_tu_chuyen_tien.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('noiBoNgheKetQuaDay được gọi ở CẢ engine app lẫn engine nền', () {
    for (final p in ['lib/main.dart', 'lib/core/nen/chay_nen.dart']) {
      expect(File(p).readAsStringSync(), contains('noiBoNgheKetQuaDay();'),
          reason: '$p: thiếu thì resolver không nghe kết quả đẩy của engine ấy');
    }
  });

  test('chỉ hàm nối chung gọi batDauNghe của hai resolver (nối hai lần = hoàn tác hai lượt)', () {
    final loi = <String>[];
    final noi = RegExp(r'(BillPaymentConflictResolver|ViTrungTenResolver)>\(\)\s*\.batDauNghe');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final p = f.path.replaceAll(r'\', '/');
      // Tệp ĐỊNH NGHĨA hàm nối chung (DI, từ 2026-10-15 — G88 gạch 4) được miễn; trong nó mỗi resolver nối đúng MỘT lần (dưới).
      if (!p.endsWith('.dart') || p.endsWith('core/di/injection_container.dart')) continue;
      if (noi.hasMatch(f.readAsStringSync())) loi.add(p);
    }
    expect(loi, isEmpty);
    final di = File('lib/core/di/injection_container.dart').readAsStringSync();
    for (final r in ['BillPaymentConflictResolver', 'ViTrungTenResolver']) {
      expect(RegExp('$r>\\(\\)\\s*\\.batDauNghe').allMatches(di).length, 1,
          reason: '$r phải được nối ĐÚNG MỘT lần trong hàm nối chung — hai lần là hoàn tác chạy hai lượt.');
    }
  });

  test('main.dart khai entrypoint nền đúng tên, có @pragma (bản release bỏ hàm không ai gọi)', () {
    final s = File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');
    expect(s, contains("@pragma('vm:entry-point')\nFuture<void> $kEntrypointNen()"));
  });

  test('engine nền: DI chế độ nền, đặt gói trước khi quét, báo nenXong trong finally', () {
    final s = File('lib/core/nen/chay_nen.dart').readAsStringSync();
    expect(s, contains('setupDependencies(cheDoNen: true)'));
    expect(s, contains('datTaiKhoan('), reason: 'thiếu thì coQuyenNen trả true — Basic được tự trả ở nền');
    expect(s, contains("invokeMethod<void>('nenXong'"));
    expect(s.indexOf('finally'), lessThan(s.indexOf("'nenXong'")),
        reason: 'Dart ném lỗi mà không báo xong thì worker chờ hết 3 phút');
  });
}
