import 'package:intl/intl.dart';

/// Formatter tiền tệ Việt Nam cho FlowMoney.
///
/// Sử dụng `intl` package — đảm bảo format đúng locale vi_VN.
///
/// Ví dụ:
/// ```dart
/// CurrencyFormatter.format(1234567)   // → "1.234.567 ₫"
/// CurrencyFormatter.formatCompact(1200000) // → "1,2M ₫"
/// CurrencyFormatter.formatSigned(-50000)   // → "-50.000 ₫"
/// ```
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _fullFormatter = NumberFormat('#,###', 'vi_VN');
  static final _compactFormatter = NumberFormat.compact(locale: 'vi_VN');

  /// Format số tiền đầy đủ: `1234567` → `"1.234.567 ₫"`
  static String format(num amount) {
    if (amount == 0) return '0 ₫';
    final formatted = _fullFormatter.format(amount.abs());
    // vi_VN dùng dấu phẩy làm phân cách ngàn — đổi sang dấu chấm theo chuẩn VN
    final vnFormatted = formatted.replaceAll(',', '.');
    return amount < 0 ? '-$vnFormatted ₫' : '$vnFormatted ₫';
  }

  /// Format thu nhập với dấu +: `500000` → `"+500.000 ₫"`
  static String formatIncome(num amount) {
    final formatted = format(amount.abs());
    return '+$formatted';
  }

  /// Format chi tiêu với dấu -: `500000` → `"-500.000 ₫"`
  static String formatExpense(num amount) {
    final formatted = format(amount.abs());
    return '-$formatted';
  }

  /// Format số tiền gọn: `1200000` → `"1,2M ₫"`, `1500` → `"1,5K ₫"`
  static String formatCompact(num amount) {
    if (amount == 0) return '0 ₫';
    final compact = _compactFormatter.format(amount.abs());
    return amount < 0 ? '-$compact ₫' : '$compact ₫';
  }

  /// Parse chuỗi tiền về double: `"1.234.567"` → `1234567.0`
  /// Trả về `null` nếu không parse được.
  static double? parse(String text) {
    final cleaned = text
        .replaceAll('₫', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned);
  }
}
