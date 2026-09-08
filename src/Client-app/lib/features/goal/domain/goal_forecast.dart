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
  if (!_duCuaSo(soNgayDaQua, goal.cycleTakeMoney)) return null;

  final moiNgay = goal.currentAmount / soNgayDaQua;
  return moiNgay * soNgayChuKy(goal.cycleTakeMoney);
}

/// Đã theo dõi đủ lâu để nói một câu về **nhịp** chưa?
///
/// ## Vì sao cần, và vì sao `soNgayDaQua > 0` là chưa đủ
///
/// Cả [tocDoThucTe] lẫn [duBaoHoanThanh] đều **ngoại suy**: lấy số tiền của
/// *n* ngày đã qua rồi nhân lên độ dài chu kỳ. Hệ số phóng đại là `chuKỳ / n`,
/// nên *n* càng nhỏ thì con số càng bịa.
///
/// Đo được trên máy thật ngày 2026-09-08: mục tiêu tạo 05/09, xem 08/09, đã
/// tích 1.101.000 đ, chu kỳ tháng → màn hình hiện **"đang tích 11.010.000 đ
/// mỗi tháng"**, gấp mười lần tổng đã tích được cả đời mục tiêu, kèm dự báo
/// hoàn thành ngay tháng ấy cho một mục tiêu hạn 2028. Phép chặn cũ
/// (`soNgayDaQua <= 0`) chỉ đỡ được phép chia cho 0, không đỡ được việc bịa
/// ra một nhịp.
///
/// ## Vì sao là NỬA chu kỳ, không phải một chu kỳ trọn
///
/// Nửa chu kỳ đưa hệ số phóng đại tối đa về **2** — mức sai lệch chấp nhận
/// được cho một câu ước lượng. Đợi trọn một chu kỳ thì mục tiêu hàng tháng câm
/// suốt tháng đầu, mà tháng đầu mới là lúc người dùng mở ra xem nhiều nhất.
///
/// ## Vì sao ngưỡng tính THEO chu kỳ, không phải một số ngày cứng
///
/// Chu kỳ **ngày** không có ngoại suy nào để chặn (hệ số bằng 1), nên một
/// ngưỡng cứng kiểu "phải đủ 7 ngày" sẽ bắt nó im lặng vô cớ. Ngược lại chu kỳ
/// **năm** thì hai tháng vẫn là hệ số 6 — cùng một lỗi với ca ba ngày, chỉ
/// khác thang.
bool _duCuaSo(int soNgayDaQua, String? chuKy) =>
    soNgayDaQua > 0 && soNgayDaQua * 2 >= soNgayChuKy(chuKy);

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
  // Cùng cửa sổ với `tocDoThucTe`, và phải là CÙNG MỘT phép kiểm: chặn một
  // chỗ mà để chỗ kia nói tiếp thì hộp dự báo vẫn sai, chỉ sai gọn hơn — hai
  // dòng cạnh nhau trên màn hình vốn đọc như một câu.
  if (!_duCuaSo(soNgayDaQua, goal.cycleTakeMoney)) return null;

  final moiNgay = goal.currentAmount / soNgayDaQua;
  if (moiNgay <= 0) return null;

  final soNgayCanThem = (goal.remainingAmount / moiNgay).ceil();
  // Kẹp trên 100 năm: một tốc độ rất nhỏ cho ra ngày vượt khỏi tầm biểu diễn
  // của DateTime, và một dự báo "năm 12045" cũng vô dụng như không có.
  if (soNgayCanThem > 36500) return null;

  return now.add(Duration(days: soNgayCanThem));
}
