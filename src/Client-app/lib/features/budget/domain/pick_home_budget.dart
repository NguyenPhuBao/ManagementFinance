import '../data/models/budget_entity.dart';

/// Ngân sách đáng chú ý nhất để đưa lên trang chủ: ngân sách **đang chạy** có
/// tỉ lệ đã chi cao nhất. So theo tỉ lệ chứ không theo số tiền — 150% của
/// 100k căng hơn 95% của 1 triệu. `null` khi không có ngân sách nào đang chạy.
///
/// Thuần Dart, tách khỏi widget để test bằng `expect` thường. Dời từ
/// `home/presentation/widgets/home_budget_card.dart` 2026-10-15 (quét 28: hai gói
/// số `ai_edge/domain` dùng chung hàm này với thẻ Ngân sách của Trang chủ, mà
/// domain không được import một tệp widget).
BudgetView? pickHomeBudget(List<BudgetView> views, DateTime now) {
  BudgetView? best;
  var bestRatio = -1.0;
  for (final v in views) {
    if (v.budget.isExpired(now)) continue;
    final ratio = v.budget.rawPercentSpent;
    if (ratio > bestRatio) {
      best = v;
      bestRatio = ratio;
    }
  }
  return best;
}
