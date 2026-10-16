/// Hai kiểu Dart thuần của biểu mẫu Thêm / Sửa mục tiêu — dời từ `goal_add_page.dart` (spec 2026-10-13 mục 5.1) để các khối ở `widgets/them_muc_tieu/` dùng mà không import trang.
library;

enum DepositFrequency { daily, weekly, monthly }

/// Ba chu kỳ lặp lại mục tiêu, khoá là giá trị ghi xuống `time_recurrence`.
///
/// Cố ý HẸP hơn `mocKeTiep` (vốn nhận thêm `'Day'` và `'Quarter'`): lặp lại một
/// mục tiêu tiết kiệm mỗi ngày không có nghĩa gì, và mỗi lựa chọn thừa là một
/// hàng người dùng phải đọc qua. `mocKeTiep` vẫn xử lý được giá trị lạ đến từ
/// Admin-web hay bản app cũ, nên thu hẹp ở đây không làm hỏng dữ liệu sẵn có.
const Map<String, String> kChuKyLapLai = {
  'Week': 'Hàng tuần',
  'Month': 'Hàng tháng',
  'Year': 'Hàng năm',
};
