import 'package:intl/intl.dart';

/// Formatter ngày tháng cho FlowMoney — tất cả hiển thị tiếng Việt.
///
/// Ví dụ:
/// ```dart
/// DateFormatter.formatDate(DateTime.now())         // → "10/08/2026"
/// DateFormatter.formatMonthYear(DateTime.now())    // → "Tháng 8, 2026"
/// DateFormatter.formatRelative(DateTime.now())     // → "Hôm nay"
/// DateFormatter.formatRelative(yesterday)          // → "Hôm qua"
/// DateFormatter.formatRelative(lastWeek)           // → "Thứ Hai, 04/08"
/// ```
class DateFormatter {
  DateFormatter._();

  static final _dateFormat       = DateFormat('dd/MM/yyyy', 'vi_VN');
  static final _dateTimeFormat   = DateFormat('HH:mm, dd/MM/yyyy', 'vi_VN');
  static final _monthYearFormat  = DateFormat('MMMM, yyyy', 'vi_VN');
  static final _dayMonthFormat   = DateFormat('dd/MM', 'vi_VN');
  static final _weekdayFormat    = DateFormat('EEEE', 'vi_VN');
  static final _timeFormat       = DateFormat('HH:mm', 'vi_VN');

  /// `10/08/2026`
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// `10:30, 10/08/2026`
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// `Tháng 8, 2026`
  static String formatMonthYear(DateTime date) {
    final formatted = _monthYearFormat.format(date);
    // Viết hoa chữ cái đầu tháng
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// `10:30`
  static String formatTime(DateTime date) => _timeFormat.format(date);

  /// Hiển thị date dạng tương đối:
  /// - Hôm nay → "Hôm nay"
  /// - Hôm qua → "Hôm qua"  
  /// - Trong tuần hiện tại → "Thứ Hai, 04/08"
  /// - Xa hơn → "10/08/2026"
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    if (diff < 7) {
      final weekday = _weekdayFormat.format(date);
      final dayMonth = _dayMonthFormat.format(date);
      // Viết hoa chữ cái đầu thứ
      final weekdayCap = weekday[0].toUpperCase() + weekday.substring(1);
      return '$weekdayCap, $dayMonth';
    }
    return formatDate(date);
  }

  /// Nhóm transactions theo ngày: "Hôm nay", "Hôm qua", vv.
  static String groupHeader(DateTime date) => formatRelative(date);

  /// So sánh 2 ngày có cùng ngày không (bỏ qua giờ)
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Parse chuỗi dd/MM/yyyy về DateTime, trả null nếu lỗi
  static DateTime? parseDate(String text) {
    try {
      return _dateFormat.parseStrict(text);
    } catch (_) {
      return null;
    }
  }
}
