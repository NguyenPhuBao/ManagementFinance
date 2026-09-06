import 'goal_auto_deposit.dart';

/// Hạn định cho **vòng mới** của một mục tiêu lặp lại.
///
/// ## Vì sao luôn bước ít nhất một kỳ
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
  required String? chuKy,
  required DateTime now,
  int toiDa = 1200,
}) {
  var moc = mocKeTiep(hanCu, chuKy);
  var soVong = 1;

  while (!moc.isAfter(now)) {
    if (++soVong > toiDa) return null;
    moc = mocKeTiep(moc, chuKy);
  }

  return moc;
}
