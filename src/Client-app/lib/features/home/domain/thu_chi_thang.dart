import '../../../core/database/app_database.dart';

/// Tổng thu và tổng chi của tháng chứa [now] — con số của thẻ số liệu tháng
/// ở Trang chủ (`TheSoLieuThang`).
///
/// Tách thành hàm thuần vì từ 2026-09-19 có **hai** chỗ đọc nó: thẻ số liệu
/// và gói số của khối Nhận xét (`GoiSoTrangChu.tu`). Điều kiện 12 của mảng AI
/// là *số trên thẻ = số trong gói*; hai vòng lặp chép tay là hai định nghĩa
/// sẽ lệch nhau im lặng.
///
/// Cố ý là phép cộng **thô** theo `type` — đúng như thẻ đã làm từ đầu, không
/// đi qua `khoanVaoThongKe` — để gói số nhận đúng con số người dùng đang thấy
/// ngay phía trên. Đổi luật thì đổi ở đây, cả hai chỗ đổi theo.
({double thu, double chi}) thuChiThangCua(
  Iterable<Transaction> ds,
  DateTime now,
) {
  var thu = 0.0;
  var chi = 0.0;
  for (final t in ds) {
    if (t.date.year != now.year || t.date.month != now.month) continue;
    if (t.type == 'thu') thu += t.amount;
    if (t.type == 'chi') chi += t.amount;
  }
  return (thu: thu, chi: chi);
}
