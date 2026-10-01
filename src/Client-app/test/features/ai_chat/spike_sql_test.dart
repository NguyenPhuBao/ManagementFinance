/// Spike "E2B sinh SQL" (mục 9.29 `AI_EDGE_FEATURE.md`, 2026-09-27): hai hàm
/// thuần của đường đo tạm — hàng rào chỉ-đọc quanh câu SELECT mô hình viết, và
/// prompt lược đồ. Đường này chỉ sống sau `--dart-define=SPIKE_SQL=true`.
library;

import 'package:flowmoney/features/ai_chat/spike/spike_sql.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trichSelect — hàng rào chỉ đọc', () {
    test('lấy câu SELECT trong rào ```sql``` và thêm LIMIT', () {
      final s = trichSelect('```sql\nSELECT name FROM wallets WHERE x = 1;\n```');
      expect(s, 'SELECT name FROM wallets WHERE x = 1 LIMIT 20');
    });

    test('giữ LIMIT mô hình đã đặt', () {
      expect(trichSelect('SELECT 1 LIMIT 3'), 'SELECT 1 LIMIT 3');
    });

    test('từ chối mọi câu không phải SELECT', () {
      expect(trichSelect('UPDATE wallets SET balance = 0'), isNull);
      expect(trichSelect('DELETE FROM transactions'), isNull);
      expect(trichSelect('không có sql'), isNull);
    });

    test('từ chối SELECT chở theo câu thứ hai hoặc từ khoá ghi', () {
      expect(trichSelect('SELECT 1; DROP TABLE wallets'), isNull,
          reason: 'hai câu trong một chuỗi là đường ghi trá hình');
      expect(trichSelect('SELECT * FROM t WHERE 1 = 1 UNION SELECT * FROM pragma_table_info(1)'),
          isNull, reason: 'PRAGMA/pragma_ đọc lược đồ, ngoài phạm vi spike');
    });
  });

  group('promptSpikeSql', () {
    final p = promptSpikeSql(
      'Tháng này tôi chi bao nhiêu?',
      idaccount: 10,
      now: DateTime(2026, 9, 27, 15),
    );

    test('mang mã tài khoản, mốc kỳ epoch giây và câu hỏi ở cuối', () {
      expect(p, contains('idaccount = 10'));
      // Tháng 9/2026 giờ máy: 01/09 00:00 và 01/10 00:00.
      final tu = DateTime(2026, 9, 1).millisecondsSinceEpoch ~/ 1000;
      final den = DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000;
      expect(p, contains('$tu'));
      expect(p, contains('$den'));
      expect(p.trimRight(), endsWith('Hỏi: Tháng này tôi chi bao nhiêu?\nSQL:'));
    });

    test('nêu ba luật ngầm mà lược đồ không tự nói', () {
      expect(p, contains('amount luôn dương'));
      expect(p, contains("'transfer'"));
      expect(p, contains('Điều chỉnh số dư'));
    });
  });
}
