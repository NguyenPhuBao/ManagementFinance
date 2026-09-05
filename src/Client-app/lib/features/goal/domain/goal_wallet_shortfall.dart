import 'package:intl/intl.dart';

final NumberFormat _tien =
    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

/// Câu nhắc khi ví tích lũy **không còn đủ tiền** cho các mục tiêu trỏ vào nó,
/// hoặc `null` khi không có gì lệch.
///
/// ## Vì sao chỉ báo mà không tự sửa
///
/// Tiến độ mục tiêu và số dư ví là hai con số độc lập. Nạp và rút đều đi qua
/// mục tiêu nên chúng khớp nhau; nhưng một **giao dịch chi tiêu thường** từ
/// chính ví tích lũy thì không mang `goalId`, nên nó hạ số dư ví mà không hạ
/// tiến độ. Kết quả: mục tiêu ghi "đã tích 2 triệu" trong khi ví chỉ còn 300
/// nghìn.
///
/// App **không tự hoà giải** hai con số ấy, vì không đủ căn cứ để làm đúng:
///
/// - Một ví có thể phục vụ **nhiều mục tiêu** — trừ vào cái nào?
/// - Ví tích lũy cũng chứa tiền không thuộc mục tiêu nào — khoản chi có thể ăn
///   đúng vào phần dư ấy.
/// - Tự hạ tiến độ là bất ngờ: mua ly cà phê từ ví tiết kiệm mà mục tiêu mua xe
///   lùi lại một bậc, không ai hỏi han gì.
///
/// Đây là mô hình phong bì: phong bì nói **ý định**, tài khoản nói **thực tế**,
/// lệch nhau thì báo cho người dùng quyết — chỉ họ biết khoản chi ấy ăn vào đâu.
///
/// [tongMucTieuDangGiu] phải là **tổng của MỌI mục tiêu** trỏ vào ví này, không
/// phải riêng mục tiêu đang mở: so lẻ từng cái thì ba mục tiêu đều thấy "đủ
/// tiền" trong khi cộng lại thì thiếu.
String? canhBaoViKhongDu({
  required String tenVi,
  required double soDuVi,
  required double tongMucTieuDangGiu,
}) {
  // Chưa mục tiêu nào tích được gì thì không có gì để lệch. Ví âm là chuyện của
  // ví, đã có quy tắc thông báo riêng lo.
  if (tongMucTieuDangGiu <= 0) return null;
  if (soDuVi >= tongMucTieuDangGiu) return null;

  return 'Ví "$tenVi" còn ${_tien.format(soDuVi)}, ít hơn '
      '${_tien.format(tongMucTieuDangGiu)} mà các mục tiêu đang ghi nhận. '
      'Có khoản chi nào đó đã tiêu vào tiền tích lũy.';
}
