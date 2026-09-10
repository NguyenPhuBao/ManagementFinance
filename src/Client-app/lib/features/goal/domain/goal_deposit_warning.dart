import '../../../core/utils/currency_formatter.dart';

import '../data/models/goal_entity.dart';

/// Câu nhắc khi số tiền định nạp **vượt** phần còn thiếu của mục tiêu, hoặc
/// `null` khi không có gì để nhắc.
///
/// ## Vì sao nhắc mà không chặn
///
/// Tiết kiệm dư là chuyện bình thường — người dùng có thể cố ý gửi tròn số,
/// hoặc gộp luôn khoản của tháng sau. Chặn lại biến một thao tác hợp lệ thành
/// lỗi. Nhưng im lặng hoàn toàn cũng không đúng: nạp nhầm một số 0 thì tiền đã
/// rời khỏi ví nguồn và người dùng chỉ phát hiện khi xem lại số dư.
///
/// Nên: vẫn nạp đủ số người dùng nhập, kèm một câu nói rõ vượt bao nhiêu.
///
/// [soTienNap] không hợp lệ (≤ 0) thì trả `null` — ô nhập đã có phép kiểm riêng
/// cho việc đó, chồng hai thông báo lên nhau chỉ làm rối.
String? canhBaoNapVuot(GoalEntity mucTieu, double soTienNap) {
  if (soTienNap <= 0) return null;

  final conThieu = mucTieu.remainingAmount;
  if (soTienNap <= conThieu) return null;

  final vuot = soTienNap - conThieu;
  return 'Khoản này vượt ${CurrencyFormatter.format(vuot)} so với mục tiêu. '
      'Tiền vẫn được ghi nhận đầy đủ.';
}
