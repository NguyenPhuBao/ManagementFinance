/// Canary phiên có tool (bước 1b, 2026-09-23) phải được NỐI vào app thật.
///
/// Lớp `CanaryCongCu` có đủ test riêng, xanh hết — nhưng nếu không chỗ nào gọi
/// nó thì trên máy sập native app vẫn văng ở **mọi** câu hỏi, và không test
/// nào đỏ: `flutter test` chạy trên x86_64, nơi engine mô hình không chạy, nên
/// đường thật của phiên có tool là vùng mù (bẫy 4.33 `AI_EDGE_FEATURE.md`).
///
/// Bốn mối nối, mỗi mối là một chuỗi rời nhau nên `flutter analyze` không bắt
/// được khi thiếu. Tệp này đọc mã nguồn của từng mối — cùng lối
/// `bill_conflict_resolver_wiring_test.dart`; nó đọc **tệp cụ thể** nên không
/// nằm trong chuỗi đánh số test quét `lib/`.
library;

import 'dart:io';

import 'package:flowmoney/features/ai_edge/data/nguon_ly_do_thoat.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(String duongDan) => File(duongDan).readAsStringSync();

void main() {
  test('runtime thật: mở phiên hỏi daTat(), lượt sinh đi qua quaCanary', () {
    final s = _doc('lib/features/ai_edge/data/slm_runtime.dart');
    expect(s, contains('daTat()'),
        reason: 'không hỏi thì máy đã biết là sập vẫn mở phiên có tool');
    expect(s, contains('throw const BacCongCuDaTat()'),
        reason: 'vòng lặp tool nhận ra đúng lỗi này để đi bậc 1 thay vì L4');
    expect(s, contains('quaCanary('),
        reason: 'không bọc thì dấu không bao giờ được đặt — canary vô dụng');
  });

  test('DI: SlmRuntimeThat nhận canaryCongCu với nguồn là kênh Android thật',
      () {
    final s = _doc('lib/core/di/injection_container.dart');
    expect(s, contains('canaryCongCu:'));
    expect(s, contains('NguonLyDoThoatAndroid()'));
  });

  test('main.dart xét dấu sót lúc khởi động', () {
    expect(_doc('lib/main.dart'), contains('xetDauSot()'),
        reason: 'xét ngay lúc mở app là lúc lịch sử lý do thoát của Android '
            'còn nguyên bản ghi của cú sập; để tới câu hỏi kế thì có thể đã '
            'qua nhiều lần mở app và bản ghi bị đẩy khỏi lịch sử');
  });

  test('Kotlin: MainActivity mở đúng kênh, đúng phương thức, trả đúng khoá', () {
    final kt = _doc(
        'android/app/src/main/kotlin/com/flowmoney/flowmoney/MainActivity.kt');
    expect(kt, contains('"$kKenhLyDoThoat"'),
        reason: 'tên kênh hai phía lệch nhau thì phía Dart nhận '
            'MissingPluginException, đọc thành "không biết" — im lặng');
    expect(kt, contains('"thongTin"'));
    for (final khoa in ['phienBan', 'lanThoat', 'lyDo', 'luc']) {
      expect(kt, contains('"$khoa"'),
          reason: 'khoá "$khoa" là thứ nguon_ly_do_thoat.dart đọc');
    }
    expect(kt, contains('getHistoricalProcessExitReasons'));
  });
}
