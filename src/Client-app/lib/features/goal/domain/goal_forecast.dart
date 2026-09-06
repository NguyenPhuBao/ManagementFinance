/// Dự báo tiến độ mục tiêu dựa trên **nhịp tích luỹ thật**, không phải kế hoạch
/// đã cài lúc tạo.
///
/// ## Vì sao cần
///
/// `targetDate` được tính MỘT LẦN lúc tạo mục tiêu, từ số tiền và chu kỳ người
/// dùng nhập vào khối "Tự động trích tiền định kỳ", rồi đóng băng thành hạn
/// chót. Nhưng không có bộ lập lịch nào trích tiền cả — người dùng nạp tay, số
/// bất kỳ, lúc bất kỳ. Kế hoạch và thực tế trôi xa nhau mà không có gì đối
/// chiếu, và màn hình chỉ lặp lại cái hạn chót đã cũ.
///
/// Các hàm ở đây dựng lại nhịp thật từ số tiền đã tích được, để hiển thị được
/// "cần 3 triệu mỗi tháng · đang tích 1,2 triệu mỗi tháng".
///
/// Mọi hàm trả `null` khi **không đủ căn cứ**, cùng nguyên tắc với
/// [GoalEntity.isBehindSchedule]: im lặng đúng hơn là báo bừa.
library;

import '../data/models/goal_entity.dart';

/// Số ngày quy ước của một chu kỳ trích tiền.
///
/// Bộ giá trị lấy đúng theo cột `Cycle_take_money` của backend. Giá trị lạ hoặc
/// trống thì coi như hàng tháng — mặc định của cả app; đoán một chu kỳ khác làm
/// mọi con số hiển thị sai lệch mà không ai biết vì sao.
int soNgayChuKy(String? cycle) => switch (cycle) {
      'Day' => 1,
      'Week' => 7,
      'Month' => 30,
      'Quarter' => 90,
      'Year' => 365,
      _ => 30,
    };

/// Số ngày trọn vẹn giữa hai mốc, tính theo NGÀY chứ không theo thời điểm.
///
/// Trừ `DateTime` thô thì cùng một mục tiêu ra 29 hay 30 ngày tuỳ giờ người
/// dùng mở app, và con số hiển thị nhảy qua nhảy lại.
int _soNgay(DateTime tu, DateTime den) =>
    DateTime(den.year, den.month, den.day)
        .difference(DateTime(tu.year, tu.month, tu.day))
        .inDays;

/// Tiền tích được mỗi chu kỳ tính tới [now], theo nhịp THẬT.
///
/// `null` khi chưa có `startDate` (mục tiêu do bản app cũ tạo) hoặc chưa qua
/// ngày nào — chia cho 0 ngày ra `Infinity` chứ không ném, và giá trị hỏng sẽ
/// trôi thẳng lên màn hình.
///
/// Trả `0.0` khi chưa nạp đồng nào: "chưa tích được gì" là một câu trả lời có
/// nghĩa, khác hẳn "không đủ căn cứ để nói".
double? tocDoThucTe(GoalEntity goal, DateTime now) {
  final batDau = goal.startDate;
  if (batDau == null) return null;

  final soNgayDaQua = _soNgay(batDau, now);
  if (soNgayDaQua <= 0) return null;

  final moiNgay = goal.currentAmount / soNgayDaQua;
  return moiNgay * soNgayChuKy(goal.cycleTakeMoney);
}

/// Tiền CẦN tích mỗi chu kỳ để kịp hạn, tính từ [now].
///
/// Đọc theo phần **còn thiếu** chứ không phải toàn bộ mục tiêu: đã tích được
/// một nửa thì nhịp cần thiết cho phần còn lại chỉ bằng một nửa. Dùng mục tiêu
/// gốc thì câu "cần 3 triệu mỗi tháng" không bao giờ giảm dù người dùng đã tích
/// gần đủ.
///
/// `null` khi đã quá hạn mà chưa đạt — chia cho số ngày âm ra một con số âm vô
/// nghĩa. Trả `0.0` khi đã đạt mục tiêu.
double? tocDoKeHoach(GoalEntity goal, {DateTime? now}) {
  if (goal.remainingAmount <= 0) return 0.0;

  final tuMoc = now ?? goal.startDate;
  if (tuMoc == null) return null;

  final soNgayConLai = _soNgay(tuMoc, goal.targetDate);
  if (soNgayConLai <= 0) return null;

  final moiNgay = goal.remainingAmount / soNgayConLai;
  return moiNgay * soNgayChuKy(goal.cycleTakeMoney);
}

/// Ngày dự kiến đạt mục tiêu **nếu giữ đúng nhịp hiện tại**.
///
/// `null` khi không đủ căn cứ, và cũng `null` khi tốc độ bằng 0 — tốc độ 0 cho
/// ra ngày ở vô cực, nơi gọi phải nói "chưa đạt được với tốc độ hiện tại" chứ
/// không hiện một ngày bịa.
///
/// Đã đạt mục tiêu thì trả về chính [now].
DateTime? duBaoHoanThanh(GoalEntity goal, DateTime now) {
  if (goal.remainingAmount <= 0) return now;

  final batDau = goal.startDate;
  if (batDau == null) return null;

  final soNgayDaQua = _soNgay(batDau, now);
  if (soNgayDaQua <= 0) return null;

  final moiNgay = goal.currentAmount / soNgayDaQua;
  if (moiNgay <= 0) return null;

  final soNgayCanThem = (goal.remainingAmount / moiNgay).ceil();
  // Kẹp trên 100 năm: một tốc độ rất nhỏ cho ra ngày vượt khỏi tầm biểu diễn
  // của DateTime, và một dự báo "năm 12045" cũng vô dụng như không có.
  if (soNgayCanThem > 36500) return null;

  return now.add(Duration(days: soNgayCanThem));
}
