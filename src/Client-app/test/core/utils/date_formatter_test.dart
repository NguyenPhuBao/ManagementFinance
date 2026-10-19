/// `DateFormatter` — nơi duy nhất dựng `DateFormat` (test quét `lib/` thứ 32). Mỗi mẫu một hàm, chữ ra giữ nguyên từng
/// ký tự so với bản dựng tay trước 2026-10-19.
library;

import 'package:flowmoney/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Thứ Hai 03/08/2026 09:05 — ngày, tháng, giờ, phút đều một chữ số để canh phần đệm 0.
  final d = DateTime(2026, 8, 3, 9, 5);

  group('mẫu chỉ có số — KHÔNG cần initializeDateFormatting (nhóm này phải chạy trước mọi lời init)', () {
    test('mỗi hàm ra đúng chữ đang hiện trên màn', () {
      expect(DateFormatter.formatDate(d), '03/08/2026', reason: 'ngày dd/MM/yyyy, đệm 0');
      expect(DateFormatter.formatDayMonth(d), '03/08', reason: 'dd/MM');
      expect(DateFormatter.formatDateTime(d), '03/08/2026 09:05', reason: 'ngày rồi giờ — năm chỗ trong app');
      expect(DateFormatter.formatTimeDate(d), '09:05 03/08/2026', reason: 'giờ rồi ngày — thẻ đơn Premium theo Stitch');
      expect(DateFormatter.formatMonthYear(d), '08/2026', reason: 'MM/yyyy — khối Nhận định mục tiêu');
      expect(DateFormatter.formatMonthYearShort(d), '08/26', reason: 'MM/yy — trục biểu đồ tiến độ dài');
      expect(DateFormatter.dayKey(d), '2026-08-03', reason: 'khoá nhóm ngày ở Sổ giao dịch, so chuỗi được theo thời gian');
    });
  });

  group('mẫu có tên thứ — cần dữ liệu locale vi_VN', () {
    setUpAll(() => initializeDateFormatting('vi_VN'));

    test('formatWeekdayDate: tên thứ tiếng Việt + dd/MM/yyyy', () {
      final s = DateFormatter.formatWeekdayDate(d);
      expect(s, endsWith(', 03/08/2026'), reason: 'mẫu EEEE, dd/MM/yyyy');
      expect(s.toLowerCase(), startsWith('thứ hai'), reason: 'locale vi_VN, không phải "Monday"');
    });
  });
}
