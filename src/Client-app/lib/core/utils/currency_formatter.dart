import 'package:intl/intl.dart';

/// Định dạng số tiền — **một định nghĩa duy nhất cho cả app**.
///
/// Thông lệ Việt Nam: dấu **chấm** ngăn từng ba chữ số của phần nguyên, dấu
/// **phẩy** cho phần thập phân.
///
/// ```dart
/// CurrencyFormatter.format(1234567)     // → "1.234.567 đ"
/// CurrencyFormatter.format(1234567.5)   // → "1.234.567,50 đ"
/// CurrencyFormatter.formatIncome(500000)  // → "+500.000 đ"
/// CurrencyFormatter.formatExpense(500000) // → "-500.000 đ"
/// ```
///
/// ## Đây là nơi DUY NHẤT được dựng `NumberFormat`
///
/// Trước 2026-09-09 lớp này đã tồn tại nhưng **21 tệp vẫn gọi thẳng
/// `NumberFormat`, sáu kiểu khác nhau, 45 chỗ**. Hậu quả đo được: 18 chỗ hiện
/// `đ` còn lớp này hiện `₫` — cùng một app, hai ký hiệu tiền. Và đổi quy tắc ở
/// một nơi chỉ làm app hiện hai định dạng lẫn lộn thay vì một.
///
/// `test/core/utils/currency_formatter_test.dart` có một test quét toàn bộ
/// `lib/` và **cấm** chuỗi `NumberFormat` xuất hiện ngoài tệp này. Cần định
/// dạng mới thì thêm hàm ở đây, đừng dựng tại chỗ.
///
/// ## Vì sao [format] làm tròn về đồng chẵn
///
/// Tiền Việt không có đơn vị nhỏ hơn đồng, và cả 17 chỗ trong app trước đây
/// đều cố ý đặt `decimalDigits: 0`. Bản đầu của lớp này hiện phần lẻ khi có,
/// và hậu quả lộ ra ngay ở bộ test: mọi số **tính ra** — thiếu hụt so với kế
/// hoạch, chi trung bình mỗi ngày, dự phóng — đều có đuôi lẻ, nên màn hình đầy
/// những `7.927.272,73 đ` thay vì `7.927.273 đ`.
///
/// Nên [format] làm tròn, còn [formatCoLe] mới hiện phần lẻ — và khi hiện thì
/// nó dùng **dấu phẩy**, đúng thông lệ Việt Nam.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Ký hiệu tiền đồng. Chọn `đ` (chữ cái) chứ không phải `₫` (ký hiệu tiền
  /// tệ Unicode) vì 18/20 chỗ trong app và bản thiết kế Stitch đều dùng `đ`.
  static const String kyHieu = 'đ';

  /// Cả hai khuôn đều lấy dấu ngăn từ locale `vi_VN` — chấm cho nhóm nghìn,
  /// phẩy cho thập phân — thay vì tự thay ký tự bằng tay. Bản trước làm bằng
  /// tay (`formatted.replaceAll(',', '.')`) kèm một chú thích **sai** rằng
  /// "vi_VN dùng dấu phẩy làm phân cách ngàn"; nó chỉ chạy đúng vì phép thay
  /// ấy không tìm thấy gì để thay.
  static final NumberFormat _nguyen = NumberFormat('#,##0', 'vi_VN');
  static final NumberFormat _coLe = NumberFormat('#,##0.00', 'vi_VN');
  static final NumberFormat _gon = NumberFormat.compact(locale: 'vi_VN');

  /// `1234567` → `"1.234.567 đ"`. Làm tròn về đồng chẵn — xem chú thích lớp.
  static String format(num amount) {
    final dau = amount < 0 ? '-' : '';
    return '$dau${_nguyen.format(amount.abs())} $kyHieu';
  }

  /// `1234567.5` → `"1.234.567,50 đ"`. Luôn hiện đúng hai chữ số thập phân,
  /// ngăn bằng **dấu phẩy**.
  ///
  /// Chỉ dùng ở chỗ phần lẻ thật sự có nghĩa. Mặc định của app là [format].
  static String formatCoLe(num amount) {
    final dau = amount < 0 ? '-' : '';
    return '$dau${_coLe.format(amount.abs())} $kyHieu';
  }

  /// Thu nhập với dấu `+`. Chiều tiền do **nơi gọi** quyết định, không suy từ
  /// dấu của số — nếu không, một khoản chi lưu số âm sẽ thành `--500.000`.
  static String formatIncome(num amount) => '+${format(amount.abs())}';

  /// Chi tiêu với dấu `-`.
  static String formatExpense(num amount) => '-${format(amount.abs())}';

  /// Số có nhóm nghìn nhưng **không kèm ký hiệu** — cho ô nhập liệu và những
  /// chỗ tự đặt ký hiệu ở vị trí khác.
  ///
  /// Cùng quy tắc dấu với [format]: chấm ngăn nghìn, phẩy cho phần lẻ.
  static String formatSoThoi(num amount) {
    final soChu = _nguyen.format(amount.abs());
    return amount < 0 ? '-$soChu' : soChu;
  }

  /// `1200000` → `"1,2 Tr đ"`. Dùng cho chỗ hẹp, ví dụ nhãn trục biểu đồ.
  static String formatCompact(num amount) {
    if (amount == 0) return '0 $kyHieu';
    final gon = _gon.format(amount.abs());
    return amount < 0 ? '-$gon $kyHieu' : '$gon $kyHieu';
  }

  /// Đọc ngược một chuỗi tiền về số. Trả `null` nếu không đọc được.
  ///
  /// Đúng chiều ngược của [format]: bỏ dấu chấm (nhóm nghìn), đổi dấu phẩy
  /// thành dấu chấm (thập phân của Dart).
  static double? parse(String text) {
    final cleaned = text
        .replaceAll('₫', '')
        .replaceAll(kyHieu, '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned);
  }
}
