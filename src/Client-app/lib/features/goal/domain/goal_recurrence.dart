import 'goal_auto_deposit.dart';

/// Hạn định cho **vòng mới** của một mục tiêu lặp lại.
///
/// ## Luật chính: vòng mới dài ĐÚNG bằng vòng trước (2026-11-04)
///
/// Có [batDauCu] (mốc bắt đầu của vòng vừa xong) thì vòng mới dài đúng số
/// ngày người dùng đã đặt cho vòng ấy, tính từ [now] — lúc họ bấm "Bắt đầu vòng
/// mới": hạn mới = ngày của [now] + (ngày [hanCu] − ngày [batDauCu]), giữ giờ
/// phút của [hanCu]. Người dùng chốt thay cho chu kỳ tuần / tháng / năm chọn
/// tay: hạn đặt bằng một số ngày bất kỳ (tạo 01/11, hạn 12/12 = 41 ngày) mà
/// cộng "một tuần" vào hạn cũ thì vòng sau dài 18 hay 8 ngày tuỳ hôm bấm — không
/// liên quan gì tới kế hoạch họ đã đặt. Vì `batDauVongMoi` đặt lại mốc bắt đầu
/// bằng lúc bấm, độ dài này giữ nguyên qua mọi vòng (trừ khi người dùng tự sửa
/// hạn giữa chừng — khi ấy vòng sau theo hạn đã sửa, đúng ý họ).
///
/// Đếm theo **ngày lịch** (so hai mốc UTC dựng từ năm-tháng-ngày), không theo
/// `Duration`: hiệu hai `DateTime` cục bộ lệch giờ nhau cho `inDays` hụt một
/// khi hạn mang giờ sớm hơn mốc bắt đầu.
///
/// ## Dự phòng: thiếu mốc bắt đầu thì theo chu kỳ cũ
///
/// Mục tiêu tạo từ bản app cũ hay Admin-web có thể trống `start_date`, hoặc
/// mang mốc bắt đầu không trước hạn (dữ liệu hỏng) — không đo được độ dài vòng.
/// Khi ấy hàm giữ luật trước 2026-11-04: bước theo [chuKy] (`time_recurrence`,
/// trống quy về hàng tháng) từ [hanCu] tới mốc đầu tiên sau [now].
///
/// ## Vì sao bản dự phòng luôn bước ít nhất một kỳ
///
/// Đạt mục tiêu **sớm** là chuyện thường: hạn cũ có thể vẫn còn ở tương lai lúc
/// người dùng bấm "Bắt đầu vòng mới". Giữ nguyên hạn ấy thì vòng mới thừa
/// hưởng phần thời gian còn lại của vòng trước — càng về đích sớm thì vòng sau
/// càng ngắn, ngược hẳn với ý nghĩa của một chu kỳ.
///
/// Ngược lại, hoàn thành **muộn** thì hạn cũ đã lùi lại phía sau; đặt vòng mới
/// vào một mốc đã qua là nó quá hạn ngay giây đầu tiên, và bộ dự báo kêu "chậm
/// tiến độ" trước khi người dùng kịp nạp đồng nào.
///
/// Nên: bước một kỳ, rồi bước tiếp chừng nào còn chưa vượt qua [now].
///
/// ## Vì sao gọi lại `mocKeTiep` thay vì tự cộng
///
/// `DateTime(2028, 2, 31)` **không ném lỗi** — Dart tự chuẩn hoá thành 02/03.
/// Cộng tháng kiểu thô cho một mục tiêu đặt vào ngày 31 sẽ đẩy mốc trôi dần
/// sang tháng sau, mỗi vòng một ít, và không có gì báo. Hàng rào cho chuyện đó
/// đã dựng sẵn trong [mocKeTiep] kèm test năm nhuận; dựng bản thứ hai ở đây là
/// tự chuốc hai luật lệch nhau.
///
/// Trả `null` khi [hanCu] xa quá [toiDa] bước — dữ liệu hỏng phải dừng ở một
/// con số hữu hạn. Một vòng `while` không trần trong hàm được giao diện gọi là
/// cách treo app mà không để lại lấy một dòng log.
DateTime? hanVongMoi({
  required DateTime hanCu,
  DateTime? batDauCu,
  required String? chuKy,
  required DateTime now,
  int toiDa = 1200,
}) {
  final soNgay = batDauCu == null ? null : soNgayMotVong(batDauCu, hanCu);
  if (soNgay != null) {
    return DateTime(
      now.year,
      now.month,
      now.day + soNgay,
      hanCu.hour,
      hanCu.minute,
      hanCu.second,
      hanCu.millisecond,
      hanCu.microsecond,
    );
  }

  var moc = mocKeTiep(hanCu, chuKy);
  var soVong = 1;

  while (!moc.isAfter(now)) {
    if (++soVong > toiDa) return null;
    moc = mocKeTiep(moc, chuKy);
  }

  return moc;
}

/// Số ngày lịch của một vòng, từ ngày [batDau] tới ngày [han].
///
/// `null` khi hạn không đứng SAU ngày bắt đầu ít nhất một ngày — dữ liệu ấy
/// không cho ra một độ dài dùng được, và [hanVongMoi] rơi về chu kỳ cũ.
int? soNgayMotVong(DateTime batDau, DateTime han) {
  final soNgay = DateTime.utc(han.year, han.month, han.day)
      .difference(DateTime.utc(batDau.year, batDau.month, batDau.day))
      .inDays;
  return soNgay >= 1 ? soNgay : null;
}
