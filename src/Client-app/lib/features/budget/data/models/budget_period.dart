/// Số học chu kỳ ngân sách — logic thuần, không phụ thuộc Drift hay giao diện.
///
/// Tách khỏi `BudgetEntity` vì đây là số học lịch: nó không cần biết gì về hạn
/// mức, đồng bộ hay tài khoản, và tách ra thì test được thẳng từng phép tính
/// thay vì phải dựng cả một ngân sách trong CSDL.
///
/// ## Vì sao phải kẹp ngày
///
/// Dart cho ngày tràn: `DateTime(2026, 2, 31)` trả về **03/03/2026** chứ không
/// ném lỗi. Ai đặt ngân sách bắt đầu ngày 31 sẽ gặp chuyện đó ngay ở tháng Hai:
/// nếu để tràn thì kỳ tháng Hai biến mất và mọi giao dịch trong tháng rơi ra
/// ngoài mọi kỳ — không exception, không log.
library;

import 'budget_entity.dart';

/// Ngày [day] của tháng [month]/[year], **kẹp về ngày cuối tháng** nếu tháng đó
/// ngắn hơn.
///
/// [month] được phép nằm ngoài 1–12: `DateTime` tự quy về năm liền kề, nên gọi
/// với `month + 3` hay `month + 12` đều đúng.
DateTime _atDay(int year, int month, int day) {
  // Ngày 0 của tháng kế tiếp chính là ngày cuối của tháng đang xét.
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day < lastDay ? day : lastDay);
}

/// Nhảy [steps] chu kỳ kể từ [anchor].
///
/// Luôn tính từ **mốc gốc**, không cộng dồn từ kết quả của lần nhảy trước: mốc
/// "ngày 31 hàng tháng" bị kẹp về 28 ở tháng Hai, nếu lần sau lại nhảy từ 28
/// thì mốc tụt dần về ngày 28 và không bao giờ quay lại ngày 31.
DateTime advancePeriodFrom({
  required DateTime anchor,
  required int steps,
  required String timeRecurrence,
}) {
  return switch (timeRecurrence) {
    BudgetRecurrence.week => anchor.add(Duration(days: 7 * steps)),
    BudgetRecurrence.quarter =>
      _atDay(anchor.year, anchor.month + 3 * steps, anchor.day),
    BudgetRecurrence.year =>
      _atDay(anchor.year + steps, anchor.month, anchor.day),
    _ => _atDay(anchor.year, anchor.month + steps, anchor.day),
  };
}

/// Nhảy đúng một chu kỳ kể từ [from].
DateTime advancePeriod(DateTime from, String timeRecurrence) =>
    advancePeriodFrom(anchor: from, steps: 1, timeRecurrence: timeRecurrence);
