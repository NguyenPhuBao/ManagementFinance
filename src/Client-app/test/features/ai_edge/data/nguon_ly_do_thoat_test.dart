/// Kênh `flowmoney/ly_do_thoat` — phía Dart đọc lý do các lần app chết gần đây
/// (`ApplicationExitInfo`, Android 11+) và phiên bản app, cho canary phiên có
/// tool (bước 1b). Mã Kotlin nằm ở `MainActivity`; test này dựng bản giả của
/// phía native và canh phép dịch dữ liệu.
library;

import 'package:flowmoney/features/ai_edge/data/nguon_ly_do_thoat.dart';
import 'package:flowmoney/features/ai_edge/domain/canary_cong_cu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kenh = MethodChannel(kKenhLyDoThoat);
  final may = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => may.setMockMethodCallHandler(kenh, null));

  void traVe(Object? ketQua) => may.setMockMethodCallHandler(kenh, (call) async {
        expect(call.method, 'thongTin');
        return ketQua;
      });

  test('Android 11+: đọc danh sách lần thoát và phiên bản', () async {
    traVe({
      'phienBan': 42,
      'lanThoat': [
        {'lyDo': 5, 'luc': 1790000000000},
        {'lyDo': 13, 'luc': 1790000100000},
      ],
    });
    const nguon = NguonLyDoThoatAndroid();

    final ds = await nguon.cacLanThoat();
    expect([for (final l in ds!) (l.lyDo, l.luc.millisecondsSinceEpoch)],
        [(kLyDoSapNative, 1790000000000), (13, 1790000100000)]);
    expect(await nguon.phienBan(), 42);
  });

  test('Android 10 trở xuống: không có danh sách → "không biết" (null)',
      () async {
    traVe({'phienBan': 42, 'lanThoat': null});
    const nguon = NguonLyDoThoatAndroid();

    expect(await nguon.cacLanThoat(), isNull,
        reason: 'null khác danh sách rỗng: rỗng là "không chết lần nào", null '
            'là "không biết" — canary rơi về luật hai lần liền');
    expect(await nguon.phienBan(), 42);
  });

  test('kênh chưa có (nền tảng khác, bản native cũ) → null, không ném',
      () async {
    const nguon = NguonLyDoThoatAndroid();

    expect(await nguon.cacLanThoat(), isNull,
        reason: 'phép này chạy ở đường khởi động — ném ra là hỏng lúc mở app');
    expect(await nguon.phienBan(), isNull);
  });

  test('bản ghi hỏng bị bỏ qua, bản ghi lành vẫn đọc được', () async {
    traVe({
      'phienBan': '42',
      'lanThoat': [
        {'lyDo': 5},
        'rác',
        {'lyDo': 10, 'luc': 1790000200000},
      ],
    });
    const nguon = NguonLyDoThoatAndroid();

    final ds = await nguon.cacLanThoat();
    expect([for (final l in ds!) l.lyDo], [10]);
    expect(await nguon.phienBan(), isNull,
        reason: 'phiên bản phải là số; đoán từ chuỗi là tự mở lại bậc tool '
            'bằng một so sánh sai');
  });
}
