/// Các kỳ gần nhất của một ngân sách — nguồn cho biểu đồ lịch sử.
///
/// Đi lại **đúng** phép cắt kỳ của `BudgetEntity.currentPeriod` (cùng lưới
/// `BudgetEntity.mocKy`, cùng cách cắt ở ngày hết hạn) thay vì tự tính:
/// hai cách cắt lệch nhau một ngày là có giao dịch bị đếm hai lần hoặc không
/// lần nào, và không có exception nào báo.
library;

import '../data/models/budget_entity.dart';

typedef BudgetPeriod = ({DateTime from, DateTime to});

/// Một kỳ đã cộng xong số chi — một cột trên biểu đồ lịch sử.
///
/// [amount] là hạn mức **hiện tại** của ngân sách, kể cả với kỳ đã qua: không
/// có nơi nào lưu hạn mức cũ, và bịa một con số khác là tệ hơn nói thẳng.
class BudgetPeriodSummary {
  final DateTime from;
  final DateTime to;
  final double amount;
  final double spent;

  const BudgetPeriodSummary({
    required this.from,
    required this.to,
    required this.amount,
    required this.spent,
  });

  double get remaining => amount - spent;
  bool get isOverBudget => spent > amount;
}

/// Tối đa [count] kỳ gần nhất, **cũ trước mới sau**, kỳ cuối là kỳ hiện tại
/// (hoặc kỳ cuối cùng nếu ngân sách đã hết hạn). Rỗng khi chưa tới ngày bắt
/// đầu.
List<BudgetPeriod> recentPeriods(
  BudgetEntity b, {
  required int count,
  required DateTime now,
}) {
  if (count <= 0 || now.isBefore(b.startDate)) return const [];

  final current = b.currentPeriod(now);
  // "Ngày cụ thể" là một kỳ duy nhất — không có kỳ trước để liệt kê.
  if (b.timeRecurrence == null && b.endDate != null) return [current];

  final until = b.expiresAt;
  final periods = <BudgetPeriod>[];

  var steps = 0;
  var from = b.startDate;
  var to = b.mocKy(0);
  while (steps < 1000) {
    // Ngày hết hạn cắt ngắn kỳ cuối, y như `currentPeriod`.
    final end = until != null && until.isBefore(to) ? until : to;
    periods.add((from: from, to: end));
    if (!current.from.isAfter(from)) break;
    steps++;
    from = to;
    to = b.mocKy(steps);
  }

  if (periods.length <= count) return periods;
  return periods.sublist(periods.length - count);
}
