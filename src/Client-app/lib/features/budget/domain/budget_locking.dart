import '../data/models/budget_entity.dart';

/// Ngân sách đã hết hạn thì khoá sửa và xoá: số liệu đã chốt sổ không được đổi
/// về sau, và tab "Đã hết hạn" là nền cho phần thống kê sẽ làm sau.
///
/// Nơi duy nhất quyết định điều đó. Trước đây phép kiểm nằm rải ở hai chỗ trong
/// giao diện (`budget_tabs_view` chặn vuốt xoá, `budget_detail_page` bỏ nút
/// Sửa), nên nới một chỗ mà quên chỗ kia là chuyện sớm muộn.
///
/// ⚠️ Một ngoại lệ, và nó là **G15**: bản ghi chưa lên tới server được thì
/// luôn mở. Một ngân sách vừa hết hạn vừa bị backend từ chối vĩnh viễn sẽ kẹt
/// không lối ra — không đẩy lên được, mà cũng không mở ra sửa hay xoá được.
/// Đã gặp thật ngày 2026-09-04 với `end = start` vi phạm
/// `chk_budget_end_after_start`; lối thoát duy nhất khi ấy là xoá dữ liệu site
/// của trình duyệt rồi pull lại.
///
/// Khoá thao tác là để bảo vệ **số liệu đã chốt**, không phải để nhốt **dữ
/// liệu hỏng**.
bool budgetActionsLocked({
  required bool expired,
  required BudgetEntity budget,
}) {
  if (!expired) return false;
  return !budget.hasSyncError;
}
