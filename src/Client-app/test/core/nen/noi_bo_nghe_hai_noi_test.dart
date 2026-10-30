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
    final di = File('lib/core/di/injection_container.dart').readAsStringSync().replaceAll('\r\n', '\n');
    // Phạm vi miễn trừ là THÂN hàm nối chung chứ không cả tệp DI: dời lời gọi vào một factory `registerLazySingleton` thì
    // engine nền không ai resolve resolver → không nối (spec 2026-10-15 mục 9, rủi ro 4).
    final dau = di.indexOf('void noiBoNgheKetQuaDay() {');
    expect(dau, isNonNegative, reason: 'DI mất hàm nối chung noiBoNgheKetQuaDay');
    final cuoi = di.indexOf('\n}', dau);
    expect(cuoi, greaterThan(dau), reason: 'không thấy dấu } ở cột 0 đóng thân noiBoNgheKetQuaDay');
    final than = di.substring(dau, cuoi);
    final ngoai = di.substring(0, dau) + di.substring(cuoi);
    for (final r in ['BillPaymentConflictResolver', 'ViTrungTenResolver']) {
      final mau = RegExp('$r>\\(\\)\\s*\\.batDauNghe');
      expect(mau.allMatches(than).length, 1,
          reason: '$r phải được nối ĐÚNG MỘT lần trong THÂN hàm nối chung — hai lần là hoàn tác chạy hai lượt.');
      expect(mau.allMatches(ngoai).length, 0,
          reason: '$r nối NGOÀI thân noiBoNgheKetQuaDay (vd. trong factory registerLazySingleton): engine nền không resolve nó nên không nối.');
    }
    // Gia đình (2026-10-24): trạng thái nhà nghe mã đẩy HOUSEHOLD_* — cùng luật một lần trong thân hàm nối chung.
    final nha = RegExp(r'NhaRepository>\(\)\s*\.noiKetQuaDay');
    expect(nha.allMatches(than).length, 1, reason: 'NhaRepository phải nghe kết quả đẩy ĐÚNG MỘT lần trong hàm nối chung');
    expect(nha.allMatches(ngoai).length, 0);
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
