/// Một khoản chi sắp ghi sẽ làm ngân sách của danh mục ấy ra sao — logic
/// thuần cho form thêm giao dịch.
///
/// Đây là nơi duy nhất đọc `OverSpending`: trước 2026-09-06 lựa chọn "Chặn"
/// tồn tại trên form ngân sách nhưng không nơi nào dùng tới. "Chặn" nghĩa là
/// **hỏi xác nhận** trước khi ghi khoản làm vượt, không phải từ chối ghi —
/// tiền đã tiêu thật ngoài đời, app không ghi thì số dư ví lệch (người dùng
/// chốt ngày 2026-09-06).
library;

import '../../../core/utils/currency_formatter.dart';
import '../data/models/budget_entity.dart';

class BudgetImpact {
  final BudgetView view;

  /// Còn lại **sau khi** ghi. Âm khi vượt.
  final double remainingAfter;

  /// Sắp chạm ngưỡng cảnh báo của chính ngân sách ấy sau khi ghi.
  final bool nearLimitAfter;

  const BudgetImpact({
    required this.view,
    required this.remainingAfter,
    required this.nearLimitAfter,
  });

  bool get exceeds => remainingAfter < 0;
  double get exceedsBy => exceeds ? -remainingAfter : 0.0;

  /// Chỉ khi ngân sách đặt "Chặn" VÀ khoản này làm vượt. "Cảnh báo" thì ghi
  /// luôn rồi báo.
  bool get requiresConfirmation =>
      exceeds && view.budget.overSpending == BudgetOverSpending.stop;
}

/// [date] có nằm trong kỳ hiện tại của [b] không (biên `to` mở).
bool budgetPeriodContains(BudgetEntity b, DateTime date, DateTime now) {
  final ky = b.currentPeriod(now);
  return !date.isBefore(ky.from) && date.isBefore(ky.to);
}

/// `null` khi không có gì để nói: không có ngân sách, hoặc khoản ghi ngoài kỳ
/// hiện tại (ghi lùi ngày sang tháng trước không đụng kỳ đang chạy).
///
/// [previousAmount] là số tiền cũ của khoản đang **sửa** nếu nó đã nằm trong
/// số đã chi; không trừ ra là báo vượt oan mỗi lần sửa một khoản lớn.
BudgetImpact? budgetImpactOf({
  required BudgetView? view,
  required double amount,
  double previousAmount = 0,
  required DateTime date,
  required DateTime now,
}) {
  if (view == null) return null;
  final b = view.budget;
  if (b.isExpired(now) || !budgetPeriodContains(b, date, now)) return null;

  final spentAfter = b.spent - previousAmount + amount;
  final after = b.copyWith(spent: spentAfter);
  return BudgetImpact(
    view: view,
    remainingAfter: b.amount - spentAfter,
    nearLimitAfter: after.isNearLimit,
  );
}

/// Lời nhắn sau khi lưu — **không có con số**: người dùng muốn banner tạm thời
/// tối giản, chi tiết nằm ở trang ngân sách. `null` khi không có gì đáng nói.
String? budgetImpactSnackText(BudgetImpact? impact) {
  if (impact == null) return null;
  final ten = impact.view.displayName;
  if (impact.exceeds) return 'Đã lưu. Ngân sách $ten đã vượt hạn mức.';
  if (impact.nearLimitAfter) return 'Đã lưu. Ngân sách $ten sắp hết.';
  return null;
}

/// Nội dung hộp thoại xác nhận — có số, vì đây là điểm quyết định.
String budgetImpactDialogText(BudgetImpact impact) {
  return 'Khoản này làm ngân sách ${impact.view.displayName} vượt hạn mức '
      '${CurrencyFormatter.format(impact.exceedsBy)}. Vẫn ghi?';
}
